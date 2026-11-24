import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/office_check_in_activity.dart';
import '../services/company_backend.dart';

/// The selected office's inbox and its device-local read marker.
class AdminActivityProvider extends ChangeNotifier {
  AdminActivityProvider(this.backend, {String? viewer, String? office})
    : _key = backend.isPreview || viewer == null || office == null
          ? null
          : 'admin_activity_read:$viewer:$office' {
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _startLive();
        unawaited(refresh());
      },
      onHide: _stopLive,
    );
    unawaited(refresh());
    _startLive();
  }

  final CompanyBackend backend;
  final String? _key;
  late final AppLifecycleListener _lifecycle;
  List<OfficeCheckInActivity> _rows = const [];
  Object? _error;
  Future<void>? _pending;
  bool _disposed = false;
  bool _saving = false;
  bool _markerLoaded = false;
  int _readAt = -1;
  String _readId = '';
  final _arrivals = StreamController<OfficeCheckInActivity>.broadcast();
  final _signals = <String?>{};
  final _announced = <String>{};
  StreamSubscription<String?>? _live;
  Timer? _liveTimer;
  int _liveGeneration = 0;

  bool get loading => _pending != null;
  bool get hasUnread => _rows.any(isUnread);
  bool get saving => _saving;
  List<OfficeCheckInActivity> get rows => _rows;
  Object? get error => _error;
  Stream<OfficeCheckInActivity> get arrivals => _arrivals.stream;

  void _startLive() {
    if (_key == null || _live != null || _disposed) return;
    _live = backend.checkInActivitySignals.listen(
      (id) {
        _signals.add(id);
        _scheduleLiveRefresh();
      },
      onError: (Object _) {
        // Manual refresh and resume remain available if Realtime is unavailable.
      },
    );
  }

  void _stopLive() {
    _liveGeneration++;
    _liveTimer?.cancel();
    _liveTimer = null;
    _signals.clear();
    final live = _live;
    _live = null;
    if (live != null) unawaited(live.cancel());
  }

  void _scheduleLiveRefresh() {
    final generation = _liveGeneration;
    _liveTimer ??= Timer(const Duration(milliseconds: 250), () async {
      // A read already in flight may have missed the newly committed rows.
      await _pending;
      if (generation != _liveGeneration) return;
      final ids = _signals.toSet();
      _signals.clear();
      await refresh();
      if (generation != _liveGeneration) return;
      if (_error == null) {
        for (final row in _rows.reversed) {
          if (ids.contains(row.id) && isUnread(row) && _announced.add(row.id)) {
            if (_announced.length > 60) _announced.remove(_announced.first);
            _arrivals.add(row);
          }
        }
      }
      _liveTimer = null;
      if (_signals.isNotEmpty) _scheduleLiveRefresh();
    });
  }

  bool isUnread(OfficeCheckInActivity row) {
    final at = row.receivedAt.microsecondsSinceEpoch;
    return at > _readAt || (at == _readAt && row.id.compareTo(_readId) > 0);
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    final pending = _pending;
    if (pending != null) return pending;
    final request = _pending = _load();
    notifyListeners();
    return request;
  }

  Future<void> _load() async {
    try {
      final result = await Future.sync(backend.checkInActivity);
      if (_disposed) return;
      if (!_markerLoaded && _key != null) {
        final prefs = await SharedPreferences.getInstance();
        if (_disposed) return;
        final marker = prefs.getString(_key)?.split('|');
        if (marker != null && marker.length == 2) {
          _readAt = int.tryParse(marker.first) ?? -1;
          _readId = marker.last;
        }
      }
      _markerLoaded = true;
      _rows = List.unmodifiable(result);
      _error = null;
    } catch (failure) {
      if (_disposed) return;
      _rows = const [];
      _error = failure;
    } finally {
      _pending = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> markAllRead() async {
    if (_disposed || _saving || !hasUnread) return true;
    // The RPC orders by the same timestamp and id pair, newest first.
    final latest = _rows.first;
    final at = latest.receivedAt.microsecondsSinceEpoch;
    _saving = true;
    notifyListeners();
    try {
      if (_key != null) {
        final prefs = await SharedPreferences.getInstance();
        if (_disposed || !await prefs.setString(_key, '$at|${latest.id}')) {
          return false;
        }
      }
      _readAt = at;
      _readId = latest.id;
      return true;
    } catch (_) {
      return false;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopLive();
    unawaited(_arrivals.close());
    _lifecycle.dispose();
    super.dispose();
  }
}
