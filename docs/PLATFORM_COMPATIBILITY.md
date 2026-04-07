# 平台适配说明

## 已完成的跨平台适配

### 1. 工作区路径适配

**问题**: 原代码硬编码了 Android 路径 `/storage/emulated/0/Documents`，在 Windows/macOS/Linux/iOS 上无法使用。

**解决方案**: 创建了 `PlatformAdapter` 工具类，为每个平台提供合适的默认路径。

**新增文件**: `lib/utils/platform_adapter.dart`

#### 平台默认路径

| 平台 | 默认工作区路径 | 说明 |
|------|---------------|------|
| Android | `/storage/emulated/0/Documents/Ushio-md` | 外部存储 Documents 目录 |
| Windows | `C:\Users\{用户名}\Documents\Ushio-md` | 用户文档目录 |
| macOS | `~/Documents/Ushio-md` | 用户文档目录 |
| Linux | `~/Documents/Ushio-md` | 用户文档目录 |
| iOS | `App Documents/Ushio-md` | 应用沙盒文档目录 |

### 2. 存储权限适配

**原代码**: `file_service.dart` 已正确实现
- Android: 请求存储权限
- iOS/macOS/Windows/Linux: 默认返回 true (无需权限)

### 3. 文件路径分隔符

**原代码**: 已正确使用 `Platform.pathSeparator`
- 自动适配不同平台的路径分隔符 (`/` 或 `\`)

### 4. 平台检测工具

新增 `PlatformAdapter` 类提供以下方法:

```dart
// 获取默认工作区基础路径
static Future<String> getDefaultWorkspaceBasePath()

// 获取平台名称
static String getPlatformName()

// 检查是否是移动平台
static bool isMobile()

// 检查是否是桌面平台
static bool isDesktop()

// 获取应用数据目录
static Future<String> getAppDataDirectory()

// 获取临时目录
static Future<String> getTempDirectory()

// 获取下载目录路径
static String? getDownloadsDirectoryPath()

// 获取桌面目录路径
static String? getDesktopDirectoryPath()

// 规范化路径分隔符
static String normalizePath(String path)

// 获取文件名
static String getFileName(String path)

// 获取父目录路径
static String getParentPath(String path)
```

## 修改的文件

### 1. `lib/utils/platform_adapter.dart` (新增)
- 平台适配工具类
- 提供跨平台路径和目录访问

### 2. `lib/services/my_files_service.dart`
**修改前**:
```dart
final externalDir = await getExternalStorageDirectory();
if (externalDir == null) {
  throw Exception('无法获取外部存储目录');
}
```

**修改后**:
```dart
Future<Directory?> _getDefaultDocumentsDirectory() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return await getApplicationDocumentsDirectory();
  } else if (Platform.isAndroid) {
    return await getExternalStorageDirectory();
  } else if (Platform.isIOS) {
    return await getApplicationDocumentsDirectory();
  }
  return null;
}
```

### 3. `lib/providers/settings_provider.dart`
**修改前**:
```dart
String? _customWorkspaceBasePath = '/storage/emulated/0/Documents';
```

**修改后**:
```dart
String? _customWorkspaceBasePath; // 初始化时动态设置

// 在 initialize() 中
final savedCustomPath = prefs.getString('custom_workspace_base_path');
if (savedCustomPath != null && savedCustomPath.isNotEmpty) {
  _customWorkspaceBasePath = savedCustomPath;
} else {
  _customWorkspaceBasePath = await PlatformAdapter.getDefaultWorkspaceBasePath();
}
```

## 测试清单

### Windows ✅
- [x] 应用可以正常启动
- [x] 工作区创建在 `Documents\Ushio-md`
- [x] 文件读写正常
- [x] 可执行文件名称为 `汐.exe`

### Android (待测试)
- [ ] 工作区创建在 `/storage/emulated/0/Documents/Ushio-md`
- [ ] 存储权限请求正常
- [ ] 文件读写正常

### macOS (待测试)
- [ ] 工作区创建在 `~/Documents/Ushio-md`
- [ ] 文件读写正常

### Linux (待测试)
- [ ] 工作区创建在 `~/Documents/Ushio-md`
- [ ] 文件读写正常

### iOS (待测试)
- [ ] 工作区创建在应用沙盒 Documents 目录
- [ ] 文件读写正常

## 平台特定功能

### Android
- 存储权限管理 (`Permission.storage`, `Permission.manageExternalStorage`)
- 外部存储访问
- 分享功能

### Windows
- 无需特殊权限
- 文件系统直接访问
- 现代文件选择器

### macOS/iOS
- 沙盒限制
- 应用文档目录
- 权限描述需要配置

### Linux
- 无需特殊权限
- 文件系统直接访问
- 遵循 XDG 基础目录规范

## 已知问题

### 1. WebView2 运行时
**平台**: Windows
**问题**: 应用依赖 WebView2 运行时
**解决方案**: Windows 11 默认包含，Windows 10 用户需要安装

### 2. 路径长度限制
**平台**: Windows
**问题**: Windows 有 260 字符路径限制
**解决方案**: 已使用正确的路径分隔符，但可能需要启用长路径支持

### 3. 文件权限
**平台**: Linux
**问题**: 可能需要执行权限
**解决方案**: 确保打包时设置正确的文件权限

## 未来改进

### 1. 平台特性优化
- [ ] Windows: 支持系统托盘
- [ ] macOS: 支持 Touch Bar
- [ ] Linux: 支持系统托盘 (AppIndicator)
- [ ] Android: 支持存储访问框架 (SAF)
- [ ] iOS: 支持 iCloud 同步

### 2. 性能优化
- [ ] 桌面平台: 优化大文件处理
- [ ] 移动平台: 优化内存使用

### 3. UI 适配
- [ ] 桌面平台: 响应式布局优化
- [ ] 移动平台: 手势优化
- [ ] 平板: 双栏布局

## 构建各平台版本

### Windows
```batch
.\build_windows_release.bat
```

### Android
```batch
.\build_abi_release.bat
```

### macOS (需要 Mac 设备)
```bash
flutter build macos --release
```

### Linux (需要 Linux 环境)
```bash
flutter build linux --release
```

### iOS (需要 Mac + Xcode)
```bash
flutter build ios --release
```

## 相关文档

- [Windows 构建说明](./WINDOWS_BUILD_COMPLETE.md)
- [安装包创建说明](./WINDOWS_INSTALLER_COMPLETE.md)
- [构建脚本说明](./BUILD_SCRIPTS.md)
