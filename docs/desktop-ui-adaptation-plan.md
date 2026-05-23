# 桌面端 UI 适配实施计划

> 目标读者：执行能力较弱的实现 agent。  
> 执行要求：严格按本文顺序改文件，不要顺手重构无关代码，不要改变移动端现有交互。  
> 当前日期：2026-05-16。  
> 当前项目：Flutter Markdown 编辑器，已有 Windows/macOS/Linux 桌面入口，但主界面仍以移动端底部导航、纵向列表和底部工具栏为主。

---

## 0. 目标和非目标

### 目标

1. 桌面端从“手机界面放大版”改成真正的桌面工作台：
   - 左侧固定导航栏。
   - 中间内容区有最大宽度、合理留白和列表密度。
   - 编辑器在宽屏下使用阅读/写作专用版心，而不是全屏铺满。
   - 文件管理和历史记录在桌面端更紧凑，减少滚动。
2. 保持移动端现状：
   - 手机和平板窄屏仍使用底部导航。
   - 原有 `PageView` 滑动切页保留给移动端。
3. 桌面端操作更符合鼠标键盘：
   - 文件/设置列表减小垂直 padding。
   - 常用操作在桌面端一行展示。
   - 编辑器浮动按钮和工具栏不遮挡正文。
4. 所有适配集中在少数 UI 文件，后续容易继续演进。

### 非目标

1. 不改文件服务、云同步、版本历史、导出、Milkdown bridge 的业务逻辑。
2. 不新增第三方依赖。
3. 不重新设计主题系统，只复用现有 `AppStyleTheme`、`AppConstants`、`SettingsProvider`。
4. 不删除现有移动端底部导航和移动端浮动按钮。

---

## 1. 当前问题清单

这些问题来自当前代码结构，请实现 agent 不要再做重复调研。

1. `lib/screens/main_screen.dart`
   - 桌面端只加了 `CustomTitleBar`，仍使用 `bottomNavigationBar`。
   - `_buildBody` 总是返回 `PageView`。
   - `_buildDrawer` 桌面端仍存在，但实际不适合桌面主导航。

2. `lib/screens/main/tabs/home_tab.dart`
   - `ListView(padding: EdgeInsets.all(20))` 在宽屏下横向拉满。
   - `QuickActions` 桌面端没有使用四列/横向工作台布局。

3. `lib/screens/main/components/quick_actions.dart`
   - 无置顶时使用 2x2 卡片，桌面端显得过大。
   - 有置顶时使用一行图标，但没有宽屏尺寸控制。

4. `lib/screens/folder_browser_screen.dart`
   - 文件列表宽屏下铺满，行宽过长。
   - 搜索时和普通状态都是移动端列表。

5. `lib/screens/folder/components/file_tile.dart`
   - 所有平台统一 `margin: bottom 8`、`padding: all 12`、`borderRadius: 16`。
   - 桌面端列表密度偏低。

6. `lib/screens/main/tabs/history_tab.dart`
   - 宽屏下列表铺满。
   - 头部标题过大，按钮区域没有桌面宽度约束。

7. `lib/screens/main/tabs/settings_tab.dart`
   - 设置入口仍是手机列表。
   - 桌面端应该限制宽度并使用更紧凑行高。

8. `lib/screens/editor_screen.dart`
   - 编辑器正文宽屏铺满，长行阅读体验差。
   - 浮动按钮固定 `right: 24`，宽屏时离正文太远。
   - Markdown 工具栏底部全宽铺满。
   - `_buildBody` 里直接写死渐变背景，没有统一内容版心。

9. `lib/widgets/markdown_toolbar.dart`
   - 桌面端仍是横向滚动底栏。
   - 按钮尺寸是按 `shortestSide < 600` 判断触摸设备，没有复用统一断点。

---

## 2. 总体方案

新增一个轻量响应式工具文件，然后按页面逐步接入：

1. 新增 `lib/utils/responsive_layout.dart`
   - 统一判断 desktop/tablet/compact。
   - 提供内容最大宽度、页面 padding、列表密度、编辑器版心宽度。

2. 新增 `lib/widgets/responsive_page_frame.dart`
   - 桌面端把页面内容限制在固定最大宽度。
   - 移动端保持原样。

3. 新增 `lib/widgets/desktop_navigation_shell.dart`
   - 桌面端主界面使用左侧 `NavigationRail`。
   - 右侧内容不使用 `PageView`，直接展示当前 tab。

4. 修改主界面：
   - `MainScreen` 根据 `ResponsiveLayout.isDesktopWidth(context)` 分流。
   - 桌面端：标题栏 + 横向壳层 + 左侧导航。
   - 移动端：保留现有 `PageView` + `bottomNavigationBar`。

5. 修改各 Tab 和列表组件：
   - 桌面端包一层 `ResponsivePageFrame`。
   - 文件列表行距变紧凑。
   - QuickActions 桌面端改成一行四个操作。

6. 修改编辑器：
   - 桌面端正文版心限制在 920-1080。
   - 底部工具栏限制到正文宽度。
   - 浮动按钮跟随正文右边缘。
   - 专注模式仍可全屏，但正文版心保持。

---

## 3. 断点和尺寸规范

必须使用同一套断点，禁止在各文件里随意写 `width > 900`。

| 场景 | 条件 | 行为 |
| --- | --- | --- |
| compact | width < 840 | 移动端布局，底部导航，PageView |
| medium | 840 <= width < 1100 | 可视为窄桌面/平板横屏，仍保守使用移动布局或窄 Rail |
| desktop | width >= 1100 且运行在桌面平台 | 左侧导航，内容限宽 |
| wideDesktop | width >= 1600 且运行在桌面平台 | 更大留白，编辑器版心不再继续放大 |

注意：桌面平台判断使用已有 `PlatformAdapter.isDesktop()`。

---

## 3.1 审查后加固要求

以下要求是本计划的硬约束，执行 agent 不得省略：

