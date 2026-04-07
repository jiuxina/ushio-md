# 快速开始指南

## Windows 用户

### 方式一: 便携版 (推荐)
1. 下载 `汐-1.4.4-Windows-x64.zip`
2. 解压到任意目录
3. 双击 `汐.exe` 启动

### 方式二: 安装版
1. 下载 `汐-Setup-1.4.4.exe`
2. 运行安装程序
3. 按照向导完成安装
4. 从开始菜单或桌面快捷方式启动

### 系统要求
- Windows 10/11 (64-bit)
- WebView2 运行时 (Windows 11 默认包含)

### 工作区位置
默认工作区: `C:\Users\{用户名}\Documents\Ushio-md`

## Android 用户

### 安装
1. 下载对应的 APK 文件:
   - `汐-1.4.4-arm64-v8a.apk` - 推荐(大多数现代设备)
   - `汐-1.4.4-armeabi-v7a.apk` - 旧款 32 位设备
   - `汐-1.4.4-x86_64.apk` - 模拟器/x86 设备
2. 安装 APK
3. 授予文件访问权限

### 系统要求
- Android 5.0+ (API 21)

### 工作区位置
默认工作区: `/storage/emulated/0/Documents/Ushio-md`

## 开发者

### 构建 Windows 版本
```batch
# 方式一: 使用构建脚本
.\build_windows_release.bat

# 方式二: 手动构建
flutter build windows --release
cd build\windows\x64\runner\Release
ren Ushio.exe 汐.exe
```

### 构建 Android 版本
```batch
# 分架构 APK (推荐)
.\build_abi_release.bat

# 通用 APK
flutter build apk --release
```

### 构建安装包
```batch
# 需要先安装 Inno Setup 6
.\build_installer.bat

# 或创建完整发布
.\build_release.bat
```

### 构建所有平台
```batch
# Windows + Android
.\build_all_release.bat

# 仅 Windows
.\build_all_release.bat windows

# 仅 Android
.\build_all_release.bat android
```

## 常见问题

### Q: Windows 提示缺少 WebView2?
A: 下载并安装 [WebView2 运行时](https://developer.microsoft.com/en-us/microsoft-edge/webview2/)

### Q: Android 提示无法访问文件?
A: 在设置中授予应用文件访问权限

### Q: 如何修改工作区位置?
A: 在应用设置中更改工作区路径

### Q: 如何导入外部 Markdown 文件?
A: 
- Windows: 文件 → 打开 → 选择文件
- Android: 使用文件管理器打开文件,选择用"汐"打开

### Q: 数据会丢失吗?
A: 所有文件保存在本地工作区,不会丢失。建议定期备份。

## 技术支持

- GitHub Issues: https://github.com/jiuxina/ushio-md/issues
- 文档: 项目 `docs/` 目录

## 平台支持矩阵

| 功能 | Android | Windows | macOS | Linux | iOS |
|------|---------|---------|-------|-------|-----|
| Markdown 编辑 | ✅ | ✅ | 🔄 | 🔄 | 🔄 |
| 文件管理 | ✅ | ✅ | 🔄 | 🔄 | 🔄 |
| 云同步 | ✅ | ✅ | 🔄 | 🔄 | 🔄 |
| 导出 PDF | ✅ | ✅ | 🔄 | 🔄 | 🔄 |
| 导出图片 | ✅ | ✅ | 🔄 | 🔄 | 🔄 |

✅ = 已支持
🔄 = 待测试
❌ = 不支持

## 更新日志

### v1.4.4
- ✅ 添加 Windows 平台支持
- ✅ 跨平台路径适配
- ✅ 可执行文件重命名为"汐.exe"
- ✅ Windows 安装包
- ✅ 统一构建脚本
