import 'package:flutter/material.dart';

enum SaaSTier {
  starter,
  pro,
  enterprise;

  String get titleArabic {
    switch (this) {
      case SaaSTier.starter:
        return 'الباقة الأساسية';
      case SaaSTier.pro:
        return 'باقة المحترفين (Pro)';
      case SaaSTier.enterprise:
        return 'باقة الشركات (Enterprise)';
    }
  }

  String get subtitleArabic {
    switch (this) {
      case SaaSTier.starter:
        return 'للأفراد والمصاريف اليومية';
      case SaaSTier.pro:
        return 'لأصحاب الأعمال والمتاجر والفريلانسرز';
      case SaaSTier.enterprise:
        return 'للشركات والمؤسسات ذات الفروع المتعددة';
    }
  }

  String get priceText {
    switch (this) {
      case SaaSTier.starter:
        return 'مجاناً مدى الحياة';
      case SaaSTier.pro:
        return '39 ر.س / شهرياً';
      case SaaSTier.enterprise:
        return '99 ر.س / شهرياً';
    }
  }

  int get maxWorkspaces {
    switch (this) {
      case SaaSTier.starter:
        return 2;
      case SaaSTier.pro:
        return 10;
      case SaaSTier.enterprise:
        return 999;
    }
  }

  List<String> get features {
    switch (this) {
      case SaaSTier.starter:
        return [
          'حسابان منفصلان (شخصي + تجاري)',
          'تتبع المصاريف والدخول اللامحدودة',
          'إدارة الحسابات البنكية والنقدية',
          'سجل الديون والالتزامات',
          'نسخ احتياطي محلي مشفر',
        ];
      case SaaSTier.pro:
        return [
          'حتى 10 حسابات ومساحات عمل مستقلة تماماً',
          'قراءة رسائل البنوك التلقائية بالذكاء الاصطناعي',
          'كشوف حسابات احترافية بصيغة PDF و Excel',
          'دعم تعدد العملات لكل مساحة عمل بشكل مستقل',
          'إدارة حسابات جهات الاتصال والعملاء',
          'تخصيص أيقونات وألوان الحسابات',
        ];
      case SaaSTier.enterprise:
        return [
          'عدد غير محدود من مساحات العمل والشركات',
          'تصدير فواتير وتقارير ضريبية معتمدة',
          'دعم المزامنة السحابية المتقدمة لفرق العمل',
          'أولوية الدعم الفني المخصص 24/7',
          'ربط بوابات الدفع والتجارة الإلكترونية',
          'صلاحيات وصول ومسؤولين متعددين',
        ];
    }
  }

  Color get color {
    switch (this) {
      case SaaSTier.starter:
        return const Color(0xFF64748B);
      case SaaSTier.pro:
        return const Color(0xFFD97706); // Warm Amber Gold
      case SaaSTier.enterprise:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  IconData get icon {
    switch (this) {
      case SaaSTier.starter:
        return Icons.person_outline_rounded;
      case SaaSTier.pro:
        return Icons.workspace_premium_rounded;
      case SaaSTier.enterprise:
        return Icons.domain_rounded;
    }
  }
}

class SaaSPlanModel {
  final SaaSTier tier;
  final DateTime subscribedAt;
  final DateTime? expiresAt;
  final bool isActive;

  SaaSPlanModel({
    required this.tier,
    required this.subscribedAt,
    this.expiresAt,
    this.isActive = true,
  });

  factory SaaSPlanModel.starter() {
    return SaaSPlanModel(
      tier: SaaSTier.starter,
      subscribedAt: DateTime.now(),
      isActive: true,
    );
  }

  factory SaaSPlanModel.pro() {
    return SaaSPlanModel(
      tier: SaaSTier.pro,
      subscribedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      isActive: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier': tier.name,
      'subscribedAt': subscribedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory SaaSPlanModel.fromJson(Map<String, dynamic> json) {
    return SaaSPlanModel(
      tier: SaaSTier.values.firstWhere(
        (t) => t.name == json['tier'],
        orElse: () => SaaSTier.starter,
      ),
      subscribedAt: json['subscribedAt'] != null
          ? DateTime.parse(json['subscribedAt'] as String)
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}
