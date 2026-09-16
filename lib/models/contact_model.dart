class ContactModel {
  final String id;
  final String name;
  final String? phone;
  final String relationship; // 'friend', 'family', 'work', 'client', 'merchant', 'other'
  final String? notes;
  final DateTime createdAt;

  ContactModel({
    required this.id,
    required this.name,
    this.phone,
    this.relationship = 'friend',
    this.notes,
    required this.createdAt,
  });

  String get relationshipLabel {
    switch (relationship) {
      case 'friend':
        return 'صديق';
      case 'family':
        return 'عائلة / قريب';
      case 'work':
        return 'زميل عمل';
      case 'client':
        return 'عميل';
      case 'merchant':
        return 'متجر / مورد';
      case 'other':
      default:
        return 'أخرى';
    }
  }

  String get avatarInitial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '؟';
    return trimmed.substring(0, 1).toUpperCase();
  }

  ContactModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    String? notes,
    DateTime? createdAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      relationship: json['relationship'] as String? ?? 'friend',
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
