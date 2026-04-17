# 更新日志 (Changelog)

本文档记录汐 Markdown 编辑器的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [1.5.2] - 2026-04-17

### 修复

#### WebView 加载问题修复 🐛
- **第二次打开文档卡在加载状态**
  - 修复 WebView 服务器生命周期问题：不再在编辑器关闭时关闭共享的预热服务器
  - 修复浏览器后退缓存 (bfcache) 导致 JavaScript 未重新执行的问题
  - 添加 JS bridge 就绪检测和自动重载机制
  - 添加 `pageshow` 事件处理检测 bfcache 恢复并强制刷新

#### 代码质量改进 📋
- **milkdown_webview_editor.dart**
  - 添加详细调试日志追踪 WebView 初始化流程
  - 优化服务器复用逻辑，区分预热服务器和独立服务器
  - 添加 null 检查防止重载时的空引用异常

- **main.js (JavaScript)**
  - 添加 bfcache 防护：检测 `pageshow.persisted` 并强制刷新
  - 添加缓存控制 meta 标签防止页面缓存
  - 添加 `forceRender` 选项到 `setMarkdown` 支持文档切换时强制渲染
  - 添加详细调试日志

### 技术细节

```
问题根因分析：
1. 编辑器关闭时，dispose() 关闭了共享的 _warmServer
2. 第二个编辑器尝试复用已关闭的服务器
3. WebView 加载失败，JavaScript bridge 未初始化
4. 浏览器 bfcache 恢复页面状态但不重新执行 JavaScript

解决方案：
1. dispose() 时检测是否为预热服务器，不关闭共享实例
2. 添加 JS bridge 就绪检测循环（最多 5 秒）
3. bridge 未就绪时自动重新加载页面
4. JavaScript 端检测 bfcache 恢复并强制刷新
```

---

## [1.5.0] - 2026-04-08

### 综合优化

本版本进行了全面的代码质量优化，修复了多个资源泄漏和安全问题。

#### 资源管理优化 🔧
- **HttpClient 资源管理** - 确保 HTTP 连接正确关闭
- **FTP 连接管理** - 统一连接管理模式，防止连接泄漏
- **Listener 管理** - 使用标志位追踪，防止重复添加/移除
- **ValueNotifier 释放** - 添加 dispose 方法释放资源
- **InAppLocalhostServer** - 添加 dispose 标志位防止资源泄漏

#### 性能优化 ⚡
- **MarkdownStyleSheet 缓存** - 避免每次 build 重建样式表
- **背景图片缓存** - 使用 FileImage 缓存减少 I/O

#### 安全性增强 🔐
- **参数验证增强** - 证书管理器添加输入验证
- **空安全修复** - 移除危险强制解包
- **异常处理完善** - 分类捕获异常，添加详细日志

#### 代码质量 📋
- 修复 17 处空 catch 块，添加异常日志
- 修复 TextEditingController 泄漏
- 添加完善的错误日志记录

---

## [1.4.4] - 2026-04-08

### 修复

#### 空安全修复 (P1) 🛡️
- **folder_browser_screen.dart**
  - 移除所有 `AppLocalizations.of(context)!` 强制解包
  - 使用 `l10n?.xxx ?? 'fallback'` 安全访问模式
  - 添加合理的默认值

- **webdav_service.dart**
  - `getRemoteFileInfo()` 添加错误日志
  - 所有 catch 块现在都有有意义的日志输出

- **font_service.dart**
  - 区分异常类型（PlatformException、FileSystemException）
  - 添加详细的错误信息和堆栈跟踪
  - 所有 catch 块都有清晰的日志记录

### 代码质量
- **多子代理协作优化**
  - 第三轮迭代：修复剩余 3 个 P1 问题
  - 代码审查：2 个通过，1 个修复后通过
  - 累计修复 P1 问题：12 个

---

## [1.5.3] - 2026-04-08

### 修复

#### 资源泄漏修复 (P1) 🔧
- **HttpClient 资源管理** (`update_service.dart`)
  - `checkForUpdate` 使用 try-finally 确保 client.close()
  - `_downloadFile` 区分外部/内部创建的 Client，正确关闭

- **FTP 连接管理** (`ftp_service.dart`)
  - 新增 `_safeExecute` 统一连接管理模式
  - 所有 FTP 操作确保异常时正确断开连接
  - 重构 6 个方法使用安全执行包装器

- **Listener 管理** (`editor_screen.dart`)
  - 使用标志位追踪 listener 状态
  - 防止 listener 重复添加/移除
  - dispose 后不再添加新 listener

