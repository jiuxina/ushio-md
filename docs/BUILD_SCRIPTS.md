# 构建脚本说明

## 一键构建脚本

### build_all_release.bat - 统一构建脚本

支持构建 Android 和 Windows 版本,使用以下命令:

```batch
# 构建所有平台(Android + Windows)
build_all_release.bat

# 仅构建 Android
build_all_release.bat android

# 仅构建 Windows
build_all_release.bat windows

# 构建所有平台(显式指定)
build_all_release.bat all
```

**构建流程:**
1. 同步 Milkdown Web 运行时
2. 清理项目
3. 获取依赖
4. 生成应用图标
5. 构建目标平台
6. 打开输出目录

**输出位置:**
- Android APK: `build\app\outputs\flutter-apk\`
- Windows EXE: `build\windows\x64\runner\Release\`

---

## 平台专用构建脚本

### build_abi_release.bat - Android APK 构建

构建分架构的 Android APK (arm64-v8a, armeabi-v7a, x86_64)

**优点:**
- 每个 APK 体积更小
- 用户只下载适合其设备的版本

**输出:**
- `app-arm64-v8a-release.apk` - 适用于 64 位 ARM 设备
- `app-armeabi-v7a-release.apk` - 适用于 32 位 ARM 设备
- `app-x86_64-release.apk` - 适用于 x86_64 模拟器/设备

---

### build_flutter_release.bat - 多平台构建

同时构建 Android 和 Windows 版本

---

### build_windows_release.bat - Windows 独立构建

仅构建 Windows 版本

---

## Windows 平台适配说明

### 系统要求

- Windows 10/11 (64-bit)
- Visual Studio 2022 with C++ workload
- Flutter SDK 3.9.2+

### 已配置项

✅ Windows 应用图标 (256x256)
✅ 应用版本信息 (1.4.4+7)
✅ 公司名称和版权信息
✅ Unicode 支持
✅ C++17 标准

### 依赖项检查

运行以下命令检查环境:

```batch
flutter doctor
```

确保 Windows toolchain 显示 ✓

### 已知问题

1. **WebView 支持**
   - Windows 使用 `flutter_inappwebview` 插件
   - 需要确保 WebView2 运行时已安装 (Windows 11 默认包含)

2. **文件权限**
   - Windows 版本需要文件访问权限
   - 首次运行可能需要用户授权

3. **安全软件**
   - 某些杀毒软件可能误报
   - 建议添加到白名单或使用代码签名

### 打包发布

#### 生成 MSIX 安装包 (推荐)

```batch
# 安装 MSIX 打包工具
flutter pub global activate msix

# 生成 MSIX 安装包
flutter pub run msix:create
```

#### ZIP 分发包

构建完成后,直接打包 `build\windows\x64\runner\Release\` 目录:

```batch
# 使用 PowerShell 压缩
Compress-Archive -Path "build\windows\x64\runner\Release\*" -DestinationPath "mdreader-windows-1.4.4.zip"
```

### 代码签名 (可选但推荐)

```batch
# 使用 signtool 签名
signtool sign /f "path\to\certificate.pfx" /p password /t http://timestamp.digicert.com "build\windows\x64\runner\Release\mdreader.exe"
```

---

## 常见问题

### Q: 构建失败 "Visual Studio not found"
A: 安装 Visual Studio 2022 并选择以下工作负载:
- 使用 C++ 的桌面开发
- Windows 10/11 SDK

### Q: 如何更新版本号?
A: 编辑 `pubspec.yaml` 文件中的 `version` 字段:
```yaml
version: 1.4.4+7
# 格式: version_name+version_code
```

### Q: Windows 版本文件放在哪里?
A: Windows 版本会自动从以下位置读取用户文件:
- 文档目录
- 桌面
- 下载目录
- 用户指定的自定义目录

### Q: 如何启用调试日志?
A: 使用 debug 模式构建:
```batch
flutter build windows --debug
```

---

## 版本历史

- **v1.4.4 (Build 7)** - 当前版本
  - 添加 Windows 平台支持
  - 统一构建脚本
  - Windows 应用图标配置

---

## 相关链接

- [Flutter Windows 桌面支持](https://docs.flutter.dev/desktop)
- [Windows 应用打包](https://docs.microsoft.com/en-us/windows/msix/)
- [代码签名最佳实践](https://docs.microsoft.com/en-us/windows/win32/seccrypto/cryptography-tools)
