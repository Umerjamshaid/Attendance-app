import 'package:shared_preferences/shared_preferences.dart';

/// Advisory, per-account history of email sends confirmed on this device.
class InviteEmailActivity {
  InviteEmailActivity(String? accountId)
    : _key = accountId == null ? null : 'invite_email_sends:$accountId';

  static const window = Duration(hours: 1);
  static const noticeThreshold = 2;
  final String? _key;
  List<DateTime> _sends = const [];

  Future<List<DateTime>> recent({bool recordSend = false}) async {
    final now = DateTime.now();
    final key = _key;
    SharedPreferences? prefs;
    if (key != null) {
      try {
        prefs = await SharedPreferences.getInstance();
        _sends = [
          for (final value in prefs.getStringList(key) ?? const <String>[])
            if (int.tryParse(value) case final stamp?
                when stamp > now.subtract(window).millisecondsSinceEpoch &&
                    stamp <= now.millisecondsSinceEpoch)
              DateTime.fromMillisecondsSinceEpoch(stamp),
        ];
      } catch (_) {
        // A storage error must not change the result of sending an invitation.
      }
    }
    _sends = [...withinWindow(_sends, now), if (recordSend) now]..sort();
    if (recordSend && key != null && prefs != null) {
      try {
        await prefs.setStringList(key, [
          for (final send in _sends) send.millisecondsSinceEpoch.toString(),
        ]);
      } catch (_) {
        // Keep the count in memory for this screen if persistence fails.
      }
    }
    return List.unmodifiable(_sends);
  }

  static List<DateTime> withinWindow(Iterable<DateTime> sends, DateTime now) {
    final start = now.subtract(window);
    return [
      for (final send in sends)
        if (send.isAfter(start) && !send.isAfter(now)) send,
    ];
  }
}
