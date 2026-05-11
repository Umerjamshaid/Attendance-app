import 'package:attendance/providers/admin_provider.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceHistoryProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: const AttendanceApp(),
    ),
  );
}
