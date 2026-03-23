# Milkdown V7 全功能接入路线图（ushio-md）

> 更新时间：2026-03-23  
> 范围：`web/milkdown`、`lib/widgets/milkdown_webview_editor.dart`、`lib/models/milkdown_bridge.dart`

## 1) 官方组件全量审计（Milkdown V7）

### 1.1 Presets（预设）

| 组件 | 核心功能 | 当前仓库状态 |
| --- | --- | --- |
| `@milkdown/preset-commonmark` | 提供 CommonMark 核心 schema、命令与 markdown 转换能力 | ✅ 已接入 |
| `@milkdown/preset-gfm` | 提供 GitHub Flavored Markdown 扩展（表格、删除线、任务列表等） | ✅ 已接入 |

### 1.2 Plugins（官方插件）

| 组件 | 核心功能 | 当前仓库状态 |
| --- | --- | --- |
| `@milkdown/plugin-listener` | 监听 markdown/doc 生命周期事件（内容变更、初始化等） | ✅ 已接入 |
| `@milkdown/plugin-history` | ProseMirror 历史记录（undo/redo） | ✅ 已接入 |
| `@milkdown/plugin-tooltip` | 选区浮动工具条（格式化入口） | ✅ 已接入（动作集可继续扩展） |
| `@milkdown/plugin-slash` | 斜杠命令面板（`/` 快速插入块/结构） | ✅ 已接入（动作集可继续扩展） |
| `@milkdown/plugin-block` | 块级操作入口（块菜单/拖拽锚点能力基础） | ✅ 已接入（当前为最小可用） |
| `@milkdown/plugin-cursor` | 光标/选区可视增强与编辑定位体验优化 | ✅ 已接入 |
| `@milkdown/plugin-indent` | 列表/引用等节点缩进与反缩进能力 | ✅ 已接入 |
| `@milkdown/plugin-trailing` | 文档末尾保留可编辑尾部节点，提升文末可输入性 | ✅ 已接入 |
| `@milkdown/plugin-clipboard` | 剪贴板粘贴/复制处理增强 | ✅ 已接入 |
| `@milkdown/plugin-upload` | 图片/文件上传扩展点（可接管上传逻辑） | ✅ 已接入（已桥接 Flutter） |
| `@milkdown/plugin-prism` | 代码块语法高亮（Prism） | ✅ 已接入 |
| `@milkdown/plugin-math` | 数学公式节点与渲染集成（KaTeX） | ✅ 已接入（官方已标 deprecated） |
| `@milkdown/plugin-automd` | Markdown 输入自动转换规则（auto markdown） | ✅ 已接入 |
| `@milkdown/plugin-emoji` | Emoji 补全/输入支持 | ✅ 已接入 |
| `@milkdown/plugin-highlight` | 高亮标记扩展（`==highlight==`） | ✅ 已接入 |
| `@milkdown/plugin-collab` | 协同编辑能力（Yjs 等协作栈） | ❌ 未接入 |

### 1.3 Components（交互组件）

| 组件 | 核心功能 | 当前仓库状态 |
| --- | --- | --- |
| `@milkdown/components` | 官方 UI 组件集（工具栏、菜单、上传等可组合组件能力） | ❌ 未接入 |
| `@milkdown/crepe` | 官方“开箱即用”编辑器组件（预置 UI/交互） | ❌ 未接入 |
| `@milkdown/react` | React 集成层（Provider、hooks、组件化接入） | ❌ 未接入（当前项目为 Flutter + WebView） |

### 1.4 Themes（主题）

| 组件 | 核心功能 | 当前仓库状态 |
| --- | --- | --- |
| `@milkdown/theme-nord` | 官方 V7 主题包（变量与视觉基线） | ✅ 已接入 |

---

## 2) 存量与差异分析（Gap Analysis）

### 2.1 已完全接入（稳定运行）

| 能力 | 现状说明 | 代码位置 |
| --- | --- | --- |
| CommonMark + GFM 基础能力 | 编辑器基础 schema/命令完整运行 | `web/milkdown/src/main.js` |
| 历史记录 | 已切换为官方 `plugin-history` 的 undo/redo | `web/milkdown/src/main.js` |
| 监听回写 | 已接入 `plugin-listener`，并有内容变更防抖 | `web/milkdown/src/main.js` |
| 代码高亮 | `plugin-prism` + Prism 主题可用 | `web/milkdown/src/main.js` |
| Markdown 自动转换 | `plugin-automd` 已接入输入自动转换链路 | `web/milkdown/src/main.js` |
| Emoji 与高亮语法扩展 | `plugin-emoji` / `plugin-highlight` 已接入 | `web/milkdown/src/main.js` |
| 基础交互插件 | `block/cursor/indent/trailing/clipboard` 已进入正式链路 | `web/milkdown/src/main.js` |
| 上传桥接主链路 | `plugin-upload` 已与 Flutter bridge 联动，支持回执 | `web/milkdown/src/main.js`、`lib/widgets/milkdown_webview_editor.dart`、`lib/models/milkdown_bridge.dart` |
| 主题基线 | 使用 `theme-nord` + CSS 变量映射深浅色 | `web/milkdown/src/main.js`、`web/milkdown/src/style.css` |

### 2.2 部分接入 / 待优化

| 能力 | 当前问题 | 优化方向 |
| --- | --- | --- |
| `plugin-tooltip` | 已可用但动作集仍偏精简 | 继续补齐链接/分割线/任务列表等高频动作 |
| `plugin-slash` | 已有常用命令，但仍可继续对标官方演示丰富度 | 按场景补齐更多 block/模板命令 |
| `plugin-block` | 当前以最小接入为主 | 增强块级菜单能力与可发现性 |
| `plugin-upload` | 当前 Web->Flutter 以 dataUrl 传输，长图/多图桥接开销高 | 引入二进制/分片/临时文件句柄通道 |
| `plugin-listener` 回写策略 | 当前仍是全量 markdown 回写（已做 120ms 防抖） | 评估增量回写或批量提交策略 |
| `plugin-math` | 依赖官方 deprecated 包 | 制定替代方案观察窗口与降级策略 |

