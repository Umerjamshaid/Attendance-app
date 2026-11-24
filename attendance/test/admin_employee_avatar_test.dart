import 'dart:async';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/attendance_record_model.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/services/attendance_service.dart';
import 'package:attendance/services/employees_service.dart';
import 'package:attendance/services/preview_company_backend.dart';
import 'package:attendance/widgets/admin/employee_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/test_fonts.dart';

final _employees = [
  for (final (index, name) in ['Alice Johnson', 'Jordan Lee'].indexed)
    Employee(
      id: 'EMP$index',
      authUserId: 'user-$index',
      organizationId: 'office-a',
      name: name,
      email: '',
      role: 'employee',
      department: 'Engineering',
      time: '',
    ),
];

class _Backend extends PreviewCompanyBackend {
  Completer<Map<String, String?>> avatars = Completer<Map<String, String?>>();
  final batches = <List<Employee>>[];
  @override
  Future<List<Employee>> employees() async => _employees;
  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) async => [];
  @override
  Future<Map<String, String?>> employeeAvatars(List<Employee> employees) {
    batches.add(employees);
    return avatars.future;
  }
}

void main() {
  setUpAll(loadTestFonts);
  AdminProvider provider(_Backend backend) => AdminProvider(
    employeeService: EmployeeService(backend: backend),
    attendanceService: AttendanceService(backend: backend),
  )..setFilter('all');

  test(
    'dashboard return preserves photos until the batched refresh finishes',
    () async {
      final backend = _Backend();
      final admin = provider(backend);
      addTearDown(admin.dispose);
      await admin.loadDashboard();
      backend.avatars.complete({
        'user-0': 'https://avatar.example.invalid/current.gif',
      });
      await Future<void>.delayed(Duration.zero);
      backend.avatars = Completer<Map<String, String?>>();
      await admin.loadDashboard();
      expect(
        admin.filteredList.first.employee.avatarUrl,
        endsWith('/current.gif'),
        reason: 'a return to Admin must not briefly replace a cached photo with initials',
      );
      backend.avatars.complete({});
      await Future<void>.delayed(Duration.zero);
      expect(
        admin.filteredList.first.employee.avatarUrl,
        endsWith('/current.gif'),
        reason: 'a partial signing error does not confirm avatar removal',
      );
      backend.avatars = Completer<Map<String, String?>>();
      await admin.loadDashboard();
      backend.avatars.complete({'user-0': null});
      await Future<void>.delayed(Duration.zero);
      expect(
        admin.filteredList.first.employee.avatarUrl,
        isNull,
        reason: 'a confirmed missing avatar clears the old reference',
      );
    },
  );

  testWidgets(
    'admin cards show profile photos without delaying names or changing geometry',
    (tester) async {
      final backend = _Backend();
      final admin = provider(backend);
      addTearDown(admin.dispose);
      await admin.loadDashboard();
      expect(admin.isLoading, isFalse);
      expect(admin.totalEmployees, 2);
      expect(backend.batches.single.map((e) => e.authUserId), [
        'user-0',
        'user-1',
      ]);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: admin,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Consumer<AdminProvider>(
                  builder: (_, value, _) => Column(
                    children: [
                      for (final employee in value.filteredList)
                        EmployeeCard(data: employee),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alice Johnson'), findsOneWidget);
      expect(find.text('Jordan Lee'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      final before = tester.getRect(find.byType(EmployeeCard).first);
      backend.avatars.complete({
        'user-0': 'https://avatar.example.invalid/current.gif',
      });
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      final resize = image.image as ResizeImage;
      expect(
        (resize.imageProvider as NetworkImage).url,
        'https://avatar.example.invalid/current.gif',
      );
      expect(resize.width, (48 * tester.view.devicePixelRatio).ceil());
      expect(tester.getRect(find.byType(EmployeeCard).first), before);
      expect(
        find.text('JL'),
        findsOneWidget,
        reason: 'employee without a photo retains initials',
      );
      expect(
        find.text('AJ'),
        findsOneWidget,
        reason: 'failed download keeps initials behind the image',
      );
      expect(admin.totalEmployees, 2);
      expect(
        backend.batches.length,
        1,
        reason: 'one batch, not a request per row',
      );
      tester.view.physicalSize = const Size(320, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'old avatar responses cannot overwrite a newer dashboard refresh',
    () async {
      final backend = _Backend();
      final admin = provider(backend);
      addTearDown(admin.dispose);
      await admin.loadDashboard();
      final old = backend.avatars;
      backend.avatars = Completer<Map<String, String?>>();
      await admin.loadDashboard();
      backend.avatars.complete({
        'user-0': 'https://avatar.example.invalid/new.png',
      });
      await Future<void>.delayed(Duration.zero);
      old.complete({'user-0': 'https://avatar.example.invalid/old.png'});
      await Future<void>.delayed(Duration.zero);
      expect(admin.filteredList.first.employee.avatarUrl, endsWith('/new.png'));
    },
  );

  test(
    'avatar errors do not replace dashboard data or prevent retry',
    () async {
      final backend = _Backend();
      final admin = provider(backend);
      addTearDown(admin.dispose);
      await admin.loadDashboard();
      backend.avatars.completeError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(admin.totalEmployees, 2);
      expect(admin.error, isNull);
      backend.avatars = Completer<Map<String, String?>>();
      await admin.loadDashboard();
      backend.avatars.complete({
        'user-0': 'https://avatar.example.invalid/retry.png',
      });
      await Future<void>.delayed(Duration.zero);
      expect(
        admin.filteredList.first.employee.avatarUrl,
        endsWith('/retry.png'),
      );
    },
  );

  test('disposed office provider ignores pending avatar data', () async {
    final backend = _Backend();
    final admin = provider(backend);
    await admin.loadDashboard();
    admin.dispose();
    backend.avatars.complete({
      'user-0': 'https://avatar.example.invalid/late.png',
    });
    await Future<void>.delayed(Duration.zero);
    expect(admin.filteredList.first.employee.avatarUrl, isNull);
  });
}