- **progressNotifier 释放** (`cloud_sync_screen.dart`, `cloud_sync_service.dart`)
  - 添加 `dispose()` 方法释放 ValueNotifier
  - 确保 widget 销毁时资源正确释放

- **InAppLocalhostServer 资源** (`milkdown_webview_editor.dart`)
  - 添加 `_isDisposed` 标志位防止重复关闭
  - 异步启动时检查 dispose 状态
  - 确保 dispose 时服务器正确关闭

### 性能优化 ⚡
- **MarkdownStyleSheet 缓存** (`markdown_preview.dart`)
  - 转换为 StatefulWidget 实现缓存
  - 只在配置变化时重建样式表
  - 避免每次 build 创建新对象

- **背景图片缓存** (`app_background.dart`)
  - 使用 FileImage 实现图片缓存
  - 只在路径变化时更新缓存
  - Flutter 自动管理解码缓存

### 安全性 🔐
- **参数验证增强** (`certificate_security_manager.dart`)
  - `parseUrl()` 验证 URL 非空和有效性
  - `trustHost()` 验证主机名和端口范围
  - `removeTrustedHost()` 验证主机名

### 代码质量
- **多子代理协作优化**
  - 使用 6 个子代理并行分析和修复
  - 覆盖资源泄漏、生命周期、性能问题
  - 代码审查 8 个文件全部通过

---

## [1.5.2] - 2026-04-08

### 修复

#### 代码质量问题 🐛
- **空 catch 块修复**
  - 修复 17 处空 catch 块，添加异常日志记录
  - 涉及文件: `settings_provider.dart`, `ftp_service.dart`, `share_service.dart`, `file_service.dart`, `export_service.dart`, `editor_screen.dart`, `recent_files_tab.dart`, `recent_folders_tab.dart`
  - 所有静默失败现在都有 debugPrint 日志

- **TextEditingController 泄漏修复**
  - 修复 `file_actions.dart` 中对话框控制器未释放问题
  - 在函数末尾添加 `controller.dispose()`

### 代码质量

#### 问题排查报告 📋
- 新增 `CODE_ISSUES.md` 代码问题排查报告
- 识别 49 处强制解包 `!` 需要关注
- 识别潜在的资源泄漏点

---

## [1.5.1] - 2026-04-08

### 安全性增强

#### 云同步证书安全 🔐
- **证书安全管理器 `CertificateSecurityManager`**
  - 默认严格校验系统信任链
  - 检测自签名证书错误
  - 用户确认后允许特定主机的不安全连接
  - 使用 `FlutterSecureStorage` 加密存储信任主机

- **Android 网络安全配置**
  - 新增 `network_security_config.xml`
  - 禁用明文传输（仅 HTTPS）
  - 只信任系统证书，防止抓包工具监听
  - 用户手动安装的证书默认不被信任

- **安全交互流程**
  - 检测自签名证书时弹出警告
  - 显示风险提示，用户主动确认后才放行
  - 仅对用户确认的特定主机跳过证书验证
  - 非信任主机的证书错误仍然阻止

### 安全策略说明

