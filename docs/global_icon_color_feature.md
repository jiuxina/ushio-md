# 自定义全局图标颜色功能（2026-08-10）

## 功能说明

在“外观 → 主题设置”中新增“全局图标颜色”设置项：

- 提供与“主题色”一致的 12 色调色板快捷选择。
- 提供“自定义全局图标颜色”开关，开启后可进一步用颜色选择器精确选色。
- 开启后，应用内主要图标统一使用所选颜色；关闭后回退到主题默认前景色。

## 实现要点

- `SettingsProvider`
  - 新增 `useCustomIconColor`、`customIconColor` 状态与持久化。
  - 支持 `use_custom_icon_color`、`custom_icon_color` 两个 SharedPreferences 键。
- `AppStyleTheme`
  - 新增 `iconColor`、`mutedIconColor` 解析结果。
  - 未启用自定义颜色时分别使用 `colorScheme.onSurface` 与 `colorScheme.onSurfaceVariant`。
- `main.dart`
  - 将自定义图标颜色传入浅色/深色主题，并设置默认 `IconThemeData`。
- 主要图标引用
  - 设置页、外观分类、快捷操作、文件列表、对话框、信息横幅等改为通过
    `context.appIconColor` / `context.appMutedIconColor` 获取颜色。
- 调色板一致性
  - `uiFontColors` 与 `globalIconColors` 均直接复用 `themeColors`，
    保证 UI 文字颜色、全局图标颜色与主题色的预置可选颜色一致。

## 验证

- `dart analyze`：本次改动文件无新增 error。
- `flutter test test/providers/settings_provider_test.dart`：13 个测试全部通过，
  包含自定义图标颜色的默认值、设置、持久化、初始化恢复与调色板一致性断言。
- `flutter build apk --debug` 构建成功并安装到模拟器。
- 视觉桥核验：
  - 主题设置页出现“全局图标颜色”区块、12 色预设与“自定义全局图标颜色”开关。
  - 选中红色预设后，设置页 6 个入口图标与底部导航未选中图标全部变为红色。
