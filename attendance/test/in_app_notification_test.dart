import 'package:attendance/widgets/in_app_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _mount(
  WidgetTester tester, {
  bool reducedMotion = false,
}) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: Scaffold(
        body: InAppNotificationHost(
          child: Builder(
            builder: (context) {
              hostContext = context;
              return const Center(child: Text('Home'));
            },
          ),
        ),
      ),
    ),
  );
  return hostContext;
}

void main() {
  testWidgets(
    'queues banners, dismisses by swipe, and invokes an action once',
    (tester) async {
      final context = await _mount(tester);
      var tapped = 0;
      expect(
        InAppNotification.show(
          context,
          const InAppNotification(
            title: 'Check-in saved',
            kind: InAppNotificationKind.success,
          ),
        ),
        isTrue,
      );
      InAppNotification.show(
        context,
        InAppNotification(
          title: 'New activity',
          kind: InAppNotificationKind.warning,
          actionLabel: 'Open activity',
          onTap: () => tapped++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Check-in saved'), findsOneWidget);
      expect(find.text('New activity'), findsNothing);
      await tester.drag(find.text('Check-in saved'), const Offset(-650, 0));
      await tester.pumpAndSettle();
      expect(find.text('Check-in saved'), findsNothing);
      await tester.tap(find.text('Open activity'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
      expect(find.text('New activity'), findsNothing);
    },
  );

  testWidgets('modals hide the banner until the route is current again', (
    tester,
  ) async {
    final context = await _mount(tester, reducedMotion: true);
    InAppNotification.show(
      context,
      const InAppNotification(title: 'Office activity'),
    );
    await tester.pump();
    expect(find.text('Office activity'), findsOneWidget);
    final dialog = showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm action'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close dialog'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm action'), findsOneWidget);
    expect(find.text('Office activity'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.tap(find.text('Close dialog'));
    await tester.pumpAndSettle();
    await dialog;
    expect(find.text('Office activity'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss notification'));
    await tester.pump();
    expect(find.text('Office activity'), findsNothing);
  });
}
