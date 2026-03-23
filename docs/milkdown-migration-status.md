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

基于当前仓库实现，后续建议按 **“先稳定基础设施，再替换能力，再收口旧链路”** 的方式推进。  
目标是：**最终仅保留 Milkdown WebView 渲染/编辑链路，旧 WebView 预览内核不再作为生产路径存在。**

### 5.1 当前待完成项（状态检查结论）

当前代码已完成页面接入迁移，但仍有关键收尾项：

1. **Web 运行时资源尚未完全本地化**
   - ✅ 已完成：运行时已切换为 `assets/milkdown_web/index.html` 单文件产物（本地构建内联 JS/CSS）。
   - ✅ 已完成：移除 `assets/milkdown_web/main.js` / `style.css` 运行时依赖，不再通过 `esm.sh` 远端导入。

2. **`exec_cmd` 命令集已建桥，但 Web 侧只实装了 `focus_editor`**
   - Flutter 侧已下发 `undo/redo/toggle_bold/toggle_italic/insert_table/insert_image`。
   - Web 侧尚未完成对应命令路由，功能仍有缺口。

3. **测试与验收仍偏人工**
   - 迁移关键链路（bridge 协议、主题同步、命令执行、图片/链接行为）缺少系统化自动回归矩阵。

### 5.2 完整迁移计划（可分步执行）

> 你下次对话说“开始下一步迁移”时，可直接从 Phase A 开始逐步落地。

#### Phase A：构建与运行时收敛（先做）

- [x] 将 `web/milkdown/` 作为唯一源码入口，固定依赖版本并锁定 lockfile。
- [x] 用 Vite 构建本地产物（单文件 `dist/index.html`）覆盖 `assets/milkdown_web/`。
- [x] 去除运行时对 `esm.sh` 的远端依赖，确保完全离线可运行。
- [x] 在文档补充“源码 -> 构建 -> 产物同步”命令与发布前检查项。

**验收标准**
- 飞行模式/断网环境下，渲染编辑页与全屏预览页可正常打开、编辑、渲染。
- 无任何运行时远端脚本加载请求。

#### Phase B：补齐命令系统与编辑能力（核心功能）

- [x] 在 Web 侧实现 `exec_cmd` 全命令路由：
  - [x] `undo`
  - [x] `redo`
  - [x] `toggle_bold`
  - [x] `toggle_italic`
  - [x] `insert_table`
  - [x] `insert_image`
- [x] 对 `insert_image` 完成路径策略统一（相对路径、file 路径、baseDirectory 解析）。
- [x] 明确失败回执（命令不支持/执行失败时的 bridge 反馈）。

**验收标准**
- Flutter 工具栏触发上述命令时，Milkdown 编辑区行为与现有用户预期一致。
- 命令失败可观测（日志或回调），不出现静默失败。

#### Phase C：主题、排版与行为一致性（体验收敛）

- [x] 对齐字体、字号、行高、色板、暗色模式切换行为。
- [x] 对齐目录跳转、高亮闪烁、链接点击、任务列表勾选等现有交互。
- [ ] 对大文档（长列表/多表格/多图片）做滚动与输入稳定性回归。

**验收标准**
- 主题切换无闪烁、颜色无错位、排版与 Flutter 外层视觉一致。
- 目录跳转、链接、checkbox 在编辑页与全屏预览页行为一致。

#### Phase D：测试与观测补齐（质量兜底）

- [x] 为 Dart bridge 模型与消息分发补充单元测试。
- [x] 为核心回调链路补充 Widget/集成测试（至少覆盖 onContentChange/onLinkClick/onCheckboxToggle）。
- [ ] 建立真机回归清单（Android 主版本 + WebView 版本差异）。
- [x] 固化性能基线采样方法（指标、记录格式、阈值与判定规则）。

#### Step 8 / Step 9 / Step 10 最新进展（2026-03-23）

