import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../config/backend_config.dart';
import '../models/attendance_record_model.dart';
import '../models/employees_model.dart';
import 'company_backend.dart';

class SupabaseCompanyBackend extends CompanyBackend {
  SupabaseCompanyBackend(this.client);
  final SupabaseClient client;
  AttendancePolicy _policy = const AttendancePolicy();
  bool _recovering = false;

  @override
  DateTime get companyNow =>
      tz.TZDateTime.now(tz.getLocation(_policy.timezone));
  @override
  bool get needsPasswordSetup =>
      _recovering ||
      (client.auth.currentUser != null &&
          client.auth.currentUser!.userMetadata?['password_set'] != true);
  @override
  Stream<void> get authChanges => client.auth.onAuthStateChange.map((event) {
    if (event.event == AuthChangeEvent.passwordRecovery) _recovering = true;
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on CompanyException {
      rethrow;
    } on AuthException catch (error) {
      if ([
        'session_not_found',
        'session_expired',
        'bad_jwt',
        'user_not_found',
        'user_banned',
        'refresh_token_not_found',
      ].contains(error.code)) {
        throw const CompanyAccessException(
          'Your session is no longer available. Sign in again.',
        );
      }
      if (error.code == 'invalid_credentials') {
        throw const CompanyException('Email or password is incorrect.');
      }
      throw const CompanyException(
        'Account request failed. Check your details and try again.',
      );
    } on PostgrestException catch (error) {
      if (['PGRST301', 'PGRST302', 'PGRST303'].contains(error.code)) {
        throw const CompanyAccessException(
          'Your session is no longer available. Sign in again.',
        );
      }
      throw const CompanyException(
        'Could not connect to your company. Please try again.',
      );
    } on FunctionException catch (error) {
      final details = error.details;
      // Only server-owned public error messages are shown, never raw responses.
      final code = details is Map ? details['code'] : null;
      throw CompanyException(switch (code) {
        'window_closed' => 'The attendance window is closed.',
        'inactive' => 'Your company access is inactive. Contact an admin.',
        'forbidden' => 'You do not have permission for this action.',
        'duplicate_employee' =>
          'That employee number or invitation already exists.',
        'invitation_delivery_failed' =>
          'The invitation email could not be sent. Ask the project owner to check email delivery.',
        'last_admin' => 'The last active administrator cannot be deactivated.',
        'processing' => 'This upload is still processing. Try again shortly.',
        'evidence_expired' =>
          'This evidence has expired under the retention policy.',
        'invalid_image' => 'Choose a JPEG or PNG image smaller than 2 MB.',
        _ => 'The request could not be completed. Please try again.',
      });
    } catch (_) {
      throw const CompanyException(
        'Could not connect to your company. Please try again.',
      );
    }
  }

  Future<Employee> _current() async {
    final row = await client.rpc('current_employee');
    if (row == null) {
      throw const CompanyAccessException(
        'Your company access is inactive. Contact an admin.',
      );
    }
    return Employee.fromMap(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<Employee?> restoreSession() => _guard(() async {
    if (client.auth.currentSession == null) return null;
    final employee = await _current();
    await policy();
    return employee;
  });
  @override
  Future<Employee> signIn(String email, String password) => _guard(() async {
    await client.auth.signInWithPassword(email: email, password: password);
    try {
      final employee = await _current();
      await policy();
      return employee;
    } catch (_) {
      await client.auth.signOut();
      rethrow;
    }
  });
  @override
  Future<void> signOut() => _guard(() async {
    await client.auth.signOut();
    _recovering = false;
  });
  @override
  Future<Employee> updateProfile({
    String? name,
    String? headline,
    List<String>? chips,
  }) => _guard(() async {
    final values = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (headline != null) 'headline': headline.trim(),
      'chips': ?chips,
    };
    if (values.isNotEmpty) {
      await client
          .from('profiles')
          .update(values)
          .eq('user_id', client.auth.currentUser!.id)
          .select()
          .single();
    }
    return _current();
  });
  @override
  Future<void> resetPassword(String email) => _guard(
    () => client.auth.resetPasswordForEmail(
      email,
      redirectTo: BackendConfig.authRedirect,
    ),
  );
  @override
  Future<void> setPassword(String password) => _guard(() async {
    await client.auth.updateUser(
      UserAttributes(password: password, data: {'password_set': true}),
    );
    _recovering = false;
  });
  @override
  Future<void> changeEmail(String email) => _guard(() async {
    await client.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: BackendConfig.authRedirect,
    );
  });
  @override
  Future<List<Employee>> employees() => _guard(() async {
    final rows = await client.rpc('company_employees') as List;
    return rows
        .map((row) => Employee.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  });

  AttendanceRecord _record(Map<String, dynamic> row) => AttendanceRecord(
    id: row['id'] as String,
    userId: row['employee_code'] as String,
    isPresent: true,
    timestamp: tz.TZDateTime.from(
      DateTime.parse(row['received_at'] as String),
      tz.getLocation(_policy.timezone),
    ),
    device: row['device_model'] as String? ?? 'Unknown device',
  );
  @override
  Future<List<AttendanceRecord>> history({
    String? employeeId,
    bool todayOnly = false,
  }) => _guard(() async {
    var query = client.from('check_ins').select();
    if (employeeId != null) query = query.eq('employee_code', employeeId);
    if (todayOnly) {
      final now = companyNow;
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      query = query.eq('company_day', day);
    }
    final records = <AttendanceRecord>[];
    for (var offset = 0; ; offset += 1000) {
      final rows = await query
          .order('received_at', ascending: false)
          .order('id')
          .range(offset, offset + 999);
      records.addAll(rows.map(_record));
      if (rows.length < 1000) return records;
    }
  });

  Future<Map<String, dynamic>> _invoke(
    String function,
    Map<String, dynamic> body,
  ) async {
    final response = await client.functions.invoke(function, body: body);
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<AttendanceRecord> submit({
    required String requestId,
    required String base64Image,
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime capturedAt,
    required String installationId,
    required String deviceModel,
    required String platform,
  }) => _guard(() async {
    final payload = <String, dynamic>{
      'request_id': requestId,
      'image': base64Image,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'captured_at': capturedAt.toUtc().toIso8601String(),
      'installation_id': installationId,
      'device_model': deviceModel,
      'platform': platform,
    };
    Map<String, dynamic> row;
    try {
      row = await _invoke('submit-attendance', payload);
    } catch (error) {
      final retryable =
          error is SocketException ||
          error is TimeoutException ||
          (error is FunctionException && error.status >= 500);
      if (!retryable) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      row = await _invoke('submit-attendance', payload);
    }
    return _record(Map<String, dynamic>.from(row['record'] as Map));
  });
  @override
  Future<AttendancePolicy> policy() => _guard(() async {
    final row = await client.from('organizations').select().single();
    return _policy = AttendancePolicy(
      mode: row['window_mode'] as String,
      startHour: row['start_hour'] as int,
      endHour: row['end_hour'] as int,
      timezone: row['timezone'] as String,
    );
  });
  @override
  Future<void> savePolicy(AttendancePolicy policy) => _guard(() async {
    await client.rpc(
      'save_attendance_policy',
      params: {
        'p_mode': policy.mode,
        'p_start': policy.startHour,
        'p_end': policy.endHour,
      },
    );
    await this.policy();
  });
  @override
  Future<Map<String, String?>> profileMedia() => _guard(() async {
    final row = await client
        .from('profiles')
        .select('avatar_path,banner_path')
        .eq('user_id', client.auth.currentUser!.id)
        .single();
    final result = <String, String?>{};
    for (final kind in ['avatar', 'banner']) {
      final path = row['${kind}_path'] as String?;
      result[kind] = path == null
          ? null
          : await client.storage
                .from('profile-media')
                .createSignedUrl(path, 900);
    }
    return result;
  });
  @override
  Future<void> saveMedia(String kind, Uint8List? bytes) => _guard(() async {
    if (!['avatar', 'banner'].contains(kind)) {
      throw const CompanyException('Invalid profile image.');
    }
    String? path;
    if (bytes != null) {
      if (bytes.length > 2 * 1024 * 1024) {
        throw const CompanyException('Choose an image smaller than 2 MB.');
      }
      final png = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80;
      path =
          '${client.auth.currentUser!.id}/$kind-${const Uuid().v4()}.${png ? 'png' : 'jpg'}';
      await client.storage
          .from('profile-media')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: png ? 'image/png' : 'image/jpeg',
            ),
          );
    }
    try {
      final previous = await client
          .from('profiles')
          .select('${kind}_path')
          .eq('user_id', client.auth.currentUser!.id)
          .single();
      await client
          .from('profiles')
          .update({'${kind}_path': path})
          .eq('user_id', client.auth.currentUser!.id)
          .select()
          .single();
      final old = previous['${kind}_path'] as String?;
      if (old != null) {
        try {
          await client.storage.from('profile-media').remove([old]);
        } catch (_) {
          /* Retention cleanup retries orphaned media. */
        }
      }
    } catch (_) {
      if (path != null) {
        try {
          await client.storage.from('profile-media').remove([path]);
        } catch (_) {}
      }
      rethrow;
    }
  });
  @override
  Future<void> invite({
    required String email,
    required String name,
    required String employeeCode,
    required String department,
  }) => _guard(() async {
    await _invoke('manage-employees', {
      'action': 'invite',
      'email': email,
      'name': name,
      'employee_code': employeeCode,
      'department': department,
    });
  });
  @override
  Future<void> setEmployeeActive(String employeeId, bool active) =>
      _guard(() async {
        await _invoke('manage-employees', {
          'action': 'set_active',
          'employee_code': employeeId,
          'active': active,
        });
      });
  @override
  Future<Map<String, dynamic>> evidence(String recordId) =>
      _guard(() => _invoke('attendance-evidence', {'record_id': recordId}));
}
