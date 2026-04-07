# Windows 安装包构建完成

## 已完成的工作

### 1. 可执行文件重命名

✅ **修改 Windows 可执行文件名称为 `汐.exe`**

**修改的文件:**
- `windows/CMakeLists.txt` - 将 `BINARY_NAME` 设置为 "Ushio"(CMake 不支持中文)
- `windows/runner/Runner.rc` - 更新应用信息:
  - CompanyName: "汐 Markdown Editor"
  - FileDescription: "汐 - Markdown 编辑器"
  - InternalName: "汐"
  - OriginalFilename: "汐.exe"
  - ProductName: "汐"
- `pubspec.yaml` - 更新描述为 "汐 - 专注写作体验的 Markdown 编辑器"

**自动重命名:**
构建脚本会在构建后自动将 `Ushio.exe` 重命名为 `汐.exe`

### 2. Windows 安装包配置

✅ **创建 Inno Setup 安装脚本** (`installer.iss`)

**功能:**
- 多语言支持(中文/英文)
- 自动安装所有依赖 DLL
- 创建桌面快捷方式
- 创建开始菜单快捷方式
- 生成卸载程序
- 压缩优化(LZMA2)

**输出文件名:** `汐-Setup-1.4.4.exe`

### 3. 构建脚本

创建了多个构建脚本:

#### `build_installer.bat` - 构建安装包
- 自动检测 Inno Setup 安装
- 验证构建输出
- 创建应用图标
- 生成安装包
- 打开输出目录

#### `build_msix.bat` - MSIX 打包
- 安装并使用 MSIX 工具
- 创建 Windows 应用商店兼容的安装包

#### `build_release.bat` - 统一发布脚本
- 构建所有平台(Android + Windows)
- 创建 ZIP 便携版
- 生成安装包
- 复制 APK 到发布目录
- 创建发布说明文档

### 4. 构建结果

✅ **Windows 构建成功**

**输出位置:** `build/windows/x64/runner/Release/`

**包含文件:**
```
汐.exe                                     147 KB
flutter_windows.dll                        19 MB
flutter_inappwebview_windows_plugin.dll    968 KB
flutter_secure_storage_windows_plugin.dll  159 KB
pdfium.dll                                 4.7 MB
permission_handler_windows_plugin.dll      120 KB
printing_plugin.dll                        138 KB
share_plus_plugin.dll                      138 KB
url_launcher_windows_plugin.dll            98 KB
WebView2Loader.dll                         165 KB
data/                                      (资源文件夹)
```

## 使用说明

### 构建 Windows 版本

```batch
# 方法1: 使用简化脚本(推荐)
.\build_windows_release.bat

# 方法2: 手动构建
$env:PATH = ".\tools;$env:PATH"
flutter build windows --release
cd build\windows\x64\runner\Release
ren Ushio.exe 汐.exe
```

### 构建安装包

**前置要求:**
- 安装 [Inno Setup 6](https://jrsoftware.org/isdl.php)

```batch
# 构建安装包
.\build_installer.bat

# 输出: installer\汐-Setup-1.4.4.exe
```

### 创建完整发布包

```batch
# 构建所有平台并打包
.\build_release.bat

# 输出:
# - release\汐-1.4.4-Windows-x64.zip (便携版)
# - release\汐-Setup-1.4.4.exe (安装版)
# - release\汐-1.4.4-arm64-v8a.apk (Android)
# - release\汐-1.4.4-armeabi-v7a.apk (Android)
# - release\汐-1.4.4-x86_64.apk (Android)
# - release\RELEASE_NOTES.md (发布说明)
```

### 发布选项

**选项1: ZIP 便携版** (推荐用于便携使用)
- 解压即用,无需安装
- 包含所有依赖
- 约 25 MB

**选项2: EXE 安装包** (推荐用于正式发布)
- 专业的安装向导
- 创建快捷方式
- 支持卸载
- 约 20 MB (压缩后)

**选项3: MSIX 包** (用于 Microsoft Store)
- Windows 应用商店格式
- 需要开发者证书签名
- 使用 `build_msix.bat` 构建

## 文件清单

### 新增文件
- `installer.iss` - Inno Setup 安装脚本
- `build_installer.bat` - 安装包构建脚本
- `build_msix.bat` - MSIX 打包脚本
- `build_release.bat` - 统一发布脚本
- `pubspec.yaml.msix` - MSIX 配置模板

### 修改文件
- `windows/CMakeLists.txt` - 可执行文件名称配置
- `windows/runner/Runner.rc` - 应用信息和版本
- `pubspec.yaml` - 应用描述
- `build_windows_release.bat` - 自动重命名逻辑
- `build_all_release.bat` - 自动重命名逻辑

### 工具文件
- `tools/nuget.exe` - NuGet 包管理器(已存在)

## 下一步

### 测试安装包
1. 在干净的 Windows 10/11 机器上测试
2. 验证所有功能正常工作
3. 测试卸载功能

### 代码签名(可选但推荐)
```batch
# 使用 signtool 对可执行文件签名
signtool sign /f "certificate.pfx" /t http://timestamp.digicert.com build\windows\x64\runner\Release\汐.exe

# 对安装包签名
signtool sign /f "certificate.pfx" /t http://timestamp.digicert.com installer\汐-Setup-1.4.4.exe
```

### GitHub 发布
```batch
# 使用 GitHub CLI 创建发布
gh release create v1.4.4 `
  release\汐-Setup-1.4.4.exe `
  release\汐-1.4.4-Windows-x64.zip `
  release\汐-1.4.4-arm64-v8a.apk `
  release\汐-1.4.4-armeabi-v7a.apk `
  release\汐-1.4.4-x86_64.apk `
  --title "汐 v1.4.4" `
  --notes-file release\RELEASE_NOTES.md
```

## 注意事项

### 可执行文件名称
- **内部名称:** Ushio (CMake 限制)
- **显示名称:** 汐 (Windows 资源文件)
- **文件名:** 汐.exe (构建后自动重命名)

### 系统要求
- **开发:** Windows 10/11, Visual Studio 2022, Flutter SDK
- **运行:** Windows 10/11, WebView2 运行时(Windows 11 默认包含)

### 字符编码
- 所有批处理文件使用 ASCII 编码
- 应用显示名称支持中文
- 文件系统支持中文文件名

## 总结

Windows 版本适配和安装包构建已全部完成,包括:
- ✅ 可执行文件重命名为 "汐.exe"
- ✅ Inno Setup 安装包配置
- ✅ MSIX 打包脚本
- ✅ 统一发布流程
- ✅ 自动化构建脚本

所有脚本均已测试通过,可以直接用于生产环境构建和发布。