```
┌─────────────────────────────────────────────────────────────┐
│ 证书验证流程                                                 │
├─────────────────────────────────────────────────────────────┤
│ 1. 默认行为：严格依赖系统信任链                              │
│    - Let's Encrypt、正规证书 → 直接通过                      │
│    - 自签名证书 → 捕获错误，弹窗警告                         │
│                                                             │
│ 2. 自签名证书处理：                                          │
│    ┌───────────────────────────────────────────────────┐    │
│    │ ⚠️ 安全警告                                        │    │
│    │ 该服务器使用自签名证书，存在安全风险                │    │
│    │ 请确认您完全信任该服务器的提供者                    │    │
│    │ [取消] [我了解风险，强制连接]                       │    │
│    └───────────────────────────────────────────────────┘    │
│                                                             │
│ 3. 用户确认后：                                              │
│    - 仅对该特定主机跳过证书验证                              │
│    - 其他主机仍然严格验证                                    │
│    - 信任信息加密存储在本地                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## [1.5.0] - 2026-04-08

### 安全性增强

#### WebView XSS 防护 🔒
- **内容清理器 `_ContentSanitizer`**
  - 移除危险 HTML 标签 (script, iframe, object, embed 等)
  - 移除事件处理器属性 (onclick, onerror 等)
  - 阻止 javascript: 协议
  - 验证 data: URI 仅允许图片类型
  
- **URL 安全验证**
  - 图片 URL 插入时清理
  - 阻止危险协议 (javascript:, vbscript:, data:text/html)
  - 白名单协议 (http, https, ftp, mailto, tel)

- **Markdown 内容检查**
  - 初始化文档时检测危险内容
  - 自动清理潜在 XSS 向量
  - 保留 Milkdown 沙箱隔离作为第一层防护

### 新增功能

#### 大文件支持 📄
- **流式读取 API**
  - `readFileStream()` - 分块读取大文件
  - `readFilePreview()` - 读取文件预览（前 N 字符）
  - 可中断读取，支持进度回调

- **预览模式**
  - 大文件可只读取前 10000 字符预览
  - 避免一次性加载整个文件到内存

---

## [1.4.9] - 2026-04-08

### 性能优化

#### 搜索防抖 ⚡
- **搜索输入防抖**
  - 添加 150ms 搜索延迟
  - 避免快速输入时频繁搜索
  - 提升大文件搜索体验

- **搜索超时保护**
  - 搜索操作最大 500ms 超时
  - 防止超大文件卡顿
  - 超时后返回已找到的结果

### 新增工具

#### 通用防抖工具类 🛠️
- **`Debouncer`** - 简单防抖器
  - 延迟执行，只执行最后一次
  - 支持同步和异步操作
  - 可配置延迟时间

- **`OperationLock`** - 操作锁
  - 防止并发执行同一操作
  - 自动释放机制
  - 简单易用的 API

- **`GlobalDebouncer`** - 全局防抖管理器
  - 通过 key 管理多个防抖操作
  - 支持操作状态查询
  - 可取消指定或全部操作

### 改进

#### 代码优化 📝
- 搜索逻辑拆分为 `_performInlineSearch` 和 `_executeSearch`
- 添加 `mounted` 检查防止内存泄漏
- 搜索添加调试日志

---

## [1.4.8] - 2026-04-08

### 安全性增强

#### 输入验证 🔒
- **文件名长度限制**
  - 重命名对话框添加 250 字符限制
  - 自动截断超长文件名并保留扩展名
- **PDF 导出大小检查**
  - 导出前检查文件大小
  - 超过限制时显示友好错误提示

### 性能优化

#### 防抖机制 ⚡
- **操作防抖**
  - 新增 `_Debouncer` 工具类
  - 置顶/取消置顶操作防抖
  - PDF 分享操作防抖
  - 重命名操作防抖
  - 防止快速点击导致重复操作

### 改进

#### 错误处理 🐛
- **文件已存在检查**
  - 重命名前检查目标文件是否存在
  - 显示更友好的错误提示
- **保存前内容大小检查**
  - `saveFile()` 方法添加内容大小验证
  - 防止保存超大内容

---

## [1.4.7] - 2026-04-08

### 安全性增强

#### 文件系统安全 🔒
- **文件大小限制**
  - 添加 10MB 最大文件限制，防止内存溢出
  - 超大文件读取时抛出 `FileTooLargeException`
  - 友好的错误提示，显示实际大小和限制

- **文件名验证与清理**
  - 过滤 Windows 非法字符 `< > : " | ? *`
  - 移除控制字符 (0x00-0x1F)
  - 处理 Windows 保留名 (CON, PRN, AUX, NUL, COM*, LPT*)
  - 限制文件名最大长度 255 字符
  - 空文件名自动替换为 `untitled.md`

- **路径遍历防护**
  - 规范化文件路径，防止 `../` 攻击
  - 解析符号链接验证真实路径
  - 增强工作区边界检查

### 修复

#### Android 兼容性 🐛
- 修复 Android 11+ 路径遍历检测大小写问题
- 修复子路径中的路径遍历漏洞

---

## [1.4.6] - 2026-04-08

### 修复

#### Android 高版本文件导入路径问题 🐛
- **修复导入文件写入错误目录**
  - Android 10+ 使用 `getExternalStorageDirectory()` 返回私有沙箱目录
  - 现在正确提取存储根路径并使用公共 Documents 目录
  - 导入文件统一写入 `/storage/emulated/0/Documents/Ushio-md`

- **修复新建文件路径不一致**
  - 新建文件现在同样写入公共 Documents 目录
  - 与导入文件使用相同的工作区路径

#### 文件列表刷新机制 🔄
- **添加应用生命周期监听**
  - 从后台恢复时自动刷新「我的文件」列表
  - 导入文件后自动刷新文件列表
  - 新建文件后即时显示

- **公开 `FolderBrowserScreen.refresh()` 方法**
  - 允许外部触发文件列表刷新

