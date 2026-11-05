import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  DeviceService({this.useRealInfo = false});
  final bool useRealInfo;
  Future<String> getDeviceModel() async {
    if (useRealInfo) {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final device = await info.androidInfo;
        return '${device.manufacturer} ${device.model}';
      }
      if (Platform.isIOS) return (await info.iosInfo).utsname.machine;
    }
    // In a real app, use package:device_info_plus
    // For now, returning platform name
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iPhone';
    return 'Web Browser';
  }

  Future<String> getDeviceId() async {
    if (useRealInfo) {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('workcheck_installation_id');
      if (existing != null) return existing;
      final id = const Uuid().v4();
      await prefs.setString('workcheck_installation_id', id);
      return id;
    }
    // In a real app, use package:android_id or similar
    return 'DEV-${DateTime.now().millisecondsSinceEpoch % 1000000}';
  }
}
