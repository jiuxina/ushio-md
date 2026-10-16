import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../widgets/capsule_tab_bar_scope.dart';

/// 液态玻璃胶囊底栏在页面底部占用的滚动余量。
///
/// 数值来自 [CapsuleTabBarScope] 提供的运行时测量高度；
/// 未启用胶囊底栏时返回 0。
double capsuleTabBarBottomInset(BuildContext context) {
  return CapsuleTabBarScope.maybeOf(context)?.inset ?? 0;
}

/// 系统导航栏（三键横条/手势条）在屏幕底部占用的高度。
///
/// 没有胶囊底栏的二级页直接用它补滚动区底部余量，否则最后一屏控件会被
/// 导航栏压住。用 [MediaQueryData.viewPadding] 而不是 [MediaQueryData.padding]：
/// 后者会被祖先 SafeArea 扣掉，量出来的就不再是系统真实占用。
double systemNavBottomInset(BuildContext context) {
  return MediaQuery.viewPaddingOf(context).bottom;
}

/// 胶囊底栏需要额外抬升的高度。
///
/// GlassTabBar.bottom 自己就在底部留了约 15dp 的余量，手势条那一档刚好够用；
/// 三键导航的横条比这高得多，所以只补差额，避免手势条下凭空多出一截空档。
double capsuleBottomLift(BuildContext context) {
  return math.max(0.0, MediaQuery.viewPaddingOf(context).bottom - 15.0);
}
