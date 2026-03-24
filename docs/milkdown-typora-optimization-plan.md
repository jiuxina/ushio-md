# Milkdown 编辑体验优化计划书（Typora 手感对齐）

> 适用仓库：`jiuxina/ushio-md`  
> 制定时间：2026-03-23  
> 目标：在保持现有 Flutter + WebView + Milkdown 架构不变的前提下，让编辑体验更贴近 Typora，且同时兼容手机端与电脑端操作逻辑。  
> 范围说明：本计划基于当前代码现状制定，重点覆盖 `web/milkdown/src/main.js`、`web/milkdown/src/style.css`、`lib/widgets/milkdown_webview_editor.dart`、`lib/screens/editor_screen.dart` 四条主链路。

---

## 1. 现状基线（基于当前代码）

当前 Milkdown 已具备较完整编辑核心能力：

- Web 端主入口：`web/milkdown/src/main.js`
  - 已接入 `history/tooltip/slash/block/indent/trailing/clipboard/upload` 等官方插件。
  - 已有 `exec_cmd` 命令路由（撤销重做、加粗斜体、插表格、插图、搜索跳转、上传结果回传）。
  - 已有 `on_content_change` 防抖（120ms）、`on_outline_update`、`on_cmd_result` 与命令遥测。
- Web 样式层：`web/milkdown/src/style.css`
  - 已完成基础主题变量映射、heading 高亮动画、浮层按钮样式。
- Flutter 承载层：`lib/widgets/milkdown_webview_editor.dart`
  - 已完成 `init_doc/update_theme/exec_cmd` 下发与统一 bridge 分发。
  - 已完成图片上传 request/result 桥接与落盘。
- 编辑页业务层：`lib/screens/editor_screen.dart`
  - 已有预览态搜索跳转（`search_jump`）、目录跳转、复选框状态同步、链接点击处理。

**结论**：基础能力已经“可用”，下一阶段重点应从“功能有无”转向“交互细腻度、输入连贯性、端侧一致性”。

---

## 2. 体验目标（Typora 手感拆解）

对齐 Typora 手感，核心不是单一功能，而是以下四个体验维度：

1. **输入不断流**：光标稳定、输入反馈即时、少打断弹窗。
2. **所见即所得**：结构化块（表格/列表/引用/代码）编辑时自然，不跳戏。
3. **弱工具感**：常用能力“就近可达”（键盘、手势、轻量浮层），而不是频繁切换面板。
4. **跨端一致**：手机端与电脑端在“能力集合一致”的基础上，交互方式按设备习惯差异化。

---

## 3. 优化列表（按优先级）

> 说明：每项都给出“现状锚点（代码）—优化动作—验收标准”，便于后续逐步落地。

| 优先级 | 优化项 | 现状锚点（代码） | 计划优化动作 | 验收标准 |
| --- | --- | --- | --- | --- |
| P0 | 输入链路去打断（图片插入） | `main.js` 中 `insert_image_prompt` 使用 `window.prompt` | 替换为 Flutter 原生图片选择/链接输入流程，Web 侧只保留命令与结果回执 | 编辑时不再出现浏览器 prompt；手机与桌面统一由原生 UI 承接 |
| P0 | 搜索体验连续化 | `editor_screen.dart` 的 `_performInlineSearch/_jumpToSearchMatch` + `main.js:search_jump` | 增加“上一个/下一个命中”与当前命中计数，统一编辑态/预览态行为反馈 | 搜索栏可连续跳转，不需要重复点候选 |
| P0 | 光标/选区稳定性 | `main.js` 的 `setMarkdown/replaceAll`、`on_content_change` | 降低不必要整文替换触发，补充“仅外部变更才 replaceAll”守卫策略 | 连续输入、撤销重做、上传插图后，光标不跳到意外位置 |
| P1 | Slash 菜单可用性升级 | `main.js` 中 `createSlashElement/runSlashAction` | 增加任务列表、分割线、二级引用、代码语言模板等高频项，支持移动端更大触控面积 | Slash 菜单覆盖常见结构创建，手机点按准确率提升 |
| P1 | Tooltip 更贴近 Typora | `main.js` 中 `createTooltipElement` | 增加链接/删除线/行内代码等基础格式按钮，并支持选区为空时隐藏策略优化 | 选中文本后常用格式 1 次点击可达，误触减少 |
| P1 | 表格编辑手感增强 | `gfm + insertTableCommand` 现有仅插入能力 | 增加表格内 Tab/Shift+Tab 导航策略与手机端辅助操作入口（如行列操作菜单） | 表格连续录入不需频繁离开键盘 |
| P1 | 目录跳转体感优化 | `on_outline_update` + `scrollToHeading` + `heading-flash` | 跳转后增加短暂定位保持（防止立刻被键盘/重排打断），统一高亮时长 | 目录点击后定位稳定，用户不迷失上下文 |
| P2 | 移动端键盘与视口适配 | `milkdown_webview_editor.dart` WebView 承载 | 补齐输入法弹出时可视区域策略与底部遮挡规避，确保浮层不被键盘覆盖 | 手机端输入时光标、slash/tooltip 不被遮挡 |
| P2 | 桌面端快捷键补齐 | `exec_cmd` 已支持部分命令 | 对齐常用快捷键映射（如加粗/斜体/查找下一项）并保留平台差异（Ctrl/Cmd） | 外接键盘/桌面环境可高效操作 |
| P2 | 上传链路性能与容错 | `customUploadHandler` dataUrl 桥接 | 在现有限制基础上补失败重试、用户可读错误提示、更细粒度失败原因 | 大图/多图上传失败时可恢复，不出现“静默失败” |
| P3 | 可观测性与灰度开关 | `on_cmd_metric/on_cmd_failure_aggregate` 已存在 | 新增关键体验指标埋点（搜索跳转成功率、slash 使用率、撤销失败率），并预留开关 | 迭代后可量化“是否更像 Typora” |

