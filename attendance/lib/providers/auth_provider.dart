import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employees_model.dart';
import '../services/employees_service.dart';
import '../services/company_backend.dart';
import '../services/preview_company_backend.dart';

enum AuthStatus { authenticated, unauthenticated, authenticating, initial }

class AuthProvider extends ChangeNotifier {
  final EmployeeService _employeeService;
  final CompanyBackend? _liveBackend;
  CompanyBackend? _backend;
  StreamSubscription<void>? _authSubscription;
  bool _disposed = false;
  int _sessionGeneration = 0;

  AuthStatus _status = AuthStatus.initial;
  Employee? _currentUser;
  String? _error;

  AuthProvider({EmployeeService? employeeService, CompanyBackend? backend})
    : _employeeService = employeeService ?? EmployeeService(),
      _backend = backend,
      _liveBackend = backend {
    if (backend == null) {
      _checkLoginStatus();
    } else {
      _authSubscription = backend.authChanges.listen((_) {
        if (_backend == backend && _status != AuthStatus.authenticating) {
          refreshSession();
        }
      });
      refreshSession();
    }
  }

  AuthStatus get status => _status;
  Employee? get currentUser => _currentUser;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isDemoMode => _backend?.isPreview ?? _employeeService.isDemoMode;
  bool get isPublicBuild => _liveBackend != null;
  bool get isPreview => _backend?.isPreview ?? false;
  bool get isConfigured => _backend?.isConfigured ?? true;
  bool get needsPasswordSetup => _backend?.needsPasswordSetup ?? false;
  CompanyBackend? get backend => _backend;

  /// Refreshes membership without discarding a loaded account during outages.
  Future<void> refreshSession() async {
    if (_backend == null) return;
    final generation = ++_sessionGeneration;
    try {
      final user = await _backend!.restoreSession();
      if (_disposed || generation != _sessionGeneration) return;
      _currentUser = user;
      _status = user == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      _error = null;
    } catch (e) {
      if (_disposed || generation != _sessionGeneration) return;
      if (e is CompanyAccessException) _currentUser = null;
      _status = _currentUser == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<void> enterPreview() async {
    if (!isPublicBuild) return;
    ++_sessionGeneration;
    _backend = PreviewCompanyBackend();
    _currentUser = await _backend!.restoreSession();
    _status = AuthStatus.authenticated;
    _error = null;
    notifyListeners();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId != null) {
      final employees = await _employeeService.getAllEmployees();
      try {
        Employee user = employees.firstWhere((e) => e.id == userId);

        // Load persisted name/email/headline/chips specific to this user
        final savedName = prefs.getString('${userId}_userName');
        final savedEmail = prefs.getString('${userId}_userEmail');
        final savedHeadline = prefs.getString('${userId}_headline');
        final savedChips = prefs.getStringList('${userId}_chips');
        if (savedName != null ||
            savedEmail != null ||
            savedHeadline != null ||
            savedChips != null) {
          user = user.copyWith(
            name: savedName,
            email: savedEmail,
            headline: savedHeadline,
            chips: savedChips,
          );
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

  Future<bool> login(String employeeId, {String password = ''}) async {
    if (_status == AuthStatus.authenticating) return false;
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      if (_backend != null) {
        _currentUser = await _backend!.signIn(employeeId.trim(), password);
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 900));

      final employees = await _employeeService.getAllEmployees();
      final idUpper = employeeId.toUpperCase();
      Employee employee = employees.firstWhere(
        (e) => e.id.toUpperCase() == idUpper,
        orElse: () => throw Exception('Invalid Employee ID'),
      );

      final prefs = await SharedPreferences.getInstance();

      // Load persisted name/email/headline/chips specific to this user
      final savedName = prefs.getString('${employee.id}_userName');
      final savedEmail = prefs.getString('${employee.id}_userEmail');
      final savedHeadline = prefs.getString('${employee.id}_headline');
      final savedChips = prefs.getStringList('${employee.id}_chips');
      if (savedName != null ||
          savedEmail != null ||
          savedHeadline != null ||
          savedChips != null) {
        employee = employee.copyWith(
          name: savedName,
          email: savedEmail,
          headline: savedHeadline,
          chips: savedChips,
        );
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

  Future<void> updateProfile({
    String? name,
    String? email,
    String? headline,
    List<String>? chips,
  }) async {
    if (_currentUser == null) return;
    if (_backend != null) {
      if (email != null && email.trim() != _currentUser!.email) {
        throw const CompanyException(
          'Change your sign-in email from Account & security.',
        );
      }
      _currentUser = await _backend!.updateProfile(
        name: name,
        headline: headline,
        chips: chips,
      );
      notifyListeners();
      return;
    }

    final userId = _currentUser!.id;
    _currentUser = _currentUser!.copyWith(
      name: name,
      email: email,
      headline: headline,
      chips: chips,
    );

    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('${userId}_userName', name);
    if (email != null) await prefs.setString('${userId}_userEmail', email);
    if (headline != null) await prefs.setString('${userId}_headline', headline);
    if (chips != null) await prefs.setStringList('${userId}_chips', chips);

    notifyListeners();
  }

  Future<void> logout() async {
    if (_backend != null) {
      await _backend!.signOut();
      ++_sessionGeneration;
      _backend = _liveBackend;
      _status = AuthStatus.unauthenticated;
      _currentUser = null;
      _error = null;
      notifyListeners();
      return;
    }
    _status = AuthStatus.unauthenticated;
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');

    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_sessionGeneration;
    _authSubscription?.cancel();
    super.dispose();
  }
}