1. 桌面端不仅要“看起来像桌面”，还要支持键鼠：
   - 主界面支持 `Ctrl+1` 到 `Ctrl+4`，macOS 使用 `Cmd+1` 到 `Cmd+4`，用于切换首页、我的文件、历史、设置。
   - 文件和文件夹条目在桌面端必须显示点击光标。
   - 文件和文件夹条目必须支持鼠标右键打开同一套上下文操作。
   - 编辑器搜索必须支持 `Esc` 关闭、`F3` 下一个结果、`Shift+F3` 上一个结果。
2. 桌面端列表不能因为 `ResponsivePageFrame` 嵌套 `ListView` 而丢失滚动能力。优先使用“外层滚动 + 内层 `Column`”的稳定写法。
3. 桌面端主导航不要调用 `_switchTab`，因为 `_switchTab` 会驱动移动端 `PageController`。
4. 从桌面宽度缩小到移动宽度时，`PageController` 必须同步到当前 tab，否则底部导航选中态和页面内容会错位。
5. 所有新增快捷键必须只在对应页面生效，不要做全局注册。

---

## 4. 第一步：新增响应式工具

### 文件：`lib/utils/responsive_layout.dart`

新建文件，完整内容如下：

```dart
import 'package:flutter/material.dart';

import 'platform_adapter.dart';

enum AppLayoutClass {
  compact,
  medium,
  desktop,
  wideDesktop,
}

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
```

验收：

```powershell
dart format lib/utils/responsive_layout.dart
```

---

## 5. 第二步：新增桌面内容框架

### 文件：`lib/widgets/responsive_page_frame.dart`

新建文件，完整内容如下：

```dart
import 'package:flutter/material.dart';

import '../utils/responsive_layout.dart';

class ResponsivePageFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;
  final Alignment alignment;

  const ResponsivePageFrame({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? ResponsiveLayout.pagePadding(context);
    final effectiveMaxWidth = maxWidth ?? ResponsiveLayout.pageMaxWidth(context);

    if (!ResponsiveLayout.isDesktopWidth(context)) {
      return Padding(padding: effectivePadding, child: child);
    }

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}
```

验收：

```powershell
dart format lib/widgets/responsive_page_frame.dart
```

---

## 6. 第三步：新增桌面主导航壳层

### 文件：`lib/widgets/desktop_navigation_shell.dart`

新建文件，完整内容如下：

```dart
import 'package:flutter/material.dart';

import '../utils/app_style.dart';
import '../utils/responsive_layout.dart';

class DesktopNavigationDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const DesktopNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class DesktopNavigationShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DesktopNavigationDestination> destinations;
  final Widget child;

  const DesktopNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appStyle = theme.extension<AppStyleTheme>()!;
    final railWidth = ResponsiveLayout.navigationRailWidth(context);

    return Row(
      children: [
        Container(
          width: railWidth,
          decoration: BoxDecoration(
            color: appStyle.scaledSurfaceColor(theme.colorScheme, alpha: 0.82),
            border: Border(
              right: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.35),
              ),
            ),
            boxShadow: appStyle.useBorderlessButtons
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(4, 0),
                      spreadRadius: -12,
                    ),
                  ]
                : null,
          ),
          child: NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            backgroundColor: Colors.transparent,
            minWidth: railWidth,
            groupAlignment: -0.82,
            labelType: NavigationRailLabelType.all,
            useIndicator: true,
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
```

验收：

```powershell
dart format lib/widgets/desktop_navigation_shell.dart
```

---

## 7. 第四步：改造主屏布局

### 文件：`lib/screens/main_screen.dart`

#### 7.1 新增 import

在现有 import 区添加：

```dart
import 'package:flutter/services.dart';

import '../utils/responsive_layout.dart';
import '../widgets/desktop_navigation_shell.dart';
```

#### 7.2 替换 `build` 中的 Scaffold 部分

找到 `return AppBackground(... child: Scaffold(...))` 这一段。将 `Scaffold` 内容改成下面结构。

原逻辑要保留：

- `useCustomTitleBar`
- `CustomTitleBar(isEditorMode: false)`
- `AppBackground`
- `fileProvider.hasPermission`

替换为：

```dart
final isDesktopLayout = ResponsiveLayout.isDesktopWidth(context);

return AppBackground(
  wrapWithSafeArea: false,
  child: Scaffold(
    backgroundColor: Colors.transparent,
    body: Column(
      children: [
        if (useCustomTitleBar) const CustomTitleBar(isEditorMode: false),
        Expanded(
          child: isDesktopLayout
              ? _buildDesktopKeyboardScope(
                  child: _buildDesktopShell(l10n, fileProvider),
                )
              : _buildBody(fileProvider),
        ),
      ],
    ),
    bottomNavigationBar: isDesktopLayout ? null : _buildBottomNav(l10n),
    drawer: isDesktopLayout ? null : _buildDrawer(l10n),
  ),
);
```

#### 7.3 新增 `_buildDesktopShell`

放在 `_buildBottomNav` 前面：

```dart
Widget _buildDesktopKeyboardScope({required Widget child}) {
  final isMac = Platform.isMacOS;

  return Focus(
    autofocus: true,
    child: CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.digit1,
          control: !isMac,
          meta: isMac,
        ): () => _selectDesktopTab(0),
        SingleActivator(
          LogicalKeyboardKey.digit2,
          control: !isMac,
          meta: isMac,
        ): () => _selectDesktopTab(1),
        SingleActivator(
          LogicalKeyboardKey.digit3,
          control: !isMac,
          meta: isMac,
        ): () => _selectDesktopTab(2),
        SingleActivator(
          LogicalKeyboardKey.digit4,
          control: !isMac,
          meta: isMac,
        ): () => _selectDesktopTab(3),
      },
      child: child,
    ),
  );
}

void _selectDesktopTab(int index) {
  if (index == _currentIndex) return;
  setState(() => _currentIndex = index);
}
```

然后新增：

