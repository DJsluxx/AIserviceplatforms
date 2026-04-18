import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Live Globe — real Mapbox globe view wired at integration time.
/// For this scaffold, render a placeholder canvas showing rarity arcs.
class WorldmapScreen extends ConsumerWidget {
  const WorldmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Globe')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF1D2A4D), AppColors.surfaceDark],
          ),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, size: 160, color: AppColors.coral),
                SizedBox(height: AppSpacing.lg),
                Text(
                  'Packages travelling worldwide',
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Globe rendering wires up at runtime via Mapbox. '
                  'Watch arcs light up as packages hop between cities.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
