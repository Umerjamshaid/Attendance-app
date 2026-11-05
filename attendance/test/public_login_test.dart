import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/login/login_screen.dart';
import 'package:attendance/screens/profile/account_edit_screen.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('public login shows email/password plus demo without autofocus', (
    tester,
  ) async {
    final auth = AuthProvider(backend: PreviewCompanyBackend(available: false));
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.theme, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Work email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Explore demo'), findsOneWidget);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.autofocus, false);
    }
    await tester.ensureVisible(find.text('Explore demo'));
    await tester.tap(find.text('Explore demo'));
    await tester.pumpAndSettle();
    expect(auth.isPreview, true);
    expect(tester.takeException(), isNull);
  });
  testWidgets('focused edit tracks changes and resets when text is restored', (
    tester,
  ) async {
    var saved = '';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: AccountEditScreen(
          title: 'Display name',
          label: 'Name',
          initialValue: 'Alex',
          onSave: (value) async {
            saved = value;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    FilledButton button() => tester.widget(find.byType(FilledButton));
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, true);
    expect(button().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Alex M');
    await tester.pump();
    expect(button().onPressed, isNotNull);
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.pump();
    expect(button().onPressed, isNull);
    expect(saved, '');
  });
}
