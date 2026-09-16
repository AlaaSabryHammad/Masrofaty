import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final int iconCode;
  final int colorValue;
  final bool isExpense;
  final double budgetLimit;

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.colorValue,
    this.isExpense = true,
    this.budgetLimit = 0.0,
  });

  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  CategoryModel copyWith({
    String? id,
    String? name,
    int? iconCode,
    int? colorValue,
    bool? isExpense,
    double? budgetLimit,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      isExpense: isExpense ?? this.isExpense,
      budgetLimit: budgetLimit ?? this.budgetLimit,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'colorValue': colorValue,
      'isExpense': isExpense,
      'budgetLimit': budgetLimit,
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCode: json['iconCode'] as int,
      colorValue: json['colorValue'] as int,
      isExpense: json['isExpense'] as bool? ?? true,
      budgetLimit: (json['budgetLimit'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
