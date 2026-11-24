import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/admin/employee_management_screen.dart';
import 'package:attendance/screens/login/office_code_screen.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/invite_email_activity.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/admin/invite_email_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portal_labs/portal_labs.dart' as portal;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

class _InviteBackend extends PreviewCompanyBackend {
  static const code = 'ABCD EFGH JKLM NPQR';
  final recipients = <(String, String)>[];
  CompanyException? emailError = const InvitationRateLimitException();
  bool emailSent = false;
  bool live = false;

  @override
  bool get isPreview => !live;
  @override
  bool get supportsOfficeInviteCodes => true;
  @override
  _InviteBackend forOffice(Employee employee) => this;

  @override
  Future<bool> invite({
    required String email,
    required String name,
    required String employeeCode,
    required String department,
  }) async {
    if (emailError case final error?) throw error;
    return emailSent;
  }

  @override
  Future<String> createOfficeInviteCode({
    required String email,
    required String name,
    required String employeeCode,
    required String department,
  }) async {
    recipients.add((email, employeeCode));
    return code;
  }
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final dark in [false, true]) {
    testWidgets(
      'invite form ${dark ? 'dark' : 'light'} and small keyboard layout',
      (tester) async {
        final backend = _InviteBackend();
        final auth = AuthProvider(backend: backend);
        addTearDown(auth.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: auth,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? AppTheme.darkTheme : AppTheme.theme,
              home: const InviteEmployeeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/invite_employee_${dark ? 'dark' : 'light'}.png',
          ),
        );

        tester.view.physicalSize = const Size(320, 650);
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final methods = find.byType(RadioListTile<bool>);
        await tester.pumpAndSettle();
        expect(methods, findsNWidgets(2));
        await tester.ensureVisible(find.text('Office code'));
        await tester.tap(find.text('Office code'));
        await tester.pumpAndSettle();
        final create = find.widgetWithText(FilledButton, 'Create office code');
        await tester.ensureVisible(create);
        await tester.pumpAndSettle();
        await tester.tap(create);
        await tester.pumpAndSettle();
        final firstField = find.byType(TextFormField).first;
        expect(firstField.hitTestable(), findsOneWidget);
        expect(find.text('Required'), findsNWidgets(4));
        expect(backend.recipients, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('email limit sheet keeps the form for another attempt', (
    tester,
  ) async {
    final backend = _InviteBackend();
    final auth = AuthProvider(backend: backend);
    addTearDown(auth.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 650);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(home: InviteEmployeeScreen()),
      ),
    );
    final fields = find.byType(TextFormField);
    const details = ['New Member', 'member@example.invalid', 'emp9', 'Design'];
    for (var i = 0; i < details.length; i++) {
      await tester.enterText(fields.at(i), details[i]);
    }
    final send = find.widgetWithText(FilledButton, 'Send invitation');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Email limit reached'), findsOneWidget);
    expect(find.textContaining('Try again later.'), findsOneWidget);

    await tester.tap(find.text('Back to invitation'));
    await tester.pumpAndSettle();
    for (var i = 0; i < details.length; i++) {
      expect(
        tester.widget<TextFormField>(fields.at(i)).controller!.text,
        details[i],
      );
    }
    backend.emailError = const CompanyException('Invitation delivery failed.');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Email limit reached'), findsNothing);
    expect(find.text('Invitation delivery failed.'), findsOneWidget);
  });

  testWidgets('the second confirmed send opens recent email activity', (
    tester,
  ) async {
    const capture = String.fromEnvironment('ATTENDANCE_INVITE_PREVIEW');
    const captureSurface = ValueKey('invite-activity-preview');
    if (capture.isNotEmpty) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 12);
      addTearDown(tester.view.reset);
    }
    final backend = _InviteBackend()
      ..live = true
      ..emailError = null;
    final auth = AuthProvider(backend: backend);
    await auth.refreshSession();
    addTearDown(auth.dispose);
    final activity = InviteEmailActivity(auth.currentUser!.authUserId);
    if (capture.isEmpty) {
      await activity.recent(recordSend: true);
    } else {
      final earlier = DateTime.now().subtract(
        const Duration(minutes: 37, seconds: 15),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'invite_email_sends:${auth.currentUser!.authUserId}',
        [earlier.millisecondsSinceEpoch.toString()],
      );
    }
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          theme: capture.isEmpty ? null : AppTheme.darkTheme,
          builder: capture.isEmpty
              ? null
              : (_, child) =>
                    RepaintBoundary(key: captureSurface, child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const InviteEmployeeScreen(),
                  ),
                ),
                child: const Text('Open invitation'),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> send() async {
      await tester.tap(find.text('Open invitation'));
      await tester.pumpAndSettle();
      if (!backend.emailSent) {
        final activityButton = find.text('Recent email activity');
        await tester.ensureVisible(activityButton);
        await tester.pumpAndSettle();
        await tester.tap(activityButton);
        await tester.pumpAndSettle();
        final count = find.byKey(const ValueKey('invite-send-count'));
        expect(tester.widget<portal.PremiumFlipCounter>(count).value, '1');
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      }
      final fields = find.byType(TextFormField);
      const details = [
        'New Member',
        'member@example.invalid',
        'emp9',
        'Design',
      ];
      for (var i = 0; i < details.length; i++) {
        await tester.enterText(fields.at(i), details[i]);
      }
      final submit = find.widgetWithText(FilledButton, 'Send invitation');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
    }

    await send();
    expect(find.byType(InviteEmailMeter), findsNothing);
    expect(await activity.recent(), hasLength(1));
    backend.emailSent = true;
    await send();
    expect(find.text('Invitation sent'), findsOneWidget);
    expect(
      find.textContaining('not the shared email allowance'),
      findsOneWidget,
    );
    expect(find.byType(portal.PremiumFlipCounter), findsNWidgets(2));
    if (capture.isNotEmpty) {
      await expectLater(
        find.byKey(captureSurface),
        matchesGoldenFile(Uri.file(capture)),
      );
    }
    expect(await InviteEmailActivity('different-admin').recent(), isEmpty);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(InviteEmployeeScreen), findsNothing);
    expect(await activity.recent(), hasLength(2));
  });

  testWidgets('the countdown rolls each send out of the last hour', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 25, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteEmailMeter(
            now: () => now,
            sentAt: [
              now.subtract(const Duration(minutes: 59, seconds: 57)),
              now.subtract(const Duration(minutes: 59, seconds: 55)),
            ],
          ),
        ),
      ),
    );
    final count = find.byKey(const ValueKey('invite-send-count'));
    final timer = find.byKey(const ValueKey('invite-time-left'));
    dynamic value(Finder finder) =>
        tester.widget<portal.PremiumFlipCounter>(finder).value;
    expect(value(count), '2');
    expect(value(timer), '00:03');
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(value(timer), '00:02');
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(value(count), '1');
    expect(value(timer), '00:02');
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(value(count), '0');
    expect(find.text('Oldest send clears in'), findsNothing);
  });

  testWidgets('admin can reveal and copy a code without sending email', (
    tester,
  ) async {
    final backend = _InviteBackend();
    final auth = AuthProvider(backend: backend);
    addTearDown(auth.dispose);
    String? clipboard;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(home: InviteEmployeeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Send invitation'),
      findsOneWidget,
    );
    await tester.tap(find.text('Office code'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    for (final (index, value) in [
      (0, 'New Member'),
      (1, 'member@example.invalid'),
      (2, 'emp9'),
      (3, 'Engineering'),
    ]) {
      await tester.enterText(fields.at(index), value);
    }
    final create = find.widgetWithText(FilledButton, 'Create office code');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(backend.recipients, [('member@example.invalid', 'EMP9')]);
    expect(find.text('Office code ready'), findsOneWidget);
    expect(find.text('member@example.invalid'), findsOneWidget);
    expect(find.text(_InviteBackend.code), findsNothing);
    final action = find.byKey(const ValueKey('reveal_copy_action_button'));
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text(_InviteBackend.code), findsOneWidget);
    await tester.tap(action);
    await tester.pump();
    expect(clipboard, _InviteBackend.code);
    await tester.pump(const Duration(seconds: 14));
    await tester.pumpAndSettle();
    expect(find.text(_InviteBackend.code), findsNothing);
  });

  testWidgets(
    'shows an inline rejection and supports retry with a pasted code',
    (tester) async {
      const code = 'ABCD-EFGH-JKLM-NPQR';
      final received = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => OfficeCodeScreen(
                    join: (code, _, _) async {
                      received.add(code);
                      return received.length == 1 ? 'Code expired.' : null;
                    },
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField);
      expect(field, findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller, isNotNull);
      final submit = find.widgetWithText(FilledButton, 'Join office');
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(received, isEmpty);
      expect(find.textContaining('16-character code'), findsOneWidget);
      await tester.enterText(field, code);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(received, [code]);
      expect(find.text('Code expired.'), findsOneWidget);
      await tester.enterText(field, code.toLowerCase());
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(received, [code, code.toLowerCase()]);
      expect(find.byType(OfficeCodeScreen), findsNothing);
    },
  );
}
