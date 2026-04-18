import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// PEELED brand wordmark — clean, crisp text with a coral underline accent.
///
/// Chosen over SVG to avoid CanvasKit rendering quirks with compound paths.
class PeelWordmark extends StatelessWidget {
  const PeelWordmark({
    super.key,
    this.height = 40,
    this.color = AppColors.cream,
    this.accent = AppColors.coral,
    this.showAccent = true,
  });

  final double height;
  final Color color;
  final Color accent;
  final bool showAccent;

  @override
  Widget build(BuildContext context) {
    final fontSize = height * 0.72;
    final underlineH = (height * 0.06).clamp(2.0, 5.0);
    return SizedBox(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'PEELED',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: fontSize * 0.08,
              color: color,
              height: 1.0,
            ),
          ),
          if (showAccent) ...[
            SizedBox(height: height * 0.08),
            Container(
              width: fontSize * 1.6,
              height: underlineH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withOpacity(0.0), accent, accent.withOpacity(0.0)],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(underlineH),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
