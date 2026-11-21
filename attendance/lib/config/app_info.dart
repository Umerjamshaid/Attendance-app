import 'package:package_info_plus/package_info_plus.dart';

abstract final class AppInfo {
  static const name = 'Attendance';
  static const maker = 'Umer Jamshaid';
  static const makerPhoto = 'assets/logos/credits.jpeg';
  static const supportEmail = 'umerjamshaid481@gmail.com';
  static const makerGitHub = 'https://github.com/Umerjamshaid';
  static const sourceRepository = '$makerGitHub/Attendance-app';

  static String versionLabel(PackageInfo info) => info.buildNumber.isEmpty
      ? 'Version ${info.version}'
      : 'Version ${info.version} (Build ${info.buildNumber})';
}
