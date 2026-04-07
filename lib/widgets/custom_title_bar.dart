// ============================================================================
// 自定义标题栏组件
// ============================================================================
//
// 提供无边框窗口的自定义标题栏，包含：
// - 应用图标和名称
// - 当前文件名（可选）
// - 窗口控制按钮（最小化、最大化、关闭）
// - 拖拽移动窗口功能
//
// 设计风格：
// - 匹配应用主题（深色/浅色）
// - 使用应用的 soft-shadow 按钮风格
// - 圆角设计
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/settings_provider.dart';
import '../utils/app_style.dart';
import '../utils/constants.dart';

/// 自定义窗口标题栏
///
/// 特点：
/// - 支持拖拽移动窗口
/// - 双击最大化/还原
/// - 窗口控制按钮（最小化、最大化、关闭）
/// - 自动适配深色/浅色主题
/// - 匹配应用的 soft-shadow 风格
class CustomTitleBar extends StatefulWidget {
  /// 当前文件名（可选，显示在标题栏）
  final String? fileName;

  /// 是否在编辑器模式（编辑器模式下显示文件名）
  final bool isEditorMode;

  const CustomTitleBar({super.key, this.fileName, this.isEditorMode = false});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  bool _isMaximized = false;
  bool _isHoveringClose = false;
  bool _isHoveringMaximize = false;
  bool _isHoveringMinimize = false;

  @override
  void initState() {
    super.initState();
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    final isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = isMaximized);
    }
  }

  Future<void> _minimize() async {
    await windowManager.minimize();
  }

  Future<void> _maximizeOrRestore() async {
    if (_isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _checkMaximized();
  }

  Future<void> _close() async {
    await windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final appStyle = Theme.of(context).extension<AppStyleTheme>();
    final useBorderless = appStyle?.useBorderlessButtons ?? false;

    // 获取主题颜色
    final backgroundColor = isDark
        ? settings.darkThemeIndex < AppConstants.darkThemeSchemes.length
              ? AppConstants.darkThemeSchemes[settings.darkThemeIndex].surface
              : AppConstants.darkSurface
        : settings.lightThemeIndex < AppConstants.lightThemeSchemes.length
        ? AppConstants.lightThemeSchemes[settings.lightThemeIndex].surface
        : AppConstants.lightSurface;

    final textColor = isDark
        ? settings.darkThemeIndex < AppConstants.darkThemeSchemes.length
              ? AppConstants.darkThemeSchemes[settings.darkThemeIndex].text
              : AppConstants.darkText
        : settings.lightThemeIndex < AppConstants.lightThemeSchemes.length
        ? AppConstants.lightThemeSchemes[settings.lightThemeIndex].text
        : AppConstants.lightText;

    final textSecondaryColor = isDark
        ? settings.darkThemeIndex < AppConstants.darkThemeSchemes.length
              ? AppConstants
                    .darkThemeSchemes[settings.darkThemeIndex]
                    .textSecondary
              : AppConstants.darkTextSecondary
        : settings.lightThemeIndex < AppConstants.lightThemeSchemes.length
        ? AppConstants.lightThemeSchemes[settings.lightThemeIndex].textSecondary
        : AppConstants.lightTextSecondary;

    final primaryColor = settings.primaryColor;

    // 标题栏高度
    const titleBarHeight = 32.0;

    return GestureDetector(
      // 拖拽移动窗口
      onPanStart: (_) {
        windowManager.startDragging();
      },
      // 双击最大化/还原
      onDoubleTap: _maximizeOrRestore,
      child: Container(
        height: titleBarHeight,
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: settings.cardOpacity),
          border: Border(
            bottom: BorderSide(
              color: textSecondaryColor.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          boxShadow: useBorderless
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // 左侧：应用图标和名称
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 应用图标
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: Image.asset('app.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 8),
                  // 应用名称
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                      fontFamily: settings.uiFontFamily == 'System'
                          ? null
                          : settings.uiFontFamily,
                    ),
                  ),
                  // 文件名（编辑器模式）
                  if (widget.isEditorMode && widget.fileName != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '-',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondaryColor,
                        fontFamily: settings.uiFontFamily == 'System'
                            ? null
                            : settings.uiFontFamily,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.fileName!,
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondaryColor,
                          fontFamily: settings.uiFontFamily == 'System'
                              ? null
                              : settings.uiFontFamily,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // 右侧：窗口控制按钮
            _buildWindowControls(
              context: context,
              isDark: isDark,
              textColor: textColor,
              textSecondaryColor: textSecondaryColor,
              primaryColor: primaryColor,
              useBorderless: useBorderless,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建窗口控制按钮组
  Widget _buildWindowControls({
    required BuildContext context,
    required bool isDark,
    required Color textColor,
    required Color textSecondaryColor,
    required Color primaryColor,
    required bool useBorderless,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildControlButton(
          icon: Icons.remove_rounded,
          tooltip: '最小化',
          onTap: _minimize,
          isHovering: _isHoveringMinimize,
          onHover: (hovering) => setState(() => _isHoveringMinimize = hovering),
          isDark: isDark,
          textColor: textColor,
          textSecondaryColor: textSecondaryColor,
          primaryColor: primaryColor,
          useBorderless: useBorderless,
        ),
        _buildControlButton(
          icon: _isMaximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          tooltip: _isMaximized ? '还原' : '最大化',
          onTap: _maximizeOrRestore,
          isHovering: _isHoveringMaximize,
          onHover: (hovering) => setState(() => _isHoveringMaximize = hovering),
          isDark: isDark,
          textColor: textColor,
          textSecondaryColor: textSecondaryColor,
          primaryColor: primaryColor,
          useBorderless: useBorderless,
        ),
        _buildControlButton(
          icon: Icons.close_rounded,
          tooltip: '关闭',
          onTap: _close,
          isHovering: _isHoveringClose,
          onHover: (hovering) => setState(() => _isHoveringClose = hovering),
          isDark: isDark,
          textColor: textColor,
          textSecondaryColor: textSecondaryColor,
          primaryColor: primaryColor,
          useBorderless: useBorderless,
          isCloseButton: true,
        ),
      ],
    );
  }

  /// 构建单个窗口控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isHovering,
    required ValueChanged<bool> onHover,
    required bool isDark,
    required Color textColor,
    required Color textSecondaryColor,
    required Color primaryColor,
    required bool useBorderless,
    bool isCloseButton = false,
  }) {
    // 按钮尺寸
    const buttonSize = 46.0;
    const iconSize = 16.0;

    // hover 背景色
    Color hoverBgColor;
    if (isCloseButton) {
      hoverBgColor = isHovering
          ? const Color(0xFFE81123) // Windows 红色关闭按钮
          : Colors.transparent;
    } else {
      hoverBgColor = isHovering
          ? (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05))
          : Colors.transparent;
    }

    // 图标颜色
    Color iconColor;
    if (isCloseButton && isHovering) {
      iconColor = Colors.white;
    } else {
      iconColor = isHovering ? textColor : textSecondaryColor;
    }

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: buttonSize,
            height: 32,
            color: hoverBgColor,
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// 标题栏包装器
///
/// 用于包装带有自定义标题栏的页面
class TitleBarWrapper extends StatelessWidget {
  final Widget child;
  final String? fileName;
  final bool isEditorMode;

  const TitleBarWrapper({
    super.key,
    required this.child,
    this.fileName,
    this.isEditorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 仅在桌面端显示自定义标题栏
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return child;
    }

    return Column(
      children: [
        CustomTitleBar(fileName: fileName, isEditorMode: isEditorMode),
        Expanded(child: child),
      ],
    );
  }
}
