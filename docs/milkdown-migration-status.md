# Milkdown 迁移状态文档

## 1. 当前结论

当前仓库 **还没有完成可稳定上线的 Milkdown 渲染迁移**。

更准确地说：

- Milkdown 的 **Flutter bridge、Web 资源页、本地 localhost 承载、Android cleartext 配置** 都已经落地。
- 但在真实运行中，直接把编辑器预览区切到 Milkdown 会出现 **打开文档后预览白屏** 的稳定性问题。
- 因此当前已经将 **编辑器预览 / 分屏 / 全屏预览主路径回退到原有 `WebViewMarkdownPreview`**，以保证文档可正常打开与预览。
- Milkdown 相关代码与资源会继续保留在仓库中，作为后续继续迭代和调试的基础。

> 结论：**Milkdown 基础设施已落地，但主预览链路尚未稳定接管。**

---

## 2. 已完成落地的部分

### 2.1 Flutter ↔ Web bridge 已建立

当前已具备：

- `MilkdownWebViewEditor`
- `MilkdownWebViewController`
- `init_doc` / `update_theme` / `exec_cmd`
- `on_content_change` / `on_outline_update` / `on_link_click`
- `on_image_error` / `on_checkbox_toggle` / `on_render_complete`

### 2.2 Web 资源页与源码目录已存在

当前仓库已包含：

- `assets/milkdown_web/index.html`
- `assets/milkdown_web/main.js`
- `assets/milkdown_web/style.css`
- `web/milkdown/` 源码目录
- `web/milkdown/package.json`
- `web/milkdown/vite.config.mjs`

### 2.3 Android localhost cleartext 问题已处理

为支持 `InAppLocalhostServer` 提供的 `http://localhost:<port>/index.html`，Android 侧已经加入 localhost 专用网络安全配置，避免 `net::ERR_CLEARTEXT_NOT_PERMITTED`。

---

## 3. 当前实际生效状态

| 模块 | 当前状态 | 说明 |
| --- | --- | --- |
| Milkdown 基础设施 | 已落地 | bridge、Web 资源、Android localhost 配置都在仓库中 |
| Milkdown 预览主路径 | 暂未启用 | 运行时存在白屏问题，因此已回退 |
| 编辑器预览链路 | 仍使用旧方案 | 当前 active path 为 `WebViewMarkdownPreview` |
| 分屏预览链路 | 仍使用旧方案 | 为保证稳定性已回退 |
| 全屏预览 / 截图导出 | 仍使用旧方案 | 为避免白屏影响分享导出已回退 |
| 编辑输入引擎 | 未迁移 | 仍是 Flutter `TextField` |

---

## 4. 为什么要回退主路径

本次回退不是放弃 Milkdown，而是为了先恢复可用性。

当前症状是：

- 打开文档后，预览区出现白屏
- 这会直接影响：预览、分屏、全屏预览、截图导出

在这种情况下，优先恢复稳定显示比继续让不稳定实现挂在主路径上更重要。

---

## 5. 下一步建议

### P1：先查清白屏根因

重点方向：

- Milkdown 页面初始化是否抛错
- 远端 ESM / CDN 资源在 Android WebView 中是否稳定可用
- WebView 与 localhost 页面上的模块加载、样式加载是否完整
- `Editor.create()` / `replaceAll()` / plugin 初始化链路是否在设备端异常

### P2：补一个“可观测”失败态

下一轮建议给 Milkdown Web 页增加：

- DOM 内错误面板
- 初始化失败日志上报到 Flutter
- 初始化超时自动 fallback

### P3：确认稳定后再重新切主路径

在以下条件满足前，不建议再把 active preview 切回 Milkdown：

- 至少一台 Android 真机可稳定打开文档
- 预览、分屏、全屏三条链路均不白屏
- 截图导出正常
- 本地图片、链接、目录跳转正常

---

## 6. 当前最终口径

当前项目的准确表述应当是：

> **Milkdown 迁移的基础设施已经进入仓库，但由于预览白屏问题，主预览链路已暂时回退到旧渲染方案，尚未完成正式切换。**
