## 🎉 汐 (Ushio) v1.5.3

### 📝 更新内容 / What's New

#### 🔧 编辑器改进 / Editor Improvements
- **修复 IME 输入时视口抖动问题** - 在中文输入法输入时，禁用视口同步以防止卡顿动画
  - Fixed viewport jitter during IME input - disabled viewport sync during composition to prevent janky animations
- **改进锚点链接跳转** - 增强了文档内标题链接的匹配算法，支持多种格式（如 `#4-下载流程` 匹配 `4. 下载流程`）
  - Improved anchor link navigation - enhanced heading link matching algorithm with multiple format support
- **修复复选框交互** - 改进了 Milkdown 自定义复选框组件的点击和触摸事件处理
  - Fixed checkbox interaction - improved click and touch event handling for Milkdown custom checkbox component
- **移除代码块工具栏** - 隐藏代码块右上角的工具按钮，简化编辑界面
  - Removed code block toolbar - hidden the tools button in top-right corner for a cleaner interface
- **Emoji 显示修复** - 确保 Twemoji 表情符号大小与字体大小一致
  - Fixed emoji display - ensured Twemoji emojis match the font size

#### 🎨 UI/样式优化 / UI/Styling Improvements
- **GPU 加速** - 为弹窗和工具提示添加硬件加速，提升动画流畅度
  - GPU acceleration - added hardware acceleration for popups and tooltips for smoother animations
- **移除长按提示** - 移除了首次编辑时显示的长按格式化菜单提示
  - Removed long-press hint - removed the formatting menu hint shown on first edit
- **清理本地化代码** - 简化了本地化文件的代码格式
  - Cleaned up localization code - simplified code formatting in localization files

### 📦 下载说明 / Download Instructions

请根据您的设备架构选择对应的 APK 文件：
Please choose the APK file according to your device architecture:

- `ushio-md-v1.5.3-armeabi-v7a.apk` - 适用于大多数 32 位设备 / For most 32-bit devices
- `ushio-md-v1.5.3-arm64-v8a.apk` - 适用于 64 位设备（推荐）/ For 64-bit devices (Recommended)
- `ushio-md-v1.5.3-x86_64.apk` - 适用于 x86 模拟器 / For x86 emulators

### 💡 安装提示 / Installation Tips

1. 下载对应架构的 APK 文件 / Download the APK for your device architecture
2. 允许安装未知来源应用 / Allow installation from unknown sources
3. 安装并授予文件访问权限 / Install and grant storage permission

---

[完整更新日志 / Full Changelog](https://github.com/jiuxina/ushio-md/blob/main/CHANGELOG.md)
