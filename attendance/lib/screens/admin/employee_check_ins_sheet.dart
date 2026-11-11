import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_icons.dart';
import '../../config/app_theme.dart';
import '../../models/attendance_record_model.dart';
import '../../models/employees_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/company_backend.dart';
import '../../widgets/user-profile/profile_section_card.dart';
import 'attendance_evidence_screen.dart';

/// Opens one employee's existing history without leaving the Admin dashboard.
Future<void> showEmployeeCheckInsSheet(
  BuildContext context,
  Employee employee,
) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  final backend = context.read<AuthProvider>().backend!;
  HapticFeedback.selectionClick();
  return navigator.push<void>(
    _CheckInsRoute(
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor:
          Theme.of(context).bottomSheetTheme.modalBarrierColor ??
          Colors.black54,
      backgroundColor: context.colors.surface,
      builder: (context) => Theme(
        data: ProfileUi.themeOf(context),
        child: _EmployeeCheckInsSheet(employee: employee, backend: backend),
      ),
    ),
  );
}

// Retain Material's scroll/drag coordination, barrier semantics and focus trap.
class _CheckInsRoute extends ModalBottomSheetRoute<void> {
  _CheckInsRoute({
    required super.builder,
    required super.capturedThemes,
    required super.barrierLabel,
    required super.barrierOnTapHint,
    required super.modalBarrierColor,
    required super.backgroundColor,
    required this.reduceMotion,
  }) : super(
         isScrollControlled: true,
         useSafeArea: true,
         showDragHandle: true,
         clipBehavior: Clip.antiAlias,
         constraints: const BoxConstraints(maxWidth: 560),
         shape: const RoundedRectangleBorder(
           borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
         ),
         settings: const RouteSettings(name: 'employee-check-in-logs'),
         sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
       );

  final bool reduceMotion;

  @override
  Simulation? createSimulation({required bool forward}) => reduceMotion
      ? null
      : SpringSimulation(
          forward
              ? const SpringDescription(
                  mass: 1,
                  stiffness: 438.6,
                  damping: 41.9,
                )
              : const SpringDescription(mass: 1, stiffness: 987, damping: 62.8),
          controller!.value,
          forward ? 1 : 0,
          controller!.velocity,
          snapToEnd: true,
        );
}

class _EmployeeCheckInsSheet extends StatefulWidget {
  const _EmployeeCheckInsSheet({required this.employee, required this.backend});

  final Employee employee;
  final CompanyBackend backend;

  @override
  State<_EmployeeCheckInsSheet> createState() => _EmployeeCheckInsSheetState();
}

class _EmployeeCheckInsSheetState extends State<_EmployeeCheckInsSheet> {
  late Future<List<AttendanceRecord>> _records;

  @override
  void initState() {
    super.initState();
    _records = _load();
  }

  Future<List<AttendanceRecord>> _load() =>
      widget.backend.history(employeeId: widget.employee.id);

  void _reload() {
    final request = _load();
    setState(() {
      _records = request;
    });
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    key: const ValueKey('employee-check-ins-sheet'),
    expand: false,
    initialChildSize: MediaQuery.sizeOf(context).height < 600 ? .85 : .72,
    minChildSize: .35,
    maxChildSize: .96,
    builder: (context, controller) => FutureBuilder<List<AttendanceRecord>>(
      future: _records,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final records = snapshot.data ?? const <AttendanceRecord>[];
        return CustomScrollView(
          key: PageStorageKey('check-ins-${widget.employee.id}'),
          controller: controller,
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              primary: false,
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight:
                  60 *
                  (MediaQuery.textScalerOf(context).scale(20) / 20).clamp(
                    1,
                    2.5,
                  ),
              titleSpacing: 20,
              backgroundColor: context.colors.surface,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              title: const Tooltip(
                message: 'Check-in logs',
                child: Text(
                  'Check-in logs',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh check-in logs',
                  style: IconButton.styleFrom(fixedSize: const Size.square(48)),
                  onPressed: loading ? null : _reload,
                  icon: const Icon(AppIcons.refresh, size: 20),
                ),
                IconButton(
                  tooltip: 'Close check-in logs',
                  style: IconButton.styleFrom(fixedSize: const Size.square(48)),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.x, size: 20),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: _EmployeeHeading(employee: widget.employee),
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Loading check-in logs',
                    ),
                  ),
                ),
              )
            else if (snapshot.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LogState(
                  icon: AppIcons.alertCircle,
                  title: 'Could not load check-ins',
                  message: 'Please try again.',
                  retry: _reload,
                ),
              )
            else if (records.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _LogState(
                  icon: AppIcons.history,
                  title: 'No check-ins yet',
                  message: 'This employee has no recorded check-ins.',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Text(
                    '${records.length} ${records.length == 1 ? 'check-in' : 'check-ins'}',
                    style: ProfileUi.small(context),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final startsDay =
                      index == 0 ||
                      !DateUtils.isSameDay(
                        records[index - 1].timestamp,
                        record.timestamp,
                      );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (startsDay)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                          child: Semantics(
                            container: true,
                            header: true,
                            child: Text(
                              DateFormat.yMMMd().format(record.timestamp),
                              style: ProfileUi.small(
                                context,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      _LogRow(record: record),
                      if (index < records.length - 1)
                        const Divider(height: 1, indent: 60, endIndent: 20),
                    ],
                  );
                },
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + 20,
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _EmployeeHeading extends StatelessWidget {
  const _EmployeeHeading({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final name = employee.name.trim().isEmpty
        ? 'Unnamed employee'
        : employee.name.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();
    final role = [
      employee.role.trim(),
      employee.department.trim(),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: context.colors.primaryContainer,
            foregroundColor: context.colors.onPrimaryContainer,
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: ProfileUi.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: name,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: ProfileUi.fontFamily,
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(role, style: ProfileUi.small(context)),
                ],
                const SizedBox(height: 3),
                Text(
                  'Employee ID: ${employee.id}',
                  style: ProfileUi.small(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(record.timestamp);
    final device = record.device.trim().isEmpty
        ? 'Unknown device'
        : record.device;
    void openEvidence() => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttendanceEvidenceScreen(record: record),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      label:
          '${record.isPresent ? 'Checked in' : 'Absent'} at $time, $device. View evidence.',
      excludeSemantics: true,
      onTap: openEvidence,
      child: InkWell(
        onTap: openEvidence,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                record.isPresent ? AppIcons.circleCheck : AppIcons.circleX,
                size: 20,
                color: record.isPresent
                    ? context.attendancePresent
                    : context.attendanceAbsent,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Tooltip(
                      message: device,
                      child: Text(
                        device,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileUi.small(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogState extends StatelessWidget {
  const _LogState({
    required this.icon,
    required this.title,
    required this.message,
    this.retry,
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? retry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 28, color: context.colors.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: ProfileUi.body(context, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: ProfileUi.small(context),
        ),
        if (retry != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(AppIcons.refresh, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ],
    ),
  );
}
