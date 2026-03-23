# Milkdown 深度实现分析与官方特性差异对照（ushio-md）

> 分析时间：2026-03-23  
> 分析范围：`web/milkdown/`、`lib/widgets/milkdown_webview_editor.dart`、`lib/models/milkdown_bridge.dart`、相关测试与迁移文档

---

## 1. 核心实现识别

### 1.1 Milkdown 初始化位置

当前唯一初始化入口：

- `/home/runner/work/ushio-md/ushio-md/web/milkdown/src/main.js`
  - `createEditor()`：创建 `Editor.make()`、配置主题/插件、建立 listener 与 bridge 回写
  - `ensureEditor()`：懒初始化
  - `onFlutterMessage(type === 'init_doc')`：首包驱动初始化与文档装载

Flutter 承载入口：

- `/home/runner/work/ushio-md/ushio-md/lib/widgets/milkdown_webview_editor.dart`
  - `MilkdownWebViewEditor`：WebView 生命周期、bridge handler 注册、`init_doc/update_theme/exec_cmd` 下发
  - `_handleBridgeArgs()`：统一分发 Web -> Flutter 消息（含 upload 请求）

### 1.2 当前已加载的官方插件（已完成 Step1-10）

`web/milkdown/src/main.js` 中实际启用链路：

- `@milkdown/preset-commonmark`
- `@milkdown/preset-gfm`
- `@milkdown/plugin-math`
- `@milkdown/plugin-prism`
- `@milkdown/plugin-listener`
- `@milkdown/plugin-block`
- `@milkdown/plugin-history`
- `@milkdown/plugin-indent`
- `@milkdown/plugin-trailing`
- `@milkdown/plugin-clipboard`
- `@milkdown/plugin-upload`
- `@milkdown/plugin-tooltip`
- `@milkdown/plugin-slash`
- 主题：`@milkdown/theme-nord`（`config(nord)`）

### 1.3 自定义插件识别

未发现通过 `.use(customPlugin)` 注册的 Milkdown 自定义插件。  
当前自定义能力主要在“Bridge 与业务层”：

- 上传桥接：
  - Web -> Flutter：`on_upload_images_request`（携带 dataUrl 文件）
  - Flutter -> Web：`exec_cmd(upload_images_result)`（回传解析后的 `images`）
- 本地图片落盘策略（`images/` 子目录）：
  - `/home/runner/work/ushio-md/ushio-md/lib/widgets/milkdown_webview_editor.dart`
  - `/home/runner/work/ushio-md/ushio-md/lib/services/my_files_service.dart`
- 渲染后 DOM 同步：链接、checkbox、heading id、图片错误回调

---

## 2. 官方核心特性与插件生态（基于 v7 最新稳定线认知）

### 2.1 官方核心能力

- 核心：`@milkdown/core`、`@milkdown/ctx`、`@milkdown/prose`、`@milkdown/utils`
- 转换层：`@milkdown/transformer`
- 预设：`@milkdown/preset-commonmark`、`@milkdown/preset-gfm`
- 主题与 UI：`@milkdown/theme-*`、`@milkdown/components`、`@milkdown/react`
- 开箱组合：`@milkdown/kit`、`@milkdown/crepe`

### 2.2 官方插件生态（本项目相关）

- listener / history / tooltip / slash / block / indent / trailing / clipboard / upload / prism / math

---

## 3. 差异对照表

