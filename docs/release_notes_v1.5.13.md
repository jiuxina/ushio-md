# Release v1.5.13

## 更新日志 2026/8/10

### 🛠 修复与改进

- **WebView 初始化卡死**：修复本地服务器端口被占用时文档永久停留在“正在初始化编辑器...”的问题，预热等待增加超时，并支持 8080-8087 端口自动回退
- **外部文件导入流程**：修复系统 `ACTION_VIEW`/分享打开外部 Markdown 时直接进入编辑器的问题，统一弹出“取消 / 仅查看 / 导入”确认对话框，避免直接改写外部原文件
- **PDF 导出失败提示**：PDF 导出异常时显示可读错误提示，不再静默失败
- **Bridge 请求 ID 唯一性**：WebView bridge 请求 ID 增加自增序号，消除连续调用时的随机碰撞

### ✅ 测试

- 在 Android 12（V2185A）模拟器完成全功能回归，覆盖文件管理、编辑器、搜索/目录、设置、WebDAV 同步、外部导入、长文档与输入法交互
- 本地 WebDAV 回归测试通过：上传 12 个文件、下载 3 个文件（含嵌套目录与中文文件名）
- 详细结果见 `docs/ANDROID_FULL_FUNCTION_TEST_2026_08_10.md`

### ✅ 下载

> 建议使用 arm64-v8a 版本

- `ushio-md-v1.5.13-armeabi-v7a.apk` - 适用于大多数 32 位设备
- `ushio-md-v1.5.13-arm64-v8a.apk` - 适用于 64 位设备（推荐）
- `ushio-md-v1.5.13-x86_64.apk` - 适用于 x86 模拟器
- `ushio-md-v1.5.13-universal.apk` - 通用包

#### • [镜像-arm64v8a](https://gh-proxy.org/https://github.com/jiuxina/ushio-md/releases/download/v1.5.13/ushio-md-v1.5.13-arm64-v8a.apk)

---

## Changelog 2026/8/10

### 🛠 Fixes & Improvements

- **WebView initialization hang**: Fixed documents stuck at “正在初始化编辑器...” when the localhost port is occupied. Warmup now times out and falls back across ports 8080-8087
- **External file import flow**: Fixed external Markdown opened via `ACTION_VIEW`/share going straight into the editor. A “Cancel / View Only / Import” confirmation dialog is now shown, protecting external source files from accidental edits
- **PDF export error feedback**: PDF export failures now show a readable error message instead of failing silently
- **Bridge request ID uniqueness**: Added a monotonic counter to WebView bridge request IDs to eliminate random collisions

### ✅ Testing

- Full functional regression on Android 12 (V2185A), covering file management, editor, search/outline, settings, WebDAV sync, external import, long documents and IME interaction
- Local WebDAV regression passed: 12 files uploaded and 3 files downloaded, including nested directories and Chinese filenames
- See `docs/ANDROID_FULL_FUNCTION_TEST_2026_08_10.md` for details

### ✅ Download

> arm64-v8a version is recommended

- `ushio-md-v1.5.13-armeabi-v7a.apk` - for most 32-bit devices
- `ushio-md-v1.5.13-arm64-v8a.apk` - for 64-bit devices (recommended)
- `ushio-md-v1.5.13-x86_64.apk` - for x86 emulators
- `ushio-md-v1.5.13-universal.apk` - universal APK

#### • [Mirror-arm64v8a](https://gh-proxy.org/https://github.com/jiuxina/ushio-md/releases/download/v1.5.13/ushio-md-v1.5.13-arm64-v8a.apk)

---

[完整更新日志](https://github.com/jiuxina/ushio-md/blob/main/docs/CHANGELOG.md)
