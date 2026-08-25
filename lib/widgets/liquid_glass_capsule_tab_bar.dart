import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../utils/app_style.dart';

/// 液态玻璃胶囊底部导航目的地。
class LiquidGlassCapsuleDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const LiquidGlassCapsuleDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// 移动端液态玻璃胶囊底部导航栏。
///
/// 使用 BackdropFilter 模糊背景，选中项以滑动胶囊高亮块呈现。
class LiquidGlassCapsuleTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<LiquidGlassCapsuleDestination> destinations;

  const LiquidGlassCapsuleTabBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = settings.tabBarOpacity.clamp(0.1, 1.0);
    final tintAlpha = (isDark ? 0.10 : 0.18) * opacity;
    final borderAlpha = (isDark ? 0.16 : 0.30) * opacity;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: tintAlpha),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: borderAlpha),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.28 : 0.14,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: (isDark ? 0.10 : 0.28) * opacity,
                            ),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final slotCount = destinations.length;
                    final slotWidth = constraints.maxWidth / slotCount;
                    final pillWidth = math.min(
                      math.max(slotWidth * 0.72, 48.0),
                      64.0,
                    );
                    const pillHeight = 44.0;
                    final pillLeft =
                        (selectedIndex + 0.5) * slotWidth - pillWidth / 2;
                    return Stack(
                      children: [
                        _SlidingSelectionPill(
                          left: pillLeft,
                          top: (constraints.maxHeight - pillHeight) / 2,
                          width: pillWidth,
                          height: pillHeight,
                        ),
                        Row(
                          children: [
                            for (
                              var i = 0;
                              i < slotCount;
                              i++
                            )
                              Expanded(
                                child: _buildItem(
                                  context,
                                  destinations[i],
                                  selected: selectedIndex == i,
                                  onTap: () => onDestinationSelected(i),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    LiquidGlassCapsuleDestination destination, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: destination.label,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.all(selected ? 13 : 12),
            child: Icon(
              selected ? destination.selectedIcon : destination.icon,
              color: selected ? primary : context.appMutedIconColor,
              size: selected ? 26 : 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// 由显式动画控制器驱动的滑动选中胶囊。
///
/// 选中项变化时从当前位置连续滑向新位置，避免隐式动画退化为消失/重现。
class _SlidingSelectionPill extends StatefulWidget {
  final double left;
  final double top;
  final double width;
  final double height;

  const _SlidingSelectionPill({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  @override
  State<_SlidingSelectionPill> createState() => _SlidingSelectionPillState();
}

class _SlidingSelectionPillState extends State<_SlidingSelectionPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _from = 0;
  double _to = 0;
  double _currentLeft = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _from = widget.left;
    _to = widget.left;
    _currentLeft = widget.left;
  }

  @override
  void didUpdateWidget(_SlidingSelectionPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.left != widget.left) {
      _from = _currentLeft;
      _to = widget.left;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: _buildPill(context),
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        final left = _from + (_to - _from) * progress;
        _currentLeft = left;
        return Positioned(
          left: left,
          top: widget.top,
          width: widget.width,
          height: widget.height,
          child: child!,
        );
      },
    );
  }

  Widget _buildPill(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      key: const ValueKey('capsule_selection_pill'),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isDark ? 0.28 : 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: primary.withValues(alpha: isDark ? 0.45 : 0.34),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.24 : 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
    );
  }
}
