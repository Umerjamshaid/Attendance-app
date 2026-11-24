import 'dart:async';
import 'dart:convert';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/models/office_model.dart';
import 'package:attendance/services/supabase_company_backend.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

const _user = '20000000-0000-4000-8000-000000000001';
const _a = '10000000-0000-4000-8000-000000000001';
const _b = '10000000-0000-4000-8000-000000000002';
const _sessionId = '30000000-0000-4000-8000-000000000001';

Future<void> _recover(SupabaseClient client) async {
  final session = client.auth.currentSession!;
  await client.auth.getSessionFromUrl(
    Uri(
      scheme: 'workcheck',
      host: 'auth',
      path: '/callback',
      queryParameters: {
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken!,
        'expires_in': '3600',
        'token_type': 'bearer',
        'type': 'recovery',
      },
    ),
  );
}

class _Server {
  String active = _a;
  String profileName = 'Global profile';
  bool loseSwitchResponse = false, failRestore = false;
  Completer<http.Response>? oldHistory;
  Completer<http.Response>? oldContext;
  Completer<http.Response>? oldAvatar;
  final avatarPaths = <String, String?>{};
  final calls = <http.Request>[];
  bool rejectPassword = false;
  bool rejectCode = false;
  String sessionId = _sessionId;
  bool rejectLogo = false;
  bool activityAvailable = true;
  Completer<void>? activityGate;
  String? bannerPath;
  Map<String, dynamic> employee(String org) => {
    'id': 'SAME_CODE',
    'authUserId': _user,
    'organizationId': org,
    'officeName': org == _a ? 'Office A' : 'Office B',
    'name': profileName,
    'email': 'test@example.invalid',
    'role': org == _a ? 'admin' : 'employee',
    'department': 'Engineering',
  };
  Map<String, dynamic> record(String org) => {
    'id': 'record-$org',
    'organization_id': org,
    'employee_code': 'SAME_CODE',
    'received_at': '2026-11-13T06:00:00Z',
    'device_model': 'Test device',
  };
  http.Response json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    request: calls.last,
    headers: {'content-type': 'application/json'},
  );
  Future<http.Response> handle(http.Request request) async {
    calls.add(request);
    final path = request.url.path;
    if (path.endsWith('/office_check_in_activity')) {
      if (!activityAvailable) {
        return json({'code': 'PGRST202', 'message': 'Function missing'}, 404);
      }
      final params = jsonDecode(request.body) as Map;
      if (params['p_organization'] != active || active != _a) {
        return json({'code': '42501', 'message': 'office_admin_required'}, 403);
      }
      await activityGate?.future;
      return json([
        {
          'id': 'activity-record',
          'employee_name': 'Sample employee',
          'received_at': '2026-11-19T04:10:00Z',
          'office_timezone': 'Asia/Karachi',
        },
      ]);
    }
    if (path.endsWith('/my_offices')) {
      return json([
        for (final id in [_a, _b])
          {
            'id': id,
            'name': 'Office $id',
            'role': 'employee',
            'logo_path': '$id/logo-current.png',
          },
      ]);
    }
    if (path.endsWith('/object/sign/office-logos')) {
      return json([
        for (final object in (jsonDecode(request.body) as Map)['paths'] as List)
          {
            'path': object,
            'signedURL': '/object/sign/office-logos/$object?token=test-token',
          },
      ]);
    }
    if (path.contains('/object/sign/office-logos/')) {
      if (rejectLogo) return json({'message': 'Access denied'}, 403);
      return json({
        'signedURL': '${path.replaceFirst('/storage/v1', '')}?token=renewed',
      });
    }
    if (path.contains('/object/office-logos/')) {
      return json({'Key': path.split('/object/').last});
    }
    if (path.endsWith('/update_office_fields')) return json(null);
    if (path.endsWith('/user')) {
      if (rejectPassword) {
        return json({'code': 'weak_password', 'msg': 'Test rejection'}, 422);
      }
      return json({
        'id': _user,
        'email': 'test@example.invalid',
        'aud': 'authenticated',
        'role': 'authenticated',
        'created_at': '2026-11-01T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {'password_set': true},
      });
    }
    if (path.endsWith('/token') || path.endsWith('/verify')) {
      if (path.endsWith('/verify') && rejectCode) {
        return json({'error_code': 'otp_expired', 'msg': 'Test expiry'}, 403);
      }
      String part(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final jwt =
          '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': _user, 'aud': 'authenticated', 'role': 'authenticated', 'exp': now + 3600, 'iat': now, 'session_id': sessionId})}.dGVzdA';
      return json({
        'access_token': jwt,
        'refresh_token': 'test-refresh',
        'expires_in': 3600,
        'token_type': 'bearer',
        'user': {
          'id': _user,
          'email': 'test@example.invalid',
          'aud': 'authenticated',
          'role': 'authenticated',
          'created_at': '2026-11-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {'password_set': true},
        },
      });
    }
    if (path.endsWith('/resolve_office_context')) {
      if (oldContext != null) return oldContext!.future;
      if (failRestore) {
        return json({'code': 'XX000', 'message': 'Test outage'}, 503);
      }
      return json(employee(active));
    }
    if (path.endsWith('/switch_office')) {
      active = (jsonDecode(request.body) as Map)['p_organization'] as String;
      if (loseSwitchResponse) {
        return json({'code': 'XX000', 'message': 'Test lost response'}, 503);
      }
      return json(employee(active));
    }
    if (path.endsWith('/organizations')) {
      final id = request.url.queryParameters['id']!.substring(3);
      return json({
        'id': id,
        'window_mode': 'always',
        'start_hour': 7,
        'end_hour': 13,
        'timezone': id == _a ? 'Asia/Karachi' : 'Etc/UTC',
      });
    }
    if (path.endsWith('/check_ins')) {
      final id = request.url.queryParameters['organization_id']!.substring(3);
      if (id == _a && oldHistory != null) return oldHistory!.future;
      return json([record(id)]);
    }
    if (path.endsWith('/profiles')) {
      if (request.url.queryParameters['select'] == 'avatar_path,banner_path') {
        return json({
          'avatar_path': avatarPaths[_user],
          'banner_path': bannerPath,
        });
      }
      if (request.url.queryParameters['select'] == 'user_id,avatar_path') {
        return oldAvatar?.future ??
            json([
              for (final entry in avatarPaths.entries)
                {'user_id': entry.key, 'avatar_path': entry.value},
            ]);
      }
      if (request.method == 'PATCH') {
        profileName = (jsonDecode(request.body) as Map)['name'] as String;
      }
      return json({'name': profileName, 'headline': '', 'chips': <String>[]});
    }
    if (path.endsWith('/submit-attendance')) {
      return json({
        'record': record(
          (jsonDecode(request.body) as Map)['organization_id'] as String,
        ),
      });
    }
    if (path.endsWith('/attendance-evidence')) {
      return json({'latitude': 31.5, 'longitude': 74.3});
    }
    if (path.endsWith('/company_employees')) {
      return json([
        employee((jsonDecode(request.body) as Map)['p_organization'] as String),
      ]);
    }
    if (path.endsWith('/object/sign/profile-media')) {
      return json([
        for (final object in (jsonDecode(request.body) as Map)['paths'] as List)
          if ((object as String).endsWith('missing.png'))
            {'path': object, 'error': 'Object not found'}
          else
            {
              'path': object,
              'signedURL':
                  '/object/sign/profile-media/$object?token=test-token',
            },
      ]);
    }
    if (path.endsWith('/logout')) return http.Response('', 204);
    throw StateError('Unexpected test request: $request');
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);
  test(
    'office logos use one signing batch and renew within authorized account scope',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final me = await root.signIn('test@example.invalid', 'test-password');
      final backend = root.forAccount(me);
      final offices = await backend.offices();
      expect(offices.length, 2);
      expect(
        offices.every((office) => office.logoUrl!.contains('token=test-token')),
        isTrue,
      );
      final batch = server.calls.where(
        (c) => c.url.path.endsWith('/object/sign/office-logos'),
      );
      expect(batch.length, 1);
      expect((jsonDecode(batch.single.body) as Map)['paths'], [
        '$_a/logo-current.png',
        '$_b/logo-current.png',
      ]);
      await root.switchOffice(_b);
      final url = offices.first.logoUrl!;
      expect(await backend.refreshOfficeLogo(url), contains('token=renewed'));
      final uploadedUrls = <String>[];
      for (final image in [
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2Q==',
      ]) {
        await backend.updateOffice(offices.first, logo: base64Decode(image));
        final path =
            (jsonDecode(server.calls.last.body) as Map)['p_logo'] as String;
        final uploaded = Uri.parse(url)
            .replace(path: '/storage/v1/object/sign/office-logos/$path')
            .toString();
        uploadedUrls.add(uploaded);
        expect(
          await backend.refreshOfficeLogo(uploaded),
          contains('$path?token=renewed'),
        );
      }
      expect(uploadedUrls[0], contains('.png?'));
      expect(uploadedUrls[1], contains('.jpg?'));
      final before = server.calls.length;
      await expectLater(
        backend.refreshOfficeLogo(
          url.replaceFirst(
            'office-backend.example.invalid',
            'foreign.example.invalid',
          ),
        ),
        throwsA(isA<CompanyException>()),
      );
      for (final invalid in [
        url.replaceFirst('logo-current.png', 'not-a-uuid.png'),
        uploadedUrls.first.replaceFirst('.png?', '.gif?'),
        url.replaceFirst('logo-current.png', 'nested/logo-current.png'),
        url.replaceFirst('/office-logos/', '/profile-media/'),
      ]) {
        await expectLater(
          backend.refreshOfficeLogo(invalid),
          throwsA(isA<CompanyException>()),
        );
      }
      expect(server.calls.length, before);
      server.rejectLogo = true;
      for (final denied in [url, ...uploadedUrls]) {
        await expectLater(
          backend.refreshOfficeLogo(denied),
          throwsA(isA<CompanyException>()),
        );
      }
    },
  );
  test(
    'image renewal batches visible objects and keeps account/office boundaries',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final employee = await root.signIn(
        'test@example.invalid',
        'test-password',
      );
      final office = root.forOffice(employee);
      const colleague = '20000000-0000-4000-8000-000000000002';
      String image(String user, String kind) =>
          'https://office-backend.example.invalid/storage/v1/object/sign/profile-media/$user/$kind-old.gif?token=expired';
      final results = await Future.wait([
        office.refreshProfileImage(image(_user, 'avatar')),
        office.refreshProfileImage(image(colleague, 'avatar')),
        office.refreshProfileImage(image(colleague, 'avatar')),
      ]);
      expect(results.every((url) => url!.contains('token=test-token')), isTrue);
      final signing = server.calls
          .where((call) => call.url.path.endsWith('/object/sign/profile-media'))
          .toList();
      expect(signing.length, 1);
      expect((jsonDecode(signing.single.body) as Map)['paths'], [
        '$_user/avatar-old.gif',
        '$colleague/avatar-old.gif',
      ]);
      await expectLater(
        root
            .forAccount(employee)
            .refreshProfileImage(image(colleague, 'avatar')),
        throwsA(isA<CompanyException>()),
      );
      await expectLater(
        office.refreshProfileImage(image(colleague, 'banner')),
        throwsA(isA<CompanyException>()),
      );
      await expectLater(
        office.refreshProfileImage(
          image(_user, 'avatar').replaceFirst(
            'office-backend.example.invalid',
            'other.example.invalid',
          ),
        ),
        throwsA(isA<CompanyException>()),
      );
      final stale = office.refreshProfileImage(image(_user, 'avatar'));
      final assertion = expectLater(stale, throwsA(isA<CompanyException>()));
      await root.switchOffice(_b);
      await assertion;
    },
  );
  test(
    'activity coalesces overlapping reads and rejects late office results',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final old = root.forOffice(
        await root.signIn('test@example.invalid', 'test-password'),
      );
      final before = server.calls.length;
      final gate = server.activityGate = Completer<void>();
      final first = old.checkInActivity();
      final joined = old.checkInActivity();
      await Future<void>.delayed(Duration.zero);
      expect(server.calls.length, before + 1);
      expect(jsonDecode(server.calls.last.body), {'p_organization': _a});
      gate.complete();
      final row = (await first).single;
      expect((await joined).single, same(row));
      expect(row.id, 'activity-record');
      expect(row.employeeName, 'Sample employee');
      expect(row.receivedAt.hour, 9);
      expect(row.receivedAt.minute, 10);

      server.activityAvailable = false;
      await expectLater(
        old.checkInActivity(),
        throwsA(
          isA<CompanyException>().having(
            (error) => error.message,
            'message',
            contains('not set up'),
          ),
        ),
      );
      server.activityAvailable = true;
      final lateGate = server.activityGate = Completer<void>();
      final stale = expectLater(
        old.checkInActivity(),
        throwsA(isA<CompanyException>()),
      );
      await Future<void>.delayed(Duration.zero);
      final next = root.forOffice(await root.switchOffice(_b));
      lateGate.complete();
      await stale;
      await expectLater(
        next.checkInActivity(),
        throwsA(isA<CompanyAccessException>()),
      );
      final afterSwitch = server.calls.length;
      await expectLater(
        old.checkInActivity(),
        throwsA(isA<CompanyException>()),
      );
      expect(server.calls.length, afterSwitch);
    },
  );

  testWidgets('activity times out and can retry before a late reply', (
    tester,
  ) async {
    final server = _Server();
    final office = (await tester.runAsync(() async {
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      return root.forOffice(
        await root.signIn('test@example.invalid', 'test-password'),
      );
    }))!;
    final gate = server.activityGate = Completer<void>();
    Object? error;
    unawaited(
      office.checkInActivity().then<void>(
        (_) {},
        onError: (Object failure) {
          error = failure;
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 14));
    expect(error, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(
      error,
      isA<CompanyException>().having(
        (error) => error.message,
        'message',
        contains('took too long'),
      ),
    );

    server.activityGate = null;
    final retry = await tester.runAsync(office.checkInActivity);
    expect(retry!.single.id, 'activity-record');
    gate.complete();
    await tester.pump();
  });

  test('office actions send only the field being changed', () async {
    final server = _Server();
    final client = SupabaseClient(
      'https://office-backend.example.invalid',
      'test-publishable-key',
      httpClient: MockClient(server.handle),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final root = SupabaseCompanyBackend(client);
    final employee = await root.signIn('test@example.invalid', 'test-password');
    final backend = root.forAccount(employee);
    const stale = Office(
      id: _a,
      name: 'Old name',
      role: 'admin',
      logoPath: 'old-logo.png',
    );
    await backend.updateOffice(stale, name: 'New name');
    expect(jsonDecode(server.calls.last.body), {
      'p_organization': _a,
      'p_name': 'New name',
    });
    await backend.updateOffice(stale, removeLogo: true);
    expect(jsonDecode(server.calls.last.body), {
      'p_organization': _a,
      'p_change_logo': true,
      'p_logo': null,
    });
  });
  test(
    'AuthProvider leaves password setup after a successful scoped update',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      await root.signIn('test@example.invalid', 'test-password');
      final auth = AuthProvider(backend: root);
      addTearDown(auth.dispose);
      await auth.refreshSession();
      await _recover(client);
      await auth.refreshSession();
      expect(auth.needsPasswordSetup, isTrue);
      server.oldContext = Completer<http.Response>();
      await auth.finishPasswordSetup('new-test-password');
      expect(auth.needsPasswordSetup, isFalse);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.authUserId, _user);
      server.oldContext!.complete(server.json(server.employee(_a)));
    },
  );
  test('recovery is restored only for the pending Supabase session', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final server = _Server();
    SupabaseClient makeClient() => SupabaseClient(
      'https://office-backend.example.invalid',
      'test-publishable-key',
      httpClient: MockClient(server.handle),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final client = makeClient();
    addTearDown(client.dispose);
    final source = SupabaseCompanyBackend(client, preferences: preferences);
    final auth = AuthProvider(backend: source);
    addTearDown(auth.dispose);
    await source.signIn('test@example.invalid', 'old-test-password');
    final recoveryEvent = source.authChanges.firstWhere(
      (_) => source.needsPasswordSetup,
    );
    await _recover(client);
    await recoveryEvent;
    expect(source.needsPasswordSetup, isTrue);

    final reopened = makeClient();
    addTearDown(reopened.dispose);
    await reopened.auth.setInitialSession(
      jsonEncode(client.auth.currentSession!.toJson()),
    );
    final restored = SupabaseCompanyBackend(reopened, preferences: preferences);
    expect(restored.needsPasswordSetup, isTrue);
    server.sessionId = '30000000-0000-4000-8000-000000000002';
    await restored.signIn('test@example.invalid', 'old-test-password');
    expect(restored.needsPasswordSetup, isFalse);

    await reopened.auth.setInitialSession(
      jsonEncode(client.auth.currentSession!.toJson()),
    );
    expect(restored.needsPasswordSetup, isTrue);
    await restored.setPassword('new-test-password');
    expect(
      SupabaseCompanyBackend(
        reopened,
        preferences: preferences,
      ).needsPasswordSetup,
      isFalse,
    );
  });
  test(
    'email codes verify only through the matching Supabase OTP flow',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final subscription = root.authChanges.listen((_) {});
      addTearDown(subscription.cancel);
      server.rejectCode = true;
      await expectLater(
        root.verifyEmailCode(
          'test@example.invalid',
          '111111',
          CompanyEmailCode.invitation,
        ),
        throwsA(
          isA<CompanyException>().having(
            (e) => e.message,
            'message',
            contains('no longer usable'),
          ),
        ),
      );
      expect(client.auth.currentSession, isNull);
      server.rejectCode = false;
      await root.verifyEmailCode(
        'test@example.invalid',
        '222222',
        CompanyEmailCode.invitation,
      );
      expect((jsonDecode(server.calls.last.body) as Map)['type'], 'invite');
      await root.verifyEmailCode(
        'test@example.invalid',
        '333333',
        CompanyEmailCode.recovery,
      );
      expect((jsonDecode(server.calls.last.body) as Map)['type'], 'recovery');
      await Future<void>.delayed(Duration.zero);
      expect(root.needsPasswordSetup, isTrue);
    },
  );
  test(
    'profile avatar and banner are signed in one request with missing-media fallback',
    () async {
      final server = _Server()..bannerPath = '$_user/banner-current.png';
      server.avatarPaths[_user] = '$_user/avatar-current.gif';
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final me = await root.signIn('test@example.invalid', 'test-password');
      final media = await root.forAccount(me).profileMedia();
      expect(media['avatar'], contains('/avatar-current.gif?token='));
      expect(media['banner'], contains('/banner-current.png?token='));
      final calls = server.calls.where(
        (c) => c.url.path.endsWith('/object/sign/profile-media'),
      );
      expect(calls.length, 1);
      expect((jsonDecode(calls.single.body) as Map)['paths'], [
        '$_user/avatar-current.gif',
        '$_user/banner-current.png',
      ]);
      server.bannerPath = '$_user/banner-missing.png';
      final partial = await root.forAccount(me).profileMedia();
      expect(partial['avatar'], isNotNull);
      expect(partial['banner'], isNull);
      expect(
        partial.containsKey('banner'),
        isFalse,
        reason: 'failed signing must not masquerade as a removed banner',
      );
      server.avatarPaths.clear();
      server.bannerPath = null;
      final before = server.calls.length;
      expect(await root.forAccount(me).profileMedia(), {
        'avatar': null,
        'banner': null,
      });
      expect(
        server.calls.length,
        before + 1,
        reason: 'empty profiles do not need signing',
      );
    },
  );
  test(
    'scoped password reset clears the root recovery gate without restart',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final subscription = root.authChanges.listen((_) {});
      addTearDown(subscription.cancel);
      final me = await root.signIn('test@example.invalid', 'test-password');
      final office = root.forOffice(me);
      final account = root.forAccount(me);
      await _recover(client);
      await Future<void>.delayed(Duration.zero);
      expect(root.needsPasswordSetup, isTrue);
      server.rejectPassword = true;
      await expectLater(
        office.setPassword('new-test-password'),
        throwsA(isA<CompanyException>()),
      );
      expect(root.needsPasswordSetup, isTrue);
      server.rejectPassword = false;
      await office.setPassword('new-test-password');
      expect(root.needsPasswordSetup, isFalse);
      expect(account.needsPasswordSetup, isFalse);
      expect(client.auth.currentSession, isNotNull);
      expect((await root.restoreSession())?.authUserId, _user);
      expect(
        jsonDecode(server.calls.firstWhere((c) => c.method == 'PUT').body),
        {
          'password': 'new-test-password',
          'data': {'password_set': true},
        },
      );
    },
  );
  test(
    'employee avatars use private short-lived URLs, UUID ownership and office scope',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final me = await root.signIn('test@example.invalid', 'test-password');
      final backend = root.forOffice(me);
      final colleague = Employee.fromMap(
        server.employee(_a),
      ).copyWith(authUserId: '20000000-0000-4000-8000-000000000002');
      expect(await backend.employeeAvatars([colleague]), isEmpty);
      server.avatarPaths[colleague.authUserId!] = null;
      expect(await backend.employeeAvatars([colleague]), {
        colleague.authUserId!: null,
      });
      expect(
        server.calls.where((c) => c.url.path.contains('/object/sign/')),
        isEmpty,
      );
      final path = '${colleague.authUserId}/avatar-current.gif';
      server.avatarPaths[colleague.authUserId!] = path;
      final missing = colleague.copyWith(
        authUserId: '20000000-0000-4000-8000-000000000003',
      );
      server.avatarPaths[missing.authUserId!] =
          '${missing.authUserId}/avatar-missing.png';
      final urls = await backend.employeeAvatars([colleague, missing]);
      expect(
        urls[colleague.authUserId],
        contains('/storage/v1/object/sign/profile-media/$path'),
      );
      expect(
        urls.containsKey(missing.authUserId),
        isFalse,
        reason: 'missing avatar does not fail other photos',
      );
      final profile = server.calls.lastWhere(
        (c) => c.url.path.endsWith('/profiles'),
      );
      expect(profile.url.queryParameters['select'], 'user_id,avatar_path');
      expect(
        profile.url.queryParameters['user_id'],
        allOf(
          startsWith('in.'),
          contains(colleague.authUserId!),
          contains(missing.authUserId!),
        ),
      );
      expect(jsonDecode(server.calls.last.body)['expiresIn'], 60);
      expect((jsonDecode(server.calls.last.body)['paths'] as List).length, 2);
      final count = server.calls.length;
      await expectLater(
        backend.employeeAvatars([colleague.copyWith(organizationId: _b)]),
        throwsA(isA<CompanyException>()),
      );
      expect(server.calls.length, count);
      server.avatarPaths.clear();
      server.avatarPaths[colleague.authUserId!] =
          'wrong-user/avatar-current.png';
      expect(await backend.employeeAvatars([colleague]), isEmpty);
      server.oldAvatar = Completer<http.Response>();
      final pending = backend.employeeAvatars([colleague]);
      await Future<void>.delayed(Duration.zero);
      await root.switchOffice(_b);
      final rejected = expectLater(pending, throwsA(isA<CompanyException>()));
      server.oldAvatar!.complete(
        server.json([
          {'user_id': colleague.authUserId, 'avatar_path': path},
        ]),
      );
      await rejected;
      expect(
        server.calls.where((c) => c.url.path.contains('/object/sign/')).length,
        1,
        reason: 'late old-office profile response cannot mint a signed URL',
      );
    },
  );
  test(
    'real backend scopes history, policies, employees, upload and evidence without retargeting old requests',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final first = await root.signIn('test@example.invalid', 'test-password');
      final account = root.forAccount(first);
      final old = root.forOffice(first);
      expect(
        (await old.history()).single.timestamp.hour,
        11,
        reason: 'office timezone, not device/default timezone',
      );
      server.oldHistory = Completer<http.Response>();
      final pending = old.history();
      await Future<void>.delayed(Duration.zero);
      final next = root.forOffice(await root.switchOffice(_b));
      final late = expectLater(pending, throwsA(isA<CompanyException>()));
      server.oldHistory!.complete(server.json([server.record(_a)]));
      await late;
      expect((await next.history()).single.timestamp.hour, 6);
      expect((await next.employees()).single.organizationId, _b);
      final saved = await next.submit(
        requestId: '30000000-0000-4000-8000-000000000001',
        base64Image: 'test-image',
        latitude: 31.5,
        longitude: 74.3,
        accuracy: 5,
        capturedAt: DateTime.now(),
        installationId: '40000000-0000-4000-8000-000000000001',
        deviceModel: 'Test',
        platform: 'android',
      );
      expect(saved.id, 'record-$_b');
      await next.evidence('test-record');
      for (final request in server.calls.where(
        (call) => call.url.path.contains('/functions/'),
      )) {
        expect((jsonDecode(request.body) as Map)['organization_id'], _b);
      }
      expect(
        account.validateContext,
        returnsNormally,
        reason: 'global profile scope survives office switches',
      );
      final profile = await account.updateProfile(
        name: 'Updated global profile',
      );
      expect(profile.name, 'Updated global profile');
      expect(
        server.active,
        _b,
        reason: 'editing an account profile must not switch its office',
      );
      final before = server.calls.length;
      await expectLater(
        old.evidence('old-record'),
        throwsA(isA<CompanyException>()),
      );
      expect(
        server.calls.length,
        before,
        reason: 'stale scopes must not even send an HTTP request',
      );
    },
  );

  test(
    'ambiguous switch blocks old requests until an authenticated context is recovered',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final first = await root.signIn('test@example.invalid', 'test-password');
      final old = root.forOffice(first);
      server.loseSwitchResponse = true;
      await expectLater(
        root.switchOffice(_b),
        throwsA(isA<CompanyException>()),
      );
      final blocked = root.forOffice(first);
      expect(blocked.validateContext, throwsA(isA<CompanyException>()));
      expect(old.validateContext, throwsA(isA<CompanyException>()));
      final restored = (await root.restoreSession())!;
      expect(restored.organizationId, _b);
      expect(root.forOffice(restored).validateContext, returnsNormally);
      await root.signOut();
      expect(
        root.forAccount(restored).validateContext,
        throwsA(isA<CompanyAccessException>()),
      );
    },
  );
  test(
    'a session refresh begun before a switch cannot poison the new request scope',
    () async {
      final server = _Server();
      final client = SupabaseClient(
        'https://office-backend.example.invalid',
        'test-publishable-key',
        httpClient: MockClient(server.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final root = SupabaseCompanyBackend(client);
      final first = await root.signIn('test@example.invalid', 'test-password');
      root.forOffice(first);
      server.oldContext = Completer<http.Response>();
      final old = root.restoreSession();
      await Future<void>.delayed(Duration.zero);
      final next = root.forOffice(await root.switchOffice(_b));
      final rejected = expectLater(old, throwsA(isA<CompanyException>()));
      server.oldContext!.complete(server.json(server.employee(_a)));
      await rejected;
      expect(next.validateContext, returnsNormally);
      expect((await next.history()).single.id, 'record-$_b');
    },
  );
}
