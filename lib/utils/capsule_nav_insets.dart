import 'package:flutter/widgets.dart';

import '../widgets/capsule_tab_bar_scope.dart';

/// 液态玻璃胶囊底栏在页面底部占用的滚动余量。
///
/// 数值来自 [CapsuleTabBarScope] 提供的运行时测量高度；
/// 未启用胶囊底栏时返回 0。
double capsuleTabBarBottomInset(BuildContext context) {
  return CapsuleTabBarScope.maybeOf(context)?.inset ?? 0;
}
