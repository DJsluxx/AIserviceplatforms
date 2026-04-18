import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.coral,
      brightness: Brightness.dark,
      surface: AppColors.surfaceDark,
      primary: AppColors.coral,
      secondary: AppColors.gold,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: _textTheme(scheme, onDark: true),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.coral,
      brightness: Brightness.light,
      surface: AppColors.surfaceLight,
      primary: AppColors.coralDeep,
      secondary: AppColors.gold,
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: AppColors.surfaceLight,
      textTheme: _textTheme(scheme, onDark: false),
    );
  }

  static ThemeData _base(ColorScheme scheme) => ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        splashFactory: InkSparkle.splashFactory,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );

  static TextTheme _textTheme(ColorScheme scheme, {required bool onDark}) {
    final color = onDark ? AppColors.textOnDark : AppColors.textOnLight;
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.02,
        letterSpacing: -1.5,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.08,
        letterSpacing: -1,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Fraunces',
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: color,
      ),
    );
  }
}
