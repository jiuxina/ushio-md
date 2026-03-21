# Milkdown 迁移状态文档

## 1. 当前结论

当前项目的正确产品模型是：

- 一个 **渲染编辑页**：以渲染结果为主，直接承载编辑交互
- 一个 **纯编辑页**：只做文本编辑，不承担渲染

**不存在分屏模式。**

在这个模型下，当前仓库已经把 **渲染编辑页** 与 **全屏预览页** 的实际渲染链路切到 Milkdown，不再保留旧预览内核的运行时回退逻辑。

> 结论：**当前方向就是直接迁移到 Milkdown，而不是混合或回退。**

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

### 2.3 Web 侧初始化链路

Milkdown Web 页当前已经调整为：

- 收到首个 `init_doc` 后再创建编辑器
- 在创建前就使用传入的 `markdown` 与 `readOnly` 配置
- 初始化成功后主动发出首次 render-complete 信号
- 初始化失败时，在页面内显示错误信息并通过 bridge 上报

---

## 3. 当前实际生效状态

| 模块 | 当前状态 | 说明 |
| --- | --- | --- |
| 渲染编辑页 | 已迁移到 Milkdown | 不再走旧预览内核 |
| 全屏预览页 | 已迁移到 Milkdown | 与渲染编辑页使用同一内核 |
| 纯编辑页 | 保持 Flutter 编辑 | 不承担渲染 |
| 分屏模式 | 不存在 | 不应再继续描述或恢复 |
| Milkdown 基础设施 | 已落地 | bridge、Web 资源、本地 localhost、Android 配置均已进入仓库 |

---

## 4. 当前迁移口径

当前项目状态应表述为：

> **项目已经按“渲染编辑页 + 纯编辑页”的产品模型推进，并把实际渲染链路切换到 Milkdown；当前不再依赖旧预览内核的回退机制。**

---

## 5. 后续工作重点

接下来应该继续做的是：

- 在真机上稳定验证 Milkdown 初始化链路
- 补齐渲染编辑页与全屏预览页的回归测试
- 继续清理所有仍然以旧预览逻辑为中心的遗留代码与文档
