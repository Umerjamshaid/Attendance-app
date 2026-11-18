import 'package:attendance/widgets/profile_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cold image fades once; a decoded hit paints immediately', (
    tester,
  ) async {
    final builder = profileImageFrame(const ColoredBox(color: Colors.grey));
    Widget frame({int? index, bool sync = false, bool reduceMotion = false}) =>
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Center(
            child: SizedBox.square(
              dimension: 40,
              child: Builder(
                builder: (context) => builder(
                  context,
                  const ColoredBox(color: Colors.teal),
                  index,
                  sync,
                ),
              ),
            ),
          ),
        );
    final fade = find.byType(AnimatedOpacity);
    await tester.pumpWidget(frame());
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 0);
    await tester.pumpWidget(frame(index: 0));
    expect(tester.widget<AnimatedOpacity>(fade).opacity, 1);
    await tester.pumpAndSettle();
    await tester.pumpWidget(frame(index: 0, sync: true));
    expect(fade, findsNothing);
    await tester.pumpWidget(frame(index: 0, reduceMotion: true));
    expect(fade, findsNothing);
  });
}
