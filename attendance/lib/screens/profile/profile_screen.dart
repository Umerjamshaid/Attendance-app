import 'package:attendance/config/ui_tokens.dart';
import 'package:attendance/config/app_icons.dart';
import 'package:attendance/config/app_theme.dart';
import 'package:attendance/models/employees_model.dart';
import 'package:attendance/providers/attendance_history_provider.dart';
import 'package:attendance/providers/auth_provider.dart';
import 'package:attendance/providers/profile_provider.dart';
import 'package:attendance/screens/profile/appearance_screen.dart';
import 'package:attendance/screens/profile/privacy_screen.dart';
import 'package:attendance/screens/profile/profile_details_screen.dart';
import 'package:attendance/screens/profile/settings_screen.dart';
import 'package:attendance/screens/profile/settings_sheets.dart';
import 'package:attendance/widgets/app_toast.dart';
import 'package:attendance/widgets/user-profile/attendance_stats_card.dart';
import 'package:attendance/widgets/user-profile/profile_header.dart';
import 'package:attendance/widgets/user-profile/profile_menu_item.dart';
import 'package:attendance/widgets/user-profile/profile_section_card.dart';
import 'package:flutter/material.dart';
import '../../widgets/check_in_summary.dart';
import '../../widgets/app_identity_footer.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  static const double _contentMaxWidth = 560;
  static const double _nameInTitleOffset = 150;
  static const int _sectionCount = 5;

  bool _notificationsEnabled = true;
  bool _signingOut = false;

  // Scroll-driven app bar state. Only the title and divider rebuild.
  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolled = ValueNotifier(false);
  final ValueNotifier<bool> _nameInTitle = ValueNotifier(false);

  // One-shot staggered entrance for the sections.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final List<CurvedAnimation> _reveals = List.generate(_sectionCount, (i) {
    final start = i * 0.1;
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, start + 0.5, curve: Curves.easeOutCubic),
    );
  });
  bool _entranceStarted = false;

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final offset = _scroll.offset;
    _scrolled.value = offset > 4;
    _nameInTitle.value = offset > _nameInTitleOffset;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<ProfileProvider>().loadProfileData(auth.currentUser!.id);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _scrolled.dispose();
    _nameInTitle.dispose();
    for (final animation in _reveals) {
      animation.dispose();
    }
    _entrance.dispose();
    super.dispose();
  }

  TodayStatus _statusFor(AttendanceHistoryProvider history) {
    if (history.isLoading && history.records.isEmpty) {
      return TodayStatus.loading;
    }
    if (history.isPresentToday) return TodayStatus.present;
    if (history.error != null && history.records.isEmpty) {
      return TodayStatus.unknown;
    }
    return TodayStatus.notCheckedIn;
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ProfileUi.themeOf(context),
    child: Builder(builder: _buildContent),
  );

  Widget _buildContent(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final historyProvider = context.watch<AttendanceHistoryProvider>();
    final Employee? user = auth.currentUser;

    if (user == null) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    // Show the user with live counts from the attendance history.
    final updatedUser = user.copyWith(
      totalPresents: historyProvider.presentCount,
      totalAbsents: historyProvider.absentCount,
    );
    final historyLoading =
        historyProvider.isLoading && historyProvider.records.isEmpty;

    final sections = <Widget>[
      ProfileHeader(
        employee: updatedUser,
        todayStatus: _statusFor(historyProvider),
      ),
      if (auth.isPublicBuild)
        Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.copyWith(
              headlineSmall: AppTypography.inter(
                textStyle: Theme.of(context).textTheme.headlineSmall,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          child: const CheckInSummary(),
        )
      else
        AttendanceStatsCard(employee: updatedUser, isLoading: historyLoading),
      ProfileSectionCard(
        label: 'Preferences',
        children: [
          if (!auth.isPublicBuild)
            ProfileSwitchItem(
              icon: AppIcons.bellRinging,
              title: 'Push notifications',
              value: _notificationsEnabled,
              onChanged: (value) =>
                  setState(() => _notificationsEnabled = value),
            ),
          ProfileMenuItem(
            icon: AppIcons.idBadge2,
            title: 'Profile details',
            onTap: auth.isPreview
                ? null
                : () => ProfileDetailsScreen.open(context, user),
          ),
          ProfileMenuItem(
            icon: AppIcons.moon,
            title: 'Appearance',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const AppearanceScreen()),
            ),
          ),
          // Placeholder row kept from the previous screen; it has no action.
          if (!auth.isPublicBuild)
            const ProfileMenuItem(icon: AppIcons.language, title: 'Language'),
        ],
      ),
      ProfileSectionCard(
        label: 'Support',
        children: [
          ProfileMenuItem(
            icon: AppIcons.help,
            title: 'Help Centre',
            onTap: () => showHelpCentre(context),
          ),
          ProfileMenuItem(
            icon: AppIcons.infoCircle,
            title: 'About app',
            onTap: () => showAboutApp(context),
          ),
          ProfileMenuItem(
            icon: AppIcons.shield,
            title: 'Privacy',
            // badge: 'Verified',
            badgeColor: context.attendancePresent,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
          ProfileMenuItem(
            icon: AppIcons.settings,
            title: 'App permissions',
            onTap: openAppSettings,
          ),
        ],
      ),
      ProfileSectionCard(
        children: [
          ProfileMenuItem(
            icon: AppIcons.logout,
            title: _signingOut ? 'Signing out...' : 'Sign out',
            textColor: context.colors.error,
            onTap: _signingOut ? null : () => _signOut(context),
          ),
        ],
      ),
    ];

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          _buildSliverAppBar(context, updatedUser.name),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sections.length; i++)
                      _Reveal(animation: _reveals[i], child: sections[i]),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          ProfileUi.gutter,
                          28,
                          ProfileUi.gutter,
                          24,
                        ),
                        child: AppIdentityFooter(
                          onCreditTap: () => showMakerCredit(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, String name) {
    final displayName = name.trim();
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: true,
      title: ValueListenableBuilder<bool>(
        valueListenable: _nameInTitle,
        builder: (_, nameInTitle, _) {
          final showName = nameInTitle && displayName.isNotEmpty;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              showName ? displayName : 'Profile',
              key: ValueKey(showName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ProfileUi.body(context, weight: FontWeight.w600),
            ),
          );
        },
      ),
      actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(AppIcons.settings),
          color: context.colors.onSurface,
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: ValueListenableBuilder<bool>(
          valueListenable: _scrolled,
          builder: (_, scrolled, _) => AnimatedOpacity(
            opacity: scrolled ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Divider(
              height: 1,
              thickness: 1,
              color: context.colors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!await confirmSignOut(context) || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await auth.logout();
    } catch (_) {
      if (context.mounted) {
        AppToast.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out. Try again.')),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }
}

/// Fades and nudges a section up as the entrance animation plays.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
