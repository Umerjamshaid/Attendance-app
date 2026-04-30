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
      // In a real app, we might fetch the user profile from the server here
      // For now, we'll assume the user is valid if the ID exists
      // You could also mock fetching the employee details
      final employees = await _employeeService.getAllEmployees();
      try {
        _currentUser = employees.firstWhere((e) => e.id == userId);
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
      final employee = employees.firstWhere(
        (e) => e.id.toUpperCase() == employeeId.toUpperCase(),
        orElse: () => throw Exception('Invalid Employee ID'),
      );

      _currentUser = employee;
      _status = AuthStatus.authenticated;
      
      final prefs = await SharedPreferences.getInstance();
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

  Future<void> logout() async {
    _status = AuthStatus.unauthenticated;
    _currentUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    
    notifyListeners();
  }
}
