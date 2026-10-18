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

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        recipientUserId: json['recipientUserId'] as String,
        recipientName: json['recipientName'] as String,
        recipientEmail: json['recipientEmail'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        groupId: json['groupId'] as String?,
        groupName: json['groupName'] as String?,
        type: json['type'] as String,
        isRead: json['isRead'] as bool? ?? false,
      );
}
