# Milkdown 迁移状态文档

## 1. 当前结论

当前项目的正确产品模型是：

- 一个 **渲染编辑页**：以渲染结果为主，支持预览内联编辑
- 一个 **纯编辑页**：只做文本编辑，不承担渲染

**不存在分屏模式。**

在这个模型下，当前仓库已经把 **渲染编辑页** 与 **全屏预览页** 的实际渲染链路切到 Milkdown，并移除了旧 `WebViewMarkdownPreview` 的页面接入。

> 结论：**当前方向就是直接迁移到 Milkdown，而不是回退到旧预览内核。**

---

## 2. 已完成迁移的部分

### 2.1 页面层级

当前已经完成：

- 渲染编辑页 → `MilkdownWebViewEditor`
- 全屏预览页 → `MilkdownWebViewEditor`
- 纯编辑页 → 保持 Flutter 文本编辑，不承担渲染

### 2.2 Flutter ↔ Web 基础设施

已具备：

- `MilkdownWebViewEditor`
- `MilkdownWebViewController`
- `assets/milkdown_web/` 运行时资源
- `web/milkdown/` 源码目录
- Android localhost cleartext 配置
- `init_doc` / `update_theme` / `exec_cmd` bridge
- `on_content_change` / `on_outline_update` / `on_link_click` / `on_checkbox_toggle` / `on_render_complete` 回调

### 2.3 当前链路修正

本次修正重点是：

- 补上 `@milkdown/preset-commonmark` 作为基础 preset，避免仅挂 `gfm` 时编辑器上下文不完整
- 将 `nord` 主题改为 `config(nord)` 用法，而不是作为普通插件挂载
- 删除旧 `WebViewMarkdownPreview` 页面接线，活动界面全部回到 `MilkdownWebViewEditor`

---

## 3. 当前实际生效状态

| 模块 | 当前状态 | 说明 |
| --- | --- | --- |
| 渲染编辑页 | 已使用 Milkdown | 由 `MilkdownWebViewEditor` 承载 |
| 全屏预览页 | 已使用 Milkdown | 与渲染编辑页使用同一内核 |
| 纯编辑页 | 保持 Flutter 编辑 | 不承担渲染 |
| 分屏模式 | 不存在 | 不应再继续描述或恢复 |
| Milkdown 基础设施 | 已落地 | localhost、bridge、截图、主题同步均保留 |

---

## 4. 当前迁移口径

当前项目状态应表述为：

> **项目已经按“渲染编辑页 + 纯编辑页”的产品模型推进，并把实际渲染链路切换到 Milkdown；当前不再允许生产页面回退到旧 `WebViewMarkdownPreview`。**

---

## 5. 后续工作重点

接下来应该继续做的是：

- 继续把剩余远端资源彻底收敛到本地构建产物
- 补齐 Milkdown 真机回归测试与桥接消息测试
- 继续围绕 Milkdown 补功能，不再恢复旧预览组件