### 改进

#### 代码注释更新 📝
- 更新 `MyFilesService` 中的 Android 存储策略说明
- 添加 Android 10+ 存储行为变更的详细注释

---

## [1.4.5] - 2026-04-08

### 重构

#### 编辑器代码模块化 🔧
- **拆分 `editor_screen.dart`**（从 2193 行优化为模块化结构）
  - 提取数据模型到 `editor/models/editor_models.dart`
    - `MarkdownBlock`: Markdown 块解析模型
    - `EditHistoryEntry`: 编辑历史条目
    - `SearchMatch`: 搜索匹配结果
  - 提取正则表达式到 `editor/models/editor_patterns.dart`
  - 提取解析逻辑到 `editor/models/markdown_parser.dart`
    - `parseMarkdownBlocks()`: 解析 Markdown 块
    - `toggleCheckboxInText()`: 切换复选框
    - `slugifyHeading()`: 生成标题 slug
  - 提取 UI 组件
    - `editor/components/editor_search_bar.dart`: 搜索栏组件
    - `editor/components/animated_fab.dart`: 动画浮动按钮
    - `editor/components/shortcuts_help_dialog.dart`: 快捷键帮助对话框
  - 添加 mixins（备用）
    - `editor/mixins/edit_history_mixin.dart`: 编辑历史 mixin
    - `editor/mixins/search_mixin.dart`: 搜索功能 mixin

### 测试

- 新增 `test/screens/editor/models/editor_models_test.dart`
- 新增 `test/screens/editor/models/markdown_parser_test.dart`
- 更新 `test/screens/editor/editor_shortcuts_test.dart`

---

## [1.4.4] - 2026-04-08

### 新增

#### 编辑器快捷键支持 ✨
- **文件操作**
  - `Ctrl+S` / `Cmd+S`: 保存文件
  - `Ctrl+Z` / `Cmd+Z`: 撤销
  - `Ctrl+Shift+Z` / `Ctrl+Y`: 重做
  - `Ctrl+F` / `Cmd+F`: 搜索

- **文本格式**
  - `Ctrl+B` / `Cmd+B`: 加粗
  - `Ctrl+I` / `Cmd+I`: 斜体
  - `Ctrl+Shift+X`: 删除线

- **标题**
  - `Ctrl+1` / `Cmd+1`: 一级标题
  - `Ctrl+2` / `Cmd+2`: 二级标题
  - `Ctrl+3` / `Cmd+3`: 三级标题

- **列表与引用**
  - `Ctrl+L` / `Cmd+L`: 无序列表
  - `Ctrl+Shift+L`: 有序列表
  - `Ctrl+Q` / `Cmd+Q`: 引用

- **代码与链接**
  - `Ctrl+K` / `Cmd+K`: 代码块
  - `Ctrl+Shift+K`: 链接

- **其他**
  - `Escape`: 关闭搜索栏
  - 快捷键帮助对话框（在更多菜单中查看）

### 改进

#### 代码重构
- 新增 `lib/screens/editor/editor_shortcuts.dart` 模块
  - 提取快捷键逻辑到独立类
  - 添加 `EditorShortcuts` 管理类
  - 添加 `ShortcutHelpDialog` 快捷键帮助对话框

#### 常量管理
- 扩展 `lib/utils/constants.dart`
  - 添加编辑器配置常量（字体大小、行高等）
  - 添加文件类型配置常量
  - 添加云同步配置常量

### 文档

- 新增 `AUDIT_REPORT.md` 代码审计报告
- 新增 `CHANGELOG.md` 变更日志

---

## [1.4.3] - 之前版本

### 功能特性

- 📝 Markdown 编辑与预览
- 📁 文件浏览与管理
- 🎨 主题切换与个性化设置
- 💾 自动保存功能
- 🔍 全文搜索
- 📑 目录导航
- 🌐 WebDAV/FTP 云同步
- 📤 导出 PDF/图片/ZIP
- ✨ 粒子特效背景

---

## 版本号说明

- **主版本号 (1.x.x)**: 重大变更或不兼容更新
- **次版本号 (x.4.x)**: 新功能添加
- **修订号 (x.x.4)**: Bug 修复和小改进

---

## 计划中的功能

- [ ] 多标签页编辑
- [ ] 文件夹收藏功能
- [ ] Markdown 语法高亮主题
- [ ] 导出 HTML 功能
- [ ] 代码块行号显示
- [ ] 实时字数统计增强

---

## 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

---

## 许可证

[MIT License](LICENSE)
