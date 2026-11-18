import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/screens/history/history_screen.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/history/history_subgroups.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/overview_fonts.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final dark in [false, true]) {
    testWidgets(
      'History date groups pin, fade and keep the ${dark ? 'dark' : 'light'} theme',
      (tester) async {
        final fixture = await _pump(tester, dark: dark);
        final scroll = tester.widget<HistorySubgroups>(
          find.byType(HistorySubgroups),
        );
        expect(find.byType(CustomScrollView), findsOneWidget);
        for (final label in [
          'Overview',
          'This month',
          'Current streak',
          'Overall rate',
          'Days present',
          'Days absent',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        final first = scroll.groups[0].date;
        final second = scroll.groups[1].date;
        final header = _header(first);
        final material = tester.widget<Container>(header);
        expect(
          material.color,
          Theme.of(
            tester.element(find.text(first)),
          ).colorScheme.surfaceContainerLow,
        );
        await expectLater(
          find.byType(HistoryScreen),
          matchesGoldenFile(
            'goldens/history_subgroups_${dark ? 'dark' : 'light'}.png',
          ),
        );

        final initialTop = tester.getTopLeft(header).dy;
        scroll.controller.jumpTo(initialTop - scroll.pinnedTop + 72);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(header).dy, closeTo(scroll.pinnedTop, 1));
        await expectLater(
          find.byType(HistoryScreen),
          matchesGoldenFile(
            'goldens/history_subgroups_scrolled_${dark ? 'dark' : 'light'}.png',
          ),
        );

        final headerHeight = tester.getSize(header).height;
        final nextTop = tester.getTopLeft(_header(second)).dy;
        scroll.controller.jumpTo(
          scroll.controller.offset +
              nextTop -
              scroll.pinnedTop -
              headerHeight +
              12,
        );
        await tester.pumpAndSettle();
        final opacity = tester.widget<SliverOpacity>(_opacity(first)).opacity;
        expect(opacity, inExclusiveRange(0, 1));
        final clip = tester.widget<ClipRRect>(
          find
              .ancestor(of: find.text(first), matching: find.byType(ClipRRect))
              .first,
        );
        expect(
          (clip.borderRadius as BorderRadius).bottomLeft.x,
          greaterThan(0),
        );
        expect(fixture.history.records.length, 48);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'large text, narrow and wide viewports, RTL and reduced motion stay readable',
    (tester) async {
      await _pump(tester, reducedMotion: true, rtl: true);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final size in [const Size(320, 560), const Size(800, 600)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final scroll = tester.widget<HistorySubgroups>(
          find.byType(HistorySubgroups),
        );
        final first = scroll.groups[0].date;
        await tester.scrollUntilVisible(
          find.text(first),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final start = tester.getTopLeft(_header(first)).dy;
        scroll.controller.jumpTo(
          scroll.controller.offset + start - scroll.pinnedTop + 72,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(_header(first)).dy,
          closeTo(scroll.pinnedTop, 1),
        );
        expect(tester.widget<SliverOpacity>(_opacity(first)).opacity, 1);
        expect(tester.getSize(_header(first)).height, greaterThan(48));
        expect(tester.takeException(), isNull);
        scroll.controller.jumpTo(0);
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'same-length group replacement cannot retain old headers or motion state',
    (tester) async {
      final fixture = await _pump(tester);
      final before = tester
          .widget<HistorySubgroups>(find.byType(HistorySubgroups))
          .groups
          .first
          .date;
      fixture.backend.start = DateTime(2026, 10, 17);
      await fixture.history.loadHistory('DEMO001', force: true);
      await tester.pumpAndSettle();
      final after = tester
          .widget<HistorySubgroups>(find.byType(HistorySubgroups))
          .groups
          .first
          .date;
      expect(after, isNot(before));
      expect(find.text(before), findsNothing);
      expect(find.text(after), findsOneWidget);
      expect(fixture.history.records.length, 48);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loading, errors, empty history and refresh retain their existing states',
    (tester) async {
      final fixture = await _pump(tester);
      fixture.backend.pending = Completer<List<AttendanceRecord>>();
      final load = fixture.history.loadHistory('DEMO001', force: true);
      await tester.pump();
      expect(
        tester.widget<HistorySubgroups>(find.byType(HistorySubgroups)).groups,
        isEmpty,
      );
      expect(find.bySemanticsLabel('Loading history'), findsOneWidget);
      fixture.backend.pending!.completeError(StateError('Test outage'));
      await load;
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong'), findsOneWidget);
      fixture.backend.pending = null;
      fixture.backend.days = 0;
      await fixture.history.loadHistory('DEMO001', force: true);
      await tester.pumpAndSettle();
      expect(find.text('No history yet'), findsOneWidget);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('No history yet'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _header(String date) =>
    find.ancestor(of: find.text(date), matching: find.byType(Container)).first;
Finder _opacity(String date) => find
    .ancestor(of: find.text(date), matching: find.byType(SliverOpacity))
    .first;

Future<_Fixture> _pump(
  WidgetTester tester, {
  bool dark = false,
  bool reducedMotion = false,
  bool rtl = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final fixture = _Fixture();
  addTearDown(fixture.auth.dispose);
  addTearDown(fixture.history.dispose);
  await fixture.auth.refreshSession();
  await fixture.history.loadHistory('DEMO001');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: fixture.auth),
        ChangeNotifierProvider.value(value: fixture.history),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.theme,
        builder: (context, child) => Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
        ),
        home: const HistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

class _Fixture {
  final backend = _Backend();
  late final auth = AuthProvider(backend: backend);
  late final history = AttendanceHistoryProvider(
    service: AttendanceService(backend: backend),
  );
}

class _Backend extends PreviewCompanyBackend {
  DateTime start = DateTime(2026, 11, 17);
  int days = 12;
  Completer<List<AttendanceRecord>>? pending;
  @override
  bool get isPreview => false;
  @override
  DateTime get companyNow => DateTime(2026, 11, 17, 12);
  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) async => pending != null
      ? pending!.future
      : [
          for (var day = 0; day < days; day++)
            for (var row = 3; row >= 0; row--)
              AttendanceRecord(
                id: 'day-$day-row-$row',
                userId: 'DEMO001',
                isPresent: true,
                timestamp: DateTime(
                  start.year,
                  start.month,
                  start.day - day,
                  9,
                  row * 10,
                ),
                device: 'Sample Android device',
              ),
        ];
}
