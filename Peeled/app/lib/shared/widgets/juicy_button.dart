import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Duolingo-style juicy button.
///
/// The rest state shows a top face offset 4px above a darker side strip — when
/// pressed, the top face slides down, the strip collapses, and the overall
/// button looks physically "pressed."
///
/// - [label]        main text
/// - [primary]      fill color of the top face
/// - [shadow]       deeper tint for the 4px side strip (auto-derived if null)
/// - [icon]         optional leading icon
/// - [wide]         fills width
/// - [onPressed]    callback; null disables
class JuicyButton extends StatefulWidget {
  const JuicyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = AppColors.coral,
    this.shadow,
    this.icon,
    this.wide = true,
    this.size = JuicyButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color primary;
  final Color? shadow;
  final IconData? icon;
  final bool wide;
  final JuicyButtonSize size;

  @override
  State<JuicyButton> createState() => _JuicyButtonState();
}

enum JuicyButtonSize { small, medium, large }

class _JuicyButtonState extends State<JuicyButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  double get _stripHeight => switch (widget.size) {
        JuicyButtonSize.small => 3,
        JuicyButtonSize.medium => 4,
        JuicyButtonSize.large => 6,
      };

  EdgeInsets get _padding => switch (widget.size) {
        JuicyButtonSize.small => const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        JuicyButtonSize.medium => const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        JuicyButtonSize.large => const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      };

  TextStyle get _textStyle => switch (widget.size) {
        JuicyButtonSize.small => const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        JuicyButtonSize.medium => const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.6),
        JuicyButtonSize.large => const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.7),
      };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final primary = enabled ? widget.primary : widget.primary.withOpacity(0.45);
    final shadow = (widget.shadow ?? Color.lerp(widget.primary, Colors.black, 0.35)!)
        .withOpacity(enabled ? 1.0 : 0.4);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                HapticFeedback.mediumImpact();
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedPadding(
          duration: AppDurations.quick,
          curve: Curves.easeOut,
          padding: EdgeInsets.only(top: _pressed ? _stripHeight : 0),
          child: Stack(
            children: [
              // Side strip (always full height; top face slides down to cover it on press)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: shadow,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
              // Top face
              AnimatedContainer(
                duration: AppDurations.quick,
                curve: Curves.easeOut,
                margin: EdgeInsets.only(bottom: _pressed ? 0 : _stripHeight),
                padding: _padding,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      primary.withOpacity(0.96),
                      primary,
                    ],
                  ),
                ),
                child: SizedBox(
                  width: widget.wide ? double.infinity : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: _textStyle.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
