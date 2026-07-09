import 'package:attendance/providers/attendance_provider.dart';
import 'package:attendance/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/wc_tokens.dart';

class SetAttendanceWindowSheet extends StatefulWidget {
  const SetAttendanceWindowSheet({super.key});

  @override
  State<SetAttendanceWindowSheet> createState() =>
      _SetAttendanceWindowSheetState();
}

class _SetAttendanceWindowSheetState extends State<SetAttendanceWindowSheet> {
  final _storageService = LocalStorageService();

  bool _always = false;
  int _startHour = 7;
  int _endHour = 13;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await _storageService.getAttendanceWindow();
    if (saved != null && mounted) {
      setState(() {
        _always = (saved['mode'] as String?) == 'always';
        _startHour = (saved['startHour'] as int?) ?? 7;
        _endHour = (saved['endHour'] as int?) ?? 13;
      });
    }
  }

  String _formatHour(int hour) {
    final normalized = ((hour % 24) + 24) % 24;
    final period = normalized >= 12 ? 'PM' : 'AM';
    var h = normalized % 12;
    if (h == 0) h = 12;
    return '$h:00 $period';
  }

  Future<void> _save() async {
    if (!_always && _endHour <= _startHour) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _storageService.saveAttendanceWindow(
        mode: _always ? 'always' : 'period',
        startHour: _startHour,
        endHour: _endHour,
      );

      if (!mounted) return;

      // Refresh the provider so the attendance button updates immediately.
      await context.read<AttendanceProvider>().loadWindowConfig();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Attendance window saved!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: WC.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: WC.rFull,
              ),
            ),
          ),
          const Text(
            'Attendance Window',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: WC.black,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose when employees are allowed to mark attendance.',
            style: TextStyle(fontSize: 13, color: WC.muted, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Always-open toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: WC.bg,
              borderRadius: WC.r12,
              border: Border.all(color: WC.border, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Always Open',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: WC.black,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'No time restriction (24 hours).',
                        style: TextStyle(fontSize: 12, color: WC.muted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _always,
                  activeThumbColor: WC.black,
                  onChanged: (v) => setState(() => _always = v),
                ),
              ],
            ),
          ),

          if (!_always) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _HourSelector(
                    label: 'START TIME',
                    value: _startHour,
                    formatter: _formatHour,
                    onChanged: (v) => setState(() => _startHour = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HourSelector(
                    label: 'END TIME',
                    value: _endHour,
                    formatter: _formatHour,
                    onChanged: (v) => setState(() => _endHour = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Employees can mark attendance from ${_formatHour(_startHour)} to ${_formatHour(_endHour)}.',
              style: const TextStyle(fontSize: 11, color: WC.muted),
            ),
          ],

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: WC.surface,
                      borderRadius: WC.rFull,
                      border: Border.all(color: WC.border),
                    ),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: WC.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: WC.black,
                      borderRadius: WC.rFull,
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: WC.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  color: WC.white,
                                  size: 18,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Save Window',
                                  style: TextStyle(
                                    color: WC.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourSelector extends StatelessWidget {
  final String label;
  final int value;
  final String Function(int) formatter;
  final ValueChanged<int> onChanged;

  const _HourSelector({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: WC.muted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: WC.bg,
            borderRadius: WC.r12,
            border: Border.all(color: WC.border, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: WC.muted),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WC.black,
              ),
              items: List.generate(24, (h) => h)
                  .map(
                    (h) => DropdownMenuItem<int>(
                      value: h,
                      child: Text(formatter(h)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
