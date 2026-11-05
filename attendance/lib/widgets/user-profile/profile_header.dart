import 'package:attendance/config/app_icons.dart';
import '../profile_image.dart';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/widgets/user-profile/edit_profile_sheet.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../screens/profile/account_edit_screen.dart';

/// Whether the employee has checked in today, as derived by the screen from
/// the attendance history.
enum TodayStatus { loading, present, notCheckedIn, unknown }

/// Centered profile header: rounded cover banner, overlapping avatar, name,
/// handle, today's status pill, headline, info chips and an edit action.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.employee,
    this.todayStatus = TodayStatus.notCheckedIn,
  });

  final Employee employee;
  final TodayStatus todayStatus;

  static const double _bannerHeight = 112;
  static const double _avatarSize = 104;
  static const double _ring = 4;
  static const double _avatarOuter = _avatarSize + _ring * 2;

  /// First letter of [name] for the avatar fallback ('?' when empty).
  static String _initialOf(String name) =>
      name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();

  Future<void> _changeImage(
    BuildContext context,
    Future<void> Function(ProfileProvider provider) pick,
  ) async {
    HapticFeedback.selectionClick();
    final provider = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await pick(provider);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Couldn’t update the photo. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeBanner(BuildContext context) async {
    HapticFeedback.selectionClick();
    final provider = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.removeBanner(employee.id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Banner removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Couldn’t remove the banner. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEditSheet(BuildContext context) async {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (auth.isPreview) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile editing is unavailable in the preview.'),
        ),
      );
      return;
    }
    if (auth.isPublicBuild) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AccountEditScreen(
            title: 'Display name',
            label: 'Display name',
            initialValue: employee.name,
            onSave: (value) => auth.updateProfile(name: value),
          ),
        ),
      );
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ProfileUi.sheetRadius),
        ),
      ),
      builder: (_) => EditProfileSheet(
        initialName: employee.name,
        initialEmail: employee.email,
        onSave: (name, email) => auth.updateProfile(name: name, email: email),
      ),
    );

    if (saved == true) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Profile updated'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final name = employee.name.trim();
    final handle = employee.id.trim().toLowerCase();
    final headline = employee.headline?.trim() ?? '';
    final role = employee.role.trim();
    final department = employee.department.trim();
    final seen = {role.toLowerCase(), department.toLowerCase()};
    final tags = employee.chips
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty && seen.add(tag.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ProfileUi.gutter,
            8,
            ProfileUi.gutter,
            0,
          ),
          child: SizedBox(
            height: _bannerHeight + _avatarOuter / 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _bannerHeight,
                  child: _Banner(
                    path: profile.bannerPath,
                    onTap: () =>
                        _changeImage(context, (p) => p.pickBanner(employee.id)),
                    onRemove: () => _removeBanner(context),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: _bannerHeight - _avatarOuter / 2,
                  child: Center(
                    child: _Avatar(
                      initial: _initialOf(name),
                      localPath: profile.pfpPath,
                      networkUrl: employee.avatarUrl,
                      size: _avatarSize,
                      ring: _ring,
                      onTap: () =>
                          _changeImage(context, (p) => p.pickPfp(employee.id)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ProfileUi.gutter),
          child: Column(
            children: [
              Semantics(
                header: true,
                child: Text(
                  name.isEmpty ? 'Your profile' : name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              if (handle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '@$handle',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileUi.small(context),
                ),
              ],
              if (department.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  department,
                  textAlign: TextAlign.center,
                  style: ProfileUi.small(context),
                ),
              ],
              const SizedBox(height: 10),
              _ProfileChipGroup(
                children: [
                  if (role.isNotEmpty)
                    _InfoChip(
                      label: role[0].toUpperCase() + role.substring(1),
                      icon: AppIcons.idBadge2,
                    ),
                  _StatusPill(status: todayStatus),
                ],
              ),
              if (headline.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileUi.small(
                    context,
                    color: context.colors.onSurface,
                  ),
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Semantics(
                  container: true,
                  label: 'Profile tags',
                  child: _ProfileChipGroup(
                    children: [for (final tag in tags) _InfoChip(label: tag)],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openEditSheet(context),
                icon: const Icon(AppIcons.edit, size: 24),
                label: const Text('Edit profile'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.surfaceContainerLow,
                  foregroundColor: context.colors.onSurface,
                  elevation: 0,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileChipGroup extends StatelessWidget {
  const _ProfileChipGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final child in children)
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: child,
          ),
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.path,
    required this.onTap,
    required this.onRemove,
  });

  final String? path;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  static const int _decodeWidth = 1080;

  @override
  Widget build(BuildContext context) {
    final image = path;
    final hasBanner = image != null;
    return Semantics(
      container: true,
      button: true,
      label: hasBanner ? 'Change cover photo' : 'Select cover photo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ProfileUi.cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: !hasBanner
                  ? const _BannerGradient(key: ValueKey('default-banner'))
                  : SizedBox.expand(
                      key: ValueKey(image),
                      child: Image(
                        image: ResizeImage(
                          profileImageProvider(image),
                          width: _decodeWidth,
                        ),
                        fit: BoxFit.cover,
                        // The picked file can disappear (cache cleared). The
                        // remove action stays available to clear the stale path.
                        errorBuilder: (_, _, _) => const _BannerGradient(),
                      ),
                    ),
            ),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ),
            if (!hasBanner)
              const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: IgnorePointer(child: _BannerPrompt()),
                ),
              )
            else
              Positioned(
                top: 4,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RemoveBannerButton(onPressed: onRemove),
                    const SizedBox(width: 2),
                    const IgnorePointer(child: _CameraChip()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty-banner hint. It sits in the top half because the avatar overlaps the
/// bottom centre of the banner.
class _BannerPrompt extends StatelessWidget {
  const _BannerPrompt();

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.85);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.photoPlus, size: 24, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Tap to select banner',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Round "remove" action with a 44dp touch target around the 32dp visual.
class _RemoveBannerButton extends StatelessWidget {
  const _RemoveBannerButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Remove cover photo',
      // excludeSemantics drops the GestureDetector's own tap action, so it is
      // exposed here for screen readers.
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(AppIcons.trash, size: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _BannerGradient extends StatelessWidget {
  const _BannerGradient({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkNavy, AppTheme.primaryNavy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _CameraChip extends StatelessWidget {
  const _CameraChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: const Icon(AppIcons.camera, size: 24, color: Colors.white),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initial,
    required this.localPath,
    required this.networkUrl,
    required this.size,
    required this.ring,
    required this.onTap,
  });

  final String initial;
  final String? localPath;
  final String? networkUrl;
  final double size;
  final double ring;
  final VoidCallback onTap;

  static const int _decodeWidth = 336;

  Widget _buildImage(BuildContext context) {
    final url = networkUrl;
    final path = localPath;

    Widget network() {
      if (url == null || url.isEmpty) return const SizedBox.shrink();
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: _decodeWidth,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
        frameBuilder: (_, child, frame, wasSync) => wasSync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // The initial sits underneath so a failed or slow image never leaves
        // an empty circle.
        Center(
          child: Text(
            initial,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              color: context.colors.primary,
            ),
          ),
        ),
        if (path != null)
          Image(
            image: ResizeImage(profileImageProvider(path), width: _decodeWidth),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => network(),
          )
        else
          network(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final outer = size + ring * 2;
    return _PressableScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Change profile photo',
        child: SizedBox(
          width: outer,
          height: outer,
          child: Stack(
            children: [
              Container(
                width: outer,
                height: outer,
                padding: EdgeInsets.all(ring),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.surface,
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: SizedBox.expand(
                        key: ValueKey('${localPath ?? ''}|${networkUrl ?? ''}'),
                        child: _buildImage(context),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.surface, width: 3),
                  ),
                  child: Icon(
                    AppIcons.cameraPlus,
                    size: 24,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scales its child down slightly while pressed.
class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TodayStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TodayStatus.present => ('Present today', context.attendancePresent),
      TodayStatus.loading => (
        'Checking status…',
        context.colors.onSurfaceVariant,
      ),
      TodayStatus.notCheckedIn => (
        'Not checked in yet',
        context.colors.onSurfaceVariant,
      ),
      TodayStatus.unknown => (
        'Status unavailable',
        context.colors.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: 'Attendance today: $label',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 24), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: context.colors.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