### 2.3 完全未接入（官方能力）

| 分类 | 未接入项 | 说明 |
| --- | --- | --- |
| Plugins | `plugin-collab` | 协同编辑能力（Yjs 等协作栈） |
| Components | `@milkdown/components`、`@milkdown/crepe`、`@milkdown/react` | 当前项目主架构是 Flutter + WebView，自定义 UI 为主 |
| Themes | 除 `theme-nord` 外暂无多主题包并行接入 | 当前依赖 CSS 变量适配深浅色，未做官方主题包切换体系 |

---

## 3) 全量接入实施计划（分阶段）

### 阶段 A：基础核心层（稳定内核与协议）

| 目标 | 技术步骤（安装 / 配置 / 集成点） |
| --- | --- |
| 固化 V7 基线 | 1) 锁定 `@milkdown/*` 版本；2) 在 `web/milkdown/package.json` 维护统一版本策略；3) 每次升级后执行 `npm ci && npm run build` 并同步 `dist/index.html` 到 `assets/milkdown_web/index.html` |
| 保持 bridge 协议稳定 | 1) 统一维护 `exec_cmd` / `on_cmd_result` / `on_content_change`；2) 协议变更同时修改 `main.js` + `milkdown_bridge.dart` + 对应测试 |
| 提升可观测性 | 1) 扩展 `on_cmd_metric` / 失败聚合；2) 将关键命令耗时、失败原因接入 Flutter 日志与埋点 |

### 阶段 B：通用 Markdown 层（语法能力补齐）

| 目标 | 技术步骤（安装 / 配置 / 集成点） |
| --- | --- |
| 接入高价值语法插件 | 1) 安装 `@milkdown/plugin-highlight`、`@milkdown/plugin-emoji`、`@milkdown/plugin-automd`；2) 在 `createEditor()` 中 `.use(...)` 注册；3) 在 slash/tooltip 添加对应入口 |
| 数学能力长期治理 | 1) 保留 `plugin-math` 现状并标注 deprecated 风险；2) 在文档中建立替代路线（兼容层/切换开关）；3) 增加异常降级展示策略 |
| Markdown 兼容性验证 | 1) 以典型文档集做 round-trip（md -> editor -> md）；2) 检查表格/任务列表/数学公式/高亮标记是否无损 |

### 阶段 C：高级交互层（编辑体验对标官方示例）

| 目标 | 技术步骤（安装 / 配置 / 集成点） |
| --- | --- |
| 扩展 Slash / Tooltip / Block | 1) 完整梳理官方 demo 动作集；2) 在 `SlashProvider` 与 `TooltipProvider` 增加高频动作与错误提示；3) 与 Flutter 工具栏命令对齐 |
| 上传链路性能升级 | 1) 将 dataUrl 桥接逐步替换为“临时路径/二进制”协议；2) 保留失败重试与批量限制；3) 增加进度/失败态 UI 回执 |
| 可编辑性细节优化 | 1) 强化光标定位、表格单元格跳转、长文档滚动恢复；2) 对齐 Android 键盘弹起后的视觉视口处理 |

### 阶段 D：UI/UX 增强层（主题与组件体系）

| 目标 | 技术步骤（安装 / 配置 / 集成点） |
| --- | --- |
| 主题体系增强 | 1) 基于 `theme-nord` + CSS 变量建立“主题令牌层”；2) 将 Flutter 主题配置映射为统一 token；3) 减少硬编码颜色 |
| 评估官方组件集接入 | 1) PoC `@milkdown/components`（仅在 Web 端容器中启用）；2) 与当前自定义 UI 做 A/B 对比；3) 保留可回滚开关 |
| 端到端体验收官 | 1) 真机矩阵回归（剪贴板、上传、大文档、键盘）；2) 输出性能基线（首帧、编辑延迟、bridge 吞吐） |

---

## 4) 技术考量与注意事项

| 维度 | 风险点 | 建议策略 |
| --- | --- | --- |
| 性能（插件过多） | 插件链增长导致初始化慢、输入延迟增加 | 分层按需启用插件；重型能力延迟加载；持续监控初始化耗时与输入 RTT |
| 性能（桥接负载） | 全量 markdown 高频回传 + dataUrl 上传易放大内存与主线程压力 | 保留防抖并引入批处理；上传改为二进制/临时文件协议；限制单次上传体量 |
| 样式冲突 | Milkdown 默认样式与 Flutter 注入样式、WebView 默认样式冲突 | 使用命名空间 CSS 变量与统一 reset；避免全局标签级覆盖；建立主题 token 映射层 |
| Markdown 一致性 | 不同插件/命令可能造成序列化格式漂移 | 建立 round-trip 回归用例；固定序列化策略；对关键语法（表格/任务/数学/高亮）做无损校验 |
| 兼容性 | Android WebView 版本差异导致 clipboard/upload 行为不一致 | 维护设备矩阵回归清单；关键能力提供降级路径与明确错误提示 |

---

## 5) 建议执行顺序（最小风险）

1. 先完成 **阶段 A**（版本、协议、可观测性）。  
2. 再推进 **阶段 B**（语法插件补齐）并做 Markdown 一致性回归。  
3. 接着做 **阶段 C**（交互增强 + 上传性能治理）。  
4. 最后完成 **阶段 D**（主题与组件体系、真机收官）。

该顺序能保证在“功能变多”之前，先把稳定性与可观测性打牢，降低回归成本。
