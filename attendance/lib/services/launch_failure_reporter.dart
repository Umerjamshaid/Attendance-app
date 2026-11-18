import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

enum LaunchFailureReason {
  initializationError,
  initializationTimeout,
  routeTimeout,
}

typedef LaunchFailureSink = Future<void> Function(LaunchFailureReason reason);

abstract final class LaunchFailureReporter {
  static Future<void> report(
    LaunchFailureReason reason, {
    String destination = const String.fromEnvironment(
      'ATTENDANCE_STARTUP_REPORT_URL',
    ),
    http.Client? client,
  }) async {
    final endpoint = Uri.tryParse(destination);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      return;
    }

    final transport = client ?? http.Client();
    try {
      final fields = {
        'event': 'attendance_launch_failure',
        'reason': reason.name,
        'platform': defaultTargetPlatform.name,
      };
      try {
        final info = await PackageInfo.fromPlatform().timeout(
          const Duration(milliseconds: 500),
        );
        fields['version'] = info.version;
        fields['build'] = info.buildNumber;
      } catch (_) {
        // Diagnostics are still useful when platform metadata is unavailable.
      }
      final request = http.Request('POST', endpoint)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(fields);
      final response = await transport
          .send(request)
          .timeout(const Duration(seconds: 4));
      await response.stream.listen(null).cancel();
    } catch (_) {
      // An unavailable receiver must not interfere with the failure screen.
    } finally {
      if (client == null) transport.close();
    }
  }
}
