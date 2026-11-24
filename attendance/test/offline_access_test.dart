import 'dart:async';
import 'dart:io';

import 'package:attendance/bootstrap.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/screens/profile/settings_sheets.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/network_status.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/services/supabase_company_backend.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:attendance/widgets/home/attendance_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/overview_fonts.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Attendance',
      packageName: 'test.attendance',
      version: '1.1.1',
      buildNumber: '4028',
      buildSignature: '',
    );
  });

  testWidgets(
    'cold offline launch releases the splash and keeps About accessible',
    (tester) async {
      final link = StreamController<bool>.broadcast();
      final connection = NetworkStatus(
        links: link.stream,
        checkLink: () async => false,
        probe: () async => throw StateError('No probe with no link'),
      );
      addTearDown(connection.dispose);
      addTearDown(link.close);
      var ready = false;
      final backend = _OfflineBackend(connection)
        ..wait = Completer<Employee?>();
      runAttendanceApp(backend: backend, onReady: () => ready = true);
      await tester.pumpAndSettle();
      expect(ready, isTrue);
      expect(find.text('You\'re offline'), findsOneWidget);
      expect(find.text(NetworkStatus.offlineMessage), findsOneWidget);
      expect(find.byType(BottomNav), findsNothing);

      await tester.tap(find.text('About app'));
      await tester.pumpAndSettle();
      expect(find.text('Download CV'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'About saves the bundled PDF and confirms only successful saves',
    (tester) async {
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _CvBundle(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAboutApp(context),
                  child: const Text('About app'),
                ),
              ),
            ),
          ),
        ),
      );

      const channel = MethodChannel('flutter_file_dialog');
      final saved = Completer<MethodCall>();
      var cancel = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (cancel) return null;
        saved.complete(call);
        return '/downloads/UmerJamshaid_CV_v2.pdf';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.tap(find.text('About app'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Download CV'));
      final confirmation = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.value == 'Saved',
      );
      await tester.tap(find.text('Download CV'));
      await tester.pumpAndSettle();
      expect(confirmation, findsNothing);
      expect(saved.isCompleted, isFalse);

      cancel = false;
      await tester.tap(find.text('Download CV'));
      await tester.pumpAndSettle();
      expect(saved.isCompleted, isTrue);
      final call = await saved.future;
      expect(call.method, 'saveFile');
      expect(call.arguments['fileName'], 'UmerJamshaid_CV_v2.pdf');
      expect(
        String.fromCharCodes((call.arguments['data'] as List<int>).take(5)),
        '%PDF-',
      );
      expect(find.text('CV saved.'), findsOneWidget);
      expect(confirmation, findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(confirmation, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a signed-in shell stays open and unlocks the History tab when online',
    (tester) async {
      final link = StreamController<bool>.broadcast();
      final connection = NetworkStatus(
        links: link.stream,
        checkLink: () async => true,
        probe: () async => true,
      );
      addTearDown(connection.dispose);
      addTearDown(link.close);
      await tester.pumpWidget(const SizedBox.shrink());
      runAttendanceApp(backend: _OfflineBackend(connection), onReady: () {});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BottomNav), findsOneWidget);
      link.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<AttendanceButton>(find.byType(AttendanceButton))
            .isUploadEnabled,
        isFalse,
      );
      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();
      expect(find.text('Available when you’re back online.'), findsOneWidget);
      link.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Available when you’re back online.'), findsNothing);
      expect(find.byType(BottomNav), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('offline backend actions stop before sending a request', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final connection = NetworkStatus(
      links: const Stream.empty(),
      checkLink: () async => false,
      probe: () async => true,
    );
    addTearDown(connection.dispose);
    var requests = 0;
    final client = SupabaseClient(
      'https://example.invalid',
      'anon',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((_) async {
        requests++;
        return http.Response('{}', 500);
      }),
    );
    addTearDown(client.dispose);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      SupabaseCompanyBackend(client, connection: connection).employees(),
      throwsA(
        isA<CompanyException>().having(
          (e) => e.message,
          'message',
          NetworkStatus.offlineMessage,
        ),
      ),
    );
    expect(requests, 0);
  });
}

class _CvBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => key == 'assets/UmerJamshaid_CV_v2.pdf'
      ? SynchronousFuture(ByteData.sublistView(File(key).readAsBytesSync()))
      : rootBundle.load(key);
}

class _OfflineBackend extends PreviewCompanyBackend {
  _OfflineBackend(this.connectionStatus);
  @override
  final NetworkStatus connectionStatus;
  Completer<Employee?>? wait;

  @override
  bool get isPreview => false;

  @override
  CompanyBackend forOffice(Employee employee) => this;

  @override
  Future<Employee?> restoreSession() async =>
      wait?.future ?? super.restoreSession();
}
