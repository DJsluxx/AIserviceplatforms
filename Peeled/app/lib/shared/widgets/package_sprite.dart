import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';

/// Premium package sprite — loads the rarity-specific SVG from
/// assets/svg/packages/{rarity}.svg and wraps it in a breathing glow halo.
class PackageSprite extends StatelessWidget {
  const PackageSprite({
    super.key,
    required this.rarity,
    this.size = 180,
    this.animate = true,
  });

  final String rarity;
  final double size;
  final bool animate;

  String get _asset => 'assets/svg/packages/$rarity.svg';

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.forRarity(rarity);
    final halo = SizedBox(
      width: size * 1.4,
      height: size * 1.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [palette.glow, palette.glow.withOpacity(0)],
          ),
        ),
      ),
    );

    final sprite = SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(_asset, fit: BoxFit.contain),
    );

    Widget stack = Stack(alignment: Alignment.center, children: [halo, sprite]);

    if (animate) {
      stack = stack.animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(0.98, 0.98),
            end: const Offset(1.02, 1.02),
            duration: 2400.ms,
            curve: Curves.easeInOut,
          );
    }
    return stack;
  }
}
