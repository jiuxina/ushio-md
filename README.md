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
- [WebView + Milkdown 详细设计（LLD）](#🧩-webview--milkdown-详细设计lld)
- [安装](#📦-安装)
- [已知问题](#⚠️-已知问题)
- [权限说明](#📋-权限说明)
- [Markdown 支持](#🎯-markdown-支持)
- [贡献](#🤝-贡献)
- [开源协议](#📄-开源协议)
- [作者](#👨‍💻-作者)

## ✨ 功能特性

### 📝 编辑功能
- 完整 Markdown 语法支持（粗体、斜体、删除线、标题、列表、表格等）
- 三种查看模式：编辑 / 预览 / 分屏
- 基于 WebView 的高保真预览渲染
- 预览模式单击段落/表格单元格，直接原地编辑（含代码块、表格、多行引用与嵌套标记）
- 自动保存，可自定义间隔
- 快捷工具栏，快速插入常用格式
- 智能目录导航，快速跳转章节
- 全文搜索，高亮匹配结果
- 代码高亮显示，支持多种语言
- KaTeX 数学公式渲染（`$$...$$` / `$...$`）
- 视频/音频链接自动渲染为 HTML5 播放器（.mp4/.mp3 等）

### 📁 文件管理
- 本地文件 & 文件夹浏览，支持搜索、排序、新建
- 最近文件/文件夹快速访问
- 长按置顶 + 拖拽排序，首页更整洁
- 一键清除最近记录
- 多种排序方式：名称、修改时间、自定义顺序
- 智能过滤：自动清理不存在的文件引用
- 输入验证：重命名时自动检测非法字符
- 外部文件导入：
- 可选"仅查看"（目前无法对源文档作修改）或"导入"（连同引用图片一起复制到工作区）

### 🎨 个性化设置
- 主题模式：跟随系统 / 浅色 / 深色
- 12 种精选主题色
- 5 套浅色主题方案（经典白、暖纸色、冷灰色、天空蓝、薄荷绿）
- 6 套深色主题方案（柔和暗灰、舒适暖灰、午夜深蓝、深邃极夜、经典黑、极致纯黑）
- 自定义背景图片，支持模糊效果
- 界面字体 / 编辑器字体 / 代码字体分别设置，支持导入本地字体
- 字体大小 6–80px 自由调节
- 粒子效果：樱花、雨滴、萤火虫、雪花
- 粒子速率 0.1x–1.0x 可调
- 全局显示开关，可单独控制编辑器区域
- 底部导航栏透明度调节

### ☁️ 云端同步（待测试，可能不可用）
- WebDAV 协议，兼容主流网盘
- FTP 协议支持
- 智能冲突检测，支持手动解决
- 同步预览，明确上传/下载文件
- 安全存储：密码加密保护（使用 Android EncryptedSharedPreferences）
- 自动同步 + 手动触发

### 🧩 插件系统（待测试，可能不可用）
- 声明式插件架构，安全稳定
- 支持工具栏、主题、预览样式等 10 大扩展点
- 内置官方插件市场，一键安装/更新
- 开发者友好，提供完整开发文档
- 详情请查阅： [插件系统](https://github.com/jiuxina/ushio-md-plugins)

### 📤 分享导出
- 文件夹压缩分享（ZIP 格式）
- PDF 导出
- 图片导出
- 全屏预览模式一键分享

## 📱 截图展示
> 截图版本为V1.3.3

| 首页 | 编辑器 | 设置 |
|:---:|:---:|:---:|
| 快速操作、置顶文件 | 目录搜索与预览单击编辑 | 多种设置 |
| <img src="sample/1.png" alt="1" style="zoom: 40%;" /> | <img src="sample/2.png" alt="1" style="zoom: 40%;" /> | <img src="sample/3.png" alt="1" style="zoom: 40%;" /> |

## 🧩 WebView + Milkdown 详细设计（LLD）

> 详见：[`docs/webview-milkdown-lld.md`](docs/webview-milkdown-lld.md)  
> 覆盖内容：Vite 单文件构建、Milkdown 初始化、JS Bridge 协议、主题变量映射、Flutter `InAppWebView` 骨架、Android 平台调优。

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
| 数学公式   | `$$E=mc^2$$`     | KaTeX 渲染   |

## 🤝 贡献

发现 bug、想加新功能、优化体验，或者单纯想打个招呼，都欢迎提交 Issue 或 Pull Request 的说~

## 📄 开源协议

[MIT License](https://github.com/jiuxina/ushio-md/blob/main/LICENSE)

## 👨‍💻 作者

**jiuxina**  

Made with ❤️ by Me & You

------

<div align="center">

[![Star History Chart](https://api.star-history.com/svg?repos=jiuxina/ushio-md&type=Date)](https://star-history.com/#jiuxina/ushio-md&Date)

</div>
