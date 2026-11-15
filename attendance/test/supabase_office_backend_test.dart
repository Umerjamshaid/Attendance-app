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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

const _user = '20000000-0000-4000-8000-000000000001';
const _a = '10000000-0000-4000-8000-000000000001';
const _b = '10000000-0000-4000-8000-000000000002';

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
    if (path.endsWith('/token')) {
      String part(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final jwt =
          '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': _user, 'aud': 'authenticated', 'role': 'authenticated', 'exp': now + 3600, 'iat': now})}.test-signature';
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
      await auth.backend!.setPassword('new-test-password');
      await auth.refreshSession();
      expect(auth.needsPasswordSetup, isFalse);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser?.authUserId, _user);
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
