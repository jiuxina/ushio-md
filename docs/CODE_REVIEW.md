# 汐 Markdown 编辑器 - 代码审查报告

**审查日期**: 2025年4月7日  
**版本**: v1.4.4  
**审查范围**: 全项目代码

---

## 总体评估

| 指标 | 评级 |
|------|------|
| **代码质量** | ⭐⭐⭐⭐☆ 良好 |
| **安全性** | ⭐⭐⭐☆☆ 需要改进 |
| **架构设计** | ⭐⭐⭐⭐☆ 良好 |
| **可维护性** | ⭐⭐⭐☆☆ 中等 |
| **测试覆盖** | ⭐⭐⭐☆☆ 中等 |

---

## 🚨 关键问题 (P0)

### 1. WebView 安全漏洞 [HIGH]

**位置**: `lib/widgets/milkdown_webview_editor.dart` (269-295, 905-910, 917, 923-929)

**问题**: 
- 自定义协议 `ushio-local-file://` 允许读取任意本地文件，无路径验证
- WebView 设置过于宽松：`allowUniversalAccessFromFileURLs: true`, `allowFileAccessFromFileURLs: true`

**风险**: 如果 WebView 中有任何脚本执行，可能被利用读取设备上的任意文件

**修复建议**:
```dart
// 限制文件访问范围
Future<CustomSchemeResponse?> _serveLocalFileRequest(Uri uri) async {
  final requestedPath = uri.queryParameters['path'] ?? '';
  
  // 1. 规范化路径，防止路径遍历
  final normalizedPath = File(requestedPath).absolute.path;
  
  // 2. 只允许访问工作区和应用私有目录
  final allowedRoots = [widget.baseDirectory, appPrivateDir];
  if (!allowedRoots.any((root) => normalizedPath.startsWith(root))) {
    return CustomSchemeResponse(data: Uint8List(0), contentType: 'text/plain');
  }
  // ...
}
```

### 2. FTP 明文传输 [HIGH]

**位置**: `lib/services/ftp_service.dart`

**问题**: FTP 协议不加密，凭据和文件内容以明文传输

**风险**: 中间人攻击可窃取密码和同步的 Markdown 文件

**修复建议**:
- 移除 FTP 支持，仅保留 WebDAV（HTTPS）
- 或强制使用 FTPS（FTP over TLS）
- 在 UI 中明确警告用户风险

### 3. 云同步路径遍历漏洞 [HIGH]

**位置**: `lib/services/cloud_sync_service.dart` (247-249, 335-337, 430-437)

**问题**: 远程路径直接用于构建本地路径，未做规范化验证

**风险**: 恶意服务器可返回包含 `../` 的路径，导致文件写入到工作区外

**修复建议**:
```dart
String buildLocalPath(String remotePath, String workspacePath) {
  final normalized = path.normalize(remotePath);
  final localPath = path.join(workspacePath, normalized);
  
  // 确保结果仍在工作区内
  if (!path.isWithin(workspacePath, localPath)) {
    throw SecurityException('Path traversal detected');
  }
  return localPath;
}
```

---

## ⚠️ 重要问题 (P1-P2)

### 4. 云同步功能未测试 [MEDIUM]

**位置**: `README.md`

```
### 云同步可以直接用于重要数据吗？
不建议，作者还没严格测试过。
```

**建议**: 在正式推荐使用前，完善测试覆盖并明确标注为 Beta 功能

### 5. 大文件职责过多 [MEDIUM]

| 文件 | 行数 | 问题 |
|------|------|------|
| `editor_screen.dart` | ~1800+ | 编辑器逻辑、TOC、搜索、历史、WebView 协调 |
| `milkdown_webview_editor.dart` | ~965 | WebView 管理、图片上传、主题、截图 |
| `settings_provider.dart` | ~1062 | 所有设置的状态管理 |

**建议**: 考虑分解为更小的组件/服务

### 6. 凭据内存暴露 [MEDIUM]

