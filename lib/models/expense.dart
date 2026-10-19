class Expense {
  final String id;
  final String? groupId;
  final String description;
  final double cost;
  final DateTime date;
  final String paidByUserId;
  final String category;
  final Map<String, double> splitShares; // userId -> amount owed
  final List<String> participantIds; // Indexed array for scoped Firestore queries
  final bool isPayment; // true if this is a "Settle up" payment transaction
  final String? notes;

  Expense({
    required this.id,
    this.groupId,
    required this.description,
    required this.cost,
    required this.date,
    required this.paidByUserId,
    this.category = 'General',
    required this.splitShares,
    List<String>? participantIds,
    this.isPayment = false,
    this.notes,
  }) : participantIds = participantIds ?? _computeParticipants(paidByUserId, splitShares);

  static List<String> _computeParticipants(
    String payer,
    Map<String, double> shares,
  ) {
    final set = <String>{payer, ...shares.keys};
    return set.toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'description': description,
        'cost': cost,
        'date': date.toIso8601String(),
        'paidByUserId': paidByUserId,
        'category': category,
        'splitShares': splitShares,
        'participantIds': participantIds,
        'isPayment': isPayment,
        'notes': notes,
      };

  factory Expense.fromJson(Map<String, dynamic> json) {
    final paidBy = json['paidByUserId'] as String;
    final splitMap = (json['splitShares'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );
    final pIds = (json['participantIds'] as List<dynamic>?)?.cast<String>() ??
        _computeParticipants(paidBy, splitMap);
    return Expense(
      id: json['id'] as String,
      groupId: json['groupId'] as String?,
      description: json['description'] as String,
      cost: (json['cost'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      paidByUserId: paidBy,
      category: json['category'] as String? ?? 'General',
      splitShares: splitMap,
      participantIds: pIds,
      isPayment: json['isPayment'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }
}

class ActivityItem {
  final String id;
  final String type; // 'expense_added', 'payment_settled', 'group_created', 'member_added', 'friend_added'
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? actorId;
  final String? actorName;
  final String? expenseId;
  final String? groupId;
  final String? groupName;
  final double? amount;
  final List<String> audienceUserIds; // Only users in this list receive this activity

  ActivityItem({
    required this.id,
    this.type = 'general',
    required this.title,
    required this.subtitle,
    required this.timestamp,
    String? actorId,
    this.actorName,
    this.expenseId,
    this.groupId,
    this.groupName,
    this.amount,
    List<String>? audienceUserIds,
    String? userId, // backward compatibility
  })  : actorId = actorId ?? userId,
        audienceUserIds = audienceUserIds ??
            (userId != null ? [userId] : const []);

  String? get userId => actorId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
        'actorId': actorId,
        if (actorName != null) 'actorName': actorName,
        'expenseId': expenseId,
        'groupId': groupId,
        if (groupName != null) 'groupName': groupName,
        if (amount != null) 'amount': amount,
        'audienceUserIds': audienceUserIds,
      };

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'general',
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        actorId: json['actorId'] as String? ?? json['userId'] as String?,
        actorName: json['actorName'] as String?,
        expenseId: json['expenseId'] as String?,
        groupId: json['groupId'] as String?,
        groupName: json['groupName'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
        audienceUserIds:
            (json['audienceUserIds'] as List<dynamic>?)?.cast<String>() ??
                (json['userId'] != null ? [json['userId'] as String] : []),
      );
}