| 特性/插件名称 | 官方状态 | 本项目是否实现 | 本地实现路径/说明 | 差异点/待补齐功能 |
| --- | --- | --- | --- | --- |
| Core Editor (`@milkdown/core`) | 官方核心，活跃（7.19.1） | 是 | `web/milkdown/src/main.js` | 已对齐主版本 |
| CommonMark Preset | 官方核心预设 | 是 | `.use(commonmark)` | 已实现 |
| GFM Preset | 官方核心预设 | 是 | `.use(gfm)` + `insertTableCommand` | 已实现 |
| Theme (`theme-nord`) | 官方主题 | 是 | `config(nord)` | 主题体系单一，可扩展更多主题策略 |
| Listener Plugin | 官方插件 | 是 | `.use(listener)` + `markdownUpdated` | 长文档回写仍是全量 markdown，上报压力可优化 |
| Prism Plugin | 官方插件 | 是 | `.use(prism)` | 已实现 |
| Math Plugin | 官方插件（deprecated） | 是 | `.use(math)` | 需长期关注替代方案或上游后续路线 |
| History Plugin | 官方插件 | 是 | `.use(history)` + undo/redo command | 已实现 |
| Tooltip Plugin | 官方插件 | 是 | `.use(tooltip)` + `TooltipProvider` | 当前仅最小按钮集（B/I） |
| Slash Plugin | 官方插件 | 是 | `.use(slash)` + `SlashProvider` | 当前动作集较小，可继续扩展 |
| Block Plugin | 官方插件 | 是 | `.use(block)` + `BlockProvider` | 已最小接入，可增加块菜单能力 |
| Indent Plugin | 官方插件 | 是 | `.use(indent)` | 已实现 |
| Trailing Plugin | 官方插件 | 是 | `.use(trailing)` | 已实现 |
| Clipboard Plugin | 官方插件 | 是 | `.use(clipboard)` | 已实现，需真机矩阵验证各 WebView 行为差异 |
| Upload Plugin | 官方插件 | 是 | `.use(upload)` + `uploadConfig` 自定义 uploader | 已桥接 Flutter 落盘，尚可优化为二进制通道避免 dataUrl 膨胀 |
| Upload 业务桥接（非官方插件） | 官方可扩展能力 | 是（自定义实现） | `main.js` + `milkdown_webview_editor.dart` + `milkdown_bridge.dart` | 已实现 request/result 协议，但需要更完善失败态与限流策略 |
| Kit / Crepe | 官方开箱方案 | 否 | 未接入 | 当前 Flutter + WebView 架构不强依赖，可按需评估 |
| 自定义 Milkdown 插件（`.use(custom)`) | 官方支持扩展 | 否 | 无 | 当前定制集中在 bridge 层，不是插件层 |

---

## 4. 优化建议

1. **上传链路优化（优先）**
   - 当前 upload 桥接基于 dataUrl 透传，图片体积大会放大 JS bridge 负载。
   - ✅ 已完成第一步：增加上传保护阈值（单文件大小/总大小/数量）并将文件转换改为顺序处理，降低并发峰值内存压力。
   - 下一步建议：评估“文件句柄/临时路径 + 原生侧读写”或分片策略。

2. **命令与回执可观测性增强**
   - ✅ 已完成第二步：在保留 `on_cmd_result` 的同时新增 `on_cmd_metric`（耗时+成功状态）与 `on_cmd_failure_aggregate`（失败原因聚合计数）。
   - 便于定位不同 WebView 版本兼容差异与高频失败命令。

3. **内容回写策略优化**
   - 当前 `on_content_change` 为全量 markdown 回写，长文档频繁编辑时成本较高。
   - 建议引入最小防抖窗口或增量策略（前提是 Flutter 侧消费模型可兼容）。

4. **插件能力继续扩展**
   - `tooltip` 与 `slash` 当前是最小可用动作集，可逐步对齐现有工具栏能力（如图片、表格参数化、更多块类型）。
   - `block` 可结合自定义块菜单提升“拖拽 + 块操作”体验。

5. **测试与真机验收收口**
   - 代码层已补充 upload bridge 单测，但当前环境缺 `flutter/dart` 可执行能力，未跑完整测试。
   - 建议在 CI 或本地完整跑：`flutter test` + 设备矩阵 checklist（clipboard/upload/大文档）。

---

## 5. 结论

- Step1-10 对照计划已在代码与文档层完成接入。
- 项目当前已经覆盖官方主要编辑插件生态（含 clipboard/upload）。
- 现阶段的主要差异不在“有没有”，而在“高负载场景下的桥接效率、可观测性与真机矩阵稳定性”。
