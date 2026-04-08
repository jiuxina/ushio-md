# 汐 Markdown 编辑器 - 鲁棒性测试报告

**测试日期**: 2026-04-08  
**测试视角**: 恶意用户/边界情况/异常操作

---

## 🎯 测试场景分类

### 1. 文件系统攻击 💀

#### 1.1 路径遍历攻击
**测试场景**: 用户尝试使用 `../` 访问工作区外的文件

```dart
// 测试输入
文件名: "../../etc/passwd"
文件名: "../../../secret/keys.txt"
文件名: "....//....//sensitive"
```

**当前防护状态**: ⚠️ 部分防护

```dart
// lib/services/my_files_service.dart:310
// 检查文件是否在工作区内
Future<bool> isInWorkspace(String filePath) async {
  final workspacePath = await getWorkspacePath();
  return filePath.startsWith(workspacePath);
}
```

**问题**: 
- `startsWith` 检查可能被符号链接绕过
- 未规范化路径 (如 `/data/../data`)

**建议修复**:
```dart
Future<bool> isInWorkspace(String filePath) async {
  final workspacePath = await getWorkspacePath();
  final canonicalWorkspace = File(workspacePath).absolute.path;
  final canonicalFile = File(filePath).absolute.path;
  // 防止符号链接绕过
  try {
    final realWorkspace = await File(canonicalWorkspace).resolveSymbolicLinks();
    final realFile = await File(canonicalFile).resolveSymbolicLinks();
    return realFile.startsWith(realWorkspace);
  } catch (_) {
    return false;
  }
}
```

#### 1.2 特殊字符文件名
**测试场景**: 文件名包含特殊字符、控制字符

```
文件名: "test<>:\"|?*.md"      // Windows 非法字符
文件名: "test\x00null.md"       // 空字符
文件名: "test\nnewline.md"      // 换行符
文件名: "CON.md"                // Windows 保留名
文件名: ".hidden.md"            // 隐藏文件
文件名: " ".md                  // 纯空格
文件名: "".md                   // 空文件名
```

**当前防护状态**: ⚠️ 部分防护

```dart
// lib/widgets/milkdown_webview_editor.dart:503
String _sanitizeFileName(String name) {
  final normalized = name.replaceAll('\\', '/');
  final lastSegment = normalized.split('/').last.trim();
  return lastSegment;
}
```

**问题**:
- 仅处理了路径分隔符和 trim
- 未过滤 Windows 非法字符
- 未检查空文件名
- 未处理控制字符

**建议修复**:
```dart
String _sanitizeFileName(String name) {
  var sanitized = name.replaceAll('\\', '/').split('/').last.trim();
  
  // 移除 Windows 非法字符
  sanitized = sanitized.replaceAll(RegExp(r'[<>:"|?*]'), '_');
  
  // 移除控制字符
  sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1f]'), '');
  
  // Windows 保留名处理
  final reserved = ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'LPT1', ...];
  if (reserved.contains(sanitized.toUpperCase().split('.').first)) {
    sanitized = '_$sanitized';
  }
  
  // 空文件名回退
  if (sanitized.isEmpty || sanitized == '.md') {
    sanitized = 'untitled.md';
  }
  
  return sanitized;
}
```

#### 1.3 超大文件攻击
**测试场景**: 用户打开超大文件导致内存溢出

```
文件大小: 100MB .md 文件
文件大小: 1GB .md 文件
行数: 100万行
```

**当前防护状态**: ❌ 无防护

```dart
// lib/services/file_service.dart
Future<String> readFile(String path, {bool allowCache = false}) async {
  final file = File(path);
  final content = await file.readAsString(); // 直接读入内存！
  // ...
}
```

**问题**:
- 无文件大小限制
- 整个文件读入内存
- WebView 渲染超大内容可能崩溃

**建议修复**:
```dart
static const int maxFileSize = 10 * 1024 * 1024; // 10MB

Future<String> readFile(String path, {bool allowCache = false}) async {
  final file = File(path);
  
  // 检查文件大小
  final stat = await file.stat();
  if (stat.size > maxFileSize) {
    throw FileTooLargeException(
      '文件过大 (${(stat.size / 1024 / 1024).toStringAsFixed(1)}MB)，'
      '最大支持 ${maxFileSize ~/ 1024 ~/ 1024}MB'
    );
  }
  
  final content = await file.readAsString();
  // ...
}
```

#### 1.4 并发写入冲突
**测试场景**: 多个编辑器同时编辑同一文件

```
场景1: 两个标签页打开同一文件
场景2: 自动保存与手动保存冲突
场景3: 云同步时本地修改
```

