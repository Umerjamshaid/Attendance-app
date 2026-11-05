import 'package:flutter/material.dart';

import '../services/local_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({LocalStorageService? storage})
    : _storage = storage ?? LocalStorageService() {
    ready = _restore();
  }

  final LocalStorageService _storage;
  late final Future<void> ready;
  ThemeMode _mode = ThemeMode.system;
  bool _busy = true;
  bool _disposed = false;

  ThemeMode get mode => _mode;
  bool get busy => _busy;

  Future<void> _restore() async {
    try {
      final saved = await _storage.getThemeMode();
      _mode = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // System is the fallback when the preference cannot be read.
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> select(ThemeMode mode) async {
    if (_busy || mode == _mode) return;
    _busy = true;
    notifyListeners();
    try {
      await _storage.saveThemeMode(mode.name);
      _mode = mode;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
