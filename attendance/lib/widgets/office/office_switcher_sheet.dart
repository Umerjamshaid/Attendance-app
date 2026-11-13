// Motion adapted from Block Buzz, Copyright 2026 Block, Inc., Apache-2.0.
// Modified for an office bottom sheet that stays open and returns to its grid.
// See docs/third-party-animations.md and assets/licenses/Buzz-Apache-2.0.txt.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_icons.dart';
import '../../config/app_theme.dart';
import '../../config/ui_tokens.dart';
import '../../models/office_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/office_provider.dart';
import '../../screens/office/manage_offices_screen.dart';
import 'office_action_badge.dart';
import 'office_scope.dart';
import 'office_selector_header.dart';

const _officeFont = 'Office Inter';

Future<void> showOfficeSwitcher(BuildContext context) async {
  final offices = context.read<OfficeProvider>();
  unawaited(offices.reload());
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppLayout.sheetRadius),
      ),
    ),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => ChangeNotifierProvider.value(
      value: offices,
      child: const OfficeSwitcherSheet(),
    ),
  );
}

class OfficeSwitcherSheet extends StatefulWidget {
  const OfficeSwitcherSheet({super.key});
  @override
  State<OfficeSwitcherSheet> createState() => _OfficeSwitcherSheetState();
}

