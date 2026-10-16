// ============================================================================
// 系统栏样式单一来源测试
// ============================================================================
//
// 状态栏/导航栏的图标明暗此前由 GlassPage 的 auto 按「系统夜间模式」推断，
// 而 App 主题可以独立于系统设置；再加上二级页 AppBar 背景透明，Material 会
// 按背景亮度自己推断图标色，浅色主题下状态栏图标会变成白色而看不见。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/main.dart';

void main() {
  group('overlayStyleForBrightness', () {
    test('浅色主题用深色图标', () {
      final style = overlayStyleForBrightness(Brightness.light);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    });

    test('深色主题用浅色图标', () {
      final style = overlayStyleForBrightness(Brightness.dark);
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    });

    test('两条系统栏都透明，且不暗化导航栏', () {
      for (final brightness in Brightness.values) {
        final style = overlayStyleForBrightness(brightness);
        expect(style.statusBarColor, Colors.transparent);
        expect(style.systemNavigationBarColor, Colors.transparent);
        expect(style.systemNavigationBarDividerColor, Colors.transparent);
        expect(style.systemNavigationBarContrastEnforced, isFalse);
      }
    });
  });
}