- [x] Step 8：已接入 `@milkdown/plugin-clipboard`，Web 端复制粘贴行为切到官方插件处理。
- [x] Step 9：已接入 `@milkdown/plugin-upload`，并通过 `on_upload_images_request` + `upload_images_result` 桥接 Flutter 侧图片落盘与插入。
- [x] Step 10：已补充 bridge 模型/分发测试（upload 请求场景），并更新实现计划文档与回归清单项。

当前命令与消息口径新增：

- Web -> Flutter：`on_upload_images_request`（携带 requestId 与 dataUrl 文件列表）
- Flutter -> Web：`exec_cmd(upload_images_result)`（回传 requestId、images、reason）

**验收标准**
- 迁移核心路径具备可重复执行的自动化验证。
- 关键性能指标在可接受阈值内且可复测。

#### Phase E：旧链路收口与长期维护（最终阶段）

- [x] 删除/归档旧 WebView 预览实现文档与残余资产（仅在确认无运行时引用后）。
- [x] 将“Milkdown 为唯一渲染内核”写入 README 与开发约束。
- [x] 建立上游跟踪策略（参考 `https://github.com/Milkdown/milkdown` 的版本更新与 breaking changes）。

**验收标准**
- 仓库内不再存在可被生产路径启用的旧预览内核接线。
- 新功能默认在 Milkdown 链路实现，不再双实现。

### 5.4 上游跟踪策略（Milkdown）

为避免后续升级引入隐性回归，统一采用以下节奏：

1. **版本监控**
   - 每次准备发版前检查 `https://github.com/Milkdown/milkdown/releases`。
   - 若出现 minor/major 升级，必须阅读 release note 中的 breaking changes。

2. **升级流程**
   - 先在 `web/milkdown/` 升级依赖并本地构建 `dist/index.html`；
   - 同步替换 `assets/milkdown_web/index.html`；
   - 保持 bridge 协议字段兼容（`init_doc/update_theme/exec_cmd` 及核心回调）。

3. **回归基线**
   - 至少覆盖：内容回写、链接点击、任务列表勾选、工具栏命令（undo/redo/bold/italic/table/image）。
   - 若命令路由或 payload 结构变化，必须先补测试再改实现。

4. **风险控制**
   - 发现不兼容时优先回滚到上一可用版本，避免在主干带病升级。
   - 禁止引入“Milkdown + 旧 WebView 预览”双实现作为临时方案。

### 5.3 每一步迁移的执行模板（建议）

后续逐步迁移时，每一步都按同一模板执行：

1. 明确本步目标（只做一个小阶段）。
2. 先补/改测试，再改实现（或至少同步补测试）。
3. 完成后做定向回归（编辑页 + 全屏预览页 + 纯编辑页关联入口）。
4. 更新迁移状态文档，记录“已完成 / 待完成 / 风险”。
5. 保持可回滚：每一步只提交最小必要改动。

---

## 6. 迁移完整性检查（2026-03-22）

本次按“是否完整迁移到 Milkdown”做了仓库核查，结论如下：

- **生产接线**：渲染编辑页与全屏预览页均已使用 `MilkdownWebViewEditor`。
- **旧链路引用**：`lib/` 内未检出 `WebViewMarkdownPreview` 生产路径引用。
- **运行时资产**：`assets/milkdown_web/` 仅保留 `index.html` 单文件产物。
- **开发约束**：README 已写入 Milkdown 单内核约束与上游跟踪策略。

### 结论

从“功能接线与运行时资产”角度看，已完成 Milkdown 单内核迁移；  
但从“迁移验收闭环”角度看，**仍未完全收官**，当前状态为：

- [x] 建立真机回归清单（模板已建立）
- [x] 固化性能基线采样方法（Step 2 已完成）
- [ ] 完成真机版本矩阵实测并回填（Step 3 已回填阻塞结果，待真实设备执行）

已完成 Step 3 首轮结果回填（见 `docs/milkdown-step3-first-pass-results.md`），  
并进入后续计划 v2（见 `docs/milkdown-migration-plan-v2.md` 与 `docs/milkdown-v2-device-execution-template.md`）。
