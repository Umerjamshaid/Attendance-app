class Employee {
  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final String time;
  final String? phoneNumber;
  final String? workShift;
  final String? avatarUrl;
  final String? checkInTime;
  final int totalAbsents;
  final int totalPresents;
  final int totalLeaves;
  final bool isPresentToday;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    required this.time,
    this.phoneNumber,
    this.workShift,
    this.avatarUrl,
    this.checkInTime,
    this.totalAbsents = 0,
    this.totalPresents = 0,
    this.totalLeaves = 0,
    this.isPresentToday = false,
  });

  // ✅ Helper getters
  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';
  bool get isPresent => isPresentToday;
  bool get isAbsent => !isPresentToday;

  // ✅ Total attendance count
  int get totalAttendance => totalPresents + totalAbsents + totalLeaves;

  // ✅ Attendance percentage
  double get attendanceRate {
    if (totalAttendance == 0) return 0.0;
    return (totalPresents / totalAttendance) * 100;
  }

  // ✅ From Firebase/API → Dart Object
  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'employee',
      department: map['department'] ?? '',
      time: map['time'] ?? '—',
      phoneNumber: map['phoneNumber'],
      workShift: map['workShift'],
      avatarUrl: map['avatarUrl'],
      checkInTime: map['checkInTime'],
      totalAbsents: map['totalAbsents'] ?? 0,
      totalPresents: map['totalPresents'] ?? 0,
      totalLeaves: map['totalLeaves'] ?? 0,
      isPresentToday: map['isPresentToday'] ?? false,
    );
  }

  // ✅ Dart Object → Firebase/API
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      'time': time,
      'phoneNumber': phoneNumber,
      'workShift': workShift,
      'avatarUrl': avatarUrl,
      'checkInTime': checkInTime,
      'totalAbsents': totalAbsents,
      'totalPresents': totalPresents,
      'totalLeaves': totalLeaves,
      'isPresentToday': isPresentToday,
    };
  }

  // ✅ Copy with
  Employee copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? department,
    String? time,
    String? phoneNumber,
    String? workShift,
    String? avatarUrl,
    String? checkInTime,
    int? totalAbsents,
    int? totalPresents,
    int? totalLeaves,
    bool? isPresentToday,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      time: time ?? this.time,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      workShift: workShift ?? this.workShift,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      checkInTime: checkInTime ?? this.checkInTime,
      totalAbsents: totalAbsents ?? this.totalAbsents,
      totalPresents: totalPresents ?? this.totalPresents,
      totalLeaves: totalLeaves ?? this.totalLeaves,
      isPresentToday: isPresentToday ?? this.isPresentToday,
    );
  }

  @override
  String toString() {
    return 'Employee(id: $id, name: $name, role: $role, isPresentToday: $isPresentToday)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Employee && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
