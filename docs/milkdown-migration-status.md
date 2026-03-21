# Milkdown 迁移状态文档

## 1. 当前结论

当前项目的正确目标是：

- 一个 **渲染编辑页**：以渲染结果为主，点击后进入编辑，失焦后回到渲染态
- 一个 **纯编辑页**：只做文本编辑，不承担渲染

**不存在分屏模式。**

围绕这个目标，仓库当前已经完成了 Milkdown 基础设施接入，并把产品方向调整为 **Milkdown 优先**，但为了避免再次出现“打开文档后预览白屏”，当前实现增加了 **启动失败自动回退到旧预览内核** 的保护。

> 结论：**方向仍然是迁移到 Milkdown，而不是退回旧方案；只是当前版本增加了稳定性 fallback。**

---

## 2. 当前已完成部分

### 2.1 Milkdown 基础设施已在仓库中落地

已具备：

- `MilkdownWebViewEditor`
- `MilkdownWebViewController`
- `assets/milkdown_web/` 运行时页面
- `web/milkdown/` 源码目录
- Android localhost cleartext 配置
- `init_doc` / `update_theme` / `exec_cmd` bridge
- `on_content_change` / `on_outline_update` / `on_link_click` 等回调

### 2.2 当前页面形态已按“两页模型”对齐

当前代码层面实际对应的是：

- **纯编辑页**：Flutter 文本编辑界面
- **渲染编辑页**：WebView 渲染界面，优先尝试 Milkdown，失败时自动回退
- **全屏预览页**：同样走“Milkdown 优先 + fallback”策略

---

## 3. 当前生效策略

| 模块 | 当前状态 | 说明 |
| --- | --- | --- |
| 纯编辑页 | 已稳定 | 继续使用 Flutter 文本编辑 |
| 渲染编辑页 | Milkdown 优先 | 初始化成功则走 Milkdown；失败则自动回退旧预览 |
| 全屏预览页 | Milkdown 优先 | 与渲染编辑页一致，带 fallback |
| 分屏模式 | 不存在 | 不应作为当前产品目标继续描述 |
| Milkdown 基础设施 | 已落地 | bridge、Web 资源、本地 localhost、Android 配置均已进入仓库 |

---

## 4. 为什么现在要用“Milkdown 优先 + fallback”

因为当前阶段最重要的两件事必须同时满足：

1. **方向不能退回旧方案**，仍然要继续朝 Milkdown 迁移。
2. **用户不能再看到白屏**，文档打开后必须有可用预览。

所以当前实现采用：

- **优先尝试启动 Milkdown**
- 如果启动超时或 bootstrap 失败，则自动回退到旧预览内核

这是一种迁移保护措施，不是产品方向回退。

---

## 5. 下一步建议

### P1：彻底定位 Milkdown 白屏根因

重点建议检查：

- Android WebView 中远端 ESM / CDN 资源是否稳定可用
- Milkdown 初始化链路是否在设备端抛错
- 主题、插件、样式或资源路径是否阻塞渲染

### P2：把 fallback 从“保护措施”逐步过渡到“仅调试阶段可见”

目标是：

- 真机上确认 Milkdown 可稳定打开文档
- 渲染编辑页不再依赖 fallback
- 全屏预览与截图导出也稳定跑在 Milkdown 上

### P3：继续清理不符合产品模型的表述

后续所有文档都应统一口径：

- 只有“渲染编辑页”与“纯编辑页”
- 不再描述“分屏模式”

---

## 6. 当前最终口径

当前项目状态应表述为：

> **项目仍在朝 Milkdown 迁移；当前运行策略是 Milkdown 优先，若初始化失败则自动回退到旧预览内核，以保证渲染编辑页与全屏预览页不出现白屏。**
