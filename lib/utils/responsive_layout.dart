import 'package:flutter/material.dart';

import 'platform_adapter.dart';

enum AppLayoutClass { compact, medium, desktop, wideDesktop }

class ResponsiveLayout {
  static const double compactMaxWidth = 839;
  static const double desktopMinWidth = 1100;
  static const double wideDesktopMinWidth = 1600;

  static AppLayoutClass classOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktopPlatform = PlatformAdapter.isDesktop();

    if (!isDesktopPlatform || width <= compactMaxWidth) {
      return AppLayoutClass.compact;
    }
    if (width < desktopMinWidth) {
      return AppLayoutClass.medium;
    }
    if (width >= wideDesktopMinWidth) {
      return AppLayoutClass.wideDesktop;
    }
    return AppLayoutClass.desktop;
  }

  static bool isDesktopWidth(BuildContext context) {
    final layoutClass = classOf(context);
    return layoutClass == AppLayoutClass.desktop ||
        layoutClass == AppLayoutClass.wideDesktop;
  }

  static bool isCompact(BuildContext context) {
    return classOf(context) == AppLayoutClass.compact;
  }

  static double pageMaxWidth(BuildContext context) {
    return switch (classOf(context)) {
      AppLayoutClass.compact => double.infinity,
      AppLayoutClass.medium => 920,
      AppLayoutClass.desktop => 1080,
      AppLayoutClass.wideDesktop => 1240,
    };
  }

  static double editorMaxWidth(BuildContext context) {
    return switch (classOf(context)) {
      AppLayoutClass.compact => double.infinity,
      AppLayoutClass.medium => 860,
      AppLayoutClass.desktop => 960,
      AppLayoutClass.wideDesktop => 1040,
    };
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return switch (classOf(context)) {
      AppLayoutClass.compact => const EdgeInsets.all(20),
      AppLayoutClass.medium => const EdgeInsets.fromLTRB(28, 20, 28, 24),
      AppLayoutClass.desktop => const EdgeInsets.fromLTRB(32, 24, 32, 28),
      AppLayoutClass.wideDesktop => const EdgeInsets.fromLTRB(40, 28, 40, 32),
    };
  }

  static EdgeInsets listTilePadding(BuildContext context) {
    return isDesktopWidth(context)
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 9)
        : const EdgeInsets.all(12);
  }

  static double cardRadius(BuildContext context) {
    return isDesktopWidth(context) ? 12 : 16;
  }

  static double navigationRailWidth(BuildContext context) {
    return classOf(context) == AppLayoutClass.wideDesktop ? 88 : 76;
  }
}
