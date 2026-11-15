import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  Future<BuildContext> mount(
    WidgetTester tester, {
    String scope = 'office-a',
    bool dark = false,
    bool reduceMotion = false,
    bool accessible = false,
    double textScale = 1,
  }) async {
    late BuildContext routeContext;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.darkTheme : AppTheme.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            accessibleNavigation: accessible,
            textScaler: TextScaler.linear(textScale),
            viewPadding: const EdgeInsets.only(top: 24),
            padding: const EdgeInsets.only(top: 24),
          ),
          child: AppToastHost(scopeKey: scope, child: child!),
        ),
        home: Builder(
          builder: (context) {
            routeContext = context;
            return Scaffold(
              appBar: AppBar(title: const Text('Attendance')),
              body: const Center(child: Text('Your attendance')),
            );
          },
        ),
      ),
    );
    return routeContext;
  }

  testWidgets('replaces notices, preserves timeout and does not queue', (
    tester,
  ) async {
    final context = await mount(tester);
    final feedback = AppToast.of(context);
    feedback.showSnackBar(const SnackBar(content: Text('Old notice')));
    await tester.pumpAndSettle();
    feedback.showSnackBar(
      const SnackBar(
        content: Text('Check-in saved.'),
        duration: Duration(seconds: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old notice'), findsNothing);
    expect(find.text('Check-in saved.'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Check-in saved.')).dy, greaterThan(24));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Check-in saved.'), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Old notice'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen reader action persists and fires only once', (
    tester,
  ) async {
    var actions = 0;
    final context = await mount(tester, accessible: true, reduceMotion: true);
    AppToast.of(context).showSnackBar(
      SnackBar(
        content: const Text('Camera permission is blocked.'),
        action: SnackBarAction(label: 'Settings', onPressed: () => actions++),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.tap(find.text('Settings'), warnIfMissed: false);
    await tester.pump();
    expect(actions, 1);
    expect(find.text('Camera permission is blocked.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scope changes reject stale feedback and dispose timers', (
    tester,
  ) async {
    final oldContext = await mount(tester);
    final stale = AppToast.of(oldContext);
    stale.showSnackBar(const SnackBar(content: Text('Office A saved')));
    await tester.pumpAndSettle();
    final currentContext = await mount(tester, scope: 'office-b');
    await tester.pump();
    expect(find.text('Office A saved'), findsNothing);
    stale.showSnackBar(const SnackBar(content: Text('Late office A result')));
    await tester.pump();
    expect(find.text('Late office A result'), findsNothing);
    final current = AppToast.of(currentContext);
    current.showSnackBar(const SnackBar(content: Text('Office B saved')));
    await tester.pumpAndSettle();
    expect(find.text('Office B saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    current.showSnackBar(const SnackBar(content: Text('Disposed account')));
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('appears above modals without closing them on scope changes', (
    tester,
  ) async {
    final context = await mount(tester);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SizedBox(
        height: 200,
        child: Center(
          child: TextButton(
            onPressed: () => AppToast.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Office selected'))),
            child: const Text('Switch Office'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch Office'));
    await tester.pumpAndSettle();
    expect(find.text('Office selected'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Office selected')).dy,
      lessThan(tester.getTopLeft(find.text('Switch Office')).dy),
    );
    await mount(tester, scope: 'office-b');
    await tester.pumpAndSettle();
    expect(find.text('Office selected'), findsNothing);
    expect(find.text('Switch Office'), findsOneWidget);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses semantic haptics without requiring platform support', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final context = await mount(tester);
    final feedback = AppToast.of(context);
    for (final kind in ToastKind.values) {
      feedback.showSnackBar(
        const SnackBar(content: Text('Feedback')),
        kind: kind,
      );
      await tester.pump();
    }
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('long errors remain scrollable on small screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 360);
    addTearDown(tester.view.reset);
    final context = await mount(tester, reduceMotion: true, textScale: 2);
    AppToast.of(context).showSnackBar(
      SnackBar(content: Text(List.filled(40, 'Error details.').join(' '))),
      kind: ToastKind.error,
    );
    await tester.pump();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -100),
    );
    await tester.pump();
    expect(scroll.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final dark in [false, true]) {
    testWidgets('toast adapts to ${dark ? 'dark' : 'light'} and large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 700);
      addTearDown(tester.view.reset);
      final context = await mount(tester, dark: dark);
      AppToast.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Camera permission is blocked. Enable it in Settings.',
          ),
          action: SnackBarAction(label: 'Settings', onPressed: () {}),
        ),
        kind: ToastKind.error,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppToastHost),
        matchesGoldenFile('goldens/toast_${dark ? 'dark' : 'light'}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final smallContext = await mount(
        tester,
        dark: dark,
        reduceMotion: true,
        accessible: true,
        textScale: 2,
      );
      tester.view.physicalSize = const Size(320, 700);
      AppToast.of(smallContext).showSnackBar(
        SnackBar(
          content: const Text(
            'Camera permission is blocked. Enable it in Settings.',
          ),
          action: SnackBarAction(label: 'Settings', onPressed: () {}),
        ),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('Settings')).dy,
        greaterThan(
          tester.getBottomLeft(find.textContaining('Camera permission')).dy,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
