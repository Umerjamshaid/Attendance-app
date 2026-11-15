import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/animated_app_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'selection animates once without capturing the parent button tap',
    (tester) async {
      await tester.pumpWidget(const _Host());
      final state = tester.state<_HostState>(find.byType(_Host));
      final glyph = tester.widget<lucide.LucideAnimatedIcon>(
        find.byType(lucide.LucideAnimatedIcon),
      );
      expect(glyph.trigger, lucide.AnimationTrigger.manual);
      expect(glyph.strokeWidth, 2.5);
      expect(tester.getSize(find.byType(AnimatedAppIcon)), const Size(24, 24));
      expect(glyph.controller!.value, 1);
      await tester.tap(find.byTooltip('Select'));
      await tester.pump();
      expect(state.taps, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(glyph.controller!.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(glyph.controller!.value, 1);
      state.rebuild();
      await tester.pump();
      expect(glyph.controller!.value, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final offscreen in [false, true]) {
    testWidgets(
      'motion stops cleanly when ${offscreen ? 'offscreen' : 'reduced motion is enabled'}',
      (tester) async {
        await tester.pumpWidget(const _Host());
        final state = tester.state<_HostState>(find.byType(_Host));
        await tester.tap(find.byTooltip('Select'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        state.pause(offscreen: offscreen);
        await tester.pumpAndSettle();
        final glyph = tester.widget<lucide.LucideAnimatedIcon>(
          find.byType(lucide.LucideAnimatedIcon),
        );
        expect(glyph.controller!.value, 1);
        expect(glyph.controller!.isAnimating, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Host extends StatefulWidget {
  const _Host();
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool selected = false, reduced = false, enabled = true;
  int taps = 0;
  void rebuild() => setState(() {});
  void pause({required bool offscreen}) => setState(() {
    if (offscreen) {
      enabled = false;
    } else {
      reduced = true;
    }
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.theme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: TickerMode(
          enabled: enabled,
          child: Scaffold(
            body: Center(
              child: IconButton(
                tooltip: 'Select',
                onPressed: () => setState(() {
                  taps++;
                  selected = true;
                }),
                icon: AnimatedAppIcon(icon: lucide.home, selected: selected),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
