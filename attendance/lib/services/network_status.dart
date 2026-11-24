import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// Tracks whether the device can reach the company backend, not just Wi-Fi.
class NetworkStatus extends ChangeNotifier {
  factory NetworkStatus.forBackend(Uri backend) {
    final connectivity = Connectivity();
    bool hasLink(List<ConnectivityResult> results) =>
        results.any((result) => result != ConnectivityResult.none);
    return NetworkStatus(
      links: connectivity.onConnectivityChanged.map(hasLink),
      checkLink: () async => hasLink(await connectivity.checkConnectivity()),
      probe: () async {
        final client = http.Client();
        try {
          final request = http.Request(
            'HEAD',
            backend.resolve('/auth/v1/health'),
          )..followRedirects = false;
          final response = await client
              .send(request)
              .timeout(const Duration(seconds: 3));
          // Any HTTP response from the TLS endpoint proves reachability.
          return response.statusCode < 300 || response.statusCode >= 400;
        } finally {
          client.close();
        }
      },
    );
  }

  NetworkStatus({
    required Stream<bool> links,
    required this._checkLink,
    required this._probe,
  }) {
    _links = links.distinct().listen(_observe, onError: (Object _) {});
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _foreground = false;
        _retry?.cancel();
        _generation++;
      },
      onResume: () {
        _foreground = true;
        unawaited(refresh());
      },
    );
    unawaited(refresh());
  }

  static const offlineMessage = 'Turn on your internet connection';

  final Future<bool> Function() _checkLink;
  final Future<bool> Function() _probe;
  late final StreamSubscription<bool> _links;
  late final AppLifecycleListener _lifecycle;
  bool _offline = false, _foreground = true, _disposed = false;
  int _generation = 0;
  Timer? _retry;

  bool get offline => _offline;

  Future<void> refresh() async {
    final generation = ++_generation;
    bool link;
    try {
      link = await _checkLink().timeout(const Duration(seconds: 2));
    } on Exception {
      link = true;
    }
    if (generation == _generation) await _observe(link);
  }

  Future<void> _observe(bool link) async {
    if (_disposed || !_foreground) return;
    final generation = ++_generation;
    _retry?.cancel();
    bool reachable = false;
    if (link) {
      try {
        reachable = await _probe();
      } on Exception {
        reachable = false;
      }
    }
    if (generation != _generation) return;
    final offline = !reachable;
    if (_offline != offline) {
      _offline = offline;
      notifyListeners();
    }
    if (link && !reachable && !_disposed) {
      _retry = Timer(const Duration(seconds: 15), refresh);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _retry?.cancel();
    unawaited(_links.cancel());
    _lifecycle.dispose();
    super.dispose();
  }
}
