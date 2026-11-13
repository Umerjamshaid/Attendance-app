import 'dart:async';
import 'package:attendance/bootstrap.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/office_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/widgets/bottom_nav.dart';
import 'package:attendance/widgets/office/office_selector_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'office_provider_test.dart' show ControlledOfficeBackend;
import 'support/test_fonts.dart';
import 'support/overview_fonts.dart';

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await loadOverviewFonts();
  });
  testWidgets(
    'real bootstrap hides old content, replaces office providers and preserves profile state',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Attendance',
        packageName: 'test.attendance',
        version: '1.1.0',
        buildNumber: '6',
        buildSignature: '',
      );
      final backend = ControlledOfficeBackend();
      runAttendanceApp(backend: backend);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final context = tester.element(find.byType(OfficeSelectorHeader));
      final auth = context.read<AuthProvider>();
      final offices = context.read<OfficeProvider>();
      final profile = context.read<ProfileProvider>();
      final oldHistory = context.read<AttendanceHistoryProvider>();
      expect(oldHistory.records.single.id, 'record-a');
      expect(tester.widget<BottomNav>(find.byType(BottomNav)).isAdmin, isTrue);
      backend.state.switchGate = Completer<void>();
      final pending = offices.switchOffice('b');
      await tester.pump();
      expect(find.bySemanticsLabel('Loading office'), findsOneWidget);
      final overlay = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('office-loading-overlay')),
      );
      expect(
        overlay.color.a,
        1,
        reason: 'old-office evidence cannot show through the loading layer',
      );
      backend.state.switchGate!.complete();
      await pending;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final next = tester.element(find.byType(OfficeSelectorHeader));
      expect(next.read<AuthProvider>(), same(auth));
      expect(next.read<ProfileProvider>(), same(profile));
      expect(next.read<AttendanceHistoryProvider>(), isNot(same(oldHistory)));
      expect(
        next.read<AttendanceHistoryProvider>().records.single.id,
        'record-b',
      );
      expect(tester.widget<BottomNav>(find.byType(BottomNav)).isAdmin, isFalse);
      expect(find.text('Office B'), findsOneWidget);
      expect(find.bySemanticsLabel('Loading office'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
