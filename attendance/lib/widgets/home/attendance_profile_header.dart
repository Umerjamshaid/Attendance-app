import '../profile_image.dart';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Compact greeting row for the home screen: avatar, name and department.
class AttendanceProfileHeader extends StatelessWidget {
  const AttendanceProfileHeader({super.key, required this.employee});

  final Employee employee;

  static const double _avatarSize = 48;

  /// First letter of [name] for the avatar fallback ('?' when empty).
  static String _initialOf(String name) =>
      name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final name = employee.name.trim();
    final department = employee.department.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileUi.gutter,
        8,
        ProfileUi.gutter,
        0,
      ),
      child: Row(
        children: [
          _HeaderAvatar(
            size: _avatarSize,
            initial: _initialOf(name),
            localPath: profile.pfpPath,
            networkUrl: employee.avatarUrl,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    name.isEmpty ? 'Welcome' : name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
                if (department.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    department,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ProfileUi.small(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular avatar. Falls back local file -> network image -> initial, and
/// never leaves an empty circle if an image is missing or fails to load.
class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({
    required this.size,
    required this.initial,
    required this.localPath,
    required this.networkUrl,
  });

  final double size;
  final String initial;
  final String? localPath;
  final String? networkUrl;

  static const int _decodeWidth = 144;

  Widget _network() {
    final url = networkUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: _decodeWidth,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: ColoredBox(
          color: context.colors.primaryContainer,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  initial,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
              ),
              if (path != null)
                Image(
                  image: ResizeImage(
                    profileImageProvider(path),
                    width: _decodeWidth,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _network(),
                )
              else
                _network(),
            ],
          ),
        ),
      ),
    );
  }
}
