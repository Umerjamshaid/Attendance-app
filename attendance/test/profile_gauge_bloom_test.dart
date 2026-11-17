import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/services/banner_color_image.dart';
import 'package:attendance/services/company_backend.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/services/profile_media.dart';
import 'package:attendance/widgets/user-profile/attendance_score_gauge.dart';
import 'package:attendance/widgets/user-profile/banner_color_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:portal_labs/portal_labs.dart' as portal;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_fonts.dart';

class _Backend extends PreviewCompanyBackend {
  String banner = 'https://example.invalid/banner.gif';
  Uint8List? bytes;
  bool fail = false;
  @override
  bool get isPreview => false;
  @override
  Future<void> saveMedia(String kind, Uint8List? bytes) async {
    expect(kind, 'banner');
    if (fail) throw const CompanyException('Offline');
    this.bytes = bytes;
    banner = 'https://example.invalid/color.png';
  }

  @override
  Future<Map<String, String?>> profileMedia() async => {'banner': banner};
}

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'solid colors encode as opaque PNG and use existing format validation',
    () async {
      final bytes = await bannerColorPng(const Color(0x80167D8D));
      expect(
        ProfileImageFormat.fromBytes(bytes, banner: true),
        ProfileImageFormat.png,
      );
      expect(bytes.length, lessThan(1024));
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final pixels = await frame.image.toByteData();
      expect(pixels!.buffer.asUint8List().take(4), [0x16, 0x7d, 0x8d, 0xff]);
      frame.image.dispose();
      codec.dispose();
    },
  );

  test(
    'cloud colors persist through the existing banner upload and reload',
    () async {
      final backend = _Backend();
      final profile = ProfileProvider(backend: backend);
      addTearDown(profile.dispose);
      await profile.loadProfileData('EMP1');
      expect(profile.bannerPath, endsWith('.gif'));
      backend.fail = true;
      await expectLater(
        profile.setBannerColor('EMP1', Colors.red),
        throwsA(isA<CompanyException>()),
      );
      expect(profile.bannerPath, endsWith('.gif'));
      backend.fail = false;
      await profile.setBannerColor('EMP1', Colors.blue);
      expect(profile.bannerPath, endsWith('color.png'));
      expect(
        ProfileImageFormat.fromBytes(backend.bytes!),
        ProfileImageFormat.png,
      );
      final reopened = ProfileProvider(backend: backend);
      addTearDown(reopened.dispose);
      await reopened.loadProfileData('EMP1');
      expect(reopened.bannerPath, profile.bannerPath);
    },
  );

  test(
    'legacy color banners survive provider restart and preview rejects writes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'attendance-color-test-',
      );
      final original = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = original;
        await directory.delete(recursive: true);
      });
      final profile = ProfileProvider();
      final reopened = ProfileProvider();
      addTearDown(profile.dispose);
      addTearDown(reopened.dispose);
      await profile.setBannerColor('EMP1', Colors.green);
      expect(await File(profile.bannerPath!).exists(), isTrue);
      await reopened.loadProfileData('EMP1');
      expect(reopened.bannerPath, profile.bannerPath);
      await reopened.removeBanner('EMP1');
      expect(reopened.bannerPath, isNull);
      final preview = ProfileProvider(backend: PreviewCompanyBackend());
      addTearDown(preview.dispose);
      await expectLater(
        preview.setBannerColor('EMP1', Colors.red),
        throwsA(isA<CompanyException>()),
      );
    },
  );

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    bool dark = false,
    double width = 390,
    bool reduced = false,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.darkTheme : AppTheme.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the package gauge animates data changes and clamps invalid data',
    (tester) async {
      double? value = .25;
      late StateSetter update;
      await mount(
        tester,
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return AttendanceScoreGauge(progress: value, label: 'This month');
          },
        ),
      );
      expect(find.byType(portal.ScoreGauge), findsOneWidget);
      update(() => value = .85);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<portal.ScoreGauge>(find.byType(portal.ScoreGauge)).value,
        85,
      );
      update(() => value = 3);
      await tester.pumpAndSettle();
      expect(
        tester.widget<portal.ScoreGauge>(find.byType(portal.ScoreGauge)).value,
        100,
      );
      update(() => value = double.nan);
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'actual Bloom picker ${dark ? "dark" : "light"}, hex, save and cancel',
      (tester) async {
        final saved = <Color>[];
        await mount(
          tester,
          BannerColorSheet(onSave: (color) async => saved.add(color)),
          dark: dark,
        );
        expect(find.byType(portal.BloomColorPicker), findsOneWidget);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/bloom_banner_${dark ? "dark" : "light"}.png',
          ),
        );
        final circle = find.descendant(
          of: find.byType(portal.BloomColorPicker),
          matching: find.byType(CompositedTransformTarget),
        );
        await tester.tap(circle.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Overlay).first,
          matchesGoldenFile(
            'goldens/bloom_open_${dark ? "dark" : "light"}.png',
          ),
        );
        // The package's outside-tap handler closes its anchored palette.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '#336699');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AnimatedContainer>(
                find.byKey(const ValueKey('banner-color-preview')),
              )
              .decoration,
          isA<BoxDecoration>().having(
            (d) => d.color,
            'color',
            const Color(0xff336699),
          ),
        );
        expect(saved, isEmpty);
        await tester.ensureVisible(find.text('Save color'));
        await tester.tap(find.text('Save color'));
        await tester.pumpAndSettle();
        expect(saved.single, const Color(0xff336699));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'gauge and picker fit 320dp with 2x text and reduced motion ${dark ? "dark" : "light"}',
      (tester) async {
        await mount(
          tester,
          const AttendanceScoreGauge(progress: 1, label: 'This month'),
          dark: dark,
          width: 320,
          scale: 2,
          reduced: true,
        );
        expect(find.text('100%'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
        await mount(
          tester,
          BannerColorSheet(onSave: (_) async {}),
          dark: dark,
          width: 320,
          scale: 2,
          reduced: true,
        );
        await tester.enterText(find.byType(TextField), '#abcdef');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('color save failure stays inline and permits a retry', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      BannerColorSheet(
        onSave: (_) async {
          calls++;
          throw StateError('offline');
        },
      ),
    );
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save the banner color. Try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
