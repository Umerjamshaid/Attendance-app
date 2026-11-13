import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/office_model.dart';
import '../services/company_backend.dart';
import 'auth_provider.dart';

/// Online-only office selection. Server memberships, never local preferences, grant access.
class OfficeProvider extends ChangeNotifier {
  OfficeProvider(this.auth) {
    auth.addListener(_authChanged);
    _accountKey = auth.accountScopeKey;
    _scopeKey = auth.officeScopeKey;
    _officeId = auth.currentUser?.organizationId;
    unawaited(reload());
  }
  final AuthProvider auth;
  List<Office> _offices = [];
  List<OfficeInvitation> _invitations = [];
  late String _accountKey;
  late String _scopeKey;
  String? _officeId;
  bool _loading = false, _busy = false, _disposed = false;
  int _generation = 0;
  String? _error;
  List<Office> get offices => List.unmodifiable(_offices);
  List<OfficeInvitation> get invitations => List.unmodifiable(_invitations);
  String? get activeOfficeId => auth.currentUser?.organizationId;
  Office? get activeOffice =>
      _offices.where((o) => o.id == activeOfficeId).firstOrNull;
  bool get isLoading => _loading;
  bool get isSwitching => _busy;
  bool get isPreview => auth.isPreview;
  bool get isSupported => auth.accountBackend?.supportsOffices ?? false;
  bool get canManage => !isPreview && _offices.any((o) => o.isAdmin);
  String? get error => _error;
  CompanyBackend get _backend => auth.accountBackend!;

  void _authChanged() {
    if (_disposed) return;
    if (_accountKey != auth.accountScopeKey) {
      _generation++;
      _offices = [];
      _invitations = [];
      _error = null;
      _busy = false;
      _accountKey = auth.accountScopeKey;
    }
    final changed =
        _officeId != activeOfficeId || _scopeKey != auth.officeScopeKey;
    _scopeKey = auth.officeScopeKey;
    _officeId = activeOfficeId;
    if (!_busy && (changed || _offices.isEmpty)) unawaited(reload());
    notifyListeners();
  }

  Future<void> reload({bool preserveError = false}) async {
    final generation = ++_generation;
    if (!preserveError) _error = null;
    if (auth.currentUser == null || !isSupported) {
      _offices = [];
      _invitations = [];
      _loading = false;
      notifyListeners();
      return;
    }
    final backend = _backend;
    _loading = true;
    notifyListeners();
    try {
      final offices = await backend.offices();
      final invitations = await backend.officeInvitations();
      if (_disposed || generation != _generation) return;
      _offices = offices;
      _invitations = invitations;
      if (activeOfficeId != null &&
          !offices.any((office) => office.id == activeOfficeId)) {
        unawaited(auth.refreshSession());
      }
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error.toString();
    } finally {
      if (!_disposed && generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> _change(Future<void> Function() operation) async {
    if (_busy || _disposed) return false;
    final key = auth.accountScopeKey;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await operation();
      return !_disposed && key == auth.accountScopeKey;
    } catch (error) {
      if (!_disposed && key == auth.accountScopeKey) _error = error.toString();
      return false;
    } finally {
      if (!_disposed && key == auth.accountScopeKey) {
        _busy = false;
        notifyListeners();
        await reload(preserveError: true);
      }
    }
  }

  Future<bool> switchOffice(String officeId) => _change(() async {
    // This list improves UX only; the server reauthorizes every request.
    if (!_offices.any((o) => o.id == officeId)) {
      throw const CompanyException('You do not have access to this office.');
    }
    await auth.switchOffice(officeId);
  });
  Future<bool> createOffice(String name) => _change(() async {
    if (!canManage) {
      throw const CompanyException(
        'Only an active administrator can create offices.',
      );
    }
    final id = await _backend.createOffice(name);
    await auth.switchOffice(id);
  });
  Future<bool> updateOffice(
    Office office, {
    required String name,
    Uint8List? logo,
    bool removeLogo = false,
  }) => _change(() async {
    await _backend.updateOffice(
      office,
      name: name,
      logo: logo,
      removeLogo: removeLogo,
    );
    if (office.id == activeOfficeId) await auth.refreshSession();
  });
  Future<bool> acceptInvitation(String invitationId) => _change(() async {
    final id = await _backend.acceptOfficeInvitation(invitationId);
    await auth.switchOffice(id);
  });
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    auth.removeListener(_authChanged);
    super.dispose();
  }
}
