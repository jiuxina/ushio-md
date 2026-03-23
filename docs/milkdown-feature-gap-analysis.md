# Milkdown 实现深度分析与官方特性差异对照（ushio-md）

> 分析时间：2026-03-23  
> 分析范围：`web/milkdown/` 源码、`lib/widgets/milkdown_webview_editor.dart` Bridge 接线、当前依赖版本与 npm 官方包生态

---

## 1. 核心实现识别（初始化与插件加载）

### 1.1 Milkdown 初始化入口

当前项目的 Milkdown 初始化位于：

- `/home/runner/work/ushio-md/ushio-md/web/milkdown/src/main.js`
  - `createEditor()`：第 224 行开始
  - `Editor.make()`：第 225 行
  - `ensureEditor()`：第 286 行（懒初始化）
  - `onFlutterMessage(type === 'init_doc')`：第 381 行触发初始化

### 1.2 当前已加载的官方能力（`use(...)` / `config(...)`）

在 `createEditor()` 中，当前加载链路为：

- `config(nord)`：`@milkdown/theme-nord`（官方主题）
- `.use(commonmark)`：`@milkdown/preset-commonmark`
- `.use(gfm)`：`@milkdown/preset-gfm`
- `.use(math)`：`@milkdown/plugin-math`
- `.use(prism)`：`@milkdown/plugin-prism`
- `.use(listener)`：`@milkdown/plugin-listener`

并且命令侧使用了：

- `toggleStrongCommand`、`toggleEmphasisCommand`、`insertImageCommand`（来自 `preset-commonmark`）
- `insertTableCommand`（来自 `preset-gfm`）
- `undo` / `redo`（来自 `@milkdown/prose/history`）

### 1.3 自定义插件识别结果

当前**未发现通过 `.use(customPlugin)` 注册的 Milkdown 自定义插件**。  
项目的“自定义能力”主要通过 Web 层扩展逻辑实现，而非 Milkdown 插件 API：

- Flutter ↔ Web Bridge 协议封装：`init_doc / update_theme / exec_cmd` 与回调分发
- 渲染后 DOM 增强：链接拦截、checkbox 索引映射、图片错误上报
- 目录提取：基于 Markdown 行文本正则提取标题并上报 `on_outline_update`
- 资源路径解析：`baseDirectory` + 相对路径转绝对 `file://`

---

## 2. Milkdown 官方核心特性与官方插件生态（最新）

> 基于当前 npm 官方包可见生态（`@milkdown/*`）与 v7 体系。  
> 版本检查结果：`@milkdown/core` 最新为 `7.19.1`，而本项目当前为 `7.5.0`。

### 2.1 官方核心能力（平台层）

- 核心编辑器与上下文系统：`@milkdown/core`、`@milkdown/ctx`
- ProseMirror 能力导出：`@milkdown/prose`
- Markdown 转换层：`@milkdown/transformer`
- 工具与异常：`@milkdown/utils`、`@milkdown/exception`
- 预设（Preset）：
  - `@milkdown/preset-commonmark`
  - `@milkdown/preset-gfm`
- 开箱方案：
  - `@milkdown/kit`（官方组合套件）
  - `@milkdown/crepe`（开箱即用编辑器）
- UI 集成：
  - `@milkdown/react`
  - `@milkdown/components`

### 2.2 官方插件生态（主要）

- `@milkdown/plugin-listener`
- `@milkdown/plugin-slash`
- `@milkdown/plugin-tooltip`
- `@milkdown/plugin-block`
- `@milkdown/plugin-upload`
- `@milkdown/plugin-history`
- `@milkdown/plugin-indent`
- `@milkdown/plugin-clipboard`
- `@milkdown/plugin-trailing`
- `@milkdown/plugin-prism`
- `@milkdown/plugin-math`（npm 标记 deprecated，仍可安装，最新 `7.5.9`）

---

## 3. 差异对照表（官方全量 vs 本项目）

