import 'dart:typed_data';
import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../config/backend_config.dart';
import '../models/attendance_record_model.dart';
import '../models/employees_model.dart';
import '../models/office_model.dart';
import 'company_backend.dart';
import 'profile_media.dart';

class _OfficeSession {
  String? officeId;
  int generation = 0;
  bool switching = false;
  bool recoveryRequired = false;
}

class SupabaseCompanyBackend extends CompanyBackend {
  SupabaseCompanyBackend(this.client)
    : _session = _OfficeSession(),
      _userId = null,
      _officeId = null,
      _generation = null,
      _accountEmployee = null;
  SupabaseCompanyBackend._scoped(
    this.client,
    this._session,
    this._userId,
    this._officeId, {
    Employee? accountEmployee,
  }) : _generation = _session.generation,
       _accountEmployee = accountEmployee;
  final SupabaseClient client;
  final _OfficeSession _session;
  final String? _userId;
  final String? _officeId;
  final int? _generation;
  final Employee? _accountEmployee;
  AttendancePolicy _policy = const AttendancePolicy();
  bool _hasPolicy = false;
  Future<AttendancePolicy>? _policyRequest;
  bool _recovering = false;

  @override
  bool get supportsOffices => true;
  @override
  CompanyBackend forAccount(Employee employee) =>
      SupabaseCompanyBackend._scoped(
        client,
        _session,
        employee.authUserId,
        null,
        accountEmployee: employee,
      );
  @override
  CompanyBackend forOffice(Employee employee) {
    if (_session.officeId != employee.organizationId) {
      _session.officeId = employee.organizationId;
      _session.generation++;
    }
    return SupabaseCompanyBackend._scoped(
      client,
      _session,
      employee.authUserId,
      employee.organizationId,
    );
  }

  @override
  void validateContext() {
    if (_userId != null && client.auth.currentUser?.id != _userId) {
      throw const CompanyAccessException(
        'Your account changed. Sign in again.',
      );
    }
    if (_officeId != null &&
        (_session.switching ||
            _session.recoveryRequired ||
            _generation != _session.generation ||
            _session.officeId != _officeId)) {
      throw const CompanyException('The office changed. Please try again.');
    }
  }

  String get _office {
    validateContext();
    if (_officeId == null) {
      throw const CompanyException('Select an office first.');
    }
    return _officeId;
  }

  String get _user {
    validateContext();
    final id = _userId ?? client.auth.currentUser?.id;
    if (id == null) throw const CompanyAccessException('Sign in again.');
    return id;
  }

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

