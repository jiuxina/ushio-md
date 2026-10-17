import 'package:flutter/material.dart';

import '../utils/app_style.dart';

/// 分段开关中的单个选项。
class SlidingSegmentItem {
  final IconData icon;

  /// 图标化的按钮没有可见文字，读屏靠它念出含义。
  final String? semanticLabel;

  const SlidingSegmentItem({
    required this.icon,
    this.semanticLabel,
  });
}

/// 支持按住滑块拖动切换的分段开关。
///
/// 选中项背后有滑动胶囊，按下缩放、拖动跟手，松手吸附到最近的选项。
class SlidingSegmentToggle extends StatefulWidget {
  final List<SlidingSegmentItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;
  final double? width;
  final double borderRadius;

  const SlidingSegmentToggle({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 36,
    this.width,
    this.borderRadius = 12,
  }) : assert(items.length >= 2);

  @override
  State<SlidingSegmentToggle> createState() => _SlidingSegmentToggleState();
}

class _SlidingSegmentToggleState extends State<SlidingSegmentToggle> {
  bool _dragging = false;
  double _dragLeft = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? 160,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotCount = widget.items.length;
          final slotWidth = constraints.maxWidth / slotCount;
          final pillWidth = slotWidth;
          const pillHeightInset = 8.0;
          final pillHeight = widget.height - pillHeightInset;
          final maxLeft = slotWidth * slotCount - pillWidth;
          final targetLeft =
              (widget.selectedIndex + 0.5) * slotWidth - pillWidth / 2;
          final left = _dragging ? _dragLeft : targetLeft;
          final animationDuration = _dragging
              ? Duration.zero
              : const Duration(milliseconds: 260);

          return Stack(
            children: [
              AnimatedPositioned(
                duration: animationDuration,
                curve: Curves.easeOutCubic,
                left: left,
                top: pillHeightInset / 2,
                width: pillWidth,
                height: pillHeight,
                child: AnimatedScale(
                  scale: _dragging ? 0.9 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: _buildPill(context),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < slotCount; i++)
                    Expanded(
                      child: _buildItem(
                        context,
                        widget.items[i],
                        selected: widget.selectedIndex == i,
                        onTap: () => widget.onChanged(i),
                      ),
                    ),
                ],
              ),
              AnimatedPositioned(
                duration: animationDuration,
                curve: Curves.easeOutCubic,
                left: left,
                top: pillHeightInset / 2,
                width: pillWidth,
                height: pillHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) {
                    _dragLeft = targetLeft;
                    setState(() => _dragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragLeft = (_dragLeft + (details.primaryDelta ?? 0))
                          .clamp(0.0, maxLeft)
                          .toDouble();
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    final center = _dragLeft + pillWidth / 2;
                    final index = (center / slotWidth)
                        .floor()
                        .clamp(0, slotCount - 1);
                    setState(() => _dragging = false);
                    widget.onChanged(index);
                  },
                  onHorizontalDragCancel: () {
                    setState(() => _dragging = false);
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    SlidingSegmentItem item, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Semantics(
          label: item.semanticLabel,
          button: true,
          selected: selected,
          child: Icon(
            item.icon,
            size: 18,
            color: selected ? Colors.white : context.appIconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildPill(BuildContext context) {
    return Container(
      key: const ValueKey('sliding_segment_pill'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.18
                  : 0.10,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -3,
          ),
        ],
      ),
    );
  }
}
