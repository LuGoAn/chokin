import 'package:flutter/material.dart';

class AppColors {
  // Brand & Backgrounds (Dark First Mobile Theme)
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color surface = Color(0xFF1E293B);    // Slate 800
  static const Color surfaceLight = Color(0xFF334155); // Slate 700
  static const Color cardBackground = Color(0xFF1E293B);

  // Accents
  static const Color primary = Color(0xFF10B981);    // Emerald 500 (Growth/Money)
  static const Color primaryLight = Color(0xFF34D399);
  static const Color primaryDark = Color(0xFF059669);
  static const Color secondary = Color(0xFF6366F1);  // Indigo 500
  
  // Status & Financial Indicators
  static const Color income = Color(0xFF10B981);     // Green
  static const Color expense = Color(0xFFEF4444);    // Red
  static const Color reserve = Color(0xFF3B82F6);    // Blue (Caixinha)
  static const Color committed = Color(0xFFF59E0B);  // Amber (Comprometido)
  static const Color reimbursement = Color(0xFF8B5CF6); // Purple (A receber)
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);   // Slate 50
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textMuted = Color(0xFF64748B);     // Slate 500
  static const Color textOnPrimary = Colors.white;

  // Borders & Dividers
  static const Color border = Color(0xFF334155);
  static const Color borderSubtle = Color(0xFF1E293B);
}
