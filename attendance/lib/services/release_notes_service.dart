import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads public Markdown for the installed release, never the latest tag alone.
class ReleaseNotesService {
  ReleaseNotesService({this._client, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static final shared = ReleaseNotesService();
  static final _releases = Uri.https(
    'api.github.com',
    '/repos/Umerjamshaid/Attendance-app/releases',
    {'per_page': '30'},
  );
  final http.Client? _client;
  final DateTime Function() _now;
  final _pending = <String, Future<String?>>{};

  Future<String?> notesFor(PackageInfo info, {bool allowNetwork = true}) {
    final key = 'release_notes:${info.version}+${info.buildNumber}';
    if (!allowNetwork) return _load(info, key, allowNetwork: false);
    return _pending[key] ??= _load(info, key).whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<String?> _load(
    PackageInfo info,
    String key, {
    bool allowNetwork = true,
  }) async {
    String? cached;
    http.Client? ownedClient;
    try {
      final preferences = await SharedPreferences.getInstance();
      cached = preferences.getString(key);
      if (!allowNetwork) return cached;
      final now = _now().millisecondsSinceEpoch;
      final retryAfter = preferences.getInt('$key:retry_after') ?? 0;
      if (retryAfter > now) return cached;

      // Back off even for offline, unpublished or rate-limited releases.
      await preferences.setInt(
        '$key:retry_after',
        now + const Duration(hours: 6).inMilliseconds,
      );
      final client = _client ?? (ownedClient = http.Client());
      final response = await client
          .get(
            _releases,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200 ||
          response.bodyBytes.length > 1024 * 1024) {
        return cached;
      }
      final releases = jsonDecode(utf8.decode(response.bodyBytes));
      if (releases is! List) return cached;

      final notes = _matchingNotes(releases, info);
      if (notes == null) return cached;
      await preferences.setString(key, notes);
      await preferences.setInt(
        '$key:retry_after',
        now + const Duration(days: 1).inMilliseconds,
      );
      return notes;
    } on Exception {
      return cached;
    } finally {
      ownedClient?.close();
    }
  }

  String? _matchingNotes(List<dynamic> releases, PackageInfo info) {
    final version = info.version;
    final build = info.buildNumber;
    final tags = [
      if (build.isNotEmpty) ...[
        'android-$version-$build',
        'v$version+$build',
        '$version+$build',
      ],
      'v$version',
      version,
    ];
    for (final tag in tags) {
      for (final release in releases.whereType<Map<String, dynamic>>()) {
        if (release['tag_name'] != tag ||
            release['draft'] != false ||
            release['prerelease'] != false) {
          continue;
        }
        final body = release['body'];
        if (body is String && body.trim().isNotEmpty && body.length <= 24000) {
          return body.trim();
        }
      }
    }
    return null;
  }
}
