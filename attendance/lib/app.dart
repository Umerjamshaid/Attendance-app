import 'package:attendance/screens/app_shell.dart';
import 'package:attendance/screens/root_page.dart';
import 'package:flutter/material.dart';
import 'config/app_theme.dart';

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const RootPage(),
    );
  }
}
