# 安卓全功能测试报告（V2185A）

**测试日期**: 2026-08-10
**设备**: MuMu 模拟器 V2185A，Android 12（API 32）
**构建**: `flutter build apk --debug`，包名 `com.ushiomd`
**版本**: 1.5.12+4061

## 1. 测试范围

本轮按用户常用路径覆盖：

- 首次启动、存储权限、工作区初始化
- 首页快速操作：新建文件、新建文件夹、打开文件、打开文件夹
- 文件管理：列表、搜索、排序、重命名、置顶、删除、文件夹浏览
- 编辑器：Milkdown 渲染、输入回写、工具栏命令、模式切换、保存、退出
- 搜索、目录跳转、快捷键帮助、版本历史
- 主题/语言/编辑器/存储/关于/调试设置
- WebDAV 云同步（本地服务器实测上传与下载）
- 外部文件打开与导入、文件分享
- 长文档滚动、键盘与输入法交互、前后台稳定性

## 2. 通过项

| 模块 | 结果 |
| --- | --- |
| 冷启动与权限引导 | 通过；`MANAGE_EXTERNAL_STORAGE` 授权后可正常进入首页 |
| 新建文件（不带 `.md`） | 通过；自动补 `.md`，文件保留在列表并可打开 |
| 新建/删除文件夹 | 通过；新建后进入目录，删除确认后文件系统同步移除 |
| 重命名 | 通过；不带扩展名时自动补 `.md` |
| 文件搜索/排序/置顶 | 通过；搜索过滤、排序菜单、置顶文件均正常 |
| Milkdown 渲染 | 通过；标题、粗体、斜体、删除线、高亮、公式、引用、列表、任务列表、代码块、表格、链接、特殊字符均正确渲染 |
| 编辑器输入与保存 | 通过；WebView 输入触发 `on_content_change`，保存后文件内容落盘 |
| 工具栏命令 | 通过；标题命令经 `exec_cmd` 生效 |
| 搜索/目录 | 通过；搜索命中高亮与跳转、目录层级和跳转正常 |
| 版本历史 | 通过；空历史提示与关闭正常 |
| 主题/语言 | 通过；浅色/深色切换、中英文切换生效 |
| 云同步 WebDAV | 通过；连接成功，上传 12 个文件、下载 3 个文件，含嵌套目录与中文文件名 |
| 外部文件导入 | 通过；系统 `ACTION_VIEW` 现在会弹出“仅查看/导入”确认对话框，导入后文件进入工作区 |

## 3. 本轮修复

### 3.1 WebView 本地服务器可能永久卡在“正在初始化编辑器...”

复现：端口 8080 被残留的编辑器服务器占用时，`flutter_inappwebview` 的
`InAppLocalhostServer.start()` 不会完成 Future，导致预热与编辑器启动永久等待。

修复：

- `warmUpMilkdownWebAssets()` 等待预热增加 3 秒超时，超时后自行启动。
- `_startLocalhostServer()` 等待预热同样增加超时。
- 新增 `_startMilkdownServer()`：逐端口尝试 8080-8087，任一端口成功即可使用。

验证：冷启动日志显示 `Server started on port 8080`，文档正常打开并复用预热服务器。

### 3.2 外部 Markdown 直接进入编辑器，绕过“仅查看/导入”

复现：通过系统 `ACTION_VIEW`/分享接收外部 `.md` 时，旧逻辑直接打开编辑器，
与 README 描述的“仅查看/导入”流程不一致，且可能直接改写外部原文件。

修复：`MainScreen._handleSharedFiles()` 改为调用 `FileImportHelper.openFile()`，
外部文件先弹出“取消/仅查看/导入”对话框。

验证：`adb am start -a android.intent.action.VIEW ...` 后出现导入确认弹窗，
选择“导入”后文件成功复制到工作区。

### 3.3 PDF 导出失败无提示

修复：`_showMoreMenu()` 中为 PDF 导出增加 try/catch，失败时显示可读 Snackbar。

### 3.4 测试资产修复

- `test/services/file_service_security_test.dart` 修正包名（`ushio_md` -> `mdreader`）。
- `test/models/milkdown_bridge_test.dart` 同步 `ThemePalettePayload` 新增字段。
- `createBridgeRequestId()` 增加自增序号，消除随机盐值在连续调用中的碰撞。

## 4. 已知问题与观察项

| 序号 | 问题 | 影响 | 建议 |
| --- | --- | --- | --- |
| 1 | `uiautomator dump` 在含 WebView 的页面触发 Flutter `AccessibilityBridge` `AssertionError`，进程崩溃 | 自动化/无障碍服务场景 | 升级 Flutter 引擎或复现后向 Flutter 反馈；常规触控路径未复现 |
| 2 | 模拟器无其他文本分享目标时，应用“以文件分享”会被系统解析回应用自身（`SEND text/markdown`），不再直接进入编辑器但无法展示分享面板 | 仅影响无分享目标的测试环境 | 真机存在微信/邮箱等目标时可正常弹选择器 |
| 3 | `exportAndShareAsPdf()` 依赖 `PdfGoogleFonts` 在线字体，断网时导出失败 | 离线导出 PDF 失败 | 将中文字体改为打包内置或给出下载失败提示 |
| 4 | `test/services/file_service_security_test.dart` 等存量测试与当前实现存在预期差异（如 `sanitizeFileName` 是否自动补扩展名、10MB 阈值），另有多个测试引用了旧包名 | 测试套件未全绿 | 需要单独一轮测试维护 |
| 5 | Milkdown 序列化会规范化列表符号（`-` -> `*`）并在列表项间插入空行、图片 alt 可能被改写为 `1.00` | 原文格式非严格保留 | 确认是否为产品可接受的规范化行为 |

## 5. 验收结论

常用功能路径均已在本轮回归覆盖，核心编辑、文件管理、设置、同步、导入均符合预期。
上表“已知问题与观察项”中的 1/3 项建议在后续版本继续处理。
