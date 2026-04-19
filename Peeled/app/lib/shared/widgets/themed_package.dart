import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game_state.dart';

/// Renders the "hero" package for a card. Branches on [PackageTheme]:
///
/// - [PackageTheme.rarity] loads the rarity-coloured SVG sprite.
/// - [PackageTheme.usaFlag] paints a custom stars-and-stripes package
///   with a blue star panel, 13 red/white stripes, and a gold seal.
///
/// Keeps a single external shape/size so cards can swap themes without
/// any layout reflow.
class ThemedPackage extends StatelessWidget {
  const ThemedPackage({
    super.key,
    required this.theme,
    required this.rarity,
    this.size = 200,
  });

  final PackageTheme theme;
  final PackageRarity rarity;
  final double size;

  @override
  Widget build(BuildContext context) {
    switch (theme) {
      case PackageTheme.rarity:
        return _RaritySprite(rarity: rarity, size: size);
      case PackageTheme.usaFlag:
        return _UsaFlagPackage(size: size);
    }
  }
}

class _RaritySprite extends StatelessWidget {
  const _RaritySprite({required this.rarity, required this.size});
  final PackageRarity rarity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/svg/packages/${rarity.token}.svg',
        fit: BoxFit.contain,
      ),
    );
  }
}

/// USA-themed package. Red body + horizontal white stripes, blue star
/// panel in the top-left, a gold wax seal, and a soft ribbon.
class _UsaFlagPackage extends StatelessWidget {
  const _UsaFlagPackage({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _UsaFlagPackagePainter()),
    );
  }
}

class _UsaFlagPackagePainter extends CustomPainter {
  static const _red = Color(0xFFB22234);
  static const _blue = Color(0xFF3C3B6E);
  static const _white = Color(0xFFFFFFFF);
  static const _gold = Color(0xFFE8B94B);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final pad = w * 0.1;
    final body = Rect.fromLTWH(pad, pad + h * 0.05, w - pad * 2, h - pad * 2);
    final rrect = RRect.fromRectAndRadius(body, Radius.circular(w * 0.06));

    // Soft shadow under the box.
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(
      rrect.shift(Offset(0, h * 0.035)),
      shadow,
    );

    // Base red body.
    canvas.drawRRect(rrect, Paint()..color = _red);

    // 13 stripes — alternate red/white. Use 7 white + 6 red.
    canvas.save();
    canvas.clipRRect(rrect);
    const totalStripes = 13;
    final stripeH = body.height / totalStripes;
    final stripePaint = Paint()..color = _white;
    for (int i = 0; i < totalStripes; i++) {
      if (i.isOdd) continue; // 0,2,4,... are white
      canvas.drawRect(
        Rect.fromLTWH(
          body.left,
          body.top + i * stripeH,
          body.width,
          stripeH,
        ),
        stripePaint,
      );
    }
    canvas.restore();

    // Top-left blue star panel covering upper-left quadrant of stripes.
    final panel = Rect.fromLTWH(
      body.left,
      body.top,
      body.width * 0.42,
      body.height * (7 / 13),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndCorners(
      panel,
      topLeft: Radius.circular(w * 0.06),
    ));
    canvas.drawRect(panel, Paint()..color = _blue);

    // Stars — 5 rows of 6, 4 rows of 5 (simplified to a grid of dots).
    final starPaint = Paint()..color = _white;
    const rows = 5;
    const cols = 6;
    for (int r = 0; r < rows; r++) {
      final y = panel.top + panel.height * (r + 0.8) / (rows + 1);
      for (int c = 0; c < cols; c++) {
        final x = panel.left + panel.width * (c + 0.8) / (cols + 1);
        _drawStar(canvas, Offset(x, y), w * 0.018, starPaint);
      }
    }
    canvas.restore();

    // Horizontal packing band (thin strip across middle).
    final bandH = h * 0.045;
    final band = Rect.fromCenter(
      center: body.center,
      width: body.width * 1.02,
      height: bandH,
    );
    canvas.drawRect(
      band.shift(Offset(0, 2)),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawRect(band, Paint()..color = _white.withOpacity(0.85));

    // Gold wax seal.
    final sealR = w * 0.07;
    final seal = Offset(body.center.dx, body.center.dy);
    canvas.drawCircle(
        seal + const Offset(0, 3),
        sealR,
        Paint()..color = const Color(0x55000000));
    canvas.drawCircle(seal, sealR, Paint()..color = _gold);
    canvas.drawCircle(
      seal,
      sealR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8B6514),
    );
    _drawStar(canvas, seal, sealR * 0.55, Paint()..color = const Color(0xFF8B6514));

    // "USA" top-banner chip floating just above the box.
    final chipW = w * 0.32;
    final chipH = h * 0.085;
    final chipRect = Rect.fromCenter(
      center: Offset(body.center.dx, body.top - chipH * 0.1),
      width: chipW,
      height: chipH,
    );
    final chip = RRect.fromRectAndRadius(chipRect, Radius.circular(chipH / 2));
    canvas.drawRRect(
      chip.shift(const Offset(0, 3)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRRect(chip, Paint()..color = _blue);
    canvas.drawRRect(
      chip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _gold,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: '★ USA ★',
        style: TextStyle(
          color: _white,
          fontSize: chipH * 0.55,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        chipRect.center.dx - textPainter.width / 2,
        chipRect.center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final a = -pi / 2 + (pi / 5) * i;
      final rad = i.isEven ? r : r * 0.45;
      final p = c + Offset(cos(a), sin(a)) * rad;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Palette used for the glow/ring around a package depending on its
/// theme. Rarity-themed uses [AppColors.forRarity]; USA flag has its
/// own red/blue glow.
RarityPalette paletteForPackage(PackageTheme theme, PackageRarity rarity) {
  if (theme == PackageTheme.usaFlag) {
    return const RarityPalette(
      fill: Color(0xFFB22234),
      stroke: Color(0xFF3C3B6E),
      glow: Color(0x99B22234),
    );
  }
  return AppColors.forRarity(rarity.token);
}
