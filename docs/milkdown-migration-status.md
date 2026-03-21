# Milkdown 迁移状态文档

## 1. 当前结论

当前仓库已经完成了 **Milkdown 渲染链路的真实接入**，但仍未完成“整个编辑器内核完全迁移到 Milkdown”。

更准确地说：

- **预览模式 / 分屏预览 / 全屏预览** 已切换到 Milkdown WebView 渲染。
- Flutter 侧已经接入 `InAppLocalhostServer`，并通过本地资源页加载 Milkdown 前端资源。
- 仓库中已经补齐独立的 `web/milkdown/` 前端源码目录。
- **编辑输入主链路** 仍然保留 Flutter `TextField`，因此当前属于 **“渲染已迁移、编辑仍是混合架构”**。

---

## 2. 本次已真实落地的内容

### 2.1 主渲染链路已切换到 Milkdown

已完成切换的页面：

- 编辑器预览模式
- 编辑器分屏预览面板
- 全屏预览页面
- 全屏预览的后台截图导出链路

这些页面现在统一使用 `MilkdownWebViewEditor` 作为 WebView 渲染容器，而不再走旧的 `WebViewMarkdownPreview` 主路径。

### 2.2 Flutter ↔ Web 的 Milkdown bridge 已接通

当前 bridge 已支持：

- `init_doc`
- `update_theme`
- `exec_cmd`
- `on_content_change`
- `on_outline_update`
- `on_link_click`
- `on_image_error`
- `on_checkbox_toggle`
- `on_render_complete`

### 2.3 本地资源加载方式已落地

Flutter 侧不再以内嵌字符串方式加载单页 HTML，而是通过：

- `InAppLocalhostServer(documentRoot: 'assets/milkdown_web')`
- `http://localhost:<port>/index.html`

来加载 Milkdown 页面与其关联资源文件。

这使得：

- `index.html`
- `main.js`
- `style.css`

可以作为真正的多文件 Web 前端资源存在于仓库中。

### 2.4 仓库已补齐独立 Web 源码目录

已新增：

- `web/milkdown/index.html`
- `web/milkdown/src/main.js`
- `web/milkdown/src/style.css`
- `web/milkdown/package.json`
- `web/milkdown/vite.config.mjs`

这意味着先前文档里提到但仓库中不存在的独立 Web 源码目录，现在已经真实存在。

---

## 3. 当前模块状态

| 模块 | 当前状态 | 说明 |
| --- | --- | --- |
| 预览渲染引擎 | 已迁移 | 编辑器预览 / 分屏 / 全屏预览已使用 Milkdown |
| Flutter Bridge | 已落地 | 本地服务、主题同步、回调桥接均已接通 |
| Web 前端源码目录 | 已落地 | 已有 `web/milkdown/` 目录与开发配置 |
| Markdown 目录跳转 | 已落地 | 通过 heading id 与 controller 跳转 |
| 全屏截图导出 | 已适配 | 使用 Milkdown WebView 截图 |
| 任务列表交互 | 已适配 | Web 端回传 checkbox toggle 到 Flutter |
| 编辑输入引擎 | 未迁移完成 | 仍由 Flutter `TextField` 负责 |
| 离线前端打包 | 部分完成 | 当前资源以本地页 + CDN 模块/样式组合运行 |
| 自动化测试 | 部分完成 | 模型测试仍在，但 Flutter 环境缺失 |

---

## 4. 当前实现结构

### 4.1 Flutter 侧

- `MilkdownWebViewEditor` 负责启动 localhost server、承载 WebView、下发 bridge 消息、接收回调。
- `MilkdownWebViewController` 负责滚动到标题、截图与全页截图。
- `EditorScreen` 的 preview / split 路径已切换到 Milkdown。
- `FullscreenPreviewPage` 已切换到 Milkdown，包括后台截图导出。

### 4.2 Web 侧

- 入口页面：`assets/milkdown_web/index.html`
- 主逻辑：`assets/milkdown_web/main.js`
- 样式：`assets/milkdown_web/style.css`
- 运行时使用 Milkdown 官方包初始化真实编辑器实例
- 使用 listener plugin 监听 markdown 更新
- 使用 `replaceAll` 完成 Flutter 下发内容的全量替换

### 4.3 源码目录

为了后续继续推进前端工程化，本仓库还提供了镜像源码目录：

- `web/milkdown/`

该目录用于承载后续本地开发与构建配置，不再把 Milkdown 页面完全视为“只有 Flutter asset 的黑盒文件”。

---

## 5. 仍未完成的事项

### 5.1 编辑模式尚未切换到 Milkdown

当前编辑模式仍然是：

- Flutter `TextField`
- Flutter `TextEditingController`
- Flutter toolbar 直接操作纯文本

因此当前不能宣称“整个编辑器完全迁移到 Milkdown”。

### 5.2 前端依赖仍未内置打包进仓库产物

当前 `assets/milkdown_web/` 虽然已经是真实的 Milkdown 页面，但依赖获取方式仍然是：

- 本地 HTML / JS / CSS 文件
- 远端 CDN 提供的 Milkdown / KaTeX / Prism 模块与样式

这意味着：

- 在线环境下可真实运行
- 但还不等于“完全离线自包含构建”

### 5.3 自动化验收仍不完整

目前仍缺少：

- Flutter integration test
- Flutter ↔ Web bridge 端到端测试
- 实机回归基线
- Web 前端构建产物校验流水线

---

## 6. 后续优先级建议

### P1：编辑模式迁移

下一阶段建议把编辑模式也切到 Milkdown，使编辑与预览共享统一文档模型。

### P2：离线构建闭环

建议继续把 `web/milkdown/` 目录真正接到构建流程中，产出离线可部署的本地 bundle，再同步到 `assets/milkdown_web/`。

### P3：回归测试完善

补齐：

- preview / split / fullscreen 回归测试
- checkbox / link / outline bridge 测试
- 截图导出回归测试

---

## 7. 当前最终判定

**当前可以确认：Milkdown 渲染引擎迁移已经真实落地，并已切到主预览链路。**

**当前仍不能确认：整个编辑器已经完全迁移到 Milkdown 编辑内核。**

因此，项目现阶段的准确口径应当是：

> **Milkdown 渲染引擎已完成落地并接入主预览链路；编辑器仍处于 Flutter 文本编辑 + Milkdown 渲染的混合阶段。**
