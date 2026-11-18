import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/home/attendance_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_fonts.dart';

Finder get _button => find.byType(InkWell);

Finder get _pulse => find.byKey(const ValueKey('check-in-pulse'));

double _pressScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('check-in-press')))
    .transform
    .entry(0, 0);

Future<void> _mount(
  WidgetTester tester, {
  VoidCallback? onTap,
  bool enabled = true,
  bool busy = false,
  bool reduceMotion = false,
  bool pulse = false,
  bool visible = true,
  bool dark = false,
  String label = 'Check in',
}) => tester.pumpWidget(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.darkTheme : AppTheme.theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: TickerMode(enabled: visible, child: child!),
    ),
    home: Scaffold(
      body: Center(
        child: AttendanceButton(
          isLoading: busy,
          isUploadEnabled: enabled,
          onTap: onTap ?? () {},
          uploadLabel: label,
          pulseEnabled: pulse,
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(loadTestFonts);

  testWidgets(
    'round button springs without resizing and a cancelled tap does not fire',
    (tester) async {
      var taps = 0;
      await _mount(tester, onTap: () => taps++);
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.camera), findsOneWidget);
      expect(tester.widget<InkWell>(_button).customBorder, isA<CircleBorder>());
      final size = tester.getSize(_button);
      final center = tester.getCenter(_button);

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 40));
      expect(_pressScale(tester), lessThan(1));
      expect(tester.getSize(_button), size);
      expect(tester.getCenter(_button), center);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(_pressScale(tester), closeTo(1, .01));
      expect(taps, 0);

      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 2);
    },
  );

  testWidgets(
    'reduced motion leaves the button still and busy blocks extra taps',
    (tester) async {
      var taps = 0;
      void onTap() => taps++;
      await _mount(tester, onTap: onTap, pulse: true, reduceMotion: true);
      expect(_pulse, findsNothing);
      final gesture = await tester.startGesture(tester.getCenter(_button));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_pressScale(tester), 1);
      await gesture.up();
      expect(taps, 1);

      await _mount(tester, onTap: onTap, busy: true, reduceMotion: true);
      expect(tester.widget<InkWell>(_button).onTap, isNull);
      expect(find.text('Please wait...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(AppIcons.clock), findsOneWidget);

      await _mount(
        tester,
        onTap: onTap,
        busy: true,
        enabled: false,
        label: 'Read-only preview',
      );
      expect(tester.widget<InkWell>(_button).onTap, isNull);
      expect(find.text('Read-only preview'), findsOneWidget);
      expect(find.byIcon(AppIcons.lock), findsOneWidget);
    },
  );

  testWidgets('halo stops in the background, off tab and during submission', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await _mount(tester, pulse: true);
    await tester.pump();
    double scale() => tester.widget<ScaleTransition>(_pulse).scale.value;
    final start = scale();
    await tester.pump(const Duration(milliseconds: 600));
    expect(scale(), greaterThan(start));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final paused = scale();
    await tester.pump(const Duration(milliseconds: 600));
    expect(scale(), paused);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(scale(), greaterThan(paused));
    await _mount(tester, pulse: true, visible: false);
    expect(_pulse, findsNothing);
    await _mount(tester, pulse: true, busy: true);
    expect(_pulse, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('check-in action ${dark ? 'dark' : 'light'} and large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 250);
      addTearDown(tester.view.reset);
      await _mount(tester, dark: dark, pulse: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
          'goldens/check_in_button_${dark ? 'dark' : 'light'}.png',
        ),
      );

      tester.view.physicalSize = const Size(320, 240);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _mount(
        tester,
        dark: dark,
        enabled: false,
        label: 'Upload open 7:00 AM - 1:00 PM',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Upload open 7:00 AM - 1:00 PM').hitTestable(),
        findsOneWidget,
      );
      expect(tester.getSize(_button).aspectRatio, closeTo(1, .01));
      expect(tester.takeException(), isNull);
    });
  }
}
