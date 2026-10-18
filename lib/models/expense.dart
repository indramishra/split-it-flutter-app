class Expense {
  final String id;
  final String? groupId;
  final String description;
  final double cost;
  final DateTime date;
  final String paidByUserId;
  final String category;
  final Map<String, double> splitShares; // userId -> amount owed
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
    this.isPayment = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'description': description,
        'cost': cost,
        'date': date.toIso8601String(),
        'paidByUserId': paidByUserId,
        'category': category,
        'splitShares': splitShares,
        'isPayment': isPayment,
        'notes': notes,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        groupId: json['groupId'] as String?,
        description: json['description'] as String,
        cost: (json['cost'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        paidByUserId: json['paidByUserId'] as String,
        category: json['category'] as String? ?? 'General',
        splitShares: (json['splitShares'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
        isPayment: json['isPayment'] as bool? ?? false,
        notes: json['notes'] as String?,
      );
}

class ActivityItem {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? expenseId;

  ActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.expenseId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
        'expenseId': expenseId,
      };

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        expenseId: json['expenseId'] as String?,
      );
}
