import 'dart:convert';

import 'package:attendance/services/launch_failure_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Attendance',
      packageName: 'test.attendance',
      version: '1.1.0',
      buildNumber: '2022',
      buildSignature: '',
    );
  });

  test(
    'posts only release metadata and failure category, without redirects',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('', 202);
      });
      addTearDown(client.close);

      await LaunchFailureReporter.report(
        LaunchFailureReason.initializationTimeout,
        destination: 'https://receiver.example.invalid/startup',
        client: client,
      );

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.followRedirects, isFalse);
      expect(request.headers.containsKey('authorization'), isFalse);
      expect(jsonDecode(request.body), {
        'event': 'attendance_launch_failure',
        'reason': 'initializationTimeout',
        'platform': isA<String>(),
        'version': '1.1.0',
        'build': '2022',
      });
    },
  );

  test('does not send for missing or unsafe destinations', () async {
    var sent = 0;
    final client = MockClient((_) async {
      sent++;
      return http.Response('', 202);
    });
    addTearDown(client.close);
    for (final endpoint in [
      '',
      'http://receiver.example.invalid/startup',
      'https://token@receiver.example.invalid/startup',
      'https://receiver.example.invalid/startup?token=private',
    ]) {
      await LaunchFailureReporter.report(
        LaunchFailureReason.routeTimeout,
        destination: endpoint,
        client: client,
      );
    }
    expect(sent, 0);
  });

  test('a receiver failure never escapes the reporter', () async {
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await expectLater(
      LaunchFailureReporter.report(
        LaunchFailureReason.routeTimeout,
        destination: 'https://receiver.example.invalid/startup',
        client: client,
      ),
      completes,
    );
  });
}
