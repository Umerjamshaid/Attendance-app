// ─────────────────────────────────────────────────────────────
//  SECTION 1 — MODELS
//  Plain Dart classes. No logic. Just data shapes.
// ─────────────────────────────────────────────────────────────

class Employee {
  final String id;
  final String name;
  final String department;
  final String? avatarUrl;

  Employee({
    required this.id,
    required this.name,
    required this.department,
    this.avatarUrl,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      department: map['department'] ?? '',
      avatarUrl: map['avatarUrl'],
    );
  }
}
