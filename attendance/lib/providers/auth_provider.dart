import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employees_model.dart';
import '../services/employees_service.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating, initial }

class AuthProvider extends ChangeNotifier {
  final EmployeeService _employeeService;
  
  AuthStatus _status = AuthStatus.initial;
  Employee? _currentUser;
  String? _error;

  AuthProvider({EmployeeService? employeeService})
      : _employeeService = employeeService ?? EmployeeService() {
    _checkLoginStatus();
  }

  AuthStatus get status => _status;
  Employee? get currentUser => _currentUser;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId != null) {
      final employees = await _employeeService.getAllEmployees();
      try {
        Employee user = employees.firstWhere((e) => e.id == userId);

        // Load persisted name/email specific to this user
        final savedName = prefs.getString('${userId}_userName');
        final savedEmail = prefs.getString('${userId}_userEmail');
        if (savedName != null || savedEmail != null) {
          user = user.copyWith(name: savedName, email: savedEmail);
        }

        _currentUser = user;
        _status = AuthStatus.authenticated;
      } catch (e) {
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String employeeId) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 900));

      final employees = await _employeeService.getAllEmployees();
      final idUpper = employeeId.toUpperCase();
      Employee employee = employees.firstWhere(
        (e) => e.id.toUpperCase() == idUpper,
        orElse: () => throw Exception('Invalid Employee ID'),
      );

      final prefs = await SharedPreferences.getInstance();

      // Load persisted name/email specific to this user
      final savedName = prefs.getString('${employee.id}_userName');
      final savedEmail = prefs.getString('${employee.id}_userEmail');
      if (savedName != null || savedEmail != null) {
        employee = employee.copyWith(name: savedName, email: savedEmail);
      }

      _currentUser = employee;
      _status = AuthStatus.authenticated;

      await prefs.setString('userId', employee.id);

      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({String? name, String? email}) async {
    if (_currentUser == null) return;

    final userId = _currentUser!.id;
    _currentUser = _currentUser!.copyWith(
      name: name,
      email: email,
    );

    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('${userId}_userName', name);
    if (email != null) await prefs.setString('${userId}_userEmail', email);

    notifyListeners();
  }

  Future<void> logout() async {
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    
    notifyListeners();
  }
}
