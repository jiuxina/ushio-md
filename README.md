# 汐 - Android Markdown Editor ✨

<p align="center">
  <img src="app.png" width="180" alt="汐 Logo">
</p>
<p align="center">
  <b>一款简洁优雅的安卓端 Markdown 编辑器</b><br>
  Markdown支持 · 文件管理 · 个性化设置 · 云同步 
</p>


<p align="center">
  <a href="https://github.com/jiuxina/ushio-md/stargazers">
    <img src="https://img.shields.io/github/stars/jiuxina/ushio-md?style=social" alt="GitHub stars">
  </a>
  <a href="https://github.com/jiuxina/ushio-md/network/members">
    <img src="https://img.shields.io/github/forks/jiuxina/ushio-md?style=social" alt="GitHub forks">
  </a>
  <a href="https://github.com/jiuxina/ushio-md/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/jiuxina/ushio-md" alt="GitHub license">
  </a>
  <a href="https://www.android.com">
    <img src="https://img.shields.io/badge/platform-Android-brightgreen" alt="Platform Android">
  </a>
</p>

## 目录

- [功能特性](#✨-功能特性)
- [截图展示](#📱-截图展示)
- [安装](#📦-安装)
- [权限说明](#📋-权限说明)
- [Markdown 支持](#🎯-markdown-支持)
- [贡献](#🤝-贡献)
- [开源协议](#📄-开源协议)
- [作者](#👨‍💻-作者)

## ✨ 功能特性

### 📝 编辑功能
- 完整 Markdown 语法支持（粗体、斜体、删除线、标题、列表、表格等）
- 三种查看模式：编辑 / 预览 / 分屏
- 自动保存，可自定义间隔
- 快捷工具栏，快速插入常用格式
- 智能目录导航，快速跳转章节
- 全文搜索，高亮匹配结果
- 代码高亮显示，支持多种语言
- 此外，请等待后续更新……

### 📁 文件管理
- 本地文件 & 文件夹浏览，支持搜索、排序、新建
- 最近文件/文件夹快速访问
- 长按置顶 + 拖拽排序，首页更整洁
- 一键清除最近记录
- 多种排序方式：名称、修改时间、自定义顺序
- 智能过滤：自动清理不存在的文件引用
- 输入验证：重命名时自动检测非法字符
- 此外，请等待后续更新……

### 🎨 个性化设置
- 主题模式：跟随系统 / 浅色 / 深色
- 8 种精选主题色 + 多套明暗主题方案
- 自定义背景图片，支持模糊效果
- 内置字体 + 支持导入本地字体
- 字体大小 12-24px 自由调节
- 粒子效果：樱花、雨滴、萤火虫、雪花
- 粒子速率 0.1x-1.0x 可调
- 全局显示开关，可单独控制编辑器区域
- 此外，请等待后续更新……

### ☁️ 云端同步
- WebDAV 协议，兼容主流网盘
- 智能冲突检测，支持手动解决
- 同步预览，明确上传/下载文件
- 安全存储：密码加密保护
- 自动同步 + 手动触发
- 此外，请等待后续更新……

### 🧩 插件系统
- 声明式插件架构，安全稳定
- 支持工具栏、主题、预览样式等 10 大扩展点
- 内置官方插件市场，一键安装/更新
- 支持 GitHub 风格 Alert 渲染（NOTE/TIP/WARNING）
- 开发者友好，提供完整开发文档
- 详情请查阅： [插件系统](https://github.com/jiuxina/ushio-md-plugins)

### 📤 分享导出
- 文件夹压缩分享（ZIP 格式）
- PDF 导出，支持中文字体
- WYSIWYG 图片导出（含背景、粒子效果）
- 全屏预览模式一键分享
- 此外，请等待后续更新……

## 📱 截图展示
> 可能过时

| 首页 | 编辑器 | 设置 |
|:---:|:---:|:---:|
| 快速操作、置顶文件 | 预览模式、目录导航 | 主题色、背景设置 |
| <img src="sample\1.png" alt="1" style="zoom: 25%;" /> | <img src="sample\2.png" alt="1" style="zoom: 25%;" /> | <img src="sample\3.png" alt="1" style="zoom: 25%;" /> |

## 📦 安装

1. 前往 [Releases](https://github.com/jiuxina/ushio-md/releases) 下载最新 APK
2. 安装后授予存储权限
3. 立即开始你的 Markdown 之旅～

## 📋 权限说明

| 权限         | 用途                    |
| ------------ | ----------------------- |
| 存储权限     | 读取/保存 Markdown 文件 |
| 管理所有文件 | 访问设备任意文件夹      |

## 🎯 Markdown 支持

| 语法       | 示例             | 效果         |
| ---------- | ---------------- | ------------ |
| **粗体**   | `**文字**`       | **文字**     |
| *斜体*     | `*文字*`         | *文字*       |
| ~~删除线~~ | `~~文字~~`       | ~~文字~~     |
| # 标题     | `# 标题`         | 大标题       |
| 引用       | `> 内容`         | 引用块       |
| 代码       | `` `代码` ``     | `代码`       |
| 代码块     | `````            | 代码块       |
| 链接       | `[文字](URL)`    | [文字](URL)  |
| 图片       | `![alt](URL)`    | 图片         |
| 无序列表   | `- 项目`         | • 项目       |
| 有序列表   | `1. 项目`        | 1. 项目      |
| 任务列表   | `- [ ] 待办`     | ☐ 待办       |
| 分隔线     | `---`            | ---          |
| 表格       | `\| 列 \| 列 \|` | 完整表格支持 |

## 🤝 贡献

发现 bug、想加新功能、优化体验，或者单纯想打个招呼，都欢迎提交 Issue 或 Pull Request 的说~

## 📄 开源协议

[MIT License](https://github.com/jiuxina/ushio-md/blob/main/LICENSE)

## 👨‍💻 作者

**jiuxina**  

Made with ❤️ by Me & You