---

## 4. 手机端与电脑端适配策略（同能力，不同交互）

### 4.1 手机端（触控优先）

- **入口密度降低**：优先保留高频动作（标题/列表/任务/表格/图片），按钮尺寸增大。
- **减少文本输入中断**：避免浏览器原生 prompt；优先使用 Flutter 弹层或底部 sheet。
- **键盘遮挡治理**：slash/tooltip/搜索浮层与软键盘避让联动。
- **滑动与点按冲突处理**：块拖拽、列表勾选、链接点击需有触控阈值区分，避免误触。

### 4.2 电脑端（键鼠优先）

- **快捷键优先路径**：常用格式、搜索跳转、表格导航可纯键盘完成。
- **悬浮反馈更轻量**：tooltip/slash 响应更快，支持鼠标 hover/选区触发细化。
- **精细化选择操作**：支持多光标（若后续可行）与块级拖拽可视反馈增强。

### 4.3 跨端统一原则

- 命令语义统一使用 `exec_cmd`（Flutter -> Web）与 `on_cmd_result`（Web -> Flutter）；
- 设备差异仅体现在“触发方式”与“UI 呈现”，不拆分两套业务协议。

---

## 5. 分阶段优化步骤（可直接执行）

> 每一步都包含“修改点 + 验证点”，用于后续你让我逐步优化时直接按阶段推进。

### Step A（P0）：去打断与连续编辑基线

**目标**：先解决最影响 Typora 手感的问题（打断、跳转不连续、光标漂移）。

1. 图片插入流程去 prompt
   - 修改点：
     - `web/milkdown/src/main.js`：弱化/移除 `insert_image_prompt` 的 `window.prompt` 依赖，改为发桥接请求。
     - `lib/widgets/milkdown_webview_editor.dart`：接收请求并调用 Flutter 侧选择器，再回传 `upload_images_result` 或 `insert_image` 参数。
   - 验证点：
     - 手机/桌面插图均不出现浏览器原生弹窗；
     - 取消选择时有明确回执，不影响继续输入。

2. 搜索“连续跳转”能力
   - 修改点：
     - `lib/screens/editor_screen.dart`：在现有 inline search 基础上增加 next/prev 控制和当前命中索引状态。
     - `web/milkdown/src/main.js`：`search_jump` 支持循环跳转或明确边界反馈。
   - 验证点：
     - 查询后可一步步跳转所有命中；
     - 编辑态与预览态交互一致。

3. 光标稳定守卫
   - 修改点：
     - `main.js`：限制 `replaceAll` 触发场景，避免内部编辑回流导致的无效整文覆盖。
     - `editor_screen.dart`：仅在必要时触发 WebView reload/init_doc。
   - 验证点：
     - 连续输入 30 秒无明显光标跳跃；
     - 撤销重做后选区位置符合预期。

---

### Step B（P1）：高频编辑操作“就近可达”

**目标**：减少“为了做一件小事要切模式/找入口”的操作成本。

1. Slash 菜单扩展与触控优化
   - 修改点：`main.js` 的 `actions/runSlashAction`、`style.css` 的触控尺寸/间距。
   - 验证点：任务列表、分割线、常见块一屏可达，手机点按误触率下降。

2. Tooltip 按钮集扩展
   - 修改点：`main.js:createTooltipElement` 增补链接、删除线、行内代码等。
   - 验证点：选中文本后 1 次点击可完成常见格式化。

3. 表格内编辑流优化
    - 修改点：`main.js` 表格相关命令与按键行为；必要时桥接 Flutter 辅助菜单。
    - 验证点：表格录入可连续横向/纵向移动，接近 Typora 体验。

#### Step B 实施记录（2026-03-23）

