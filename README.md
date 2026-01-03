# 汐 - Markdown 编辑器

<p align="center">
  <img src="app.png" width="100" alt="汐 Logo">
</p>

<p align="center">
  <b>一款简洁优雅的移动端 Markdown 编辑器</b>
</p>

## ✨ 功能特性

### 📝 编辑功能
- **Markdown 语法支持** - 粗体、斜体、删除线、标题、列表等
- **实时预览** - 编辑/预览/分屏三种模式
- **目录导航 (TOC)** - 自动提取标题，点击跳转
- **自动保存** - 可自定义保存间隔
- **Markdown 工具栏** - 快速插入格式符号

### 📁 文件管理
- **文件浏览** - 浏览手机存储中的 Markdown 文件
- **文件夹浏览** - 独立页面展示文件夹内容，支持搜索和排序
- **最近文件** - 快速访问最近打开的文件
- **最近文件夹** - 快速访问最近访问的文件夹
- **置顶功能** - 长按文件/文件夹置顶到首页
- **拖拽排序** - 拖动置顶项目调整顺序
- **新建文件/文件夹** - 快速创建新的文档
- **清除记录** - 一键清除最近文件/文件夹记录

### 🎨 个性化设置
- **主题切换** - 跟随系统/浅色/深色模式
- **主题色选择** - 8种精选主题色可选
- **背景图片** - 自定义背景图片
  - 模糊效果 - 可调节模糊度
- **字体大小** - 12-24px 可调

### 🚀 用户体验
- **底部导航** - 首页/最近文件/最近文件夹/设置
- **方向感美动画** - 左向滑入或右向滑入的 Tab 切换动画
- **毛玻璃效果** - 精美的玻璃态 UI 设计
- **渐变背景** - 优雅的色彩过渡

## 📱 截图

| 首页 | 编辑器 | 设置 |
|:---:|:---:|:---:|
| 快速操作、置顶文件 | 预览模式、目录导航 | 主题色、背景设置 |

## 🛠️ 技术栈

- **Flutter** - 跨平台 UI 框架
- **Provider** - 状态管理
- **flutter_markdown** - Markdown 渲染
- **file_picker** - 文件选择
- **shared_preferences** - 本地存储
- **permission_handler** - 权限管理
- **url_launcher** - 外部链接

## 📦 安装

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/jiuxina/mdreader.git
cd mdreader

# 安装依赖
flutter pub get

# 运行调试版
flutter run

# 构建 APK
flutter build apk --release
```

### 直接下载

前往 [Releases](https://github.com/jiuxina/mdreader/releases) 页面下载最新 APK。

## 📋 权限说明

| 权限 | 用途 |
|-----|------|
| 存储权限 | 读取和保存 Markdown 文件 |
| 管理所有文件 | 访问设备上的所有文件夹 |

## 🗂️ 项目结构

```
lib/
├── main.dart              # 应用入口
├── models/                # 数据模型
│   └── markdown_file.dart
├── providers/             # 状态管理
│   ├── file_provider.dart
│   └── settings_provider.dart
├── screens/               # 页面
│   ├── main_screen.dart
│   ├── editor_screen.dart
│   ├── folder_browser_screen.dart
│   └── settings_screen.dart
├── services/              # 服务层
│   └── file_service.dart
├── utils/                 # 工具类
│   └── constants.dart
└── widgets/               # 组件
    └── markdown_toolbar.dart
```

## 🎯 Markdown 支持

| 语法 | 快捷键 |
|-----|-------|
| **粗体** | `**文字**` |
| *斜体* | `*文字*` |
| ~~删除线~~ | `~~文字~~` |
| # 标题 | `# ~ ###` |
| 引用 | `> 内容` |
| 代码 | `` `代码` `` |
| 代码块 | ` ``` ` |
| 链接 | `[文字](URL)` |
| 图片 | `![描述](URL)` |
| 列表 | `- 项目` |
| 有序列表 | `1. 项目` |
| 任务 | `- [ ] 待办` |
| 分隔线 | `---` |
| 表格 | 支持 |

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 开源协议

MIT License

## 👨‍💻 作者

**jiuxina**

---

<p align="center">
  Made with ❤️ using Flutter
</p>
