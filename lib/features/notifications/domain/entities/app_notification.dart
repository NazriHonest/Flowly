class AppNotification {
  const AppNotification({
    this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });
  final int? id;
  final String title, body;
  final DateTime createdAt;
  final bool isRead;
}
