import 'package:flutter/material.dart';

class WalletModel {
  final String id;
  final String name;
  final String type; // 'cash', 'bank', 'card', 'savings', 'digital'
  final double balance;
  final int iconCode;
  final int colorValue;

  WalletModel({
    required this.id,
    required this.name,
    this.type = 'cash',
    this.balance = 0.0,
    required this.iconCode,
    required this.colorValue,
  });

  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  WalletModel copyWith({
    String? id,
    String? name,
    String? type,
    double? balance,
    int? iconCode,
    int? colorValue,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'iconCode': iconCode,
      'colorValue': colorValue,
    };
  }

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'cash',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      iconCode: json['iconCode'] as int,
      colorValue: json['colorValue'] as int,
    );
  }
}
