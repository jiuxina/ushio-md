# UI 视觉设计优化记录（2026-08-10）

## 背景

用户反馈软件 UI 存在两类视觉问题：

1. 大量文字或图标与所在卡片/底色同色系，深色模式下辨识度下降。
2. 装饰性彩色层级过多，例如设置页“云同步”卡片左侧的绿色图标及其绿色底块。

本次优化统一采用“黑白前景 + 透明图标底”的深色模式友好方案，减少不必要的彩色层级。

## 改动范围

### 设置入口与分类页

- `lib/screens/main/tabs/settings_tab.dart`
  - 移除“外观 / 编辑器 / 云同步 / 存储 / 关于 / 调试模式”的彩色图标与同色半透明底块。
  - 图标统一使用 `colorScheme.onSurface`（深色模式为白色/浅灰，浅色模式为黑色系）。
- `lib/screens/settings/appearance_categories_screen.dart`
  - 外观分类卡片同步改为单色图标、无图标底块。

### 首页与文件列表

- `lib/screens/main/components/quick_actions.dart`
  - 快捷操作按钮移除绿色/橙色/蓝色/琥珀色图标底块与彩色描边，改为前景色图标和中性卡片表面。
- `lib/screens/folder/components/file_tile.dart`
  - 文件/文件夹/图片类型图标不再使用彩色区分与彩色底块，统一为 `onSurfaceVariant`。
- `lib/widgets/glass_card.dart`
  - 移除图标渐变底块，使用前景色图标。
- `lib/screens/main/tabs/recent_files_tab.dart`、`recent_folders_tab.dart`
  - 同步移除传入的彩色 `iconColor`。

### 对话框、菜单与信息横幅

- `lib/widgets/unified_ui.dart`
  - 确认/输入对话框标题图标、底部菜单项图标改为单色，无彩色底块。
- `lib/utils/file_actions.dart`
  - 文件/文件夹右键菜单项、分享子菜单、新建文件/文件夹对话框图标统一单色化。
- `lib/screens/settings/storage_settings_screen.dart`
  - 工作区、清理历史、编辑路径等图标底块移除；蓝色/橙色提示条改为中性表面 + `onSurfaceVariant` 文本。
- `lib/screens/settings/about_screen.dart`
  - 关于页链接、更新检查等图标底块移除；应用信息卡改为中性表面。
- `lib/screens/settings/cloud_sync_screen.dart`
  - 云同步信息卡、自动同步、同步预览对话框图标单色化；FTP 警告与测试结果横幅改为中性表面 + 普通前景文本。
- `lib/widgets/markdown_toolbar.dart`、`lib/widgets/milkdown_webview_editor.dart`
  - 插入图片/表格对话框的彩色图标底块移除。
- `lib/utils/file_import_helper.dart`
  - 导入确认对话框图标与蓝色提示条改为中性样式。

## 保留的语义色

- 成功/失败/警告等状态提示（绿色对勾、红色错误、橙色警告图标）保留，但不再叠同色背景层。
- 底部导航、开关等选中态的高亮色保留，用于表达当前状态。

## 验证

- `dart analyze`（仅本次修改的 17 个文件）：无新增 error，仅保留仓库既有的 warning/info。
- `flutter build apk --debug` 构建成功。
- APK 已安装到模拟器 `emulator-5556`。
- 通过视觉桥核验深色模式：
  - 设置页 6 个入口图标为白色/浅灰，无彩色底块。
  - 首页快捷操作 4 个图标为白色，无彩色底块。
  - 云同步页云图标为白色，无彩色底块，文字对比清晰。
