import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/widgets/user-profile/profile_header.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'support/test_fonts.dart';
import 'support/overview_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final brightness in Brightness.values) {
    testWidgets('profile media icons fit ${brightness.name} UI', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final profile = _Profile();
      addTearDown(profile.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ProfileProvider>.value(
          value: profile,
          child: MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.darkTheme
                : AppTheme.theme,
            home: Scaffold(
              body: ListView(
                children: [
                  ProfileHeader(
                    employee: Employee(
                      id: 'EMP001',
                      name: 'Sample Employee',
                      email: 'sample@example.invalid',
                      department: 'Engineering',
                      role: 'employee',
                      time: '',
                      headline: 'Building with the team',
                      chips: const ['Mentor', 'Flutter'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Icon>(find.byIcon(AppIcons.cameraPlus)).size, 16);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.camera)).size, 18);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.trash)).size, 18);
      expect(tester.widget<Icon>(find.byIcon(AppIcons.idBadge2)).size, 16);
      final name = tester.widget<Text>(find.text('Sample Employee'));
      expect(name.style?.fontFamily, ProfileUi.fontFamily);
      expect(
        Theme.of(
          tester.element(find.text('Sample Employee')),
        ).textTheme.bodyLarge?.fontFamily,
        ProfileUi.fontFamily,
      );
      final remove = find.bySemanticsLabel('Remove cover photo');
      expect(tester.getSize(remove).shortestSide, greaterThanOrEqualTo(44));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/profile_media_${brightness.name}.png'),
      );
      tester.view.physicalSize = const Size(320, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(AppIcons.cameraPlus));
      await tester.pumpAndSettle();
      expect(find.text('Choose an image no larger than 2 MB.'), findsOneWidget);
    });
  }

  testWidgets('profile font does not change shared Home and History type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) {
            final normal = ProfileUi.body(context, weight: FontWeight.w600);
            expect(normal.fontFamily, startsWith('Inter'));
            expect(normal.height, 1.25);
            return Theme(
              data: ProfileUi.themeOf(context),
              child: Builder(
                builder: (context) {
                  final profile = ProfileUi.body(
                    context,
                    weight: FontWeight.w600,
                  );
                  expect(profile.fontFamily, ProfileUi.fontFamily);
                  expect(profile.height, 1.4);
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
  });

  test('attendance counter digits keep equal advance widths', () {
    final style = GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    double width(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    expect(width('1111'), closeTo(width('8888'), 0.01));
  });
}

class _Profile extends ProfileProvider {
  @override
  String? get bannerPath => 'missing-test-banner.png';

  @override
  Future<void> pickPfp(String userId) async =>
      throw const CompanyException('Choose an image no larger than 2 MB.');
}