  Future<dynamic> _rpc(String name, {Map<String, dynamic>? params}) =>
      client.rpc(name, params: params).timeout(const Duration(seconds: 20));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      validateContext();
      final result = await action();
      validateContext();
      return result;
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
      if (error.code == 'P0001') {
        throw CompanyException(switch (error.message) {
          'inactive' =>
            'Your access to this office is inactive. Refresh your offices.',
          'forbidden' => 'You do not have permission for this office.',
          'office_required' => 'Update the app and select an office.',
          'duplicate_employee' =>
            'That employee number is already in use in this office.',
          'last_admin' => 'The last active administrator must keep their role.',
          _ => 'The office request could not be completed. Please try again.',
        });
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
    } catch (_, stack) {
      Error.throwWithStackTrace(
        const CompanyException(
          'Could not connect to your company. Please try again.',
        ),
        stack,
      );
    }
  }

  Future<Employee> _current() async {
    final generation = _session.generation;
    final row = _officeId == null
        ? await _rpc('resolve_office_context')
        : await _rpc('current_employee', params: {'p_organization': _office});
    if (row == null) {
      throw const CompanyAccessException(
        'Your company access is inactive. Contact an admin.',
      );
    }
    final employee = Employee.fromMap(Map<String, dynamic>.from(row as Map));
    if (employee.authUserId != client.auth.currentUser?.id ||
        employee.organizationId == null) {
      throw const CompanyAccessException(
        'Your office context could not be verified. Sign in again.',
      );
    }
    if (_officeId == null) {
      if (generation != _session.generation || _session.switching) {
        throw const CompanyException(
          'The office changed. Refresh your session.',
        );
      }
      // Only adopting/switching an office changes the active scope. A stale
      // refresh must not roll it back before Auth's generation check.
      _session.recoveryRequired = false;
    }
    return employee;
  }

  @override
  Future<Employee?> restoreSession() => _guard(() async {
    if (client.auth.currentSession == null) return null;
    final employee = await _current();
    return employee;
  });
  @override
  Future<Employee> signIn(String email, String password) => _guard(() async {
    await client.auth.signInWithPassword(email: email, password: password);
    try {
      final employee = await _current();
      return employee;
    } catch (_) {
      await client.auth.signOut();
      rethrow;
    }
  });
  @override
  Future<void> signOut() => _guard(() async {
    _session.generation++;
    _session.officeId = null;
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
          .eq('user_id', _user)
          .select()
          .single();
    }
    if (_accountEmployee != null) {
      final row = await client
          .from('profiles')
          .select('name,headline,chips')
          .eq('user_id', _user)
          .single();
      return _accountEmployee.copyWith(
        name: row['name'] as String,
        headline: row['headline'] as String,
        chips: (row['chips'] as List).cast<String>(),
      );
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
    final rows =
        await _rpc('company_employees', params: {'p_organization': _office})
            as List;
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
    if (!_hasPolicy) await policy();
    var query = client
        .from('check_ins')
        .select()
        .eq('organization_id', _office);
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
      validateContext();
      records.addAll(rows.map(_record));
      if (rows.length < 1000) return records;
    }
  });

  Future<Map<String, dynamic>> _invoke(
    String function,
    Map<String, dynamic> body,
  ) async {
    validateContext();
    final response = await client.functions
        .invoke(function, body: {'organization_id': _office, ...body})
        .timeout(const Duration(seconds: 30));
    validateContext();
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
    if (!_hasPolicy) await policy();
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
      validateContext();
      row = await _invoke('submit-attendance', payload);
    }
    return _record(Map<String, dynamic>.from(row['record'] as Map));
  });
  @override
  Future<AttendancePolicy> policy() => _policyRequest ??= _guard(() async {
    final row = await client
        .from('organizations')
        .select()
        .eq('id', _office)
        .single();
    _hasPolicy = true;
    return _policy = AttendancePolicy(
      mode: row['window_mode'] as String,
      startHour: row['start_hour'] as int,
      endHour: row['end_hour'] as int,
      timezone: row['timezone'] as String,
    );
  }).whenComplete(() => _policyRequest = null);
  @override
  Future<void> savePolicy(AttendancePolicy policy) => _guard(() async {
    await _rpc(
      'save_attendance_policy',
      params: {
        'p_organization': _office,
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
        .eq('user_id', _user)
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
    final userId = _user;
    String? path;
    if (bytes != null) {
      final format = ProfileImageFormat.fromBytes(bytes);
      path = '$userId/$kind-${const Uuid().v4()}.${format.extension}';
      await client.storage
          .from('profile-media')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: format.contentType),
          );
    }
    try {
      validateContext();
      final previous = await client
          .from('profiles')
          .select('${kind}_path')
          .eq('user_id', userId)
          .single();
      validateContext();
      await client
          .from('profiles')
          .update({'${kind}_path': path})
          .eq('user_id', userId)
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
  @override
  Future<void> setEmployeeRole(String userId, String role) => _guard(() async {
    await _rpc(
      'set_office_role',
      params: {'p_organization': _office, 'p_user': userId, 'p_role': role},
    );
  });

  @override
  Future<List<Office>> offices() => _guard(() async {
    final rows = await _rpc('my_offices') as List;
    final offices = <Office>[];
    for (final value in rows) {
      final row = Map<String, dynamic>.from(value as Map);
      String? logoUrl;
      if (row['logo_path'] != null) {
        try {
          logoUrl = await client.storage
              .from('office-logos')
              .createSignedUrl(row['logo_path'] as String, 900);
        } catch (_) {
          /* Initials remain available if logo signing fails. */
        }
      }
      offices.add(Office.fromMap(row, logoUrl: logoUrl));
    }
    return offices;
  });
  @override
  Future<List<OfficeInvitation>> officeInvitations() => _guard(() async {
    final rows = await _rpc('my_office_invitations') as List;
    return rows
        .map(
          (row) =>
              OfficeInvitation.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  });
  @override
  Future<Employee> switchOffice(String officeId) async {
    final userId = _user;
    _session.switching = true;
    _session.generation++;
    try {
      return await _guard(() async {
        final row = await _rpc(
          'switch_office',
          params: {'p_organization': officeId},
        );
        if (client.auth.currentUser?.id != userId) {
          throw const CompanyAccessException('Your account changed.');
        }
        final employee = Employee.fromMap(
          Map<String, dynamic>.from(row as Map),
        );
        if (employee.authUserId != userId ||
            employee.organizationId != officeId) {
          throw const CompanyAccessException(
            'Your office context could not be verified.',
          );
        }
        _session.officeId = employee.organizationId;
        _session.recoveryRequired = false;
        return employee;
      });
    } catch (_) {
      _session.recoveryRequired = true;
      rethrow;
    } finally {
      _session.switching = false;
    }
  }

  @override
  Future<String> createOffice(String name) => _guard(
    () async =>
        await _rpc('create_office', params: {'p_name': name.trim()}) as String,
  );
  @override
  Future<void> updateOffice(
    Office office, {
    required String name,
    Uint8List? logo,
    bool removeLogo = false,
  }) => _guard(() async {
    final userId = _user;
    var path = removeLogo ? null : office.logoPath;
    if (logo != null) {
      final format = ProfileImageFormat.fromBytes(logo);
      if (!['image/jpeg', 'image/png'].contains(format.contentType)) {
        throw const CompanyException('Choose a JPEG or PNG office logo.');
      }
      path = '${office.id}/${const Uuid().v4()}.${format.extension}';
      await client.storage
          .from('office-logos')
          .uploadBinary(
            path,
            logo,
            fileOptions: FileOptions(contentType: format.contentType),
          );
    }
    if (client.auth.currentUser?.id != userId) {
      throw const CompanyAccessException('Your account changed.');
    }
    await _rpc(
      'update_office',
      params: {
        'p_organization': office.id,
        'p_name': name.trim(),
        'p_logo': path,
      },
    );
    // Old/failed uploads are removed by retention, never through an ambiguous rollback.
  });
  @override
  Future<String> acceptOfficeInvitation(String invitationId) => _guard(
    () async =>
        await _rpc(
              'accept_office_invitation',
              params: {'p_invitation': invitationId},
            )
            as String,
  );
}
