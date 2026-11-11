import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/screens/profile/profile_screen.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/user-profile/edit_profile_sheet.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      version: '1.1.0',
      buildNumber: '6',
      buildSignature: '',
    );
  });

  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.darkTheme : AppTheme.theme;

    testWidgets(
      'edit sheet inherits one profile font in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => EditProfileSheet(
                      initialName: 'Alex',
                      initialEmail: 'alex@example.invalid',
                      onSave: (_, _) async => throw Exception('Save failure'),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        final helper = find.text('Update your personal information.');
        expect(
          tester.widget<Text>(helper).style?.fontFamily,
          ProfileUi.fontFamily,
        );
        expect(
          Theme.of(tester.element(helper)).textTheme.bodyMedium?.fontFamily,
          ProfileUi.fontFamily,
        );
        for (final field in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          expect(field.style?.fontFamily, ProfileUi.fontFamily);
        }
        final save = find.widgetWithText(FilledButton, 'Save changes');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        await tester.enterText(find.byType(TextField).last, 'invalid');
        await tester.pumpAndSettle();
        expect(find.text('Enter a valid email address'), findsOneWidget);
        await tester.enterText(
          find.byType(TextField).last,
          'changed@example.invalid',
        );
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        final error = find.text('Couldn’t save changes. Try again.');
        expect(
          tester.widget<Text>(error).style?.fontFamily,
          ProfileUi.fontFamily,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'profile footer uses accessible opaque labels in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        final backend = PreviewCompanyBackend();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => AuthProvider(backend: backend),
              ),
              ChangeNotifierProvider(
                create: (_) => ProfileProvider(backend: backend),
              ),
              ChangeNotifierProvider(
                create: (_) => AttendanceHistoryProvider(
                  service: AttendanceService(backend: backend),
                ),
              ),
            ],
            child: MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in ['PIPFA Attendance', 'v1.1.0 (6)']) {
          final finder = find.text(label);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final color = tester.widget<Text>(finder).style!.color!;
          final background = Theme.of(
            tester.element(finder),
          ).scaffoldBackgroundColor;
          expect(color.a, 1);
          expect(color, theme.colorScheme.onSurfaceVariant);
          expect(
            _contrast(Color.alphaBlend(color, background), background),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

double _contrast(Color foreground, Color background) {
  final values = [foreground.computeLuminance(), background.computeLuminance()]
    ..sort();
  return (values.last + .05) / (values.first + .05);
}
