class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? password;
  final DateTime? createdAt;
  final bool isEmailVerified;
  final String? verificationCode;
  final DateTime? verificationCodeSentAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.password,
    this.createdAt,
    this.isEmailVerified = false,
    this.verificationCode,
    this.verificationCodeSentAt,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? password,
    DateTime? createdAt,
    bool? isEmailVerified,
    String? verificationCode,
    DateTime? verificationCodeSentAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      verificationCode: verificationCode ?? this.verificationCode,
      verificationCodeSentAt:
          verificationCodeSentAt ?? this.verificationCodeSentAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        if (password != null) 'password': password,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'isEmailVerified': isEmailVerified,
        if (verificationCode != null) 'verificationCode': verificationCode,
        if (verificationCodeSentAt != null)
          'verificationCodeSentAt': verificationCodeSentAt!.toIso8601String(),
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
        isEmailVerified: json['isEmailVerified'] as bool? ?? true,
        verificationCode: json['verificationCode'] as String?,
        verificationCodeSentAt: json['verificationCodeSentAt'] != null
            ? DateTime.tryParse(json['verificationCodeSentAt'] as String)
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
