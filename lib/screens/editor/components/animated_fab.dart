/// Animated floating action button for the editor.
library;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../utils/app_style.dart';
import '../../../utils/theme_tones.dart';
import '../../../widgets/outer_shadow.dart';

/// A floating action button with a scale-down press animation and a color
/// glow shadow that intensifies when pressed.
class AnimatedFab extends StatefulWidget {
  /// The icon to display.
  final IconData icon;

  /// The background color.
  final Color color;

  /// Callback when tapped.
  final VoidCallback onTap;

  /// Optional tooltip.
  final String? tooltip;

  /// Transparent padding that enlarges the tap target beyond the button's
  /// visual size without changing how the button looks. Null keeps the default
  /// (hit area == visual bounds).
  final EdgeInsetsGeometry? hitPadding;

  const AnimatedFab({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
    this.hitPadding,
  });

  @override
  State<AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<AnimatedFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final isGlass = appStyle.useLiquidGlass;

    final core = isGlass
        ? GlassContainer(
            padding: const EdgeInsets.all(14),
            shape: const LiquidRoundedSuperellipse(borderRadius: 16),
            child: Icon(widget.icon, color: context.appIconColor, size: 24),
          )
        : OuterShadow(
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.28 : 0.20),
                blurRadius: _pressed ? 20 : 14,
                offset: _pressed ? const Offset(0, 3) : const Offset(0, 6),
                spreadRadius: _pressed ? -6 : -10,
              ),
            ],
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _pressed
                    ? widget.color.withValues(alpha: 0.85)
                    : widget.color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                widget.icon,
                // 底色由主题派生，前景按对比度就近取白或墨色
                color: ThemeTones.readableOn(widget.color),
                size: 24,
              ),
            ),
          );

    final child = GestureDetector(
      behavior: widget.hitPadding != null
          ? HitTestBehavior.opaque
          : HitTestBehavior.deferToChild,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Padding(
        padding: widget.hitPadding ?? EdgeInsets.zero,
        child: AnimatedScale(
          scale: _pressed ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: core,
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip, child: child);
    }
    return child;
  }
}
