/// An authorized workspace; employee roles belong to this office, not the account.
class Office {
  const Office({
    required this.id,
    required this.name,
    required this.role,
    this.logoPath,
    this.logoUrl,
    this.createdBy,
  });
  final String id;
  final String name;
  final String role;
  final String? logoPath;
  final String? logoUrl;
  final String? createdBy;
  bool get isAdmin => role == 'admin';
  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .take(2)
      .map((s) => String.fromCharCodes(s.runes.take(1)))
      .join()
      .toUpperCase();
  factory Office.fromMap(Map<String, dynamic> row, {String? logoUrl}) => Office(
    id: row['id'] as String,
    name: row['name'] as String,
    role: row['role'] as String,
    logoPath: row['logo_path'] as String?,
    createdBy: row['created_by'] as String?,
    logoUrl: logoUrl,
  );
}

class OfficeInvitation {
  const OfficeInvitation({
    required this.id,
    required this.name,
    required this.employeeCode,
  });
  final String id;
  final String name;
  final String employeeCode;
  factory OfficeInvitation.fromMap(Map<String, dynamic> row) =>
      OfficeInvitation(
        id: row['id'] as String,
        name: row['name'] as String,
        employeeCode: row['employee_code'] as String,
      );
}
