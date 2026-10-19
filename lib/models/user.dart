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
  final String? resetPasswordCode;
  final DateTime? resetPasswordCodeSentAt;
  // Explicit friends list — only users this user has added as friends
  final List<String> friendIds;

  // Phone / SMS verification fields
  final String? phoneNumber;
  final bool isPhoneVerified;
  final String? phoneVerificationCode;
  final DateTime? phoneVerificationCodeSentAt;

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
    this.resetPasswordCode,
    this.resetPasswordCodeSentAt,
    this.friendIds = const [],
    this.phoneNumber,
    this.isPhoneVerified = false,
    this.phoneVerificationCode,
    this.phoneVerificationCodeSentAt,
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
    bool clearVerificationCode = false,
    DateTime? verificationCodeSentAt,
    String? resetPasswordCode,
    bool clearResetPasswordCode = false,
    DateTime? resetPasswordCodeSentAt,
    List<String>? friendIds,
    String? phoneNumber,
    bool? isPhoneVerified,
    String? phoneVerificationCode,
    bool clearPhoneVerificationCode = false,
    DateTime? phoneVerificationCodeSentAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      verificationCode: clearVerificationCode
          ? null
          : (verificationCode ?? this.verificationCode),
      verificationCodeSentAt: clearVerificationCode
          ? null
          : (verificationCodeSentAt ?? this.verificationCodeSentAt),
      resetPasswordCode: clearResetPasswordCode
          ? null
          : (resetPasswordCode ?? this.resetPasswordCode),
      resetPasswordCodeSentAt: clearResetPasswordCode
          ? null
          : (resetPasswordCodeSentAt ?? this.resetPasswordCodeSentAt),
      friendIds: friendIds ?? this.friendIds,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      phoneVerificationCode: clearPhoneVerificationCode
          ? null
          : (phoneVerificationCode ?? this.phoneVerificationCode),
      phoneVerificationCodeSentAt: clearPhoneVerificationCode
          ? null
          : (phoneVerificationCodeSentAt ?? this.phoneVerificationCodeSentAt),
    );
  }

  Map<String, dynamic> toPublicJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'isEmailVerified': isEmailVerified,
        'friendIds': friendIds,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'isPhoneVerified': isPhoneVerified,
      };

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
        if (resetPasswordCode != null) 'resetPasswordCode': resetPasswordCode,
        if (resetPasswordCodeSentAt != null)
          'resetPasswordCodeSentAt':
              resetPasswordCodeSentAt!.toIso8601String(),
        'friendIds': friendIds,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        'isPhoneVerified': isPhoneVerified,
        if (phoneVerificationCode != null)
          'phoneVerificationCode': phoneVerificationCode,
        if (phoneVerificationCodeSentAt != null)
          'phoneVerificationCodeSentAt':
              phoneVerificationCodeSentAt!.toIso8601String(),
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
        // BUG FIX: was defaulting to `true`, causing new users to skip OTP verification
        isEmailVerified: json['isEmailVerified'] as bool? ?? false,
        verificationCode: json['verificationCode'] as String?,
        verificationCodeSentAt: json['verificationCodeSentAt'] != null
            ? DateTime.tryParse(json['verificationCodeSentAt'] as String)
            : null,
        resetPasswordCode: json['resetPasswordCode'] as String?,
        resetPasswordCodeSentAt: json['resetPasswordCodeSentAt'] != null
            ? DateTime.tryParse(json['resetPasswordCodeSentAt'] as String)
            : null,
        friendIds:
            (json['friendIds'] as List<dynamic>?)?.cast<String>() ??
                const [],
        phoneNumber: json['phoneNumber'] as String?,
        isPhoneVerified: json['isPhoneVerified'] as bool? ?? false,
        phoneVerificationCode: json['phoneVerificationCode'] as String?,
        phoneVerificationCodeSentAt: json['phoneVerificationCodeSentAt'] != null
            ? DateTime.tryParse(json['phoneVerificationCodeSentAt'] as String)
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
