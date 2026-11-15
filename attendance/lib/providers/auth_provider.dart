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
  CompanyBackend? _scopedBackend;
  CompanyBackend? _accountBackend;
  int _officeEpoch = 0;
  bool _changingOffice = false;
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
        if (_backend == backend &&
            !_changingOffice &&
            _status != AuthStatus.authenticating) {
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
  CompanyBackend? get backend => _scopedBackend ?? _backend;
  CompanyBackend? get officeBackend => _backend;
  CompanyBackend? get accountBackend => _accountBackend ?? _backend;
  String get accountScopeKey =>
      '${identityHashCode(_backend)}:${_currentUser?.authUserId ?? _currentUser?.id ?? "signed-out"}';
  String get officeScopeKey =>
      '$accountScopeKey:${_currentUser?.organizationId ?? "legacy"}:${_currentUser?.role}:$_officeEpoch';

  void _adopt(Employee? user) {
    final previous = _currentUser;
    _currentUser = user;
    if (user == null) {
      _scopedBackend = null;
      _accountBackend = null;
    } else {
      if (_accountBackend == null || previous?.authUserId != user.authUserId) {
        _accountBackend = _backend?.forAccount(user);
      }
      if (_scopedBackend == null ||
          previous?.organizationId != user.organizationId ||
          previous?.authUserId != user.authUserId) {
        _scopedBackend = _backend?.forOffice(user);
      }
    }
  }

  /// Switching changes office permissions without replacing the authenticated account.
  Future<void> switchOffice(String officeId) async {
    if (_changingOffice || _backend == null || _currentUser == null) {
      throw const CompanyException('An office change is already in progress.');
    }
    _changingOffice = true;
    final generation = ++_sessionGeneration;
    final source = _backend!;
    try {
      final user = await source.switchOffice(officeId);
      if (_disposed || generation != _sessionGeneration || _backend != source) {
        return;
      }
      _scopedBackend = null;
      _adopt(user);
      _error = null;
    } catch (_) {
      // A lost response may have committed the preference. Reconcile before
      // re-enabling requests; the backend blocks stale scopes if recovery fails.
      try {
        final user = await source.restoreSession();
        if (!_disposed &&
            generation == _sessionGeneration &&
            _backend == source) {
          _scopedBackend = null;
          _adopt(user);
          _status = user == null
              ? AuthStatus.unauthenticated
              : AuthStatus.authenticated;
        }
      } on CompanyAccessException {
        if (!_disposed && generation == _sessionGeneration) {
          _adopt(null);
          _status = AuthStatus.unauthenticated;
        }
      } catch (_) {
        /* Keep the account during an outage, with office requests blocked. */
      }
      rethrow;
    } finally {
      _changingOffice = false;
      if (!_disposed && generation == _sessionGeneration) {
        // Even an ambiguous network failure invalidates old in-flight requests/caches.
        _scopedBackend = _currentUser == null
            ? null
            : _backend?.forOffice(_currentUser!);
        _officeEpoch++;
        notifyListeners();
      }
    }
  }

  /// Refreshes membership without discarding a loaded account during outages.
  Future<void> refreshSession() async {
    if (_backend == null || _changingOffice) return;
    final generation = ++_sessionGeneration;
    try {
      final user = await _backend!.restoreSession();
      if (_disposed || generation != _sessionGeneration) return;
      _adopt(user);
      _status = user == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      _error = null;
    } catch (e) {
      if (_disposed || generation != _sessionGeneration) return;
      if (e is CompanyAccessException) _adopt(null);
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
    _scopedBackend = null;
    _accountBackend = null;
    _adopt(await _backend!.restoreSession());
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
        _adopt(await _backend!.signIn(employeeId.trim(), password));
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
      final updated = await accountBackend!.updateProfile(
        name: name,
        headline: headline,
        chips: chips,
      );
      if (_currentUser == null) return;
      _currentUser = _currentUser!.copyWith(
        name: updated.name,
        headline: updated.headline,
        chips: updated.chips,
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
      _adopt(null);
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
