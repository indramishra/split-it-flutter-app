class Group {
  final String id;
  final String name;
  final String groupType; // 'home', 'trip', 'couple', 'other'
  final List<String> memberIds;
  final bool simplifyByDefault;
  final DateTime createdAt;
  final String? createdByUserId;
  final DateTime? updatedAt;

  Group({
    required this.id,
    required this.name,
    required this.groupType,
    required this.memberIds,
    this.simplifyByDefault = true,
    DateTime? createdAt,
    this.createdByUserId,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Group copyWith({
    String? id,
    String? name,
    String? groupType,
    List<String>? memberIds,
    bool? simplifyByDefault,
    DateTime? createdAt,
    String? createdByUserId,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      groupType: groupType ?? this.groupType,
      memberIds: memberIds ?? this.memberIds,
      simplifyByDefault: simplifyByDefault ?? this.simplifyByDefault,
      createdAt: createdAt ?? this.createdAt,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'groupType': groupType,
        'memberIds': memberIds,
        'simplifyByDefault': simplifyByDefault,
        'createdAt': createdAt.toIso8601String(),
        if (createdByUserId != null) 'createdByUserId': createdByUserId,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String,
        name: json['name'] as String,
        groupType: json['groupType'] as String? ?? 'other',
        memberIds: (json['memberIds'] as List<dynamic>).cast<String>(),
        simplifyByDefault: json['simplifyByDefault'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        createdByUserId: json['createdByUserId'] as String?,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
}
