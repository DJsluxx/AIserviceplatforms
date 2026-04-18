import 'package:flutter/material.dart';

/// Spacing, radius, elevation tokens. Mirrors docs/DESIGN.md.
class AppSpacing {
  AppSpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 22;
  static const double xl = 32;
  static const double pill = 999;
}

class AppElevation {
  AppElevation._();
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> dialog = [
    BoxShadow(color: Color(0x44000000), blurRadius: 32, offset: Offset(0, 16)),
  ];
  static const List<BoxShadow> buttonJuicy = [
    BoxShadow(color: Color(0x33000000), blurRadius: 0, offset: Offset(0, 4)),
  ];
}

class AppDurations {
  AppDurations._();
  static const quick = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 220);
  static const medium = Duration(milliseconds: 380);
  static const slow = Duration(milliseconds: 620);
  static const peel = Duration(milliseconds: 1100);
}
