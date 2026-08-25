import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'app_style.dart';
import 'responsive_layout.dart';

/// 液态玻璃胶囊底栏在页面底部占用的滚动余量。
///
/// 仅移动端启用胶囊底栏时返回非零值，桌面端返回 0。
double capsuleTabBarBottomInset(BuildContext context) {
  final settings = context.watch<SettingsProvider>();
  if (ResponsiveLayout.isDesktopWidth(context) ||
      settings.tabBarStyle != AppTabBarStyleMode.liquidGlassCapsule) {
    return 0;
  }
  return MediaQuery.paddingOf(context).bottom + 84;
}
