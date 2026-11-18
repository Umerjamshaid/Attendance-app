import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../services/local_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({LocalStorageService? storage})
    : _storage = storage ?? LocalStorageService() {
    ready = _restore();
  }

  final LocalStorageService _storage;
  late final Future<void> ready;
  ThemeMode _mode = ThemeMode.system;
  AppPalette _palette = AppPalette.olive;
  bool _busy = true;
  bool _disposed = false;

  ThemeMode get mode => _mode;
  AppPalette get palette => _palette;
  bool get busy => _busy;

  Future<void> _restore() async {
    try {
      final saved = await _storage.getThemeMode();
      _mode = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.system,
      );
      final palette = await _storage.getThemePalette();
      _palette = AppPalette.values.firstWhere(
        (value) => value.name == palette,
        orElse: () => AppPalette.olive,
      );
    } catch (_) {
      // Keep defaults for any appearance preference we could not read.
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> select(ThemeMode mode) async {
    if (mode == _mode) return;
    await _save(() => _storage.saveThemeMode(mode.name), () => _mode = mode);
  }

  Future<void> selectPalette(AppPalette palette) async {
    if (palette == _palette) return;
    await _save(
      () => _storage.saveThemePalette(palette.name),
      () => _palette = palette,
    );
  }

  Future<void> _save(Future<void> Function() save, VoidCallback apply) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await save();
      apply();
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
