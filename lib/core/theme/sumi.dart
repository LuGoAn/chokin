import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class Sumi {
  static const String uiFont = 'ZenKakuGothicNew';
  static const String figureFont = 'ShipporiMincho';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures(), FontFeature.liningFigures()];

  static const double gutter = 24;
  static const double radius = 6;
  static const double hairline = 1;

  static TextStyle figures(double size, {FontWeight weight = FontWeight.w500, Color color = AppColors.textPrimary}) {
    return TextStyle(
      fontFamily: figureFont,
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: _tabular,
      height: 1.15,
    );
  }

  static const TextStyle label = TextStyle(fontFamily: uiFont, fontSize: 13, color: AppColors.textSecondary);
  static const TextStyle caption = TextStyle(fontFamily: uiFont, fontSize: 11, color: AppColors.textSecondary);
  static const TextStyle body = TextStyle(fontFamily: uiFont, fontSize: 14, color: AppColors.textPrimary);
  static const TextStyle bodyStrong =
      TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: uiFont,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 1,
    color: AppColors.textSecondary,
  );

  static const List<String> shortMonths = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez'
  ];

  static String shortMonth(int month) => shortMonths[(month - 1).clamp(0, 11)];
}
