import 'dart:io';

import 'package:attendance/config/app_theme.dart';
import 'package:attendance/config/wc_tokens.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/widgets/user-profile/edit_profile_sheet.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: ProfileUi.page,
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
          backgroundColor: WC.present,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  String? get _headline {
    final custom = employee.headline?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final role = employee.role.trim();
    final department = employee.department.trim();
    if (role.isNotEmpty && department.isNotEmpty) return '$role at $department';
    final single = role.isNotEmpty ? role : department;
    return single.isEmpty ? null : single;
  }

  List<_ChipData> get _chips {
    final custom = employee.chips
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .map((c) => _ChipData(label: c))
        .toList();
    if (custom.isNotEmpty) return custom;

    final department = employee.department.trim();
    final role = employee.role.trim();
    final joined = employee.time.split(' ').first.trim();
    return [
      if (department.isNotEmpty)
        _ChipData(label: department, icon: Icons.business_center_outlined),
      if (role.isNotEmpty)
        _ChipData(
          label: role.toUpperCase(),
          icon: Icons.verified_user_outlined,
        ),
      // `time` defaults to an em dash when the join date is unknown.
      if (joined.isNotEmpty && joined != '—')
        _ChipData(label: 'Joined $joined', icon: Icons.calendar_month_outlined),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final name = employee.name.trim();
    final handle = employee.id.trim().toLowerCase();
    final headline = _headline;
    final chips = _chips;

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
                      initial: name.isEmpty
                          ? '?'
                          : name.characters.first.toUpperCase(),
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
                    color: AppTheme.textPrimary,
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
                  style: ProfileUi.small(),
                ),
              ],
              const SizedBox(height: 12),
              _StatusPill(status: todayStatus),
              if (headline != null) ...[
                const SizedBox(height: 12),
                Text(
                  headline,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileUi.small(color: AppTheme.textPrimary),
                ),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final chip in chips)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth,
                          ),
                          child: _InfoChip(data: chip),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openEditSheet(context),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit profile'),
                style: FilledButton.styleFrom(
                  backgroundColor: ProfileUi.cardFill,
                  foregroundColor: AppTheme.textPrimary,
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

class _ChipData {
  const _ChipData({required this.label, this.icon});

  final String label;
  final IconData? icon;
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
                      child: Image.file(
                        File(image),
                        fit: BoxFit.cover,
                        cacheWidth: _decodeWidth,
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
        Icon(Icons.add_photo_alternate_outlined, size: 18, color: color),
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
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 16,
              color: Colors.white,
            ),
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
      child: const Icon(
        Icons.camera_alt_rounded,
        size: 16,
        color: Colors.white,
      ),
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

  Widget _buildImage() {
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
              color: AppTheme.primaryNavy,
            ),
          ),
        ),
        if (path != null)
          Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: _decodeWidth,
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ProfileUi.page,
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: SizedBox.expand(
                        key: ValueKey('${localPath ?? ''}|${networkUrl ?? ''}'),
                        child: _buildImage(),
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
                    color: AppTheme.primaryNavy,
                    shape: BoxShape.circle,
                    border: Border.all(color: ProfileUi.page, width: 3),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    size: 14,
                    color: Colors.white,
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
      TodayStatus.present => ('Present today', WC.present),
      TodayStatus.loading => ('Checking status…', AppTheme.textSecondary),
      TodayStatus.notCheckedIn => (
        'Not checked in yet',
        AppTheme.textSecondary,
      ),
      TodayStatus.unknown => ('Status unavailable', AppTheme.textSecondary),
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
  const _InfoChip({required this.data});

  final _ChipData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.icon != null) ...[
            Icon(data.icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