```dart
Widget _buildDesktopShell(AppLocalizations l10n, FileProvider fileProvider) {
  return DesktopNavigationShell(
    selectedIndex: _currentIndex,
    onDestinationSelected: _selectDesktopTab,
    destinations: [
      DesktopNavigationDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: l10n.homeTab,
      ),
      DesktopNavigationDestination(
        icon: Icons.folder_special_outlined,
        selectedIcon: Icons.folder_special_rounded,
        label: l10n.myFiles,
      ),
      DesktopNavigationDestination(
        icon: Icons.history_outlined,
        selectedIcon: Icons.history_rounded,
        label: l10n.historyTab,
      ),
      DesktopNavigationDestination(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: l10n.settings,
      ),
    ],
    child: IndexedStack(
      index: _currentIndex,
      children: [
        HomeTab(fileProvider: fileProvider),
        MyFilesTab(fileProvider: fileProvider),
        HistoryTab(fileProvider: fileProvider),
        const SettingsTab(),
      ],
    ),
  );
}
```

#### 7.4 保持 `_buildBody` 不变

不要删除移动端 `PageView`，桌面端不走它即可。但必须在 `_buildBody` 的 `return PageView(...)` 前同步移动端控制器，避免用户在桌面端切到某个 tab 后缩小窗口，底部导航选中态和页面内容错位。

在 `_buildBody(FileProvider fileProvider)` 的 `return PageView(` 前添加：

```dart
if (_pageController.hasClients) {
  final currentPage = _pageController.page?.round();
  if (currentPage != _currentIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }
}
```

验收：

```powershell
dart format lib/screens/main_screen.dart
flutter analyze
```

---

## 8. 第五步：改造首页

### 文件：`lib/screens/main/tabs/home_tab.dart`

#### 8.1 新增 import

```dart
import '../../../utils/responsive_layout.dart';
import '../../../widgets/responsive_page_frame.dart';
```

#### 8.2 替换 `build`

将当前 `SafeArea -> Column -> Expanded -> RefreshIndicator -> ListView` 替换为：

