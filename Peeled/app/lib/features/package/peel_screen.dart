import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/package_model.dart';
import '../../shared/widgets/confetti.dart';
import '../../shared/widgets/countdown_timer.dart';
import '../../shared/widgets/juicy_button.dart';
import '../../shared/widgets/package_sprite.dart';
import 'peel_controller.dart';

/// The peel screen — the sacred moment of the game.
///
/// Visual states:
///   IDLE    — package sprite breathing with halo, "PEEL" button live
///   TUG     — on tap-and-hold, wrapper stretches subtly
///   TEAR    — burst of particles, paper rip sound, sprite fractures
///   REVEAL  — slideup card shows layer text/image
///   SETTLE  — back to idle OR → OPENED state with confetti + prize card
class PeelScreen extends ConsumerStatefulWidget {
  const PeelScreen({super.key, required this.packageId});
  final String packageId;

  @override
  ConsumerState<PeelScreen> createState() => _PeelScreenState();
}

class _PeelScreenState extends ConsumerState<PeelScreen>
    with TickerProviderStateMixin {
  PeelPhase _phase = PeelPhase.idle;
  PeeledLayerModel? _revealed;
  bool _isFinal = false;
  Map<String, dynamic>? _reward;
  int _revealKey = 0;

  Future<void> _peel(PackageModel pkg) async {
    if (_phase != PeelPhase.idle) return;
    HapticFeedback.heavyImpact();
    setState(() => _phase = PeelPhase.tug);
    await Future.delayed(AppDurations.fast);
    setState(() => _phase = PeelPhase.tear);

    try {
      final result = await ref
          .read(peelControllerProvider.notifier)
          .peel(widget.packageId);
      if (!mounted) return;
      setState(() {
        _revealed = result.revealed;
        _isFinal = result.isFinal;
        _reward = result.reward;
        _phase = PeelPhase.reveal;
        _revealKey++;
      });
      HapticFeedback.mediumImpact();
      if (_isFinal) {
        await Future.delayed(AppDurations.slow);
        if (!mounted) return;
        setState(() => _phase = PeelPhase.opened);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = PeelPhase.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(peelControllerProvider);
    return Scaffold(
      body: Stack(
        children: [
          // Rarity-tinted radial background
          Positioned.fill(
            child: state.maybeWhen(
              data: (pkg) => _Backdrop(rarity: pkg?.rarity ?? 'common'),
              orElse: () => const _Backdrop(rarity: 'common'),
            ),
          ),
          SafeArea(
            child: state.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (pkg) {
                if (pkg == null) {
                  return const Center(child: Text('Package not found'));
                }
                return _buildBody(pkg);
              },
            ),
          ),
          if (_phase == PeelPhase.opened)
            ConfettiOverlay(fireKey: _revealKey, rarity: _revealed != null ? 'mythic' : 'epic'),
        ],
      ),
    );
  }

  Widget _buildBody(PackageModel pkg) {
    final rarity = pkg.rarity;
    return Column(
      children: [
        _TopBar(pkg: pkg),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _SpritePedestal(
                rarity: rarity,
                phase: _phase,
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: AppDurations.medium,
          child: _revealed == null
              ? const SizedBox.shrink()
              : _RevealCard(layer: _revealed!, key: ValueKey(_revealKey)),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: JuicyButton(
                  label: _isFinal ? "YOU PEELED IT!" : "PEEL",
                  icon: Icons.auto_awesome,
                  primary: AppColors.coral,
                  onPressed: _phase == PeelPhase.idle ? () => _peel(pkg) : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              JuicyButton(
                label: "Pass",
                wide: false,
                primary: AppColors.kraft,
                size: JuicyButtonSize.medium,
                onPressed: _phase == PeelPhase.idle
                    ? () => _pass()
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pass() async {
    try {
      await ref.read(peelControllerProvider.notifier).pass(widget.packageId);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.rarity});
  final String rarity;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.forRarity(rarity);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            palette.glow.withOpacity(0.35),
            AppColors.surfaceDark,
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.pkg});
  final PackageModel pkg;

  @override
  Widget build(BuildContext context) {
    final deadline = pkg.holdDeadline ?? DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  pkg.rarity.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forRarity(pkg.rarity).fill,
                  ),
                ),
                Text(
                  'Layer ${pkg.peeledLayers + 1} / ${pkg.totalLayers}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          CountdownTimer(
            total: const Duration(seconds: 38),
            deadline: deadline,
            size: 64,
          ),
        ],
      ),
    );
  }
}

class _SpritePedestal extends StatelessWidget {
  const _SpritePedestal({required this.rarity, required this.phase});
  final String rarity;
  final PeelPhase phase;

  @override
  Widget build(BuildContext context) {
    final double rot = switch (phase) {
      PeelPhase.tug => -0.04,
      PeelPhase.tear => 0.02,
      _ => 0,
    };
    final double scale = switch (phase) {
      PeelPhase.tug => 1.04,
      PeelPhase.tear => 1.12,
      PeelPhase.opened => 1.25,
      _ => 1.0,
    };
    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: Curves.easeOutBack,
      transform: Matrix4.identity()
        ..rotateZ(rot)
        ..scale(scale, scale),
      child: PackageSprite(rarity: rarity, size: 240, animate: phase == PeelPhase.idle),
    ).animate(target: phase == PeelPhase.tear ? 1 : 0).shake(
          hz: 14,
          duration: AppDurations.fast,
          offset: const Offset(3, 0),
        );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({super.key, required this.layer});
  final PeeledLayerModel layer;

  @override
  Widget build(BuildContext context) {
    final label = switch (layer.layerType) {
      'hint' => 'Hint',
      'mini_reward' => 'Mini Reward',
      'powerup' => 'Power-up',
      'trap' => 'Trap!',
      'final' => 'Prize',
      _ => 'Layer',
    };
    final body = switch (layer.layerType) {
      'hint' => layer.payload['text']?.toString() ?? '...',
      'mini_reward' =>
        '+${layer.payload['amount']} ${layer.payload['kind']}',
      'powerup' => '${layer.payload['kind']} (${layer.payload['duration_s']}s)',
      'trap' => '${layer.payload['kind']}',
      'final' => (layer.payload['prize'] as Map?)?['label']?.toString() ?? 'Prize',
      _ => '',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              letterSpacing: 2,
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    ).animate().slideY(begin: 0.3, end: 0, duration: AppDurations.medium).fadeIn();
  }
}

enum PeelPhase { idle, tug, tear, reveal, settle, opened }

// silencing unused import warning
final _unused = math.pi;
