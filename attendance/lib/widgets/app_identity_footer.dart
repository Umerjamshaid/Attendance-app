import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_info.dart';
import '../config/ui_tokens.dart';

class AttendanceMark extends StatelessWidget {
  const AttendanceMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

/// The installed build and maker credit shared by Profile and Settings.
class AppIdentityFooter extends StatefulWidget {
  const AppIdentityFooter({super.key});

  @override
  State<AppIdentityFooter> createState() => _AppIdentityFooterState();
}

class _AppIdentityFooterState extends State<AppIdentityFooter> {
  late final _package = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final creditStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontFamily: 'Nanum Pen Script',
      fontSize: 22,
      height: 1.1,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AttendanceMark(size: 36),
        const SizedBox(height: 4),
        FutureBuilder(
          future: _package,
          builder: (context, snapshot) {
            final info = snapshot.data;
            return Text(
              info == null
                  ? AppInfo.name
                  : '${AppInfo.name} \u00b7 ${AppInfo.versionLabel(info)}',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: colors.onSurfaceVariant,
                fontFamily: 'monospace',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Semantics(
          label: 'Crafted by Umer Jamshaid',
          excludeSemantics: true,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text('Crafted by', style: creditStyle),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/logos/credits.jpeg',
                      key: const ValueKey('developer-credit-photo'),
                      width: 20,
                      height: 20,
                      cacheWidth: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: Text('Umer Jamshaid', style: creditStyle)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
