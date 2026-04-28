import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance/screens/login/login_screen.dart';
import 'package:attendance/screens/app_shell.dart';

class RootPage extends StatefulWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  _RootPageState createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _loggedIn = prefs.getBool('loggedIn') ?? false;
    });
  }

  void _onLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', true);
    setState(() {
      _loggedIn = true;
    });
  }

  void _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);
    setState(() {
      _loggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loggedIn) {
      // Main app with bottom nav
      return AppShell();
    } else {
      // Auth flow: show login full screen
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }
  }
}
