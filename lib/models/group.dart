class Group {
  final String id;
  final String name;
  final String groupType; // 'home', 'trip', 'couple', 'other'
  final List<String> memberIds;
  final bool simplifyByDefault;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.groupType,
    required this.memberIds,
    this.simplifyByDefault = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Group copyWith({
    String? id,
    String? name,
    String? groupType,
    List<String>? memberIds,
    bool? simplifyByDefault,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      groupType: groupType ?? this.groupType,
      memberIds: memberIds ?? this.memberIds,
      simplifyByDefault: simplifyByDefault ?? this.simplifyByDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'groupType': groupType,
        'memberIds': memberIds,
        'simplifyByDefault': simplifyByDefault,
        'createdAt': createdAt.toIso8601String(),
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
      );
}
