import 'dart:io';

class DeviceService {
  Future<String> getDeviceModel() async {
    // In a real app, use package:device_info_plus
    // For now, returning platform name
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iPhone';
    return 'Web Browser';
  }

  Future<String> getDeviceId() async {
    // In a real app, use package:android_id or similar
    return 'DEV-${DateTime.now().millisecondsSinceEpoch % 1000000}';
  }
}
