class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? profession;
  final String authMethod; // 'email', 'google', 'phone', 'guest'
  final bool isGuest;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.profession,
    required this.authMethod,
    this.isGuest = false,
    this.isEmailVerified = false,
    required this.createdAt,
    required this.lastLoginAt,
  });

  String get authMethodLabel {
    switch (authMethod) {
      case 'google':
        return 'حساب جوجل (Google)';
      case 'phone':
        return 'رقم الجوال (SMS OTP)';
      case 'guest':
        return 'وضع الضيف (تجريبي)';
      case 'email':
      default:
        return 'البريد الإلكتروني';
    }
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? profession,
    String? authMethod,
    bool? isGuest,
    bool? isEmailVerified,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      profession: profession ?? this.profession,
      authMethod: authMethod ?? this.authMethod,
      isGuest: isGuest ?? this.isGuest,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'profession': profession,
      'authMethod': authMethod,
      'isGuest': isGuest,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final method = json['authMethod'] as String? ?? 'email';
    return UserModel(
      id: json['id'] as String? ?? 'guest_user',
      name: json['name'] as String? ?? 'مستخدم مصروفاتي',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      profession: json['profession'] as String?,
      authMethod: method,
      isGuest: json['isGuest'] as bool? ?? false,
      isEmailVerified: json['isEmailVerified'] as bool? ?? (method == 'google'),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory UserModel.guestUser() {
    final now = DateTime.now();
    return UserModel(
      id: 'guest_${now.millisecondsSinceEpoch}',
      name: 'مستخدم ضيف',
      profession: 'مستخدم تجريبي',
      authMethod: 'guest',
      isGuest: true,
      isEmailVerified: false,
      createdAt: now,
      lastLoginAt: now,
    );
  }
}
