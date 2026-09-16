import 'package:flutter/material.dart';

class GoalModel {
  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final int iconCode;
  final int colorValue;

  GoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.targetDate,
    required this.iconCode,
    required this.colorValue,
  });

  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  double get progress {
    if (targetAmount <= 0) return 1.0;
    return (savedAmount / targetAmount).clamp(0.0, 1.0);
  }

  double get remainingAmount {
    final rem = targetAmount - savedAmount;
    return rem < 0 ? 0.0 : rem;
  }

  bool get isAchieved => savedAmount >= targetAmount && targetAmount > 0;

  GoalModel copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
    int? iconCode,
    int? colorValue,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      targetDate: targetDate ?? this.targetDate,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'targetDate': targetDate?.toIso8601String(),
      'iconCode': iconCode,
      'colorValue': colorValue,
    };
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      title: json['title'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: json['targetDate'] != null ? DateTime.parse(json['targetDate'] as String) : null,
      iconCode: json['iconCode'] as int,
      colorValue: json['colorValue'] as int,
    );
  }
}