```dart
@override
Widget build(BuildContext context) {
  final isDesktop = ResponsiveLayout.isDesktopWidth(context);

  return SafeArea(
    bottom: false,
    child: Column(
      children: [
        _buildHomeHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => widget.fileProvider.refresh(),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ResponsivePageFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      QuickActions(
                        fileProvider: widget.fileProvider,
                        onRefresh: () => widget.fileProvider.refresh(),
                      ),
                      if (widget.fileProvider.pinnedFiles.isNotEmpty) ...[
                        SizedBox(height: isDesktop ? 20 : 24),
                        _buildSectionHeader('置顶文件', Icons.push_pin),
                        const SizedBox(height: 12),
                        _buildPinnedFilesList(),
                      ],
                      if (widget.fileProvider.pinnedFolders.isNotEmpty) ...[
                        SizedBox(height: isDesktop ? 20 : 24),
                        _buildSectionHeader('置顶文件夹', Icons.folder_special),
                        const SizedBox(height: 12),
                        _buildPinnedFoldersList(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

#### 8.3 调整 `_buildHomeHeader`

在 `_buildHomeHeader` 的 `return Container(...)` 外层添加桌面限宽。把原来的：

```dart
return Container(
  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
  child: Row(
```

替换为：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);

return ResponsivePageFrame(
  padding: EdgeInsets.fromLTRB(
    isDesktop ? 32 : 20,
    isDesktop ? 20 : 16,
    isDesktop ? 32 : 20,
    8,
  ),
  child: Row(
```

同时把该方法结尾多余的 `);` 对齐为 `);`，确保 `ResponsivePageFrame` 包住整个 `Row`。

验收：

```powershell
dart format lib/screens/main/tabs/home_tab.dart
flutter analyze
```

---

## 9. 第六步：改造 QuickActions

### 文件：`lib/screens/main/components/quick_actions.dart`

#### 9.1 新增 import

```dart
import '../../../utils/responsive_layout.dart';
```

#### 9.2 修改 `build`

在 `build` 里 `final appStyle = ...` 后添加：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);
```

然后在 `hasPinnedItems` 判断前添加：

```dart
if (isDesktop) {
  return _buildDesktopQuickActions(context, compact: hasPinnedItems);
}
```

最终顺序应是：

```dart
if (isDesktop) {
  return _buildDesktopQuickActions(context, compact: hasPinnedItems);
}

if (hasPinnedItems) {
  return _buildCompactQuickActions(context);
}
```

#### 9.3 新增 `_buildDesktopQuickActions`

放在 `_buildCompactQuickActions` 前面：

```dart
Widget _buildDesktopQuickActions(BuildContext context, {required bool compact}) {
  final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
  final actions = [
    (
      icon: Icons.add_circle,
      label: '新建文件',
      color: Colors.green,
      onTap: () => FileActions.showCreateFileDialog(
            context,
            fileProvider,
            onRefresh: onRefresh,
          ),
    ),
    (
      icon: Icons.create_new_folder,
      label: '新建文件夹',
      color: Colors.orange,
      onTap: () => FileActions.showCreateFolderDialog(context, fileProvider),
    ),
    (
      icon: Icons.file_open,
      label: '打开文件',
      color: Colors.blue,
      onTap: () async {
        final path = await fileProvider.pickAndOpenFile();
        if (path != null && context.mounted) {
          FileImportHelper.openFile(
            context,
            path,
            onFileOpened: () => fileProvider.addToRecentFiles(path),
          );
        }
      },
    ),
    (
      icon: Icons.folder_open,
      label: '打开文件夹',
      color: Colors.amber,
      onTap: () async {
        final path = await fileProvider.pickDirectory();
        if (path != null) {
          await fileProvider.addToRecentFolders(path);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FolderBrowserScreen(folderPath: path),
              ),
            );
          }
        }
      },
    ),
  ];

  return Container(
    padding: EdgeInsets.all(compact ? 14 : 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: appStyle.surfaceShadow,
      color: appStyle.scaledSurfaceColor(
        Theme.of(context).colorScheme,
        alpha: 0.68,
      ),
      border: appStyle.useBorderlessButtons
          ? null
          : Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.18),
            ),
    ),
    child: Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(
            child: _buildDesktopActionButton(
              context,
              icon: actions[i].icon,
              label: actions[i].label,
              color: actions[i].color,
              onTap: actions[i].onTap,
            ),
          ),
          if (i != actions.length - 1) const SizedBox(width: 12),
        ],
      ],
    ),
  );
}
```

#### 9.4 新增 `_buildDesktopActionButton`

放在 `_buildDesktopQuickActions` 后面：

```dart
Widget _buildDesktopActionButton(
  BuildContext context, {
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  final appStyle = Theme.of(context).extension<AppStyleTheme>()!;

  return Tooltip(
    message: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: appStyle.surfaceDecoration(
            borderRadius: BorderRadius.circular(12),
            color: appStyle.scaledSurfaceColor(
              Theme.of(context).colorScheme,
              alpha: 0.72,
            ),
            border: appStyle.useBorderlessButtons
                ? null
                : Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

验收：

```powershell
dart format lib/screens/main/components/quick_actions.dart
flutter analyze
```

---

## 10. 第七步：改造文件列表密度

### 文件：`lib/screens/folder/components/file_tile.dart`

#### 10.1 新增 import

```dart
import '../../../utils/responsive_layout.dart';
```

#### 10.2 在 `build` 中添加桌面变量

在 `final appStyle = ...` 后添加：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);
final tileRadius = ResponsiveLayout.cardRadius(context);
```

#### 10.3 替换外层 Container 样式

把：

```dart
margin: const EdgeInsets.only(bottom: 8),
...
borderRadius: BorderRadius.circular(16),
```

替换为：

```dart
margin: EdgeInsets.only(bottom: isDesktop ? 6 : 8),
...
borderRadius: BorderRadius.circular(tileRadius),
```

同一方法里所有 `BorderRadius.circular(16)` 如果是该 tile 的点击/外层圆角，也替换成 `BorderRadius.circular(tileRadius)`。

#### 10.4 替换 item padding

把：

```dart
padding: const EdgeInsets.all(12),
```

替换为：

```dart
padding: ResponsiveLayout.listTilePadding(context),
```

#### 10.5 调整图标尺寸

把 `_buildIcon` 里的：

```dart
padding: const EdgeInsets.all(10),
...
borderRadius: BorderRadius.circular(10),
...
size: 20,
```

改成：

```dart
padding: EdgeInsets.all(ResponsiveLayout.isDesktopWidth(context) ? 8 : 10),
...
borderRadius: BorderRadius.circular(10),
...
size: ResponsiveLayout.isDesktopWidth(context) ? 18 : 20,
```

#### 10.6 添加鼠标光标和右键入口

在 `build` 方法中，找到 `Material -> InkWell` 这一段。必须做两件事：

1. 用 `MouseRegion` 包住 `InkWell`，桌面端显示点击光标。
2. 给 `InkWell` 添加 `onSecondaryTapDown`，桌面端右键打开与长按相同的上下文操作。

先在 `build` 方法里、`return Container(...)` 前添加局部函数：

```dart
void showEntityActions() {
  final fileProvider = context.read<FileProvider>();
  if (isFile) {
    FileActions.showFileContextMenu(
      context,
      entity.path,
      fileProvider,
      onRefresh: onRefresh,
      source: source,
    );
  } else {
    FileActions.showFolderContextMenu(
      context,
      entity.path,
      fileProvider,
      source: source,
      onRefresh: onRefresh,
    );
  }
}
```

然后把现有 `Material(child: InkWell(...))` 改成：

```dart
child: Material(
  color: Colors.transparent,
  child: MouseRegion(
    cursor: SystemMouseCursors.click,
    child: InkWell(
      borderRadius: BorderRadius.circular(tileRadius),
      onTap: () async {
        // 保留当前 onTap 里的原有逻辑，不要改业务行为。
      },
      onLongPress: showEntityActions,
      onSecondaryTapDown: ResponsiveLayout.isDesktopWidth(context)
          ? (_) => showEntityActions()
          : null,
      child: Padding(
        padding: ResponsiveLayout.listTilePadding(context),
        child: Row(
          // 保留当前 Row 里的原有内容。
        ),
      ),
    ),
  ),
),
```

注意：

- `onTap` 里的打开文件、打开图片、进入文件夹逻辑必须原样保留。
- 删除旧的 `onLongPress` 内重复代码，统一调用 `showEntityActions`。
- 需要使用 `SystemMouseCursors.click`，`material.dart` 已经导出它，不需要额外 import。

验收：

```powershell
dart format lib/screens/folder/components/file_tile.dart
flutter analyze
```

---

## 11. 第八步：改造文件浏览页面

### 文件：`lib/screens/folder_browser_screen.dart`

#### 11.1 新增 import

```dart
import '../utils/responsive_layout.dart';
import '../widgets/responsive_page_frame.dart';
```

#### 11.2 调整 `_buildContent`

不要直接把 `ResponsivePageFrame` 塞进现有 `ListView.builder` 外层，容易造成嵌套滚动错误。使用下面的稳定写法。

#### 11.3 新增辅助方法

在 `_buildContent` 前添加：

```dart
Widget _wrapFileList(Widget child) {
  if (!ResponsiveLayout.isDesktopWidth(context)) {
    return child;
  }

  return SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: ResponsivePageFrame(child: child),
  );
}
```

#### 11.4 替换搜索列表返回值

把搜索状态下的 `return RefreshIndicator(... ListView.builder ...)` 整段替换为：

```dart
return RefreshIndicator(
  onRefresh: _loadFiles,
  child: _wrapFileList(
    Column(
      children: [
        for (final entity in filtered)
          FileTile(
            entity: entity,
            onRefresh: _loadFiles,
            isDraggable: false,
            source: FileSource.myFiles,
          ),
      ],
    ),
  ),
);
```

#### 11.5 替换普通列表返回值

普通列表仍要保留拖拽排序，所以继续使用 `ReorderableListView.builder`。把普通状态下的 `return RefreshIndicator(... ReorderableListView.builder ...)` 改成：

```dart
return RefreshIndicator(
  onRefresh: _loadFiles,
  child: _wrapFileList(
    ReorderableListView.builder(
      shrinkWrap: ResponsiveLayout.isDesktopWidth(context),
      physics: ResponsiveLayout.isDesktopWidth(context)
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveLayout.isDesktopWidth(context)
          ? EdgeInsets.zero
          : const EdgeInsets.all(20),
      itemCount: filtered.length,
      buildDefaultDragHandles: false,
      onReorder: _handleReorder,
      proxyDecorator: ...,
      itemBuilder: ...,
    ),
  ),
);
```

注意：

- `proxyDecorator` 和 `itemBuilder` 内现有代码必须原样保留。
- 桌面端靠 `_wrapFileList` 的 `SingleChildScrollView` 滚动。
- 移动端仍由 `ReorderableListView` 自己滚动。

验收：

```powershell
dart format lib/screens/folder_browser_screen.dart
flutter analyze
```

---

## 12. 第九步：改造历史记录页

### 文件：`lib/screens/main/tabs/history_tab.dart`

#### 12.1 新增 import

```dart
import '../../../utils/responsive_layout.dart';
import '../../../widgets/responsive_page_frame.dart';
```

#### 12.2 替换 `_buildHeader` 的外层 `Padding`

把：

```dart
return Padding(
  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
  child: Row(
```

替换为：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);

return ResponsivePageFrame(
  padding: EdgeInsets.fromLTRB(
    isDesktop ? 32 : 20,
    isDesktop ? 22 : 16,
    isDesktop ? 32 : 20,
    isDesktop ? 12 : 20,
  ),
  child: Row(
```

#### 12.3 替换两个列表

在 `_buildFilesView` 中，把：

```dart
return ListView.builder(
  padding: const EdgeInsets.all(20),
```

替换为：

```dart
return ListView(
  padding: EdgeInsets.zero,
  children: [
    ResponsivePageFrame(
      child: Column(
        children: [
          for (final path in processedFiles)
            FileTile(
              key: ValueKey(path),
              entity: File(path),
              source: FileSource.history,
            ),
        ],
      ),
    ),
  ],
);
```

在 `_buildFoldersView` 中同理：

```dart
return ListView(
  padding: EdgeInsets.zero,
  children: [
    ResponsivePageFrame(
      child: Column(
        children: [
          for (final path in processedFolders)
            FileTile(
              key: ValueKey(path),
              entity: Directory(path),
              source: FileSource.history,
            ),
        ],
      ),
    ),
  ],
);
```

验收：

```powershell
dart format lib/screens/main/tabs/history_tab.dart
flutter analyze
```

---

## 13. 第十步：改造设置页

### 文件：`lib/screens/main/tabs/settings_tab.dart`

#### 13.1 新增 import

```dart
import '../../../utils/responsive_layout.dart';
import '../../../widgets/responsive_page_frame.dart';
```

#### 13.2 替换 `build` 的 `ListView`

把：

```dart
return SafeArea(
  bottom: false,
  child: ListView(
    padding: const EdgeInsets.all(16),
    children: [
```

替换为：

```dart
return SafeArea(
  bottom: false,
  child: ListView(
    padding: EdgeInsets.zero,
    children: [
      ResponsivePageFrame(
        maxWidth: ResponsiveLayout.isDesktopWidth(context) ? 760 : null,
        padding: ResponsiveLayout.isDesktopWidth(context)
            ? const EdgeInsets.fromLTRB(32, 24, 32, 28)
            : const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
```

然后在原 `children` 列表末尾补齐：

```dart
          ],
        ),
      ),
```

#### 13.3 调整设置项高度

在 `_buildSettingsItem` 内添加：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);
```

把：

```dart
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
```

替换为：

```dart
padding: EdgeInsets.symmetric(
  horizontal: 12,
  vertical: isDesktop ? 9 : 10,
),
```

验收：

```powershell
dart format lib/screens/main/tabs/settings_tab.dart
flutter analyze
```

---

## 14. 第十一步：改造 Markdown 工具栏

### 文件：`lib/widgets/markdown_toolbar.dart`

#### 14.1 新增 import

```dart
import '../utils/responsive_layout.dart';
```

#### 14.2 替换触摸设备判断

当前代码：

```dart
final isTouchDevice = MediaQuery.of(context).size.shortestSide < 600;
final toolbarHeight = isTouchDevice ? 64.0 : 56.0;
```

替换为：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);
final isTouchDevice = !isDesktop && MediaQuery.of(context).size.shortestSide < 600;
final toolbarHeight = isTouchDevice ? 64.0 : 56.0;
```

#### 14.3 调整桌面端 toolbar 外观

把 toolbar `Container` 的 `borderRadius`：

```dart
borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
```

替换为：

```dart
borderRadius: BorderRadius.vertical(
  top: Radius.circular(isDesktop ? 12 : 20),
),
```

#### 14.4 调整按钮尺寸

在 `_ToolbarButtonState.build` 里新增：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);
```

把：

```dart
final isTouchDevice = MediaQuery.of(context).size.shortestSide < 600;
```

替换为：

```dart
final isTouchDevice = !isDesktop && MediaQuery.of(context).size.shortestSide < 600;
```

把按钮宽高：

```dart
width: isTouchDevice ? 44 : 36,
height: isTouchDevice ? 44 : 36,
```

替换为：

```dart
width: isTouchDevice ? 44 : (isDesktop ? 34 : 36),
height: isTouchDevice ? 44 : (isDesktop ? 34 : 36),
```

验收：

```powershell
dart format lib/widgets/markdown_toolbar.dart
flutter analyze
```

---

## 15. 第十二步：改造编辑器桌面版心

### 文件：`lib/screens/editor/editor_shortcuts.dart`

#### 15.1 先补齐搜索键盘交互

当前 `EditorShortcuts.buildBindings` 已经支持 `onEscape`、`onNextSearchMatch`、`onPrevSearchMatch`，但文件底部的简化函数 `buildShortcutBindings` 没有把这三个参数透传出去。必须先改这里。

把底部函数签名从：

```dart
Map<ShortcutActivator, VoidCallback> buildShortcutBindings({
  required VoidCallback onSave,
  required VoidCallback onUndo,
  required VoidCallback onRedo,
  required VoidCallback onSearch,
  required void Function(MarkdownToolbarAction) onApplyAction,
}) {
```

改成：

```dart
Map<ShortcutActivator, VoidCallback> buildShortcutBindings({
  required VoidCallback onSave,
  required VoidCallback onUndo,
  required VoidCallback onRedo,
  required VoidCallback onSearch,
  required void Function(MarkdownToolbarAction) onApplyAction,
  VoidCallback? onEscape,
  VoidCallback? onNextSearchMatch,
  VoidCallback? onPrevSearchMatch,
}) {
```

然后在 `EditorShortcuts.buildBindings(...)` 调用末尾补上：

```dart
    onEscape: onEscape,
    onNextSearchMatch: onNextSearchMatch,
    onPrevSearchMatch: onPrevSearchMatch,
```

最终这三个快捷键必须生效：

- `Esc`：关闭搜索栏。
- `F3`：跳到下一个搜索结果。
- `Shift+F3`：跳到上一个搜索结果。

### 文件：`lib/screens/editor_screen.dart`

#### 15.2 新增 import

```dart
import '../utils/responsive_layout.dart';
```

#### 15.3 修改快捷键绑定

找到 `buildShortcutBindings(...)` 调用，补上：

```dart
onEscape: _closeSearch,
onNextSearchMatch: _jumpToNextSearchMatch,
onPrevSearchMatch: _jumpToPrevSearchMatch,
```

修改后结构应类似：

```dart
bindings: buildShortcutBindings(
  onSave: _saveFile,
  onUndo: _undoEditHistory,
  onRedo: _redoEditHistory,
  onSearch: _showInlineSearch,
  onApplyAction: _applyToolbarAction,
  onEscape: _closeSearch,
  onNextSearchMatch: _jumpToNextSearchMatch,
  onPrevSearchMatch: _jumpToPrevSearchMatch,
),
```

#### 15.4 新增编辑器内容包裹方法

放在 `_buildBody` 前面：

```dart
Widget _buildDesktopEditorFrame({required Widget child}) {
  if (!ResponsiveLayout.isDesktopWidth(context)) {
    return child;
  }

  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: ResponsiveLayout.editorMaxWidth(context),
      ),
      child: child,
    ),
  );
}
```

#### 15.5 修改 `_buildBody` 中的编辑区

找到：

```dart
Positioned.fill(child: _buildEditorWithGesture()),
```

替换为：

```dart
Positioned.fill(
  child: _buildDesktopEditorFrame(
    child: _buildEditorWithGesture(),
  ),
),
```

#### 15.6 修改搜索条位置

找到：

```dart
if (_showSearchBar)
  Positioned(
    top: 10,
    left: 12,
    right: 12,
child: EditorSearchBar(
```

把整个 `if (_showSearchBar) ... Positioned(...)` 替换为下面完整代码：

```dart
if (_showSearchBar)
  Positioned(
    top: 10,
    left: ResponsiveLayout.isDesktopWidth(context) ? 0 : 12,
    right: ResponsiveLayout.isDesktopWidth(context) ? 0 : 12,
    child: _buildDesktopEditorFrame(
      child: EditorSearchBar(
        controller: _searchController,
        focusNode: _searchFocusNode,
        matches: _searchMatches,
        activeMatchIndex: _activeSearchMatchIndex,
        onSearch: _performInlineSearch,
        onJumpToMatch: _jumpToSearchMatch,
        onJumpToNext: _jumpToNextSearchMatch,
        onJumpToPrevious: _jumpToPrevSearchMatch,
        onClose: _closeSearch,
        showCandidates: _showSearchCandidates,
        searchOptions: _searchOptions,
        onOptionsChanged: _updateSearchOptions,
        searchHistory: _searchHistory,
        onHistorySelected: _onHistorySelected,
      ),
    ),
  ),
```

#### 15.7 修改底部工具栏位置

找到 toolbar 的 `Positioned`：

```dart
Positioned(
  bottom: keyboardInset,
  left: 0,
  right: 0,
child: AnimatedSlide(
```

把这个 `Positioned` 的 `child` 从 `AnimatedSlide(...)` 改成 `_buildDesktopEditorFrame(child: AnimatedSlide(...))`。最终结构必须是：

```dart
Positioned(
  bottom: keyboardInset,
  left: 0,
  right: 0,
  child: _buildDesktopEditorFrame(
    child: AnimatedSlide(
      offset: Offset(
        0,
        (_mode != EditorMode.preview ||
                _editingBlockIndex != null ||
                _isMilkdownEditorFocused)
            ? 0
            : 1,
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity:
            (_mode != EditorMode.preview ||
                    _editingBlockIndex != null ||
                    _isMilkdownEditorFocused)
                ? 1.0
                : 0.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !(_mode != EditorMode.preview ||
              _editingBlockIndex != null ||
              _isMilkdownEditorFocused),
          child: MarkdownToolbar(
            controller: _editingBlockIndex != null
                ? _inlineEditController
                : _textController,
            undoController: _editingBlockIndex != null
                ? null
                : _undoController,
            canUndo: _editingBlockIndex != null ? _historyIndex > 0 : null,
            canRedo: _editingBlockIndex != null
                ? (_historyIndex >= 0 &&
                    _historyIndex < _editHistory.length - 1)
                : null,
            onUndo: _editingBlockIndex != null ? _undoEditHistory : null,
            onRedo: _editingBlockIndex != null ? _redoEditHistory : null,
            filePath: widget.filePath,
            onSearchPressed: _showInlineSearch,
            onAction: _mode == EditorMode.preview && _editingBlockIndex == null
                ? _handlePreviewToolbarAction
                : null,
          ),
        ),
      ),
    ),
  ),
),
```

#### 15.8 修改 `_buildFixedFloatingButtons`

在方法开头：

```dart
final settings = context.watch<SettingsProvider>();
final safeBottom = MediaQuery.of(context).padding.bottom;
```

后添加：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);
final viewportWidth = MediaQuery.sizeOf(context).width;
final editorWidth = ResponsiveLayout.editorMaxWidth(context);
final desktopRightInset = isDesktop
    ? ((viewportWidth - editorWidth) / 2).clamp(24.0, 320.0) + 16.0
    : 24.0;
```

然后把两个 `right: 24,` 都替换为：

```dart
right: desktopRightInset,
```

#### 15.9 修改 `_buildEditor`

当前 `_buildEditor` 在 edit/preview 都使用：

```dart
ClipRRect(
  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
```

替换为：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);
final editorRadius = BorderRadius.vertical(
  top: Radius.circular(isDesktop ? 14 : 20),
);
```

并把两个 `BorderRadius.vertical(top: Radius.circular(20))` 改成：

```dart
editorRadius
```

#### 15.10 桌面端 TextField padding

在 `_buildEditPanel` 里：

```dart
final l10n = AppLocalizations.of(context)!;
```

后添加：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);
```

把 `contentPadding`：

```dart
contentPadding: EdgeInsets.fromLTRB(
  16,
  16,
  16,
  16 + toolbarPadding,
),
```

替换为：

```dart
contentPadding: EdgeInsets.fromLTRB(
  isDesktop ? 28 : 16,
  isDesktop ? 24 : 16,
  isDesktop ? 28 : 16,
  (isDesktop ? 24 : 16) + toolbarPadding,
),
```

验收：

```powershell
dart format lib/screens/editor_screen.dart
flutter analyze
```

---

## 16. 第十三步：桌面端上下文菜单和底部菜单收敛

这一步是键鼠适配的必做项。桌面端右键已经在 `FileTile` 中接入，但如果仍让菜单全宽从底部弹出，会明显像移动端界面。第一版不强求全部改成 `showMenu`，但必须限制菜单宽度并让菜单项有鼠标点击光标。

### 文件：`lib/utils/file_actions.dart`

#### 16.1 新增 import

```dart
import '../utils/responsive_layout.dart';
```

因为当前文件本身就在 `lib/utils` 目录，实际路径也可以写成：

```dart
import 'responsive_layout.dart';
```

优先使用第二种。

#### 16.2 新增桌面菜单包裹方法

在 `class FileActions` 内部、`showFileContextMenu` 前添加：

```dart
static Widget _buildDesktopAwareSheet(BuildContext context, Widget child) {
  if (!ResponsiveLayout.isDesktopWidth(context)) {
    return child;
  }

  return Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: child,
      ),
    ),
  );
}
```

#### 16.3 包裹文件菜单 bottom sheet

在 `showFileContextMenu` 中，把：

```dart
builder: (context) => Container(
```

改成：

```dart
builder: (context) => _buildDesktopAwareSheet(
  context,
  Container(
```

然后在该 `Container` 结束处补一个 `),`，让 `_buildDesktopAwareSheet` 包住整个菜单容器。

#### 16.4 包裹文件夹菜单 bottom sheet

在 `showFolderContextMenu` 中做同样修改：

```dart
builder: (context) => _buildDesktopAwareSheet(
  context,
  Container(
```

同样在 `Container` 结束处补一个 `),`。

#### 16.5 给菜单项加鼠标光标

在 `_buildContextMenuItem` 中，把：

```dart
return Material(
  color: Colors.transparent,
  child: InkWell(
```

替换为：

```dart
return Material(
  color: Colors.transparent,
  child: MouseRegion(
    cursor: SystemMouseCursors.click,
    child: InkWell(
```

并在 `InkWell` 结束处多补一个 `),`。

### 文件：`lib/widgets/unified_ui.dart`

如果存在统一 bottom sheet 工具，第二轮可以给桌面端增加最大宽度约束：

```dart
final isDesktop = ResponsiveLayout.isDesktopWidth(context);

return showModalBottomSheet<T>(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (context) {
    final sheet = ...;
    if (!isDesktop) return sheet;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: sheet,
      ),
    );
  },
);
```

验收标准：

- 桌面端右键菜单不超过 560px。
- 桌面端右键文件/文件夹会打开菜单。
- 鼠标悬停文件/文件夹、菜单项时显示点击光标。
- 移动端仍保持原有底部弹出。

---

## 17. 必须保持的行为

实现 agent 改完后逐项检查：

1. 移动端宽度下仍有底部导航。
2. 桌面端宽度下没有底部导航。
3. 桌面端左侧导航切换不会重建文件列表状态，使用 `IndexedStack`。
4. 首页新建文件、新建文件夹、打开文件、打开文件夹仍可用。
5. 我的文件中进入子文件夹仍打开 `FolderBrowserScreen`。
6. 历史记录文件/文件夹切换仍可用。
7. 设置页二级页面仍能 push 打开。
8. 编辑器保存、返回、更多菜单、搜索、目录、版本历史仍可用。
9. Markdown 工具栏按钮仍能插入格式。
10. 专注模式不会显示顶部 Header。
11. 桌面端主界面 `Ctrl/Cmd+1..4` 能切换一级页面。
12. 桌面端文件/文件夹条目支持右键菜单。
13. 编辑器搜索支持 `Esc`、`F3`、`Shift+F3`。

---

## 18. 验收命令

每完成一个阶段都跑：

```powershell
dart format lib/utils/responsive_layout.dart lib/widgets/responsive_page_frame.dart lib/widgets/desktop_navigation_shell.dart lib/screens/main_screen.dart lib/screens/main/tabs/home_tab.dart lib/screens/main/components/quick_actions.dart lib/screens/folder/components/file_tile.dart lib/screens/folder_browser_screen.dart lib/screens/main/tabs/history_tab.dart lib/screens/main/tabs/settings_tab.dart lib/widgets/markdown_toolbar.dart lib/screens/editor/editor_shortcuts.dart lib/screens/editor_screen.dart lib/utils/file_actions.dart
flutter analyze
```

最后跑 Windows 构建：

```powershell
flutter build windows
```

如果 `flutter analyze` 出现现有项目历史 warning，不要扩大修改范围；只修复本次新增/修改文件引入的 error。

---

## 19. 手工视觉验收矩阵

至少检查这些窗口尺寸：

| 平台 | 尺寸 | 预期 |
| --- | --- | --- |
| Windows | 900x600 | 可以回落到移动/窄布局，不出现溢出 |
| Windows | 1280x720 | 左侧导航出现，内容限宽 |
| Windows | 1366x768 | 文件列表不横向铺满，行距紧凑 |
| Windows | 1920x1080 | 首页和设置页居中，编辑器版心约 960-1040 |
| Windows | 2560x1440 | 内容不继续无限变宽 |
| Android emulator | 390x844 | 底部导航仍存在，页面不变形 |

编辑器专项：

1. 打开一个短文档，预览模式正文居中。
2. 打开一个长文档，滚动正常。
3. 切换编辑模式，底部工具栏宽度跟随正文。
4. 搜索条在桌面端不铺满窗口。
5. 右下浮动按钮靠近正文右边缘，而不是贴窗口最右侧。
6. 双击进入/退出专注模式，正文版心不跳动。
7. `Esc` 可以关闭搜索条，`F3` 和 `Shift+F3` 可以切换搜索结果。

键鼠专项：

1. 在桌面主界面按 `Ctrl+1` 到 `Ctrl+4` 可以切换四个一级页面，macOS 使用 `Cmd+1` 到 `Cmd+4`。
2. 鼠标悬停文件、文件夹、菜单项时显示点击光标。
3. 右键文件会打开文件操作菜单。
4. 右键文件夹会打开文件夹操作菜单。
5. 桌面端上下文菜单宽度不超过 560px。

---

## 20. 推荐提交拆分

如果要拆 commit，按下面顺序：

1. `feat: add responsive desktop layout helpers`
   - `lib/utils/responsive_layout.dart`
   - `lib/widgets/responsive_page_frame.dart`
   - `lib/widgets/desktop_navigation_shell.dart`

2. `feat: adapt main tabs for desktop shell`
   - `lib/screens/main_screen.dart`
   - `lib/screens/main/tabs/home_tab.dart`
   - `lib/screens/main/components/quick_actions.dart`
   - `lib/screens/main/tabs/history_tab.dart`
   - `lib/screens/main/tabs/settings_tab.dart`

3. `feat: improve desktop file list density`
   - `lib/screens/folder_browser_screen.dart`
   - `lib/screens/folder/components/file_tile.dart`
   - `lib/utils/file_actions.dart`

4. `feat: adapt editor workspace for desktop`
   - `lib/screens/editor_screen.dart`
   - `lib/screens/editor/editor_shortcuts.dart`
   - `lib/widgets/markdown_toolbar.dart`

---

## 21. 常见错误和修复

1. `ResponsivePageFrame` 包住 `ListView.builder` 后页面不能滚动：
   - 原因：嵌套滚动没有设置 `shrinkWrap`。
   - 修复：桌面端使用 `SingleChildScrollView + Column` 或设置 `shrinkWrap: true`、`NeverScrollableScrollPhysics`。

2. 桌面端左侧导航切换后 PageView 位置错乱：
   - 原因：桌面端仍调用 `_switchTab`，它会操作 `_pageController`。
   - 修复：桌面端导航只 `setState(() => _currentIndex = index)`。

3. 移动端底部导航消失：
   - 原因：`isDesktopLayout` 判断过宽。
   - 修复：必须使用 `ResponsiveLayout.isDesktopWidth(context)`，不要只看平台。

4. 编辑器工具栏括号报错：
   - 原因：`_buildDesktopEditorFrame` 包裹 `AnimatedSlide` 时少补一个右括号。
   - 修复：结构必须是 `Positioned -> _buildDesktopEditorFrame -> AnimatedSlide -> AnimatedOpacity -> MarkdownToolbar`。

5. `dart format` 后仍 analyze error：
   - 先看 import 是否未使用。
   - 再看 `ResponsivePageFrame` 的括号是否完整。
   - 不要为了解决一个括号问题改业务逻辑。

---

## 22. 完成定义

只有同时满足以下条件，才算桌面端 UI 适配第一版完成：

1. 新增 3 个文件：
   - `lib/utils/responsive_layout.dart`
   - `lib/widgets/responsive_page_frame.dart`
   - `lib/widgets/desktop_navigation_shell.dart`
2. 修改 11 个文件：
   - `lib/screens/main_screen.dart`
   - `lib/screens/main/tabs/home_tab.dart`
   - `lib/screens/main/components/quick_actions.dart`
   - `lib/screens/folder/components/file_tile.dart`
   - `lib/screens/folder_browser_screen.dart`
   - `lib/screens/main/tabs/history_tab.dart`
   - `lib/screens/main/tabs/settings_tab.dart`
   - `lib/screens/editor_screen.dart`
   - `lib/screens/editor/editor_shortcuts.dart`
   - `lib/widgets/markdown_toolbar.dart`
   - `lib/utils/file_actions.dart`
3. `flutter analyze` 没有本次改动引入的 error。
4. `flutter build windows` 成功。
5. 手工视觉验收矩阵通过。
6. 移动端窄屏没有明显回归。
