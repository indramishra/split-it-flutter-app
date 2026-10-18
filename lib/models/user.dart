class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? password;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.password,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        if (password != null) 'password': password,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        password: json['password'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

class Debt {
  final String fromUserId;
  final String toUserId;
  final double amount;

  const Debt({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'amount': amount,
      };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
        fromUserId: json['fromUserId'] as String,
        toUserId: json['toUserId'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}
