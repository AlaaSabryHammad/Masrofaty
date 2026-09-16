import 'package:flutter/material.dart';

enum WorkspaceType {
  personal,
  business,
  store,
  freelance,
  family,
  investment;

  String get labelArabic {
    switch (this) {
      case WorkspaceType.personal:
        return 'شخصي';
      case WorkspaceType.business:
        return 'تجاري / مؤسسة';
      case WorkspaceType.store:
        return 'متجر إلكتروني';
      case WorkspaceType.freelance:
        return 'عمل حر ومشاريع';
      case WorkspaceType.family:
        return 'عائلة ومنزل';
      case WorkspaceType.investment:
        return 'استثمار وعقارات';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkspaceType.personal:
        return Icons.person_outline_rounded;
      case WorkspaceType.business:
        return Icons.business_rounded;
      case WorkspaceType.store:
        return Icons.storefront_rounded;
      case WorkspaceType.freelance:
        return Icons.work_outline_rounded;
      case WorkspaceType.family:
        return Icons.family_restroom_rounded;
      case WorkspaceType.investment:
        return Icons.trending_up_rounded;
    }
  }

  Color get defaultColor {
    switch (this) {
      case WorkspaceType.personal:
        return const Color(0xFF0D9488); // Emerald teal
      case WorkspaceType.business:
        return const Color(0xFF2563EB); // Royal blue
      case WorkspaceType.store:
        return const Color(0xFFE11D48); // Rose red
      case WorkspaceType.freelance:
        return const Color(0xFF8B5CF6); // Purple
      case WorkspaceType.family:
        return const Color(0xFFF59E0B); // Amber gold
      case WorkspaceType.investment:
        return const Color(0xFF059669); // Emerald green
    }
  }
}

class WorkspaceModel {
  final String id;
  final String userId;
  final String name;
  final WorkspaceType type;
  final String currency;
  final String currencySymbol;
  final int iconCode;
  final int colorValue;
  final bool isDefault;
  final DateTime createdAt;
  final String? description;
  final String? taxNumber;

  WorkspaceModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.currency = 'SAR',
    this.currencySymbol = 'ر.س',
    required this.iconCode,
    required this.colorValue,
    this.isDefault = false,
    required this.createdAt,
    this.description,
    this.taxNumber,
  });

  /// Create default personal workspace for a user
  factory WorkspaceModel.defaultWorkspace({
    required String userId,
    String name = 'حسابي الشخصي',
  }) {
    return WorkspaceModel(
      id: 'ws_personal_$userId',
      userId: userId,
      name: name,
      type: WorkspaceType.personal,
      currency: 'SAR',
      currencySymbol: 'ر.س',
      iconCode: Icons.person_outline_rounded.codePoint,
      colorValue: const Color(0xFF0D9488).toARGB32(),
      isDefault: true,
      createdAt: DateTime.now(),
      description: 'المصاريف الشخصية والميزانية اليومية',
    );
  }

  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  WorkspaceModel copyWith({
    String? id,
    String? userId,
    String? name,
    WorkspaceType? type,
    String? currency,
    String? currencySymbol,
    int? iconCode,
    int? colorValue,
    bool? isDefault,
    DateTime? createdAt,
    String? description,
    String? taxNumber,
  }) {
    return WorkspaceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      taxNumber: taxNumber ?? this.taxNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type.name,
      'currency': currency,
      'currencySymbol': currencySymbol,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'description': description,
      'taxNumber': taxNumber,
    };
  }

  factory WorkspaceModel.fromJson(Map<String, dynamic> json) {
    return WorkspaceModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String,
      type: WorkspaceType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => WorkspaceType.personal,
      ),
      currency: json['currency'] as String? ?? 'SAR',
      currencySymbol: json['currencySymbol'] as String? ?? 'ر.س',
      iconCode: json['iconCode'] as int? ?? Icons.folder_outlined.codePoint,
      colorValue: json['colorValue'] as int? ?? 0xFF0D9488,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      description: json['description'] as String?,
      taxNumber: json['taxNumber'] as String?,
    );
  }
}