| 特性/插件名称 | 官方状态 | 本项目是否实现 | 本地实现路径/说明 | 差异点/待补齐功能 |
| --- | --- | --- | --- | --- |
| Core Editor (`@milkdown/core`) | 官方核心，活跃（7.19.1） | 是 | `web/milkdown/src/main.js` `Editor.make()` | 版本落后（7.5.0） |
| Context/Utils/Prose 基础能力 | 官方核心能力 | 部分 | `main.js` 使用 `commandsCtx`、`editorViewCtx`、`@milkdown/prose/history` | 未系统引入 `@milkdown/kit` 的统一编排能力 |
| CommonMark Preset | 官方核心预设，活跃 | 是 | `.use(commonmark)` | 版本落后 |
| GFM Preset（含表格等） | 官方核心预设，活跃 | 是 | `.use(gfm)` + `insertTableCommand` | 版本落后；未显式利用更多 GFM 相关命令/UI |
| Listener Plugin | 官方插件，活跃 | 是 | `.use(listener)` + `markdownUpdated` | 当前回写无防抖，长文档可能增加桥接压力 |
| Prism Plugin | 官方插件，活跃 | 是 | `.use(prism)` | 版本落后 |
| Math Plugin | 官方插件（npm 标记 deprecated） | 是 | `.use(math)` | 当前固定 `7.5.0`；需评估后续替代路线/兼容方案 |
| Nord Theme | 官方主题，活跃 | 是 | `.config(nord)` | 版本落后；目前仅使用 nord 主题方案 |
| Slash Plugin | 官方插件，活跃 | 否 | 无 | 未实现 `/` 命令面板能力 |
| Tooltip Plugin | 官方插件，活跃 | 否 | 无 | 未实现浮层工具提示/格式化 UI |
| Block Plugin | 官方插件，活跃 | 否 | 无 | 未实现块级操作增强 |
| Upload Plugin | 官方插件，活跃 | 否 | 无 | 现为 Flutter 侧图片选择 + `insert_image`，无官方 upload 插件链路 |
| History Plugin（官方封装） | 官方插件，活跃 | 部分 | 使用 `@milkdown/prose/history` 的 `undo/redo` | 未采用 `@milkdown/plugin-history` 封装能力 |
| Indent Plugin | 官方插件，活跃 | 否 | 无 | 未提供缩进增强能力 |
| Clipboard Plugin | 官方插件，活跃 | 否 | 无 | 未启用官方剪贴板增强 |
| Trailing Plugin | 官方插件，活跃 | 否 | 无 | 未启用尾随段落/输入体验增强 |
| Kit（官方组合套件） | 官方推荐开箱组合，活跃 | 否 | 无 | 目前手工拼装插件，升级与扩展成本更高 |
| Crepe（开箱编辑器） | 官方开箱方案，活跃 | 否 | 无 | 当前是自建 WebView + Bridge，不是 Crepe 路线 |
| React/Components 生态 | 官方 UI 生态，活跃 | 否（不适用） | Flutter + WebView 架构 | 架构差异导致该能力不直接适用 |
| 自定义 Milkdown 插件（`.use(custom)`) | 官方支持扩展机制 | 否 | 无自定义插件注册 | 当前自定义能力在 DOM/Bridge 层，非标准插件层 |

---

## 4. 优化建议（结合本项目现状）

1. **优先处理版本滞后**
   - 当前 `web/milkdown/package.json` 中多数依赖为 `7.5.0`，与最新 `7.19.1` 有明显差距。
   - 建议先建立“最小升级批次”（例如先升 `core/preset/listener/prism/theme`，保留现有 bridge 协议不变）并做回归。

2. **评估 `plugin-math` 的后续策略**
   - npm 已标记 `@milkdown/plugin-math` deprecated（最新 `7.5.9`），建议在升级时明确：
     - 是继续沿用当前能力并锁版本；
     - 还是切换到官方后续推荐路径（若上游发布替代方案）。

3. **补齐缺失的官方高价值插件**
   - 若目标是“编辑器体验增强”，优先顺序建议：
     1) `plugin-tooltip`
     2) `plugin-slash`
     3) `plugin-history`（替换当前直接调用 prose history 的方式）
   - 这三项与现有工具栏/命令模型兼容度较高，改造收益明显。

4. **Bridge 性能与一致性优化**
   - 当前 `on_content_change` 是逐次更新上报，建议评估加入短防抖（如 150~300ms）或条件上报，降低长文档输入压力。
   - 当前目录提取依赖正则匹配 `#` 标题，建议后续考虑基于编辑器状态/语法树提取，减少与真实渲染结构不一致的边界情况。

5. **插件层与业务层解耦**
   - 当前项目把较多能力放在 DOM 后处理（链接、图片、checkbox、heading id）层。
   - 后续可将稳定能力逐步迁移到 Milkdown 官方插件能力或规范插件扩展层，提升可维护性与升级可控性。

---

## 5. 关键结论（简版）

- 当前项目已经完成 Milkdown 主干接入，核心可用链路完整。
- 但与官方最新生态相比，主要差异是：**版本滞后 + 官方插件利用率偏低（Slash/Tooltip/Block/Upload 等未使用）**。
- 短期建议：**先升级核心版本，再小步引入高价值官方插件**，并保持现有 Flutter Bridge 协议稳定。

