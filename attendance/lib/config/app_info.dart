import 'package:package_info_plus/package_info_plus.dart';

abstract final class AppInfo {
  static const name = 'Attendance';

  static String versionLabel(PackageInfo info) => info.buildNumber.isEmpty
      ? 'Version ${info.version}'
      : 'Version ${info.version} (Build ${info.buildNumber})';
}
