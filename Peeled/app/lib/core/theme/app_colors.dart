import 'package:flutter/material.dart';

/// PEELED brand + rarity palette. Mirrors docs/DESIGN.md.
class AppColors {
  AppColors._();

  // Brand
  static const Color coral = Color(0xFFFF6B57);
  static const Color coralDeep = Color(0xFFE04B3A);
  static const Color kraft = Color(0xFFD7B48C);
  static const Color kraftDeep = Color(0xFFB38D62);
  static const Color gold = Color(0xFFF2B84B);
  static const Color ink = Color(0xFF1A1B2E);
  static const Color cream = Color(0xFFFFF8EE);
  static const Color mint = Color(0xFF9BE8C3);
  static const Color violet = Color(0xFF7A5CFF);

  // Surfaces
  static const Color surfaceDark = Color(0xFF0F1020);
  static const Color surfaceDarkElevated = Color(0xFF1B1D36);
  static const Color surfaceLight = Color(0xFFFFF8EE);

  // Text
  static const Color textOnDark = Color(0xFFF4F0E6);
  static const Color textOnLight = Color(0xFF1A1B2E);
  static const Color textMuted = Color(0xFF8892B0);

  // Status
  static const Color success = Color(0xFF52D699);
  static const Color warning = Color(0xFFF2B84B);
  static const Color danger = Color(0xFFFF4A5B);

  // Rarity
  static const RarityPalette common = RarityPalette(
    fill: Color(0xFFB38D62),
    stroke: Color(0xFF7D5C3A),
    glow: Color(0x40B38D62),
  );
  static const RarityPalette uncommon = RarityPalette(
    fill: Color(0xFF6EC597),
    stroke: Color(0xFF3C8C63),
    glow: Color(0x556EC597),
  );
  static const RarityPalette rare = RarityPalette(
    fill: Color(0xFF4AA8F2),
    stroke: Color(0xFF1E6FBF),
    glow: Color(0x884AA8F2),
  );
  static const RarityPalette epic = RarityPalette(
    fill: Color(0xFF9B5CFF),
    stroke: Color(0xFF5F2AB2),
    glow: Color(0xAA9B5CFF),
  );
  static const RarityPalette legendary = RarityPalette(
    fill: Color(0xFFF2B84B),
    stroke: Color(0xFFB2791A),
    glow: Color(0xCCF2B84B),
  );
  static const RarityPalette mythic = RarityPalette(
    fill: Color(0xFFFF57C2),
    stroke: Color(0xFFA0207E),
    glow: Color(0xEEFF57C2),
  );

  static RarityPalette forRarity(String r) {
    switch (r) {
      case 'uncommon':
        return uncommon;
      case 'rare':
        return rare;
      case 'epic':
        return epic;
      case 'legendary':
        return legendary;
      case 'mythic':
        return mythic;
      case 'common':
      default:
        return common;
    }
  }
}

class RarityPalette {
  final Color fill;
  final Color stroke;
  final Color glow;
  const RarityPalette({required this.fill, required this.stroke, required this.glow});
}
