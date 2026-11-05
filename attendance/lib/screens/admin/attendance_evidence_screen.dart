import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/employees_model.dart';
import '../../models/attendance_record_model.dart';
import '../../providers/auth_provider.dart';
import '../profile/settings_layout.dart';

class EmployeeCheckInsScreen extends StatefulWidget {
  const EmployeeCheckInsScreen({super.key, required this.employee});
  final Employee employee;
  @override
  State<EmployeeCheckInsScreen> createState() => _EmployeeCheckInsScreenState();
}

class _EmployeeCheckInsScreenState extends State<EmployeeCheckInsScreen> {
  late Future<List<AttendanceRecord>> _records = context
      .read<AuthProvider>()
      .backend!
      .history(employeeId: widget.employee.id);
  @override
  Widget build(BuildContext context) => SettingsLayout(
    title: widget.employee.name,
    children: [
      FutureBuilder(
        future: _records,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return TextButton(
              onPressed: () => setState(
                () => _records = context.read<AuthProvider>().backend!.history(
                  employeeId: widget.employee.id,
                ),
              ),
              child: const Text('Could not load check-ins. Retry'),
            );
          }
          if (snapshot.data!.isEmpty) return const Text('No check-ins yet.');
          return Column(
            children: [
              for (final record in snapshot.data!)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${record.timestamp}'.substring(0, 16)),
                  subtitle: Text(record.device),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AttendanceEvidenceScreen(record: record),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class AttendanceEvidenceScreen extends StatefulWidget {
  const AttendanceEvidenceScreen({super.key, required this.record});
  final AttendanceRecord record;
  @override
  State<AttendanceEvidenceScreen> createState() =>
      _AttendanceEvidenceScreenState();
}

class _AttendanceEvidenceScreenState extends State<AttendanceEvidenceScreen> {
  late Future<Map<String, dynamic>> _evidence = context
      .read<AuthProvider>()
      .backend!
      .evidence(widget.record.id);
  NetworkImage? _photo;
  @override
  void dispose() {
    _photo?.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsLayout(
    title: 'Check-in evidence',
    children: [
      FutureBuilder(
        future: _evidence,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Text(snapshot.error.toString()),
                TextButton(
                  onPressed: () => setState(
                    () => _evidence = context
                        .read<AuthProvider>()
                        .backend!
                        .evidence(widget.record.id),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          final evidence = snapshot.data!;
          _photo = NetworkImage(evidence['photo_url'] as String);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Image(
                  image: _photo!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Text('Photo unavailable. Refresh to retry.'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.record.timestamp.toString()),
              Text('Latitude: ${evidence['latitude']}'),
              Text('Longitude: ${evidence['longitude']}'),
              Text('Accuracy: ${evidence['accuracy']} m'),
              Text(widget.record.device),
            ],
          );
        },
      ),
    ],
  );
}
