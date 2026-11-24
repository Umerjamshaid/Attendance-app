import 'dart:convert';

import 'package:attendance/screens/profile/whats_new_screen.dart';
import 'package:attendance/services/release_notes_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PackageInfo _installed(String build) => PackageInfo(
  appName: 'Attendance',
  packageName: 'attendance.test',
  version: '1.1.0',
  buildNumber: build,
  buildSignature: '',
);

Map<String, Object> _release(
  String tag,
  String body, {
  bool prerelease = false,
}) => {'tag_name': tag, 'body': body, 'draft': false, 'prerelease': prerelease};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Settings renders matching Markdown without loading remote images',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'Attendance',
        packageName: 'attendance.test',
        version: '1.1.1',
        buildNumber: '4028',
        buildSignature: '',
      );
      final service = ReleaseNotesService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode([
              _release(
                'android-1.1.1-4028',
                '### From GitHub\n\n![Remote](https://example.invalid/image.png)\n\n<img src="https://example.invalid/embedded.png">',
              ),
            ]),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        Provider.value(
          value: service,
          child: const MaterialApp(home: WhatsNewScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Version 1.1.1 (Build 4028)'), findsOneWidget);
      expect(find.byType(GptMarkdown), findsOneWidget);
      expect(find.text('From GitHub', findRichText: true), findsOneWidget);
      // The only Image is the bundled Attendance logo above the notes.
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .every((image) => image.image is! NetworkImage),
        isTrue,
      );
    },
  );

  test('only matching tags qualify and the installed build wins', () async {
    var calls = 0;
    final service = ReleaseNotesService(
      client: MockClient((request) async {
        calls++;
        expect(request.url.host, 'api.github.com');
        expect(request.url.path, '/repos/Umerjamshaid/Attendance-app/releases');
        expect(request.headers, isNot(contains('Authorization')));
        return http.Response(
          jsonEncode([
            _release('v2.0.0', 'Newer release'),
            _release('android-1.1.0-4028', 'Uninstalled build'),
            _release('android-1.1.0-4026', 'Prerelease', prerelease: true),
            _release('v1.1.0', 'Version notes'),
            _release('android-1.1.0-4027', '## Installed build'),
          ]),
          200,
        );
      }),
    );
    final exact = service.notesFor(_installed('4027'));
    expect(service.notesFor(_installed('4027')), same(exact));
    expect(await exact, '## Installed build');
    expect(await service.notesFor(_installed('4027')), '## Installed build');
    expect(calls, 1);
    expect(await service.notesFor(_installed('4026')), 'Version notes');
  });

  test(
    'rate limiting preserves cached notes and backs off later requests',
    () async {
      var now = DateTime(2026, 11, 24);
      var calls = 0;
      final client = MockClient((_) async {
        if (++calls > 1) return http.Response('', 429);
        return http.Response(
          jsonEncode([_release('1.1.0', 'Version notes')]),
          200,
        );
      });
      ReleaseNotesService service() =>
          ReleaseNotesService(client: client, now: () => now);
      expect(await service().notesFor(_installed('4027')), 'Version notes');
      now = now.add(const Duration(days: 2));
      expect(await service().notesFor(_installed('4027')), 'Version notes');
      expect(await service().notesFor(_installed('4027')), 'Version notes');
      expect(calls, 2);
      expect(await service().notesFor(_installed('4028')), isNull);
      expect(calls, 3);
    },
  );

  test(
    'never borrows a different build when no version-wide release exists',
    () async {
      final service = ReleaseNotesService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode([_release('android-1.1.0-4024', 'Older build')]),
            200,
          ),
        ),
      );
      expect(await service.notesFor(_installed('4027')), isNull);
    },
  );
}
