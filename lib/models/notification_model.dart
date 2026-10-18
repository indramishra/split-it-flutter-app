class AppNotification {
  final String id;
  final String recipientUserId;
  final String recipientName;
  final String recipientEmail;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? groupId;
  final String? groupName;
  final String type; // 'expense_added', 'payment_settled', 'group_created'
  bool isRead;

  AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.recipientName,
    required this.recipientEmail,
    required this.title,
    required this.body,
    required this.timestamp,
    this.groupId,
    this.groupName,
    required this.type,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipientUserId': recipientUserId,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'groupId': groupId,
        'groupName': groupName,
        'type': type,
        'isRead': isRead,
      };
}
