import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// 可拖动的 AI 悬浮按钮
///
/// 带有呼吸发光动画效果，可拖拽到屏幕任意边缘位置。
class AiFloatingButton extends StatefulWidget {
  final VoidCallback onTap;

  const AiFloatingButton({super.key, required this.onTap});

  @override
  State<AiFloatingButton> createState() => _AiFloatingButtonState();
}

class _AiFloatingButtonState extends State<AiFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathController;
  late final Animation<double> _breathAnimation;

  // Position state – defaults to bottom-right
  double? _left;
  double? _top;
  bool _positioned = false;

  static const double _size = 56;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.1, end: 0.4).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  void _initPosition(BoxConstraints constraints) {
    if (!_positioned) {
      _left = constraints.maxWidth - _size - 16;
      _top = constraints.maxHeight - _size - 100;
      _positioned = true;
    }
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    setState(() {
      _left = (_left! + details.delta.dx)
          .clamp(0, constraints.maxWidth - _size);
      _top = (_top! + details.delta.dy)
          .clamp(0, constraints.maxHeight - _size);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _initPosition(constraints);

        return Stack(
          children: [
            Positioned(
              left: _left,
              top: _top,
              child: GestureDetector(
                onTap: widget.onTap,
                onPanUpdate: (d) => _onPanUpdate(d, constraints),
                child: AnimatedBuilder(
                  animation: _breathAnimation,
                  builder: (context, child) {
                    return Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            AppConstants.primaryColor,
                            AppConstants.accentColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primaryColor
                                .withValues(alpha: _breathAnimation.value),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 26,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
