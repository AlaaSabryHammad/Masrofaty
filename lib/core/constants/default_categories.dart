import 'package:flutter/material.dart';
import '../../models/category_model.dart';
import '../../models/wallet_model.dart';

class DefaultData {
  static List<CategoryModel> get categories => [
        // Expense Categories
        CategoryModel(
          id: 'cat_food',
          name: 'طعام ومشروبات',
          iconCode: Icons.restaurant_rounded.codePoint,
          colorValue: 0xFFF43F5E,
          isExpense: true,
          budgetLimit: 1500.0,
        ),
        CategoryModel(
          id: 'cat_transport',
          name: 'مواصلات وسيارة',
          iconCode: Icons.directions_car_rounded.codePoint,
          colorValue: 0xFF3B82F6,
          isExpense: true,
          budgetLimit: 600.0,
        ),
        CategoryModel(
          id: 'cat_shopping',
          name: 'تسوق ومشتريات',
          iconCode: Icons.shopping_bag_rounded.codePoint,
          colorValue: 0xFFF59E0B,
          isExpense: true,
          budgetLimit: 800.0,
        ),
        CategoryModel(
          id: 'cat_bills',
          name: 'فواتير والتزامات',
          iconCode: Icons.receipt_long_rounded.codePoint,
          colorValue: 0xFF06B6D4,
          isExpense: true,
          budgetLimit: 1000.0,
        ),
        CategoryModel(
          id: 'cat_housing',
          name: 'سكن وإيجار',
          iconCode: Icons.home_rounded.codePoint,
          colorValue: 0xFF6366F1,
          isExpense: true,
          budgetLimit: 2500.0,
        ),
        CategoryModel(
          id: 'cat_health',
          name: 'صحة وصيدلية',
          iconCode: Icons.local_hospital_rounded.codePoint,
          colorValue: 0xFFEC4899,
          isExpense: true,
          budgetLimit: 400.0,
        ),
        CategoryModel(
          id: 'cat_entertainment',
          name: 'ترفيه وسفر',
          iconCode: Icons.movie_filter_rounded.codePoint,
          colorValue: 0xFF8B5CF6,
          isExpense: true,
          budgetLimit: 500.0,
        ),
        CategoryModel(
          id: 'cat_education',
          name: 'تعليم ودورات',
          iconCode: Icons.school_rounded.codePoint,
          colorValue: 0xFFEAB308,
          isExpense: true,
          budgetLimit: 500.0,
        ),
        CategoryModel(
          id: 'cat_family',
          name: 'عائلة وهدايا',
          iconCode: Icons.card_giftcard_rounded.codePoint,
          colorValue: 0xFFF97316,
          isExpense: true,
          budgetLimit: 400.0,
        ),
        CategoryModel(
          id: 'cat_fitness',
          name: 'رياضة ولياقة',
          iconCode: Icons.fitness_center_rounded.codePoint,
          colorValue: 0xFF10B981,
          isExpense: true,
          budgetLimit: 250.0,
        ),
        CategoryModel(
          id: 'cat_other_exp',
          name: 'مصاريف أخرى',
          iconCode: Icons.category_rounded.codePoint,
          colorValue: 0xFF64748B,
          isExpense: true,
          budgetLimit: 300.0,
        ),

        // Income Categories
        CategoryModel(
          id: 'cat_salary',
          name: 'الراتب الأساسي',
          iconCode: Icons.account_balance_wallet_rounded.codePoint,
          colorValue: 0xFF10B981,
          isExpense: false,
        ),
        CategoryModel(
          id: 'cat_freelance',
          name: 'عمل حر وتجارة',
          iconCode: Icons.laptop_mac_rounded.codePoint,
          colorValue: 0xFF0EA5E9,
          isExpense: false,
        ),
        CategoryModel(
          id: 'cat_investment',
          name: 'أرباح واستثمار',
          iconCode: Icons.trending_up_rounded.codePoint,
          colorValue: 0xFF8B5CF6,
          isExpense: false,
        ),
        CategoryModel(
          id: 'cat_bonus',
          name: 'مكافآت وحوافز',
          iconCode: Icons.emoji_events_rounded.codePoint,
          colorValue: 0xFFF59E0B,
          isExpense: false,
        ),
        CategoryModel(
          id: 'cat_gifts',
          name: 'هدايا وعيديات',
          iconCode: Icons.redeem_rounded.codePoint,
          colorValue: 0xFFEC4899,
          isExpense: false,
        ),
        CategoryModel(
          id: 'cat_other_inc',
          name: 'إيرادات أخرى',
          iconCode: Icons.attach_money_rounded.codePoint,
          colorValue: 0xFF14B8A6,
          isExpense: false,
        ),
      ];

  static List<WalletModel> get defaultWallets => [
        WalletModel(
          id: 'wallet_cash',
          name: 'نقدي (كاش)',
          type: 'cash',
          balance: 0.0,
          iconCode: Icons.payments_rounded.codePoint,
          colorValue: 0xFF10B981,
        ),
        WalletModel(
          id: 'wallet_bank',
          name: 'الحساب البنكي',
          type: 'bank',
          balance: 0.0,
          iconCode: Icons.account_balance_rounded.codePoint,
          colorValue: 0xFF3B82F6,
        ),
        WalletModel(
          id: 'wallet_card',
          name: 'البطاقة الائتمانية',
          type: 'card',
          balance: 0.0,
          iconCode: Icons.credit_card_rounded.codePoint,
          colorValue: 0xFF8B5CF6,
        ),
        WalletModel(
          id: 'wallet_savings',
          name: 'محفظة التوفير',
          type: 'savings',
          balance: 0.0,
          iconCode: Icons.savings_rounded.codePoint,
          colorValue: 0xFFF59E0B,
        ),
      ];
}
