import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);
  for (final dark in [false, true]) {
    testWidgets('navigation reference - ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 480);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_Harness(dark: dark));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(NavigationFooterBackdrop)).height, 180);
      final button = find.byTooltip('Home');
      expect(tester.getSize(button).height, 56);
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      final capsule = find.byKey(const ValueKey('floating-navigation'));
      expect(tester.getCenter(capsule).dx, 195);
      expect(tester.getSize(capsule), const Size(264, 64));
      expect(find.text('Home'), findsNothing);
      final material = find
          .descendant(of: capsule, matching: find.byType(Material))
          .first;
      expect(
        tester.widget<Material>(material).color,
        dark
            ? AppTheme.darkTheme.colorScheme.surface
            : AppTheme.theme.colorScheme.surface,
      );
      expect(
        tester.view.physicalSize.height - tester.getBottomLeft(capsule).dy,
        34,
      );
      await expectLater(
        find.byKey(const ValueKey('navigation-preview')),
        matchesGoldenFile('goldens/navigation_${dark ? 'dark' : 'light'}.png'),
      );
    });
  }

  testWidgets(
    'all destinations stay reachable during resizing, scaling and RTL',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      for (final width in [320.0, 280.0, 600.0, 390.0]) {
        tester.view.physicalSize = Size(width, 600);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(
          tester
              .getCenter(find.byKey(const ValueKey('floating-navigation')))
              .dx,
          closeTo(width / 2, 0.01),
        );
        for (final label in ['History', 'Admin', 'Profile', 'Home']) {
          final button = find.byTooltip(label);
          final size = tester.getSize(button);
          expect(size.height, 56);
          expect(size.width, greaterThanOrEqualTo(48));
          await tester.tap(button);
          await tester.pump(const Duration(milliseconds: 70));
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();
          expect(find.text('Selected $label'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label == label &&
                  widget.properties.selected == true,
            ),
            findsOneWidget,
          );
        }
      }
      await tester.pumpWidget(const _Harness(rtl: true, textScale: 2));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.byTooltip('Home')).dx,
        greaterThan(tester.getCenter(find.byTooltip('Profile')).dx),
      );
      await tester.tap(find.byTooltip('History'));
      await tester.pumpAndSettle();
      expect(find.text('Selected History'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('footer ignores taps and snackbars clear the floating controls', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byTooltip('Home')).dy;
    await tester.tapAt(Offset(20, top - 20));
    await tester.pumpAndSettle();
    expect(find.text('Content tapped'), findsOneWidget);
    expect(tester.getTopLeft(find.byTooltip('Home')).dy, top);
    expect(
      tester.getBottomLeft(find.byType(SnackBar)).dy,
      lessThanOrEqualTo(top),
    );
  });

  testWidgets(
    'iOS gets Flutter glass and reduced motion leaves no size tween',
    (tester) async {
      await tester.pumpWidget(const _Harness(ios: true, reducedMotion: true));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is BackdropFilter && widget.enabled,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('History'));
      await tester.pump();
      expect(find.text('Selected History'), findsOneWidget);
      for (final container in tester.widgetList<AnimatedAlign>(
        find.byType(AnimatedAlign),
      )) {
        expect(container.duration, Duration.zero);
      }
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness extends StatefulWidget {
  const _Harness({
    this.dark = false,
    this.rtl = false,
    this.ios = false,
    this.reducedMotion = false,
    this.textScale = 1,
  });

  final bool dark, rtl, ios, reducedMotion;
  final double textScale;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: (widget.dark ? AppTheme.darkTheme : AppTheme.theme).copyWith(
      platform: widget.ios ? TargetPlatform.iOS : TargetPlatform.android,
      textTheme: (widget.dark ? AppTheme.darkTheme : AppTheme.theme).textTheme
          .apply(fontFamily: 'Roboto'),
    ),
    builder: (context, child) => Directionality(
      textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(widget.textScale),
          disableAnimations: widget.reducedMotion,
        ),
        child: child!,
      ),
    ),
    home: RepaintBoundary(
      key: const ValueKey('navigation-preview'),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: Builder(
                builder: (context) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Content tapped'),
                    ),
                  ),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      40,
                      20,
                      MediaQuery.paddingOf(context).bottom + 20,
                    ),
                    children: [
                      Text(
                        'Selected ${['Home', 'History', 'Admin', 'Profile'][_selected]}',
                      ),
                      for (var i = 0; i < 8; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: ListTile(
                            leading: const Icon(AppIcons.clock),
                            title: Text('Attendance record ${i + 1}'),
                            subtitle: const Text('Recorded activity'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: NavigationFooterBackdrop(),
            ),
          ],
        ),
        bottomNavigationBar: BottomNav(
          currentIndex: _selected,
          isAdmin: true,
          onTap: (index) => setState(() => _selected = index),
        ),
      ),
    ),
  );
}
