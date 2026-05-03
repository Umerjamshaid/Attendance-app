// ─────────────────────────────────────────────────────────────
//  SECTION 1 — MODELS
//  Plain Dart classes. No logic. Just data shapes.
// ─────────────────────────────────────────────────────────────

class Employee {
  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final String? avatarUrl;
  final int totalAbsents;
  final int totalPresents;
  final int totalLeaves;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.avatarUrl,
    this.totalAbsents = 0, // Default to 0
    this.totalPresents = 0,
    this.totalLeaves = 0,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      department: map['department'] ?? '',
      avatarUrl: map['avatarUrl'],
      totalAbsents: map['totalAbsents'] ?? 0,
      totalPresents: map['totalPresents'] ?? 0,
      totalLeaves: map['totalLeaves'] ?? 0,
    );
  }
}