- 已扩展 Slash 菜单高频项：任务列表、分割线、二级引用、`JavaScript` 代码块模板；
- 已扩展 Tooltip 按钮集：删除线、行内代码、链接；
- 已新增表格连续编辑命令：`table_next_cell` / `table_prev_cell`（映射到 GFM `goToNextTableCellCommand` / `goToPrevTableCellCommand`）；
- 已补充 `exec_cmd` 路由命令：
  - `toggle_strikethrough`
  - `toggle_inline_code`
  - `toggle_link`
  - `insert_hr`
  - `table_next_cell`
  - `table_prev_cell`
- 已优化触控样式：Slash 面板滚动与按钮点击面积提升（coarse pointer 下放大）。

---

### Step C（P2）：端侧深度适配（手机/桌面）

**目标**：在不分叉协议的前提下，让两端都“顺手”。

1. 手机软键盘避让与浮层定位
   - 修改点：`milkdown_webview_editor.dart`（WebView 布局/可视区域）、`style.css`（浮层最大高度与滚动）。
   - 验证点：键盘弹出后 slash/tooltip/搜索栏均可见可点。

2. 桌面键盘映射补齐
   - 修改点：`main.js` 命令层按键映射（Ctrl/Cmd 兼容）。
   - 验证点：外接键盘下高频操作无需触屏点击。

#### Step C 实施记录（2026-03-23）

- 已增加移动端视口/软键盘适配变量：
  - `--ushio-viewport-height`
  - `--ushio-keyboard-inset`
- 已在 Web 侧监听 `window.visualViewport` 的 `resize/scroll` 与窗口 `resize/orientationchange`，动态更新浮层与编辑区可视高度；
- 已让 slash/tooltip 与编辑容器在软键盘弹出时自动避让（含底部 inset 补偿）；
- 已补齐桌面快捷键映射（Ctrl/Cmd）：
  - `B` 加粗
  - `I` 斜体
  - `K` 链接
  - `E` 行内代码
  - `Shift+X` 删除线
  - `Z` 撤销 / `Shift+Z` 重做
  - `Y` 重做

---

### Step D（P2-P3）：性能、稳定性、可观测性收口

**目标**：确保优化可长期维护，不是“主观感觉变好”。

1. 上传与命令失败可恢复
   - 修改点：`main.js` upload 失败分型；`milkdown_webview_editor.dart` 失败提示与回传规范。
   - 验证点：失败后可重试，不阻断编辑主流程。

2. 体验指标埋点
   - 修改点：扩展已有 `on_cmd_metric/on_cmd_failure_aggregate`。
   - 验证点：可按版本对比搜索跳转成功率、命令失败率、上传失败率。

3. 文档与回归清单同步
   - 修改点：更新 `docs/milkdown-migration-status.md`、`docs/milkdown-device-regression-checklist.md`。
   - 验证点：每次迭代有统一验收记录，便于回归。

#### Step D 实施记录（2026-03-23）

- 上传失败恢复：
  - Flutter 侧新增上传落盘重试（最多 2 次）；
  - 失败原因细分为：`upload_empty_file` / `upload_decode_failed` / `upload_write_failed` / `upload_persist_retries_exhausted` / `upload_failed`；
  - 上传失败时提供可读 SnackBar，并支持“一键重试”；
- 可观测性增强：
  - Slash 动作新增 `on_cmd_metric` 埋点（`cmd=slash_action:*`）；
  - 上传失败聚合上报增强（`cmd=upload_images`，含 reason/count）；
  - Flutter 侧 `on_cmd_result` 失败时增加用户可读提示（SnackBar）；
- 产物同步：
  - 保持 `web/milkdown` 构建后同步 `assets/milkdown_web/index.html`。

---

## 6. 迭代执行建议（你后续“逐步优化”时的工作流）

建议按以下节奏推进，保证每步都能回滚、可验收：

1. **单步只改一个体验主题**（例如先做“搜索连续跳转”）；
2. 每步都执行：
   - Web 构建验证：`cd /home/runner/work/ushio-md/ushio-md/web/milkdown && npm run build`
   - 相关桥接/业务单测（在具备 Flutter 环境时执行）；
3. 每步都记录：
   - 改了哪些文件；
   - 解决了什么手感问题；
   - 手机端/电脑端各怎么验证。

---

## 7. 风险与边界

- `plugin-math` 目前处于 deprecated 状态，后续升级需单独评估替代路径（不在本轮“手感优化”主线内）。
- WebView + JS Bridge 在大 payload（尤其图片 dataUrl）场景仍有性能边界，需避免把“手感优化”变成“桥接超载”。
- Typora 体验可接近但不必机械复刻，应优先符合本项目移动端主场景。

---

## 8. 本计划的交付物定义

本计划书已满足以下可执行性要求：

- 有明确优化列表（含优先级、代码锚点、验收标准）；
- 有分阶段优化步骤（Step A-D）；
- 明确了手机端与电脑端的适配差异与统一协议原则；
- 全部建议均基于当前仓库已有实现路径，不是脱离代码的泛化建议。
