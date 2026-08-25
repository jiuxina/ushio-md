import 'package:flutter/widgets.dart';

/// 向下层页面提供液态玻璃胶囊底栏的实际悬浮高度。
///
/// 高度来自运行时测量，避免在不同分辨率或系统导航栏高度下写死数值。
class CapsuleTabBarScope extends InheritedWidget {
  final double inset;

  const CapsuleTabBarScope({
    super.key,
    required this.inset,
    required super.child,
  });

  static CapsuleTabBarScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CapsuleTabBarScope>();
  }

  @override
  bool updateShouldNotify(CapsuleTabBarScope oldWidget) {
    return oldWidget.inset != inset;
  }
}