class _OfficeSwitcherSheetState extends State<OfficeSwitcherSheet>
    with TickerProviderStateMixin {
  final _surface = GlobalKey();
  final _avatarKeys = <String, GlobalKey>{};
  late final _center = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final _return = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Office? _flying;
  Rect? _origin;
  String? _removingId, _feedback;
  String? _previousActiveId;
  bool _editing = false, _feedbackError = false;
  bool get _moving => _flying != null || _removingId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_center.isAnimating) _center.animateTo(1, duration: Duration.zero);
      if (_return.isAnimating) _return.animateTo(1, duration: Duration.zero);
    }
  }

  Future<void> _select(Office office) async {
    final provider = context.read<OfficeProvider>();
    if (_moving || provider.isSwitching || _editing) return;
    unawaited(HapticFeedback.selectionClick());
    if (office.id == provider.activeOfficeId) return;
    final avatar = _avatarKeys[office.id]?.currentContext?.findRenderObject();
    final surface = _surface.currentContext?.findRenderObject();
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        avatar is RenderBox &&
        surface is RenderBox;
    if (animate) {
      final box = avatar;
      _origin =
          (surface).globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
    }
    setState(() {
      _previousActiveId = provider.activeOfficeId;
      _flying = office;
      _feedback = null;
      _feedbackError = false;
    });
    try {
      var success = false;
      await Future.wait<void>([
        provider.switchOffice(office.id).then((value) {
          success = value;
        }),
        if (animate) _center.forward(from: 0).orCancel,
      ]);
      if (!mounted) return;
      if (success) unawaited(HapticFeedback.lightImpact());
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        await _return.forward(from: 0).orCancel;
      }
      if (!mounted) return;
      setState(() {
        _feedback = success
            ? '${provider.activeOffice?.name ?? office.name} is active'
            : null;
      });
    } on TickerCanceled {
      /* Closing the account/sheet cancels only visual motion. */
    } finally {
      if (mounted) {
        _center.reset();
        _return.reset();
        setState(() {
          _flying = null;
          _origin = null;
          _previousActiveId = null;
        });
      }
    }
  }

  Future<void> _remove(Office office) async {
    final provider = context.read<OfficeProvider>();
    if (_moving || provider.isSwitching) return;
    if (provider.offices.length <= 1) {
      setState(() {
        _feedback =
            'Keep one office visible. Add or restore another office first.';
        _feedbackError = true;
      });
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Office?'),
        content: Text(
          'Hide "${office.name}" from this device? Your membership and attendance stay unchanged. You can restore it from Manage Offices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _removingId = office.id;
      _feedback = null;
      _feedbackError = false;
    });
    final removed = await provider.hideOffice(office.id);
    if (!mounted) return;
    setState(() {
      _removingId = null;
      if (removed) _feedback = '${office.name} removed from this device';
    });
  }

  Future<void> _manage() async {
    unawaited(HapticFeedback.selectionClick());
    final root = Navigator.of(context);
    final navigation = context.read<OfficeNavigatorController?>();
    final route = ModalRoute.of(context);
    final auth = context.read<AuthProvider>();
    final account = auth.accountScopeKey;
    root.pop();
    if (route != null) await route.completed;
    if (account != auth.accountScopeKey) return;
    final navigator = navigation?.navigator ?? root;
    if (navigator.mounted) {
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const ManageOfficesScreen()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTypography.themeOf(context, family: _officeFont),
    child: Builder(
      builder: (context) => DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!,
        child: _content(context),
      ),
    ),
  );
  Widget _content(BuildContext context) {
    final provider = context.watch<OfficeProvider>();
    final colors = Theme.of(context).colorScheme;
    final busy = _moving || provider.isSwitching;
    final options = <Widget>[
      for (final office in provider.offices) _option(context, office, busy),
      InkWell(
        key: const ValueKey('office-add'),
        borderRadius: BorderRadius.circular(8),
        onTap: busy ? null : _manage,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceContainerHighest,
                ),
                child: const Icon(AppIcons.plus, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                'Add Office',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  fontFamily: _officeFont,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
    return PopScope(
      canPop: !busy,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .4,
        maxChildSize: .94,
        builder: (context, scroll) {
          final content = ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: busy ? null : () => Navigator.pop(context),
                    icon: const Icon(AppIcons.x),
                  ),
                  TextButton(
                    key: const ValueKey('office-switcher-edit'),
                    onPressed: busy
                        ? null
                        : () {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() {
                              _editing = !_editing;
                              _feedback = null;
                            });
                          },
                    child: Text(_editing ? 'Done' : 'Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Switch Office',
                textAlign: TextAlign.center,
                style: AppTypography.title.copyWith(
                  fontFamily: _officeFont,
                  fontSize: 24,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 24),
              if (_flying != null && MediaQuery.disableAnimationsOf(context))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(
                    liveRegion: true,
                    label: 'Switching to ${_flying!.name}',
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Switching office...'),
                      ],
                    ),
                  ),
                ),
              if (provider.isLoading && provider.offices.isEmpty)
                const Center(child: CircularProgressIndicator()),
              if (provider.error != null || _feedback != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      provider.error ?? _feedback!,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        fontFamily: _officeFont,
                        color: provider.error != null || _feedbackError
                            ? colors.error
                            : context.attendancePresent,
                      ),
                    ),
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 248 ? 2 : 1;
                  return Column(
                    children: [
                      for (
                        var index = 0;
                        index < options.length;
                        index += columns
                      )
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var column = 0;
                                column < columns;
                                column++
                              ) ...[
                                if (column > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: index + column < options.length
                                      ? options[index + column]
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (provider.canManage || provider.hiddenOffices.isNotEmpty)
                TextButton.icon(
                  onPressed: busy ? null : _manage,
                  icon: const Icon(AppIcons.settings, size: 20),
                  label: const Text('Manage Offices'),
                ),
              if (provider.invitations.isNotEmpty)
                TextButton(
                  onPressed: busy ? null : _manage,
                  child: Text(
                    '${provider.invitations.length} pending office invitation(s)',
                  ),
                ),
            ],
          );
          return LayoutBuilder(
            builder: (context, constraints) => AnimatedBuilder(
              animation: Listenable.merge([_center, _return]),
              child: RepaintBoundary(child: content),
              builder: (context, child) {
                final flying = _flying;
                final flight =
                    flying != null &&
                    _origin != null &&
                    !MediaQuery.disableAnimationsOf(context);
                final center = const Cubic(
                  .22,
                  1,
                  .36,
                  1,
                ).transform(_center.value);
                final returning = const Cubic(
                  .2,
                  0,
                  .2,
                  1,
                ).transform(_return.value);
                final fade = flight ? center * (1 - returning) : 0.0;
                return Stack(
                  key: _surface,
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      ignoring: busy,
                      child: Opacity(
                        opacity: 1 - .94 * fade,
                        child: Transform.scale(
                          scale: 1 + .04 * fade,
                          child: child,
                        ),
                      ),
                    ),
                    if (flight)
                      _OfficeFlyingAvatar(
                        office: flying,
                        origin: _origin!,
                        bounds: constraints.biggest,
                        centerProgress: center,
                        returning: returning,
                      ),
                    if (flight && (provider.isSwitching || returning < .5))
                      Positioned(
                        left: 24,
                        right: 24,
                        top: flight ? constraints.maxHeight * .42 + 92 : 112,
                        child: IgnorePointer(
                          child: Semantics(
                            liveRegion: true,
                            label: 'Switching to ${flying.name}',
                            child: Column(
                              children: [
                                const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  flying.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    fontFamily: _officeFont,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _option(BuildContext context, Office office, bool busy) {
    final key = _avatarKeys.putIfAbsent(office.id, GlobalKey.new);
    final selected =
        (_flying != null
            ? _previousActiveId
            : context.read<OfficeProvider>().activeOfficeId) ==
        office.id;
    return Semantics(
      button: !_editing,
      selected: selected,
      label: office.name,
      child: InkWell(
        key: ValueKey('office-option-${office.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: busy || _editing ? null : () => _select(office),
        child: AnimatedOpacity(
          opacity: _removingId == office.id ? .35 : 1,
          duration: AppMotion.duration(context, AppMotion.fast),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity:
                          _flying?.id == office.id &&
                              _origin != null &&
                              !MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 1,
                      child: SizedBox(
                        key: key,
                        child: ExcludeSemantics(
                          child: OfficeAvatar(
                            office: office,
                            fontFamily: _officeFont,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -12,
                      bottom: -12,
                      child: OfficeActionBadge(
                        officeId: office.id,
                        name: office.name,
                        isActive: selected,
                        isEditing: _editing,
                        onRemove: busy ? null : () => _remove(office),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  office.name,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    fontFamily: _officeFont,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _center.dispose();
    _return.dispose();
    super.dispose();
  }
}

class _OfficeFlyingAvatar extends StatelessWidget {
  const _OfficeFlyingAvatar({
    required this.office,
    required this.origin,
    required this.bounds,
    required this.centerProgress,
    required this.returning,
  });
  final Office office;
  final Rect origin;
  final Size bounds;
  final double centerProgress, returning;
  @override
  Widget build(BuildContext context) {
    const centeredSize = 156.0;
    final center = Offset(bounds.width / 2, bounds.height * .42);
    final from = origin.center;
    final delta = center - from;
    final centerControl =
        (from + center) / 2 + Offset(-delta.dy, delta.dx) * .18;
    final c = centerProgress;
    final start =
        from * ((1 - c) * (1 - c)) +
        centerControl * (2 * (1 - c) * c) +
        center * (c * c);
    final travel = from - start;
    final bend = (start + from) / 2 + Offset(travel.dy, -travel.dx) * .75;
    const margin = centeredSize / 2 + 8;
    final control = Offset(
      bend.dx.clamp(margin, math.max(margin, bounds.width - margin)),
      bend.dy.clamp(margin, math.max(margin, bounds.height - margin)),
    );
    final t = returning;
    final position =
        start * ((1 - t) * (1 - t)) +
        control * (2 * (1 - t) * t) +
        from * (t * t);
    final size = lerpDouble(
      lerpDouble(104, centeredSize, centerProgress),
      104,
      t,
    )!;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      width: size,
      height: size,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: OfficeAvatar(
            fontFamily: _officeFont,
            key: const ValueKey('office-flying-avatar'),
            office: office,
            size: size,
          ),
        ),
      ),
    );
  }
}
