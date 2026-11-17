import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/widgets/user-profile/banner_actions.dart';
import 'package:attendance/widgets/user-profile/profile_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

final _user = Employee(
  id: 'EMP001',
  name: 'Sample Employee',
  email: 'sample@example.invalid',
  role: 'employee',
  department: 'Engineering',
  time: '',
);

class _Profile extends ProfileProvider {
  String? _banner = 'missing-banner-test.png';
  int removals = 0;
  int picks = 0;
  bool fail = false;
  Completer<void>? pending;

  @override
  String? get bannerPath => _banner;

  void replace() {
    _banner = 'replacement-banner-test.png';
    notifyListeners();
  }

  @override
  Future<void> removeBanner(String userId) async {
    removals++;
    if (pending != null) await pending!.future;
    if (fail) throw const CompanyException('Could not remove');
    _banner = null;
    notifyListeners();
  }

  @override
  Future<void> pickBanner(String userId) async => picks++;
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> mount(
    WidgetTester tester,
    _Profile profile, {
    bool dark = false,
    double width = 390,
    double scale = 1,
    bool reducedMotion = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
    addTearDown(profile.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>.value(
        value: profile,
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(children: [ProfileHeader(employee: _user)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Remove cover photo'));
    await tester.pumpAndSettle();
    expect(find.byType(BannerActions), findsOneWidget);
  }

  testWidgets(
    'remove is two-step; cancel, close, outside tap and back are safe',
    (tester) async {
      final profile = _Profile();
      await mount(tester, profile);
      await open(tester);
      expect(profile.removals, 0);
      expect(find.text('Remove'), findsNothing);
      await tester.tap(find.text('Remove banner'));
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(profile.removals, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Remove banner'), findsOneWidget);
      await tester.tap(find.byTooltip('Close banner options'));
      await tester.pumpAndSettle();
      expect(find.byType(BannerActions), findsNothing);
      await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(BannerActions), findsNothing);
      await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BannerActions), findsNothing);
      expect(profile.removals, 0);
      expect(profile.bannerPath, isNotNull);
    },
  );

  testWidgets(
    'confirmed removal submits once and blocks actions while pending',
    (tester) async {
      final profile = _Profile()..pending = Completer<void>();
      await mount(tester, profile);
      await open(tester);
      await tester.tap(find.text('Remove banner'));
      await tester.pumpAndSettle();
      final confirm = tester.widget<InkWell>(
        find.widgetWithText(InkWell, 'Remove'),
      );
      confirm.onTap!();
      confirm.onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(profile.removals, 1);
      expect(find.bySemanticsLabel('Remove cover photo'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      profile.pending!.complete();
      await tester.pumpAndSettle();
      expect(profile.bannerPath, isNull);
      expect(find.text('Banner removed'), findsOneWidget);
      expect(find.text('Tap to select banner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed removal preserves the banner and existing error feedback',
    (tester) async {
      final profile = _Profile()..fail = true;
      await mount(tester, profile);
      await open(tester);
      await tester.tap(find.text('Remove banner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(profile.removals, 1);
      expect(profile.bannerPath, isNotNull);
      expect(
        find.textContaining('remove the banner. Try again.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Remove cover photo'), findsOneWidget);
    },
  );

  testWidgets('change action uses the existing gallery flow without deleting', (
    tester,
  ) async {
    final profile = _Profile();
    await mount(tester, profile);
    await open(tester);
    await tester.tap(find.text('Change banner'));
    await tester.pumpAndSettle();
    expect(profile.picks, 1);
    expect(profile.removals, 0);
    expect(find.byType(BannerActions), findsNothing);
  });

  testWidgets('an old menu cannot remove a replacement banner', (tester) async {
    final profile = _Profile();
    await mount(tester, profile);
    await open(tester);
    await tester.tap(find.text('Remove banner'));
    await tester.pumpAndSettle();
    profile.replace();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(profile.removals, 0);
    expect(profile.bannerPath, 'replacement-banner-test.png');
  });

  for (final dark in [false, true]) {
    testWidgets(
      'banner action animation and preview ${dark ? "dark" : "light"}',
      (tester) async {
        await mount(tester, _Profile(), dark: dark);
        await open(tester);
        await expectLater(
          find.byType(BannerActions),
          matchesGoldenFile(
            'goldens/banner_actions_${dark ? "dark" : "light"}.png',
          ),
        );
        final before = tester.getTopLeft(find.text('Remove banner'));
        await tester.tap(find.text('Remove banner'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getTopLeft(find.text('Remove banner')), isNot(before));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(BannerActions),
          matchesGoldenFile(
            'goldens/banner_confirm_${dark ? "dark" : "light"}.png',
          ),
        );
        expect(
          tester.getSize(find.widgetWithText(InkWell, 'Remove')).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.widgetWithText(InkWell, 'Cancel')).height,
          greaterThanOrEqualTo(48),
        );
      },
    );

    testWidgets('large text and reduced motion ${dark ? "dark" : "light"}', (
      tester,
    ) async {
      await mount(
        tester,
        _Profile(),
        dark: dark,
        width: 320,
        scale: 2,
        reducedMotion: true,
      );
      await open(tester);
      await tester.tap(find.text('Remove banner'));
      await tester.pump();
      expect(find.text('Remove banner'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Remove')).dy,
        lessThan(tester.getTopLeft(find.text('Cancel')).dy),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.text('Remove banner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