**当前防护状态**: ⚠️ 部分防护

- 自动保存有定时器控制
- 无文件锁机制
- 无版本冲突检测

**建议**:
- 添加文件修改时间检测
- 实现冲突提示对话框
- 考虑使用文件锁

---

### 2. WebView 安全攻击 💀

#### 2.1 XSS 攻击
**测试场景**: Markdown 内容包含恶意脚本

```markdown
# 测试文档

<script>alert('XSS')</script>

<img src="x" onerror="alert('XSS')">

[点击](javascript:alert('XSS'))

<iframe src="javascript:alert('XSS')">
```

**当前防护状态**: ✅ 较好

Milkdown 编辑器使用 iframe 隔离，JavaScript 被沙箱化。

**验证点**:
```dart
// lib/widgets/milkdown_webview_editor.dart
// WebView 配置检查
```

**建议**:
- 确保 `javascript:` 协议被禁用
- 验证 `onerror` 等事件处理器被过滤
- 测试导出 HTML 时的 XSS 防护

#### 2.2 文件协议滥用
**测试场景**: 通过 WebView 读取本地敏感文件

```markdown
![image](file:///etc/passwd)
![image](file:///data/data/com.app/private.db)
```

**当前防护状态**: ⚠️ 需验证

**检查项**:
- WebView 是否允许 `file://` 协议
- 图片加载是否验证协议
- 导出功能是否包含敏感路径

---

### 3. 用户输入攻击 💀

#### 3.1 超长输入
**测试场景**: 各输入框输入超长字符串

```
文件名: 1000字符
搜索词: 10000字符
URL 输入: 10000字符
编辑器内容: 粘贴 1MB 文本
```

**当前防护状态**: ⚠️ 部分防护

```dart
// lib/utils/file_actions.dart:914
TextField(
  controller: controller,
  decoration: InputDecoration(
    errorText: errorText,
  ),
  // 无 maxLength 限制
)
```

**建议**:
- 添加 `maxLength` 限制
- 大文本粘贴时显示警告
- URL 验证长度限制

#### 3.2 正则表达式攻击
**测试场景**: 触发正则表达式回溯攻击

```markdown
# 搜索内容

aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!
```

**当前防护状态**: ⚠️ 需验证

```dart
// lib/screens/editor_screen.dart 搜索功能
final imageRegex = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
// 这个正则是否安全？
```

**建议**:
- 使用非回溯正则引擎
- 添加搜索超时机制
- 限制搜索字符串长度

---

### 4. 云同步攻击 💀

#### 4.1 凭证安全
**测试场景**: 云同步凭证泄露

```
攻击路径1: 通过日志获取密码
攻击路径2: 通过内存转储获取密码
攻击路径3: 通过备份文件获取密码
```

**当前防护状态**: ✅ 良好

```dart
// lib/providers/settings_provider.dart
final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
```

**优点**:
- 使用 FlutterSecureStorage
- Android 使用加密 SharedPreferences
- 密码不存储在普通 SharedPreferences

**建议**:
- 确保日志不包含密码
- 添加防调试机制
- 考虑证书锁定 (Certificate Pinning)

#### 4.2 中间人攻击
**测试场景**: WebDAV/FTP 传输被拦截

```
攻击场景: 公共 WiFi 拦截同步流量
```

**当前防护状态**: ⚠️ 需验证

**检查项**:
- WebDAV 是否强制 HTTPS
- FTP 是否支持 FTPS
- 是否验证服务器证书

---

### 5. 内存与性能攻击 💀

#### 5.1 内存泄漏
**测试场景**: 长时间使用后内存增长

```
操作: 打开/关闭编辑器 100 次
操作: 保存/自动保存 1000 次
操作: 搜索 100 次
```

**当前防护状态**: ✅ 良好

```dart
// 编辑器有 dispose 清理
@override
void dispose() {
  _textController.dispose();
  _searchController.dispose();
  _editScrollController.dispose();
  // ...
}
```

**潜在问题**:
- WebView 是否正确释放
- 图片缓存是否清理
- Stream 订阅是否取消

#### 5.2 CPU 耗尽
**测试场景**: 触发无限循环

```markdown
# 无限递归宏

\newcommand{\a}{\a\a}
\a
```

**当前防护状态**: ❌ 无防护

Milkdown 不支持 LaTeX 宏，但 Markdown 扩展可能导致问题。

---

### 6. Android 特有问题 💀

#### 6.1 权限绕过
**测试场景**: 无权限时尝试访问文件

```
场景: 用户拒绝存储权限后尝试打开文件
场景: 权限被系统回收后操作
```

**当前防护状态**: ✅ 良好

