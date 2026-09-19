class UserProfileModel {
  final String name;
  final String title;
  final String email;
  final String phone;
  final double monthlyBudget;
  final String bio;
  final String avatarPath;
  final DateTime joinDate;
  final String tier;

  UserProfileModel({
    required this.name,
    required this.title,
    required this.email,
    required this.phone,
    required this.monthlyBudget,
    required this.bio,
    required this.avatarPath,
    required this.joinDate,
    this.tier = 'عضو ذهبي ✨',
  });

  UserProfileModel copyWith({
    String? name,
    String? title,
    String? email,
    String? phone,
    double? monthlyBudget,
    String? bio,
    String? avatarPath,
    DateTime? joinDate,
    String? tier,
  }) {
    return UserProfileModel(
      name: name ?? this.name,
      title: title ?? this.title,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      bio: bio ?? this.bio,
      avatarPath: avatarPath ?? this.avatarPath,
      joinDate: joinDate ?? this.joinDate,
      tier: tier ?? this.tier,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'title': title,
      'email': email,
      'phone': phone,
      'monthlyBudget': monthlyBudget,
      'bio': bio,
      'avatarPath': avatarPath,
      'joinDate': joinDate.toIso8601String(),
      'tier': tier,
    };
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      name: json['name'] as String? ?? 'مستخدم مصروفاتي',
      title: json['title'] as String? ?? 'مستثمر طموح 🚀',
      email: json['email'] as String? ?? 'user@masrofaty.app',
      phone: json['phone'] as String? ?? '',
      monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble() ?? 5000.0,
      bio: json['bio'] as String? ?? 'الادخار المنتظم هو أولى خطوات الحرية المالية',
      avatarPath: json['avatarPath'] as String? ?? 'assets/images/default_avatar.png',
      joinDate: json['joinDate'] != null
          ? DateTime.tryParse(json['joinDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      tier: json['tier'] as String? ?? 'عضو ذهبي ✨',
    );
  }

  factory UserProfileModel.fromUserModel(dynamic user) {
    final name = (user?.name as String?)?.isNotEmpty == true ? user!.name as String : 'مستخدم مصروفاتي';
    final email = (user?.email as String?) ?? 'user@masrofaty.app';
    final profession = (user?.profession as String?)?.isNotEmpty == true
        ? user!.profession as String
        : 'مستثمر طموح 🚀';
    final phone = (user?.phone as String?) ?? '';
    final joinDate = (user?.createdAt as DateTime?) ?? DateTime.now();
    final photoUrl = (user?.photoUrl as String?);

    return UserProfileModel(
      name: name,
      title: profession,
      email: email,
      phone: phone,
      monthlyBudget: 5000.0,
      bio: 'الادخار المنتظم هو أولى خطوات الحرية المالية',
      avatarPath: (photoUrl != null && photoUrl.isNotEmpty) ? photoUrl : 'assets/images/default_avatar.png',
      joinDate: joinDate,
      tier: 'عضو ذهبي ✨',
    );
  }

  static UserProfileModel defaultProfile({
    String? name,
    String? title,
    String? email,
    String? phone,
  }) {
    return UserProfileModel(
      name: name ?? 'مستخدم مصروفاتي',
      title: title ?? 'مستثمر طموح 🚀',
      email: email ?? 'user@masrofaty.app',
      phone: phone ?? '',
      monthlyBudget: 5000.0,
      bio: 'الادخار المنتظم هو أولى خطوات الحرية المالية',
      avatarPath: 'assets/images/default_avatar.png',
      joinDate: DateTime.now(),
      tier: 'عضو ذهبي ✨',
    );
  }
}
