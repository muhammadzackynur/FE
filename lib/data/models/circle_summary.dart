class CircleSummary {
  const CircleSummary({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.referalCode,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String? name;
  final int ownerId;
  final String referalCode;
  final String createdAt;
  final String updatedAt;

  factory CircleSummary.fromJson(Map<String, dynamic> json) {
    return CircleSummary(
      id: _parseInt(json['id'] ?? json['circle_id']),
      name: (json['name'] ?? json['circle_name'])?.toString(),
      ownerId: _parseInt(json['owner_id'] ?? json['user_id']),
      referalCode: (json['referal_code'] ??
              json['referral_code'] ??
              json['invite_code'] ??
              '')
          .toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner_id': ownerId,
      'referal_code': referalCode,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get displayName {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }

    return 'Circle $referalCode';
  }

  bool isOwnedBy(int? userId) {
    return userId != null && ownerId == userId;
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