```dart
// lib/services/file_service.dart
Future<bool> requestPermissions() async {
  if (Platform.isAndroid) {
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }
    var status = await Permission.storage.request();
    // ...
  }
}
```

#### 6.2 Android 11+ 存储问题
**测试场景**: Android 11+ 访问公共目录

```
场景: 导入文件到 Documents 目录
场景: 新建文件写入路径
```

**当前防护状态**: ✅ 已修复 (v1.4.6)

#### 6.3 低存储空间
**测试场景**: 设备存储空间不足

```
场景: 保存大文件到几乎满的存储
场景: 创建文件时磁盘已满
```

**当前防护状态**: ⚠️ 部分防护

```dart
// 文件操作有 try-catch，但未专门处理磁盘空间错误
try {
  await file.writeAsString(content);
} catch (e) {
  // 通用错误处理
}
```

**建议**:
- 检测磁盘空间
- 提供更友好的错误提示
- 实现自动保存失败重试

---

### 7. 并发与竞态条件 💀

#### 7.1 快速点击
**测试场景**: 用户快速点击按钮

```
操作: 快速点击保存按钮 10 次
操作: 快速点击新建文件 10 次
操作: 快速切换编辑/预览模式
```

**当前防护状态**: ⚠️ 部分防护

```dart
// 保存有防抖
if (_isSaving) return;
setState(() => _isSaving = true);
```

**问题**:
- 不是所有操作都有防抖
- 快速切换 Tab 可能有状态残留

#### 7.2 异步操作取消
**测试场景**: 页面退出时异步操作未完成

```
操作: 打开文件后立即退出
操作: 导出 PDF 时退出
操作: 同步时退出
```

**当前防护状态**: ✅ 良好

```dart
// 大部分异步操作有 mounted 检查
if (!mounted) return;
```

---

## 📊 风险评估矩阵

| 风险项 | 严重性 | 可能性 | 当前防护 | 优先级 |
|--------|--------|--------|----------|--------|
| 路径遍历 | 高 | 中 | ⚠️ 部分 | P1 |
| 特殊字符文件名 | 中 | 高 | ⚠️ 部分 | P2 |
| 超大文件 | 高 | 中 | ❌ 无 | P1 |
| XSS 攻击 | 高 | 低 | ✅ 良好 | P3 |
| 凭证泄露 | 高 | 低 | ✅ 良好 | P3 |
| 正则回溯 | 中 | 低 | ⚠️ 需验证 | P2 |
| 磁盘空间 | 中 | 中 | ⚠️ 部分 | P2 |
| 快速点击 | 低 | 高 | ⚠️ 部分 | P3 |

---

## ✅ 推荐修复优先级

### P1 - 立即修复

1. **文件大小限制**
   ```dart
   // 在 readFile 前检查文件大小
   static const maxFileSize = 10 * 1024 * 1024; // 10MB
   ```

2. **路径规范化**
   ```dart
   // 使用 canonicalizePath 或 absolute.path
   final safePath = File(filePath).absolute.path;
   ```

### P2 - 短期修复

1. **文件名验证**
   ```dart
   // 添加完整的文件名验证函数
   String validateFileName(String name) { ... }
   ```

2. **输入长度限制**
   ```dart
   TextField(maxLength: 255)
   ```

3. **磁盘空间检查**
   ```dart
   // 保存前检查可用空间
   if (await getAvailableSpace() < content.length * 2) { ... }
   ```

### P3 - 中期改进

1. **防抖优化**
2. **日志脱敏**
3. **性能监控**

---

## 🧪 建议添加的测试用例

```dart
group('文件系统安全性', () {
  test('路径遍历防护', () async {
    final result = await service.isInWorkspace('../../etc/passwd');
    expect(result, isFalse);
  });
  
  test('特殊字符文件名', () {
    final sanitized = service.sanitizeFileName('test<>:"|?*.md');
    expect(sanitized, equals('test_______.md'));
  });
  
  test('空文件名处理', () {
    final sanitized = service.sanitizeFileName('');
    expect(sanitized, equals('untitled.md'));
  });
});

group('文件大小限制', () {
  test('超大文件拒绝', () async {
    // 创建 20MB 文件
    expect(() => service.readFile(largeFilePath), throwsException);
  });
});

group('用户输入验证', () {
  test('超长输入截断', () {
    // 输入 10000 字符
    expect(validateInput(longInput), hasLength(lessThan(1000)));
  });
  
  test('XSS 防护', () {
    final content = '<script>alert("XSS")</script>';
    expect(sanitizeMarkdown(content), isNot(contains('<script>')));
  });
});
```

---

*测试报告生成时间: 2026-04-08 08:10*
