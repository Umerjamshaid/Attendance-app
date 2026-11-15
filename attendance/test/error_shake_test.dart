import 'package:attendance/config/app_theme.dart';
import 'package:attendance/widgets/error_shake.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _offset(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(ErrorShake),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[12];

void main() {
  testWidgets(
    'Buzz shake is bounded, settles, and repeats an unchanged error',
    (tester) async {
      Future<void> show(String? error, int revision) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorShake(
                error: error,
                revision: revision,
                child: const SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        );
      }

      await show(null, 0);
      expect(_offset(tester), 0);
      await show('Required', 1);
      for (final delta in [80, 80, 60, 60]) {
        await tester.pump(Duration(milliseconds: delta));
        expect(_offset(tester).abs(), lessThanOrEqualTo(6));
      }
      expect(_offset(tester), closeTo(0, .001));
      await show('Required', 2);
      await tester.pump(const Duration(milliseconds: 80));
      expect(_offset(tester), greaterThan(0));
      await show(null, 2);
      expect(_offset(tester), 0);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('reduced motion and offscreen content stop a running shake', (
    tester,
  ) async {
    Future<void> show({
      bool reduced = false,
      bool visible = true,
      int revision = 1,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: child!,
          ),
          home: Scaffold(
            body: TickerMode(
              enabled: visible,
              child: ErrorShake(
                error: 'Invalid',
                revision: revision,
                child: const Text('Error'),
              ),
            ),
          ),
        ),
      );
    }

    await show();
    await tester.pump(const Duration(milliseconds: 80));
    expect(_offset(tester), greaterThan(0));
    await show(reduced: true);
    expect(_offset(tester), 0);
    expect(tester.binding.transientCallbackCount, 0);
    await show(reduced: true, revision: 2);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_offset(tester), 0);
    await show(revision: 3);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_offset(tester), greaterThan(0));
    await show(visible: false, revision: 3);
    expect(_offset(tester), 0);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'typing and unrelated rebuilds preserve focus, selection and the error message',
    (tester) async {
      final controller = TextEditingController(text: 'invalid');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      Future<void> show(String? error, int revision) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.theme,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: ErrorShake(
                  error: error,
                  revision: revision,
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    decoration: InputDecoration(
                      labelText: 'Work email',
                      errorText: error,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await show(null, 0);
      await tester.tap(find.byType(TextField));
      controller.selection = const TextSelection.collapsed(offset: 3);
      await show('Enter a valid email.', 1);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(controller.selection.baseOffset, 3);
      await show('Enter a valid email.', 1);
      await tester.pump(const Duration(milliseconds: 80));
      expect(_offset(tester), 0);
      expect(find.text('Enter a valid email.'), findsOneWidget);
    },
  );
}
