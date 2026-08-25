# Release v1.6.0

## 更新日志 2026/8/26

### 🚀 新功能

- **液态玻璃胶囊底栏**：外观 → 其他设置新增底部导航栏“液态玻璃胶囊”样式，选中项带滑动胶囊高亮动画，仅显示图标；胶囊悬浮于页面底部，内容可滚动到其下方
- **拖动切换**：胶囊滑块支持按住左右拖动切换 tab，带缩放反馈并吸附到最近选项；历史页文件/文件夹切换按钮同样支持拖动切换

### 🛠 修复与改进

- **换行与源文件保真**：单回车按真实换行渲染；打开文件与编辑/预览切换按原文解析，setext 标题、空行等格式不再被改写，也不会误标“已修改”或触发自动保存
- **编辑器初始化**：复杂文档初始化期间的 Milkdown 内部事务不再被当作编辑上报；切换文档/模式后的初始化写入不再计入撤销历史，首次撤销不会清空文档
- **预览页撤销/重做**：按钮状态跟随 Milkdown 真实历史，没有可撤销/重做内容时禁用，不再弹出“编辑命令失败”
- **光标视口同步**：只有真实编辑交互（点击、输入、键盘操作）后才执行滚动同步，文档下滑不再被回跳到开头
- **悬浮按钮遮挡**（QA P1）：预览模式“目录”按钮上移到底部工具栏上方，不再遮挡“标题 1/标题 2”
- **搜索高亮**（QA P3）：正文匹配改为 ProseMirror decoration，搜索后不再被编辑器重绘清除，并支持当前匹配高亮
- **搜索后输入恢复**（QA P2）：关闭/跳转搜索后重新聚焦编辑器并释放 Flutter IME client；Android 真机键盘恢复待复核
- **大文件加载**（QA P5）：>512KB 文档支持渐进渲染，15 秒首帧超时后提供“继续等待 / 返回”，不再永久卡在“正在加载内容...”
- **编码与换行**（QA P6/P7）：非法 UTF-8/二进制文件显示明确错误提示；保存保持文档原始换行风格，CRLF 文件不再被转成 LF
- **文件列表**：支持无扩展名文本/Markdown 文件；异常 stat 显示“未知”而非 `-1 B · 1970/1/1`；中文文件名统一使用原生路径构造
- **界面对齐**：统一历史/设置页标题位置、三个主页面首个卡片顶部间距；历史页文件/文件夹切换控件修复并可正常渲染

### ✅ 测试

- Android 12 模拟器回归：预览/编辑、搜索高亮、TOC、版本历史、自动保存、CRLF、非法编码、无扩展名与中文文件名文件
- `FileService` 编码/CRLF/二进制检测、液态玻璃胶囊底栏、`on_history_state` 桥接事件单元测试通过
- 详细结果见 `docs/QA_REPORT_2026_08_25.md`

### ✅ 下载

> 建议使用 arm64-v8a 版本

- `ushio-md-v1.6.0-armeabi-v7a.apk` - 适用于大多数 32 位设备
- `ushio-md-v1.6.0-arm64-v8a.apk` - 适用于 64 位设备（推荐）
- `ushio-md-v1.6.0-x86_64.apk` - 适用于 x86 模拟器
- `ushio-md-v1.6.0-universal.apk` - 通用包

#### • [镜像-arm64v8a](https://gh-proxy.org/https://github.com/jiuxina/ushio-md/releases/download/v1.6.0/ushio-md-v1.6.0-arm64-v8a.apk)

---

## Changelog 2026/8/26

### 🚀 New Features

- **Liquid glass capsule tab bar**: Added a “Liquid Glass Capsule” bottom navigation style under Appearance → Other Settings, with a sliding highlight animation and icon-only labels; the capsule floats above full-screen pages so content can scroll beneath it
- **Drag to switch**: Press and drag the capsule slider to switch tabs with press feedback and snap-to-nearest behavior; the history page file/folder toggle supports the same gesture

### 🛠 Fixes & Improvements

- **Line breaks and source fidelity**: Single newlines now render as breaks; files open and switch between edit/preview exactly as-is, so setext headings and blank lines are never rewritten, and untouched files are no longer marked modified or auto-saved
- **Editor initialization**: Internal Milkdown transactions during initialization are no longer reported as edits; initialization writes no longer enter undo history, so the first undo cannot wipe a document
- **Preview undo/redo**: Buttons now follow Milkdown’s real history state and disable when empty, instead of showing “编辑命令失败”
- **Caret viewport sync**: Scroll sync only runs after real edit interactions, so scrolling down no longer jumps back to the top
- **Floating button overlap** (QA P1): Preview “TOC” button moved above the bottom toolbar, no longer covering “Heading 1/Heading 2”
- **Search highlight** (QA P3): Inline matches use ProseMirror decorations, no longer cleared by editor redraws, with active-match highlight
- **IME recovery after search** (QA P2): Closing or jumping from search refocuses the editor and releases the Flutter IME client; real-device keyboard recovery still needs confirmation
- **Large file loading** (QA P5): Documents over 512KB render progressively, with a 15-second first-frame timeout offering “keep waiting / go back” instead of hanging on “正在加载内容...”
- **Encoding and line endings** (QA P6/P7): Invalid UTF-8/binary files now show a clear error; saves preserve original CRLF instead of converting to LF
- **File list**: Extensionless text/Markdown files are listed and openable; failed `stat` shows “未知” instead of `-1 B · 1970/1/1`; Chinese filenames use native paths so they open correctly
- **UI alignment**: Unified header layout on history/settings and first-card spacing across main tabs; the history file/folder toggle renders correctly again

### ✅ Testing

- Android 12 emulator regression: preview/edit, search highlight, TOC, version history, autosave, CRLF, invalid encoding, extensionless and Chinese-named files
- Unit tests passed for `FileService` encoding/CRLF/binary detection, liquid glass capsule tab bar, and `on_history_state` bridge events
- See `docs/QA_REPORT_2026_08_25.md` for details

### ✅ Download

> arm64-v8a version is recommended

- `ushio-md-v1.6.0-armeabi-v7a.apk` - for most 32-bit devices
- `ushio-md-v1.6.0-arm64-v8a.apk` - for 64-bit devices (recommended)
- `ushio-md-v1.6.0-x86_64.apk` - for x86 emulators
- `ushio-md-v1.6.0-universal.apk` - universal APK

#### • [Mirror-arm64v8a](https://gh-proxy.org/https://github.com/jiuxina/ushio-md/releases/download/v1.6.0/ushio-md-v1.6.0-arm64-v8a.apk)

---

[完整更新日志](https://github.com/jiuxina/ushio-md/blob/main/docs/CHANGELOG.md)
