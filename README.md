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
- [WebView + Milkdown 迁移与升级计划](#🧭-webview--milkdown-迁移与升级计划)
- [截图展示](#📱-截图展示)
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
- 预览模式双击段落/表格单元格，直接原地编辑
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

## 🧭 WebView + Milkdown 迁移与升级计划

> 目标：在保留现有功能体验的前提下，将“原生文本框 + WebView 预览”的架构升级为“WebView + Milkdown 一体化渲染/编辑”，并逐步释放 Milkdown 的可扩展能力。

### 1) 现状能力盘点（需完整保留）

当前编辑器（`EditorScreen` + `WebViewMarkdownPreview`）已经具备：
- 编辑 / 预览 / 分屏模式
- 基于 WebView 的高保真渲染（代码高亮、KaTeX、任务列表、媒体链接）
- 预览区原地编辑（块级定位与回写）
- 目录导航、全文搜索、自动保存、导出（PDF/图片）
- 主题、字体、字号、背景等个性化能力

迁移后，上述能力应做到 **不回退**，并通过灰度开关支持回滚。

### 2) 目标架构（WebView + Milkdown）

建议采用“Flutter 外壳 + 内嵌 Web 编辑内核”的分层：
- **Flutter 层**：文件系统、权限、导航、设置、导出、分享、同步、主题参数下发
- **WebView 层**：承载 Milkdown 编辑器（渲染 + 编辑 + 快捷键 + 插件体系）
- **Bridge 层（双向通信）**：
  - Flutter -> Web：文档加载、主题/字号变更、跳转到标题、查找关键词、只读切换
  - Web -> Flutter：内容变更、光标位置、任务勾选、链接点击、图片/媒体选择请求

### 3) 功能映射（现有功能 -> Milkdown 方案）

| 现有能力 | Milkdown 迁移方案 |
| --- | --- |
| Markdown 基础语法 | 使用 CommonMark + GFM 相关能力，统一解析/序列化 |
| 任务列表勾选 | 使用任务列表节点与命令，变更通过 Bridge 同步回 Flutter |
| 数学公式 KaTeX | 保留 KaTeX 渲染链路，在 Milkdown 内统一处理行内/块公式 |
| 代码块高亮 | 使用代码块节点 + 语法高亮插件，保持现有显示效果 |
| 目录导航 | 通过文档 AST/标题节点生成 TOC，支持点击定位 |
| 全文搜索 | 在 Milkdown 文档状态中实现搜索高亮与下一个/上一个跳转 |
| 原地编辑 | 迁移为 Milkdown 原生所见即所得编辑，移除预览区临时 textarea 逻辑 |
| 主题/字体/字号 | Flutter 设置实时下发 CSS 变量，Milkdown 消费变量渲染 |
| 自动保存 | 监听编辑变更（节流/防抖）后沿用现有保存策略 |
| 只读预览 | Milkdown 只读模式，替代“独立预览页面”的编辑限制逻辑 |

### 4) 分阶段迁移步骤（最小风险）

#### Phase A：基础工程接入（1 个迭代）
1. 在 `assets/` 下引入 Milkdown 前端产物 (静态 HTML/JS/CSS Bundle)。
2. 新增 `MilkdownWebViewEditor` 组件（不替换旧实现），建立 JS Handler 与消息协议。
3. 打通最小闭环：加载 Markdown、编辑后回传文本、保存文件。
4. 增加设置开关：`legacy`（旧实现）/`milkdown`（新实现）。

**验收标准**：可在不影响现有用户的情况下，手动切换到 Milkdown 并完成基本编辑保存。

#### Phase B：核心能力对齐（1~2 个迭代）
1. 对齐主题系统：暗色/亮色、主题色、字体、字号、背景。
2. 对齐 Markdown 扩展：GFM、任务列表、表格、代码高亮、KaTeX。
3. 对齐 TOC / 搜索 / 跳转能力（用 Bridge 与 Flutter UI 联动）。
4. 对齐自动保存、撤销重做、快捷键与工具栏常用命令。

**验收标准**：日常写作主流程（编辑-搜索-跳转-保存-导出）体验与旧版本一致或更优。

#### Phase C：高级能力升级（可并行迭代）
1. 引入 Milkdown 插件化工具栏/菜单，减少 Flutter 端手写插入逻辑。
2. 提升大文档性能：增量更新、输入防抖、Bridge 消息批处理。
3. 增强粘贴与内容清洗策略（代码块、表格、富文本转 Markdown）。
4. 按需规划协作相关能力（如后续需要多人协同再接入）。

**验收标准**：在中大型文档下输入流畅，常见复杂内容（表格/公式/代码）稳定。

#### Phase D：灰度发布与收敛
1. 先在测试渠道灰度（默认仍为 legacy）。
2. 收集崩溃、卡顿、编辑丢失、渲染差异等指标。
3. 分批提升 Milkdown 默认开关覆盖率。
4. 稳定后移除 legacy 特有逻辑与重复维护代码。

**验收标准**：问题率达到可控阈值后再默认切换，确保可回滚。

### 5) 关键实施细节（建议）

- **消息协议版本化**：Bridge 增加 `version` 字段，便于后续升级兼容。
- **保存策略**: 编辑变更使用防抖(如 300~800ms), 失焦/退后台强制落盘。
- **崩溃兜底**: WebView 初始化失败时自动回落到 legacy 引擎。
- **一致性测试**: 针对“同一 Markdown 输入”做新旧渲染结果对比(快照/关键节点断言)。
- **迁移开关**: 开关状态持久化到设置项，支持用户手动切回旧引擎。

### 6) 建议的执行清单（Issue / PR 可直接复用）

- [ ] 定义 Bridge 协议 (加载、保存、主题、TOC、搜索、跳转、链接、任务勾选)
- [ ] 完成 `MilkdownWebViewEditor` 最小可用版本与 feature flag
- [ ] 对齐主题与字体参数下发 (含暗色模式)
- [ ] 对齐 GFM / KaTeX / 代码高亮能力
- [ ] 对齐 TOC、搜索、自动保存、导出流程
- [ ] 增加新旧引擎对比测试 (关键场景)
- [ ] 灰度发布、观测、回滚预案验证
- [ ] 默认切换并清理 legacy 冗余代码

## 📱 截图展示
> 截图版本为V1.3.3

| 首页 | 编辑器 | 设置 |
|:---:|:---:|:---:|
| 快速操作、置顶文件 | 目录搜索双击编辑 | 多种设置 |
| <img src="sample/1.png" alt="1" style="zoom: 40%;" /> | <img src="sample/2.png" alt="1" style="zoom: 40%;" /> | <img src="sample/3.png" alt="1" style="zoom: 40%;" /> |

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
