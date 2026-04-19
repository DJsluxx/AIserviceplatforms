import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(gameStateProvider);
    final s = sim.state;

    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textOnDark),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
              fontFamily: 'Fraunces', fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        children: [
          const _SectionTitle('Notifications'),
          _Toggle(
            icon: Icons.notifications_active_outlined,
            label: 'Package arrived alerts',
            subtitle:
                'Get a heads-up the moment the package reaches your phone.',
            value: s.notificationsEnabled,
            onChanged: sim.setNotificationsEnabled,
          ),
          const _SectionTitle('Feel'),
          _Toggle(
            icon: Icons.vibration_outlined,
            label: 'Haptics',
            subtitle: 'Short buzz on peel taps and arrivals.',
            value: s.hapticsEnabled,
            onChanged: sim.setHapticsEnabled,
          ),
          _Toggle(
            icon: Icons.volume_up_outlined,
            label: 'Sound effects',
            subtitle: 'Peel pops, layer reveals, open fanfare.',
            value: s.soundEnabled,
            onChanged: sim.setSoundEnabled,
          ),
          const _SectionTitle('About'),
          const _InfoRow(label: 'Version', value: '0.2.0'),
          const _InfoRow(label: 'Build channel', value: 'beta'),
          const _InfoRow(label: 'Player id', value: 'me'),
          const SizedBox(height: AppSpacing.lg),
          const _SectionTitle('Danger zone'),
          _DangerRow(
            label: 'Reset progress',
            subtitle: 'Wipe coins, stats, and the current package.',
            onTap: () => _confirmReset(context, sim.resetProgress),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _confirmReset(
      BuildContext context, VoidCallback onConfirm) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDarkElevated,
        title: const Text(
          'Reset progress?',
          style: TextStyle(color: AppColors.textOnDark),
        ),
        content: const Text(
          'This clears your coins, stats, and starts a fresh package. '
          'This cannot be undone.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.of(ctx).pop();
            },
            child: const Text('Reset',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textOnDark),
      title: Text(
        label,
        style: const TextStyle(
            color: AppColors.textOnDark, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(subtitle,
          style:
              const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      activeColor: AppColors.coral,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label,
          style: const TextStyle(color: AppColors.textOnDark)),
      trailing: Text(value,
          style: const TextStyle(
              color: AppColors.textMuted, fontWeight: FontWeight.w600)),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.warning_amber_rounded,
          color: AppColors.danger),
      title: Text(label,
          style: const TextStyle(
              color: AppColors.danger, fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      onTap: onTap,
    );
  }
}