**位置**: `lib/providers/settings_provider.dart:266-267, 319-320`

```dart
String get webdavPassword => _webdavPassword;
String get ftpPassword => _ftpPassword;
```

**问题**: 密码通过公共 getter 暴露为明文，任何有 Provider 访问权限的代码都可读取

**建议**: 避免公开密码 getter，仅在需要时通过安全方法访问

---

## ℹ️ 一般建议 (P3)

### 代码质量

| 类型 | 数量 | 说明 |
|------|------|------|
| 警告 | 8 | 未使用的导入/变量、死代码 |
| 信息 | 25 | 不必要的 const、已弃用 API、跨异步 BuildContext 使用 |

**具体问题**:
- `milkdown_webview_editor.dart:492,945`: 死代码和空检查
- `milkdown_webview_editor.dart:953-963`: 使用已弃用的 Color 属性 (`color.red`, `color.green`, `color.blue`, `color.opacity`)
- 多处 `use_build_context_synchronously` 警告

### 测试覆盖

已有 17 个测试文件，覆盖：
- ✅ 模型层（markdown_file, milkdown_bridge）
- ✅ 提供者层（file_provider, settings_provider）
- ✅ 服务层（file_service, export_service）
- ⚠️ WebView 交互测试缺失
- ⚠️ 云同步服务测试缺失

### 架构亮点

1. **状态管理**: Provider 模式使用规范
2. **依赖注入**: FileProvider 支持注入 FileService，便于测试
3. **服务层抽象**: `SyncServiceInterface` 统一 WebDAV/FTP 接口
4. **国际化**: 完整的中英文支持
5. **主题系统**: 灵活的深浅主题配置
6. **撤销/重做**: 编辑器历史管理完善
7. **冲突处理**: 云同步预览和冲突解决机制

---

## ✅ 优秀实践

1. **密码存储**: 使用 `flutter_secure_storage` 安全存储凭据
2. **文件缓存**: LRU 缓存策略，限制 24 个文件
3. **国际化**: 完整的中英文支持
4. **主题系统**: 灵活的深浅主题配置
5. **撤销/重做**: 编辑器历史管理完善
6. **冲突处理**: 云同步预览和冲突解决机制

---

## 📊 修复优先级

| 优先级 | 问题 | 工作量 |
|--------|------|--------|
| 🔴 P0 | WebView 文件访问限制 | 2h |
| 🔴 P0 | 云同步路径验证 | 1h |
| 🟠 P1 | 移除或警告 FTP | 1h |
| 🟡 P2 | 分解大文件 | 8h |
| 🟡 P2 | 密码 getter 重构 | 2h |
| 🟢 P3 | 修复 lint 警告 | 2h |

---

## 已移除的模块

### 插件系统 (已删除)

在本次审查后，插件系统已被完全移除，原因如下：

1. **安全风险**: 插件签名验证未实现（`lib/plugins/plugin_security.dart:37` 有 TODO 注释）
2. **增加攻击面**: 动态加载外部代码增加了安全风险
3. **维护负担**: 插件系统代码复杂，需要持续维护
4. **功能重叠**: 核心功能已足够完善，插件扩展非必需

**删除的文件和目录**:
- `lib/plugins/` - 整个插件系统目录
- `lib/providers/plugin_provider.dart` - 插件状态管理
- `lib/screens/settings/plugin_settings_screen.dart` - 插件设置页面
- `test/plugins/` - 插件测试目录

---

## 总结

**汐 (Ushio-MD)** 是一个功能完整、架构清晰的 Flutter Markdown 编辑器。代码整体质量良好，遵循 Flutter 最佳实践。主要问题集中在：

1. **安全性**: WebView 和云同步存在高风险漏洞，需要优先修复
2. **测试**: 云同步功能标注为"未测试"，建议完善测试后再推广
3. **架构**: 核心编辑器文件较大，可考虑进一步模块化

建议在发布生产版本前修复 P0 级别的安全漏洞，并在 README 中明确云同步的 Beta 状态。
