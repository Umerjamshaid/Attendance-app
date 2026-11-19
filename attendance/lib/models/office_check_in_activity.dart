/// A confirmed check-in shown in the selected office's admin activity feed.
class OfficeCheckInActivity {
  const OfficeCheckInActivity({
    required this.id,
    required this.employeeName,
    required this.receivedAt,
  });

  final String id;
  final String employeeName;
  final DateTime receivedAt;
}
