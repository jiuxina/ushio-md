# Milkdown 迁移状态文档

## 1. 当前结论

当前项目的正确产品模型是：

- 一个 **渲染编辑页**：以渲染结果为主，支持预览内联编辑
- 一个 **纯编辑页**：只做文本编辑，不承担渲染

**不存在分屏模式。**

在这个模型下，当前仓库已经接入了 Milkdown 基础设施，但**当前实际生效的渲染链路已经切回稳定的旧 WebView 预览内核**，因为现有 Milkdown 资产仍依赖远端 CDN / ESM 资源，尚未形成可稳定交付的本地化实现。

> 结论：**Milkdown 仍是迁移目标，但当前线上可用链路不是完整可交付的本地 Milkdown 实现，因此运行页面已回退到稳定预览内核。**

---

## 2. 已完成迁移的部分

### 2.1 页面层级

当前已经完成：

- 渲染编辑页 → `WebViewMarkdownPreview`
- 全屏预览页 → `WebViewMarkdownPreview`
- 纯编辑页 → 保持 Flutter 文本编辑，不承担渲染

### 2.2 Flutter ↔ Web 基础设施

已具备但**当前未作为生产渲染链路启用**：

- `MilkdownWebViewEditor`
- `MilkdownWebViewController`
- `assets/milkdown_web/` 运行时资源
- `web/milkdown/` 源码目录
- Android localhost cleartext 配置
- `init_doc` / `update_theme` / `exec_cmd` bridge
- `on_content_change` / `on_outline_update` / `on_link_click` / `on_checkbox_toggle` / `on_render_complete` 回调

### 2.3 为什么当前不能把它当成“已完成迁移”

当前仓库中的 Milkdown 方案仍有两个关键问题：

- `assets/milkdown_web/` 中运行时脚本仍通过远端 ESM / CDN 拉取 Milkdown、KaTeX、Prism 资源
- 这意味着它不是一个真正“随 APP 一起交付”的本地渲染内核，也会直接暴露初始化失败问题

---

## 3. 当前实际生效状态

| 模块 | 当前状态 | 说明 |
| --- | --- | --- |
| 渲染编辑页 | 已切回旧 WebView 预览 | 当前生产路径使用稳定实现 |
| 全屏预览页 | 已切回旧 WebView 预览 | 与渲染编辑页保持一致 |
| 纯编辑页 | 保持 Flutter 编辑 | 不承担渲染 |
| 分屏模式 | 不存在 | 不应再继续描述或恢复 |
| Milkdown 基础设施 | 已入库但未投产 | 仍需本地化打包与真机验证 |

---

## 4. 当前迁移口径

当前项目状态应表述为：

> **项目已经按“渲染编辑页 + 纯编辑页”的产品模型推进，但当前实际投产的渲染链路仍是稳定的旧 WebView 预览实现；Milkdown 相关代码目前仅属于未完成的迁移基础设施。**

---

## 5. 后续工作重点

接下来应该继续做的是：

- 先把 Milkdown 依赖改为真正随仓库交付的本地构建产物，而不是远端 ESM / CDN
- 在真机上验证完整初始化、主题同步、图片/链接解析与截图链路
- 在确认稳定前，不要再次把生产页面直接切到 Milkdown
