import 'dart:async';
import 'dart:convert';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/supabase_company_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

const _user = '20000000-0000-4000-8000-000000000001';
const _a = '10000000-0000-4000-8000-000000000001';
const _b = '10000000-0000-4000-8000-000000000002';

class _Server {
  String active = _a;
  String profileName = 'Global profile';
  bool loseSwitchResponse = false, failRestore = false;
  Completer<http.Response>? oldHistory;
  Completer<http.Response>? oldContext;
  final calls = <http.Request>[];
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
    if (path.endsWith('/logout')) return http.Response('', 204);
    throw StateError('Unexpected test request: $request');
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);
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
