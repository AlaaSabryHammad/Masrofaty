import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Accent
  static const Color primary = Color(0xFF10B981); // Emerald Green
  static const Color primaryEmerald = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF059669);
  static const Color primaryLight = Color(0xFF34D399);
  static const Color primaryGradientStart = Color(0xFF059669);
  static const Color primaryGradientEnd = Color(0xFF10B981);

  // Financial Semantics
  static const Color income = Color(0xFF10B981); // Emerald
  static const Color incomeLight = Color(0xFFD1FAE5);
  static const Color expense = Color(0xFFF43F5E); // Rose / Coral
  static const Color expenseLight = Color(0xFFFFE4E6);
  static const Color debtLent = Color(0xFF0284C7); // Sky Blue (Money owed to me)
  static const Color debtBorrowed = Color(0xFFF59E0B); // Amber (Money I owe)
  static const Color transfer = Color(0xFF8B5CF6); // Purple

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Light Mode Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Mode Palette (AMOLED / Deep Slate)
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkCardElevated = Color(0xFF273549);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Vibrant Category Accent Colors
  static const List<Color> categoryPalette = [
    Color(0xFFF43F5E), // Rose (Food & Dining)
    Color(0xFF3B82F6), // Blue (Transportation)
    Color(0xFF10B981), // Emerald (Salary / Income)
    Color(0xFFF59E0B), // Amber (Shopping)
    Color(0xFF8B5CF6), // Purple (Entertainment)
    Color(0xFF06B6D4), // Cyan (Bills & Utilities)
    Color(0xFFEC4899), // Pink (Health & Medical)
    Color(0xFFEAB308), // Yellow (Education)
    Color(0xFF14B8A6), // Teal (Investment)
    Color(0xFF6366F1), // Indigo (Housing / Rent)
    Color(0xFF64748B), // Slate (Others)
    Color(0xFFF97316), // Orange (Family & Gifts)
  ];
}
