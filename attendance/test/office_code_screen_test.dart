import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/admin/employee_management_screen.dart';
import 'package:attendance/screens/login/office_code_screen.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/test_fonts.dart';

class _InviteBackend extends PreviewCompanyBackend {
  static const code = 'ABCD EFGH JKLM NPQR';
  final recipients = <(String, String)>[];

  @override
  bool get supportsOfficeInviteCodes => true;
  @override
  _InviteBackend forOffice(Employee employee) => this;

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
