import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/company_backend.dart';
import 'services/attendance_service.dart';
import 'services/employees_service.dart';

void runAttendanceApp({CompanyBackend? backend}) {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(backend: backend)),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final active = auth.backend;
          return MultiProvider(
            key: ValueKey(
              '${identityHashCode(active)}:${auth.currentUser?.id ?? "signed-out"}',
            ),
            providers: [
              ChangeNotifierProvider(
                create: (_) => AttendanceProvider(backend: active),
              ),
              ChangeNotifierProvider(
                create: (_) => AttendanceHistoryProvider(
                  service: AttendanceService(backend: active),
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => AdminProvider(
                  attendanceService: AttendanceService(backend: active),
                  employeeService: EmployeeService(backend: active),
                ),
              ),
              ChangeNotifierProvider(
                create: (_) => ProfileProvider(backend: active),
              ),
            ],
            child: const AttendanceApp(),
          );
        },
      ),
    ),
  );
}
