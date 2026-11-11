import 'package:attendance/widgets/spring_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets(
      'spring press keeps layout and settles, reduced motion: $reduced',
      (tester) async {
        final pressed = ValueNotifier(false);
        addTearDown(pressed.dispose);
        var builds = 0;
        final child = Builder(
          builder: (_) {
            builds++;
            return const SizedBox(width: 120, height: 52);
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: pressed,
                  child: child,
                  builder: (_, value, child) =>
                      SpringScale(pressed: value, child: child!),
                ),
              ),
            ),
          ),
        );
        final spring = find.byType(SpringScale);
        double scale() => tester
            .widget<Transform>(
              find
                  .descendant(of: spring, matching: find.byType(Transform))
                  .first,
            )
            .transform
            .storage[0];
        final size = tester.getSize(spring);
        pressed.value = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(scale(), lessThan(1));
        expect(scale(), greaterThan(.94));
        expect(tester.getSize(spring), size);
        final transform = tester.widget<Transform>(
          find.descendant(of: spring, matching: find.byType(Transform)).first,
        );
        expect(transform.transformHitTests, false);
        pressed.value = false;
        await tester.pumpAndSettle();
        expect(scale(), closeTo(1, .0001));
        expect(builds, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'offscreen tickers and newly enabled reduced motion stop the spring',
    (tester) async {
      Widget app({bool active = true, bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: active,
            child: const SpringScale(pressed: true, child: Icon(Icons.check)),
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpWidget(app(active: false));
      expect(tester.hasRunningAnimations, false);
      await tester.pumpWidget(app(reduced: true));
      expect(tester.hasRunningAnimations, false);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
