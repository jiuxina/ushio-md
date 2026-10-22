# Milkdown 接入审计：魔改程度、性能根因与功能混乱

日期：2026-10-18　范围：`web/milkdown/`、`lib/**/milkdown*`、`assets/milkdown_web/`、`docs/milkdown*`
方法：代码通读 + git 统计 + 可复现微基准。**实测项与推断项已分开标注。**

---

## 零、实测后的更正（2026-10-18 晚，Phase 0 数据回来后）

本报告的 §3.1 把触发频率写错了，以下三条以实测为准（数据见 `docs/milkdown-performance-baseline.md` §5.1）：

1. ❌「每敲一个字符跑一遍全量重算」→ ✅ **每次停顿跑一遍**。`@milkdown/plugin-listener/lib/index.js:75-91` 是 lodash `debounce(handler, 200)` 尾缘触发，且 `tr.getMeta('addToHistory') === false` 时直接 return（`:122`）。连续打字期间整条链不跑，停手 200ms 后跑一次。§3.2 那张表的单位因此是「每停顿」而非「每键」。
2. ❌「`emitHistoryState` 做全历史遍历」→ ✅ `undoDepth`/`redoDepth` 是 O(1)（`prosemirror-history/dist/index.js:434-437` 读 `hist.done.eventCount`）。它的成本只是每停顿一次 `editorInstance.action()` + 一次 IPC。
3. ❌「clipboard/indent/trailing/history 四个 import 后未使用」→ ✅ `history` 的 `undoCommand`/`redoCommand` 在 `executeCommand` 里**有使用**，import 必须保留；只有 `clipboard`/`indent`/`trailing` 是纯冗余。另：删掉这三个之后 **bundle 体积与文件名完全未变**（2,444.88 kB），说明 Rollup 原本就已把它们摇掉了——§2.3 里「可能仍占体积」的保留说法可以定论。

**更重要的一条是瓶颈定位被数据推翻**：每停顿的字符串扫描链实测只占 3–23ms（桌面 3.2 / 真机 22.7），真正支配的是**整篇解析建树**（桌面 Chromium 50K 字符 `crepe.create()` = 2454ms、`replaceAll` = 1015–2290ms，约 0.83–1.3ms/顶层块；AVD 同文档 = **21.9 秒**，比桌面慢 ≈8.9×）与 `syncRenderedDom` 的整棵 DOM 遍历（50K 字符 / 1359 块 = **1.29 秒**）。因此路线 A 的优先级从「Phase 1 合并字符串扫描」改为「先杀整篇重建与 DOM 全遍历」，归因矩阵见 `docs/milkdown-performance-baseline.md` §5.2。

（本报告初稿中「桌面 507K 字符 6 次 chain 0 次 settle → rAF 从未收尾」与「13K 块时 rAF 从未收尾」两句**作废**：那是后台标签里 `requestAnimationFrame` 根本不触发造成的测量假象，不是产品行为，见 §5.3。桌面 507K 字符 `crepe.create()` = 68.9 秒这一条仍然有效。）

---

## 一、结论先行

**是，魔改远超必要程度，而且性能问题主要是我们自己造成的，不是 Milkdown 或 WebView 的固有问题。**

三句话：

1. **架构选错了。** 我们把「markdown 字符串」当成真源，在 ProseMirror 的每次文档变更回调里重新序列化全文 → 跑 3 遍全文正则预处理 → 再把处理结果写回 `currentMarkdown` → 然后全量重扫全文 + 遍历整棵 DOM。这条链**每敲一个字符跑一次**，成本随文档长度线性增长。这是「编辑和渲染性能极其差」的直接原因。
2. **改动面已经失控。** 官方 `@milkdown/crepe` 的三个内建 UI 功能（BlockEdit / Toolbar / LinkTooltip）被显式禁用，然后手写重建；产物是单个 4250 行的 `main.js`、1042 行覆盖样式、2593 行 Dart 专职胶水，`main.js` 一个文件被 84 次提交反复修改，跨越 7 个月。
3. **性能从来没有被证明过。** `docs/milkdown-performance-baseline.md` 定的阈值（输入延迟 Avg≤120ms / P95≤220ms）在 7 个月里**没有任何一次实测回填**（`:29` 整行 `N/A（阻塞）`，`:216` 验收项未勾选）。仓库里有 2115 行 Milkdown 规划文档、多处互相矛盾的防抖数值，但唯一的硬数据是模式切换 440ms/1.4s 和 bundle 4.66MB→2.84MB。

---

## 二、改动面盘点（量化）

### 2.1 代码体量

| 位置 | 行数 | 性质 |
|---|---|---|
| `web/milkdown/src/main.js` | **4250** | 全部手写胶水，单文件 |
| `web/milkdown/src/style.css` | 1042 | 覆盖 Milkdown/Crepe 原生样式 |
| `lib/widgets/milkdown_webview_editor.dart` | 1742 | WebView 容器 + 桥接 |
| `lib/models/milkdown_bridge.dart` | 569 | 消息协议 |
| `lib/services/milkdown_asset_server.dart` | 146 | 本地资源服务器 |
| `lib/widgets/milkdown_warmup_view.dart` | 136 | 1×1 离屏预热 |
| **编辑器专职合计** | **7887** | 其中 Dart 2593 |

另有调用方 `editor_screen.dart` 3117 行（约 300+ 行在管 WebView）、`utils/file_actions.dart` 1634 行。

对照：Milkdown 官方最小接入约为 20 行（`new Crepe({root, defaultValue}).create()`）。

### 2.2 churn

- `main.js`：**84 次提交**（2026-03-21 → 2026-10-17），`web/milkdown/` 整体 100 次。
- `docs/` 49 篇 md 共 **12,619 行 / 103 次提交**；Milkdown 相关 14 篇 **2629 行**，其中最大的一篇是 794 行的 `webview-milkdown-lld.md`。
- 近 120 天内改动最频繁的三个文件：`main.js`(19)、`milkdown_webview_editor.dart`(15)、`style.css`(5)。**修改集中在一个 4250 行的文件里 = 没有模块边界**。

### 2.3 接口面

- Flutter→JS：**3 种信封**（`init_doc` / `update_theme` / `exec_cmd`），命令本身走通用字符串通道：JS 侧 `executeCommand` 是 **566 行单函数、27 个 `case`/`cmd ===` 分支**（`:3604-4170`），Dart 侧在 `editor_screen.dart:2955-3020` 再枚举一遍。
- JS→Flutter：**约 17 类消息**（`milkdown_bridge.dart:444-568` 的 14 个分支 + 3 个绕过 dispatch 散落在外层的 `on_bridge_ready` / `on_ready` / `on_editor_focus`）。
- 依赖 **17 个 `@milkdown/*` 包**，产物 2.44MB JS + 46.9KB CSS + 20 个 KaTeX woff2 ≈ 2.7MB。
- **其中 4 个官方插件 import 后再无任何引用**：`clipboard`（`:9`）、`indent`（`:20`）、`trailing`（`:22`）、`history`（`:18`，含 `undoCommand`/`redoCommand`）——既没有 `.use()`，也没有第二个符号引用点（`grep` 全文命中仅剩 `navigator.clipboard:2570` 和一条注释 `:1170`）。`createEditor` 实际只 `.use()` 了 7 项（`:2995-3001`）。若 Rollup 未能摇掉，这些插件仍占着 2.44MB 里的体积。
  （注：`listener` 只用到 `listenerCtx`，靠 Crepe 内部注册才生效——这一点也说明「谁注册了什么插件」在当前代码里已经查不出来了。）
- Dart→JS 通道用的是**把消息当 JS 字面量注入**（`milkdown_webview_editor.dart:1301-1313`，10 处 `evaluateJavascript`），不是类型化通道；每次 `exec_cmd`/主题/init 都是一次 eval 往返。

### 2.4 两处纯死重

1. **vendored 上游 monorepo 未使用**：仓库根 `milkdown/` 是完整的 Milkdown monorepo，**931 个文件被提交进 git（4.5MB）**，但构建实际解析的是 npm registry 的 `@milkdown/core 7.19.1`（`web/milkdown/package-lock.json:662`）。全仓唯一引用是 `docs/release_v1.4.3_fix_summary.md:119-121` 里当阅读材料。**931 个文件只用来查源码。**
2. **27 个零调用方法**：`MilkdownWebViewController` 上 `toggleBold:289` … `insertEmoji:326` 共 27 个类型化便捷方法全库无调用点，真实入口是通用字符串 `execCmd` switch。两套接口并存。

---

## 三、性能：根因与实测

### 3.1 每敲一个字符，实际发生了什么

`createEditor` 注册的 `markdownUpdated` 回调（`main.js:2956-2986`）在**每次文档变更**（即每次按键、每次 IME 组合提交）执行：

| 步 | 操作 | 代码位置 | 复杂度 |
|---|---|---|---|
| 1 | ProseMirror → markdown **全文序列化**（Milkdown 自身） | `:2956` | O(全文) |
| 2 | `stripGhostCodeLanguageMarkers(markdown)` 全文逐行 + 每个闭栏向后扫 | `:2962` `:541-631` | O(全文) |
| 3 | `wrapHtmlBlocksInCodeFence(...)` 全文逐行，每行 2 个 22 分支正则 | `:2965/2977` `:1153-1259` | O(全文) |
| 4 | `preprocessImageUrlsInMarkdown(...)` 全文 split+join+图片正则替换 | `:2964/2976` `:2426-2479` | O(全文) |
| 5 | `notifyRenderComplete()` → rAF → | `:2985` `:2313` | — |
| 5a | └ `syncRenderedDom()`：**再**全文 `parseMarkdownOutline` + `collectMarkdownImageSources` + `collectFenceLanguages`，然后遍历全部 img / a / h1-h6 / table / pre / code-block / checkbox | `:1954-2271` | O(全文 + 全 DOM) |
| 5b | └ `emitOutlineUpdate()`：**第二次**全文大纲解析 | `:2318` `:1729` | O(全文) |
| 5c | └ `emit('on_render_complete')`：**每键一次 Dart↔JS IPC 往返** | `:2319` | — |
| 5d | └ `emitHistoryState()`：`undoDepth`/`redoDepth` 全历史遍历 | `:2320` `:2273-2288` | O(历史栈) |

`syncRenderedDom` 内部还有更糟的一处：它在**遍历每个代码块的循环体里反向调用 ProseMirror**——`resolveCodeBlockLanguage()`（`:1791`）对每个代码块执行 `editorInstance.action()` + `view.posAtDOM()` + `state.doc.resolve()`，然后按位置回退到祖先节点。代码块数 × 文档解析 = **O(块数 × 文档深度)**。
（`:1800-1811`；且代码块与 markdown 围栏语言是靠**下标位置匹配**的：`fenceLanguages[codeBlockIndex]`、`markdownImageSources[imageIndex]`，`:2008`、`:2145-2214`）

### 3.2 实测：第 2–5a 步中纯字符串部分的耗时

我把 `main.js` 的 384-631 / 964-1014 / 1150-1259 / 2426-2479 行**原样切出**（`sed`，非手抄）在 Node v22 上跑基准，语料为含标题/链接/图片/代码块/HTML 块/复选框的中文混合 markdown：

| 文档 | 行数 | stripGhost | wrapHtml | preprocessImg | outline | **每键纯 JS 合计** |
|---|---|---|---|---|---|---|
| 10 KB | 356 | 0.08 ms | 0.11 | 0.13 | 0.08 | **0.38 ms** |
| 49 KB | 1756 | 0.17 | 0.29 | 0.50 | 0.28 | **1.82 ms** |
| 195 KB | 6934 | 0.66 | 1.22 | 2.09 | 1.11 | **7.61 ms** |
| 500 KB | 17516 | 1.88 | 3.48 | 5.67 | 3.08 | **21.43 ms** |

**这张表是下界，不是全貌**：它不含第 1 步 ProseMirror 全文序列化、不含 5a 的整棵 DOM 遍历与每代码块的 ProseMirror 反向查询、不含 5c 的 IPC、不含 5d 的历史遍历。桌面 Node 到 Android WebView 的 JS 通常慢 5–15×（**未实测，估计值**），所以 200KB 文档在真机上仅这几段字符串处理就可能 40–110 ms/键。

结论：**输入延迟与文档长度成正比，这是结构性的，不是调参能解决的。** 现有的自适应防抖（`calculateAdaptiveDebounceMs`：80/150/300ms，`:144-148`）只推迟了保存，完全没有减少每键计算量。

### 3.3 打开文档的成本：每次全重建

- 每打开一篇文档都 `Navigator.push` 新 `EditorScreen` → 新 `MilkdownWebViewEditor` → `onLoadStop` 全量 `_sendInitDoc` + `_sendTheme`（`editor_screen.dart:2114`、`milkdown_webview_editor.dart:1584-1588`、`editor_navigation_helper.dart:84`）。**WebView 实例与 JS 上下文不复用**，2.44MB JS 每次重新解析编译。
- 唯一的缓解是 1×1 离屏预热视图（`milkdown_warmup_view.dart`，硬超时 12s + settle 800ms）——注释自陈是因为 Android `WebView.warmUp()` 是 `@hide` 才出此下策（`:17-18`）。预热跑的是空文档（`:85-102`），**不缓解大文档的每键成本**。
- 大文档渐进渲染阈值 `PROGRESSIVE_RENDER_THRESHOLD_CHARS = 512 * 1024`（`:161`）——512KB 以下完全走一次性 `replaceAll`。而 QA 记录 **5.8MB 文档首屏 10–15 秒，未达 5 秒目标**（`QA_REPORT_2026_08_25.md:143`；修复前「数分钟未完成首屏、WebView CDP 无响应」`:97-98`）。
- 桥接未就绪时二次 `controller.loadUrl` 绕 bfcache（`milkdown_webview_editor.dart:1540-1555`），JS 里又加 `pageshow` 强制 `location.reload()`（`main.js:4246-4250`）——同一个问题两端各打一个补丁。
- 泄漏迹象：全局资源服务器 `_warmServer` 故意不关（`:140/1458`）、静态 `_cancelCallback`（`milkdown_warmup_view.dart:29`）、分享长图每次再启一个离屏 WebView + ≤30 张截图解码进 `PictureRecorder`（`file_actions.dart:354-422`）。

### 3.4 为什么「从来没有数据」

`docs/milkdown-performance-baseline.md:60-68` 定义了 S/M/L 三档阈值（TTI-Edit P95≤1200/1800/2600ms；输入延迟 Avg≤120 / P95≤220 / Max≤350ms），但：
`milkdown-step3-first-pass-results.md:29` 填的是 `N/A（阻塞）`；`milkdown-migration-status.md:216` 验收项至今未勾选；`ISSUE_FIX_PLAN_2026_08.md:132` 写「未观察到明显卡顿（**定性确认；精确帧率基准未做**）」；`editor-fix-verification-plan.md:212` 的「<50ms」是**预期值不是实测**。
**优化了 7 个月，从未按自己定的协议测过一次。** 这就是为什么改不动到位——每轮都在猜。

---

## 四、功能「乱糟糟」的具体证据

### 4.1 禁掉官方能力，再手写重建

`Crepe.Feature.BlockEdit / Toolbar / LinkTooltip` 三个显式关闭（`main.js:2944-2948`），随后手写：
- 链接 tooltip `:2510-2618`（~110 行，含触摸端「第一 tap 显示、第二 tap 跳转」的双击语义）
- 表格浮动按钮 + 面板 `:2618-2771`
- 右键上下文菜单 `:2771-2850`
- 代码块语言输入框 `:1775-1790` + `:2200-2258`，同时用 **`!important` 把原生 `.language-picker` 和 `.language-button` 藏起来**（`:2185-2198`），并对每个代码块硬写 `display/position/overflow/padding-top` 的 `!important`（`:2171-2183`）。
- 勾选框：原生 `input[type=checkbox]` 点击被 `preventDefault` 接管（`:3056-3072`），Milkdown 自己的 `.label-wrapper` 又走另一条分支（`:3074-3082`）——**同一个控件两套处理路径**。

### 4.2 HTML 块：整条平行渲染管线

`:1153-1259` 把 block-level HTML **改写成假的 ```html-block 代码围栏**骗过 parser；`:1261-1269` 注释明写「ProseMirror 会检测 DOM mutation 并重渲染、抹掉 inline style 和插入的兄弟节点，所以」：注入持久 CSS 隐藏这些伪代码块（`injectHtmlBlockHideStyle` / `hideHtmlBlockCodeNode`），把渲染结果放进 **ProseMirror DOM 树之外的绝对定位 overlay**（`ensureHtmlOverlay`），再用 `MutationObserver`（`startHtmlBlockObserver:1367`）持续对齐位置。
代价：`syncRenderedDom` 每帧三趟全 DOM 查询（`renderRawHtmlNodes` / `renderBlockHtmlGroups` / `renderHtmlBlockCodeNodes`，`:1956-1958`）。
这解释了 HTML 块相关缺陷为什么修不掉——**它已经不在 ProseMirror 的模型里，撤销、选区、协同全部覆盖不到**。

#### 实测到的具体失效（2026-10-18，桌面 Chromium，50K 字符含 48 个 HTML 块）

对同一文档连续调用渲染收尾并比对 DOM 指纹，抓到反馈环本身：

```
第 N 次与第 N+1 次的差异（仅 style 不同，位置逐块放大）：
  data-html-block-index=0   top 9474.25px -> 9482.25px   (+8)
  data-html-block-index=1   top 20025px   -> 20049px     (+24)
  data-html-block-index=2   top 30244.8px -> 30276.8px   (+32)
  data-html-block-index=3   top 40809.7px -> 40857.7px   (+48)
  data-html-block-index=4   top 51306.2px -> 51362.2px   (+56)
  data-html-block-index=5   top 61623.5px -> 61695.5px   (+72)
且所有 overlay 项 width = 2px
```

机制：`renderHtmlBlockCodeNodes` 先量伪块矩形定位 overlay，再读 overlay 的 `offsetHeight` 用 `!important` 回写伪块高度占位；下一趟量到的是**被自己改过的高度**，于是每次收尾都把所有 overlay 往下推一段，且**按文档位置逐级放大**（第 6 个块已偏 72px）。宽度 2px 说明隐藏后的伪块矩形本身不可信。

这不是「偶发错位」，而是**每次打字停顿都会重放一遍的确定性发散过程**——也正是 `ISSUE_FIX_VERIFICATION_2026_10_16.md:171` 记录的「overlay 偏差从 16 放大到 72」的根因（数值都对上了）。修法是切断反馈：占位高度只在 `contentHash` 变化时写，位置一律从不被回写的容器几何推导（Phase 5）。

### 4.3 状态机打架

- **三重回环抑制标志并存**：`suppressNextReload` token（TTL 2000ms，`editor.dart:521/1418-1426/2087`）+ JS 侧 `isApplyingFromFlutter`（`main.js:98/2372/2971/2983`）+ Dart 侧 `_isApplyingHistory`（`editor_screen.dart:73/2094`）+ `_lastSyncedMarkdown`（`:511/1427`）。
- **两套撤销栈**：Flutter `_undoEditHistory`（`editor_screen.dart:594-631`）与 JS `execCmd('undo')`（`:599`）并存。文档已登记「初始化写入计入撤销历史致首次撤销清空文档」（`CHANGELOG.md:168`）。
- **四套光标定位机制互相覆盖**：`ensureCaretInUpperViewport`(`:662`) / `forceCaretIntoUpperViewport`(`:774`) / `scheduleCaretIntoUpperViewport`(`:755`) / `suppressCaretViewportSync`(`:786`)，配合 6 个时间戳闸门（`checkboxInteractionGuardUntil`、`editorTouchScrollSuppressUntil`、`viewportScrollSuppressUntil`、`lastUserScrollAt`、`lastProgrammaticScrollAt`、`lastEditorInteractionAt`）。同一问题被规划了**四轮**：LLD 监听 `window.resize`(`:761-777`) → 强制 scroll_caret(`ISSUE_FIX_PLAN:104`) → 禁止滚动回跳(`CHANGELOG:151-152`) → 「1.2 秒闸门」被 A/B 实验否证并回退(`SESSION_FIXES…:234-242`)。
- **防抖数值四处不一致**：500ms(`webview-milkdown-lld.md:75`) → 120ms(`gap-analysis.md:85`) → 350ms(`ISSUE_FIX_PLAN:106`) → 验证计划仍写约 500ms(`editor-fix-verification-plan.md:137`)；代码里是第四套（80/150/300ms 自适应）。
- **15+ 处 magic timeout**：15s 首渲染、1500ms init 闸门、25ms×100 轮询、3s 服务器、12s 预热硬超时、800ms settle、8s/5s preload、2000ms suppress TTL、120ms 图片重试退避、350ms 合并、150ms 搜索、800ms blur fallback、10s 分享加载……
- **1.5s init 闸门有数据丢失风险**：`initializingEditor` 为真时 `scheduleContentChange` 被跳过（`:2968/2979`），而它由 `setTimeout(endEditorInitialization, 1500)` 兜底解除（`:2348`）。打开文档后 1.5 秒内的编辑能否落盘，取决于 capture 阶段 `keydown` 是否先于 `markdownUpdated`——**这条不变式没有测试覆盖**。

  **2026-10-21 实测：风险比登记的更大，且已修。** 新判据 `web/milkdown/tools/init-gate-oracle.html`
  把被测产物放进 `srcdoc`，在它执行前注入一个 ≤2s 走 MessageChannel 的 `setTimeout`
  （后台标签页的原生定时器会被节流到分钟级，不换掉就复现不出 200ms 的 listener debounce），
  并装 bridge 桩记录 `on_content_change`。测出的机制是：`setDoc` 走 `replaceAll(..., flush=true)`
  **重建 EditorState**，listener 的 `state.init` 把 `prevDoc` 直接设成新文档 ⇒ **根本没有初始回波**；
  而 `isApplyingFromFlutter` 与 1.5s 闸门都没被清掉。结果不是「1.5 秒内的编辑可能丢」，
  而是**打开文档后的第一笔编辑一定丢**（勾选框、工具栏命令、键盘输入都一样），第二笔才会发。
  修法：flush 路径在 `replaceAll` 后立刻 `isApplyingFromFlutter = false; endEditorInitialization()`。
  判据 A（闸门结束后命令）/ B（闸门内 100ms 命令）/ C（只打开不编辑）由 **FAIL / FAIL / PASS** 变为 **3/3 PASS**；
  同时 `html-roundtrip` 9/9、`overlay-oracle` 10/10、`style-baseline` 280916608、`vitest` 27/27 不变，
  `roundtrip-fidelity` 仍为 22/40（已知的语义等价清单，无新增回退）。

### 4.4 已知留开的正确性问题

Milkdown 序列化改写原文（`-`→`*`、插空行、图片 alt 变成 `1.00`）在 `ANDROID_FULL_FUNCTION_TEST_2026_08_10.md:84` 标注「确认是否为产品可接受」——**至今未定性**。这不是 bug 级别，是**数据损坏级别**：编辑器会在用户没要求时改用户的内容。

**2026-10-21 已用判据定性并处理。** 新判据 `web/milkdown/tools/roundtrip-fidelity.html` 把 40 条语法分别喂进编辑器，
不做任何编辑直接比对「序列化输出 == 原文」（逐字节）。修复了四类数据损坏（`src/md-fidelity.mjs`）：

- **图片 alt 被写成 `1.00`**：Crepe 的 image-block 把 mdast `alt` 当宽高比存储，解析时丢弃原文。
  覆盖同名 schema，单独记 `alt` attr；有原文就写原文，没有才沿用 `ratio.toFixed(2)`。
- **紧凑列表被插空行**：`bullet_list` / `list_item` 把字符串 `'false'` 当 `spread` 传给 remark-stringify，
  而它按真值判断。显式转布尔；`list_item` 的覆盖同时保留 GFM 的 `checked`，任务列表不退化为普通项目符号。
- **有序列表起始号 `3.` 变 `1.`**：解析不读 `node.start`、序列化硬编码 `start: 1`。改为双向保留 `order`。
- **Frontmatter 被拆成 `***` + 标题**：解析前剥离首部 YAML，内容回传与诊断序列化时原样接回
  （只认首行 `---`、闭合 `---`、中间至少一行 `key:`，避免把「两条分隔线夹普通文字」误判）。

**判定为语义等价、明确接受的规范化**（不再修，判据会持续显示它们）：
`-`/`+`→`*`、`1)`→`1.`、Setext→ATX、ATX 闭合井号删除、`~~~`→```` ``` ````、缩进代码块→围栏、
表格对齐空格与外侧竖线、两空格硬换行→反斜杠、引用链接展开为内联链接、`---` 分隔线→`***`、
连续空行合并为一条、非硬换行的行尾空格删除。
这些都不改变渲染语义；要保留它们需要存原始 token（marker/围栏字符/空白），代价远大于收益。

判据现状：**22/40 逐字节一致**（2026-10-22 起：未编辑场景 41/41，编辑块的 18 条规范化仍保留，见下）。改后同时通过
`html-roundtrip` 9/9、`overlay-oracle` 10/10、`style-baseline` 指纹 280916608 不变、`vitest` 27/27。

**2026-10-22 真机复验（第 1 项）**：在 AVD 上用真实 release 包走「打开 → 在 Milkdown 里插一个字符 → 保存」，发现三处桌面判据覆盖不到的缺陷，均已修复：

- **首开路径绕过 frontmatter 拆分**：`init_doc` 到达时编辑器通常尚未创建，`ensureEditor() → createEditor()` 直接拿 `currentMarkdown` 做 `defaultValue`，不经过 `setMarkdown`。桌面判据走 `setDoc`（编辑器已存在）所以显示 PASS，真机上 frontmatter 仍被渲染成 `***` + 列表。现在 `init_doc` 在赋值前先 `splitFrontmatter`。
- **相对图片的代理 URL 不可逆**：带 `baseDirectory` 时 `![说明文字](pic.png "图片标题")` 被改写成 `ushio-local-file://…` 仅用于渲染，序列化没有反向映射；旧正则还把 `"图片标题"` 当成路径的一部分，导致图片加载失败、标题丢失、落盘路径被永久改写。现在正则只替换目标并保留 title，出口用 `deproxyImageUrlsInMarkdown` 还原相对路径。
- **列表结尾多一个空行**：remark-stringify 会给以列表结尾的文档补空行；输出端统一为一个结尾换行。

真机证据：打开 587 B 的 `0RtFidelity.md`，在标题插入 `Y` 后保存，落盘 594 B；diff 只有 `# 保真测试 → # 保Y真测试` 与表格对齐空格（已接受项）。frontmatter、`3.` 起始号、任务/松散列表、HTML 块、图片行（含 alt/title/相对路径）全部逐字节不变。判据新增 `baseDirectory` 用例，并给 iframe 加缓存戳（`index.html` 的 immutable 缓存曾让判据悄悄跑旧 bundle）；未编辑场景已改为硬保证：JS 在 `documentEdited=false` 时直接返回原文，App 在 `!_isModified` 时**跳过写盘**，判据 **41/41 逐字节一致**；真机打开后直接保存，文件的 hash/mtime/size 均不变。编辑场景仍走序列化：被重新序列化的块有 18 条语义等价规范化（新增一条：多余的 `\]` 转义被去掉），未触及的块由增量合并保留；`vitest` 31/31。以列表结尾的文档真机复测：24 B → 25 B，diff 只有插入的字符，结尾仍是单个换行。

另外 `plugin-math` 官方已 deprecated 仍在用（`gap-analysis.md:40,86`）；搜索关闭后键盘进不了 WebView 仍待真机（`QA_REPORT:77,147`）；高亮当前行 overlay 偏差从 16 放大到 72（`ISSUE_FIX_VERIFICATION_2026_10_16.md:171`）。

---

## 五、归因：到底是谁的锅

| 归因 | 占比估计 | 证据 |
|---|---|---|
| **我们自己的架构选择** | **约 60%**（主要责任） | 字符串真源 + 每键全文预处理/全 DOM 同步（§3.1）；index 位置匹配（`:2008/2145`）；HTML overlay 平行管线（§4.2）；禁官方 UI 再手写（§4.1）；两套撤销栈；Dart↔JS 每键 IPC |
| **Milkdown / Crepe 本身的限制** | 约 20% | WYSIWYG 往返序列化确实贵；Crepe 的 code-block 用 CodeMirror 6 每块一实例（2.44MB bundle 的主因）；`plugin-math` deprecated；官方无移动端 IME 支持 |
| **Android WebView 平台问题** | 约 20% | 报不出软键盘高度（→ `set_keyboard_metrics` 由 Dart 推算再推回，`editor.dart:853-876`）；`WebView.warmUp()` 是 @hide（→ 1×1 预热视图）；bfcache 不重跑 JS（→ 两端各一个 reload 补丁）；V8 代码缓存只在资源独立成文件时生效（→ vite `assetsInlineLimit: 0`） |

一句话：**平台问题只解释了五分之一。剩下的是我们选了「每次按键把整篇文档重算一遍」这条路。**
文档里 Dart 侧的自评也是这个结论——约 **40% 的 Dart 胶水是在跟 WebView/IME/回环打架**，正常集成只需要 bridge DTO + 一条通用 `exec_cmd` 通道。

---

## 六、可选路线

**A. 停止加补丁 + 定点拆除每键路径（推荐，1–2 周）**
把 `markdownUpdated` 改成只做「脏标记 + debounce」，把 5 个全文解析降为：大纲/图片/围栏只在**打开文档和显式刷新**时算；`syncRenderedDom` 拆成增量（只处理本轮 transaction 影响的节点范围）；`on_render_complete` 不再每键发给 Flutter。
预期收益：每键成本从 O(全文) 降到 O(编辑范围)，§3.2 的 21.43ms 在 500KB 文档上应降到 <1ms。
风险：需要逐个回归已知的 IME/勾选框/代码块语言问题，那些补丁正是靠「每键全量重扫」兜住的。**这是本轮唯一能同时止住性能和「乱」的动作。**

**B. 编辑/预览分层（中等，2–3 周）**
只读预览继续用现在的 Milkdown 渲染；编辑态换成纯 textarea + markdown 源文本（CodeMirror 6 单实例）。彻底绕开 WYSIWYG 往返，性能可预测，功能「乱」问题一次性消失（不再有 overlay/伪围栏/双撤销栈）。
代价：失去 Typora 式所见即所得，是产品定位决策，不是技术决策。**需要你来定。**

**C. 复用 WebView 实例 + 文档级虚拟化（补 A 的打开成本）**
解决 §3.3：编辑器实例池化、切文档不换上下文。注意这需要先确认内存（现有一次分享长图会再启一个离屏 WebView）。

**D. 回退到「轻魔改」基线** — 不建议：已投入 7887 行，且真正的痛点在架构而非某个插件。

**附带清理（无风险，随时可做）**：删掉未使用的 vendored `milkdown/`（931 文件）或改成 git submodule；删掉 27 个零调用便捷方法；删掉 `main.js` 里 4 个 import 后从未使用的官方插件（clipboard / indent / trailing / history）；把 3 处 `console.warn` 调试残留（`:1964/2150`）、`RUNTIME_BUILD_TAG`（`:233`）和 13 个 `debug-*.mjs` 一次性调试脚本移出仓库。

**2026-10-21 核查结果**：仓库当前只跟踪 376 个文件，vendored `milkdown/` 与 13 个 `debug-*.mjs` **都已经不在**；
`clipboard` / `indent` / `trailing` 不是 main.js 的 import，而是 Crepe 构造器内部 `.use(...)` 的依赖，不能从 package.json 删；
逐文件扫描命名 import 后，真正未使用的只剩 `history`（`redoCommand` / `undoCommand` 仍在用），已删除。
`RUNTIME_BUILD_TAG` 仍用于 logcat 核对实际加载的 bundle（§5.11 的规矩），两条 `console.warn` 是 DOM 不变量的告警，
三者都属于有效诊断而非调试残留，保留。构建与 `vitest` 27/27 通过，未改变产物行为。

---

## 七、动手前必须补的测量

报告最大的短板是**没有真机数据**（这不是可选项，是 §3.4 描述的问题本身）。建议先测再改，否则第 5 轮还在猜：

1. 用 `window.__USHIO_BRIDGE__.onFlutterMessage`（`main.js:4233`）灌入 49KB / 195KB / 500KB 三档文档，在真机上连续输入 200 字符，用 Chrome DevTools Protocol 采样每键 long-task 与 `markdownUpdated` 自计时。
2. 按 `milkdown-performance-baseline.md:60-68` 已定义的阈值回填 **TTI-Edit 与输入延迟** 两张表——把 `N/A（阻塞）` 变成数字。
3. 记录 `syncRenderedDom` 单次调用耗时 vs 文档节点数，验证 §3.1 的 O(全 DOM) 判断。

复现 §3.2 的基准（脚本在 gitignore 的 `build/mdbench/perkeystroke.mjs`，`flutter clean` 会删）：

```bash
M=web/milkdown/src/main.js && { sed -n '384,631p;964,1014p;1150,1259p;2426,2479p' $M; <driver>; } > build/mdbench/perkeystroke.mjs
```

---

## 附：本报告的原始数据来源

- 代码：`web/milkdown/src/main.js`（4250 行，逐节引用）、`web/milkdown/vite.config.mjs`、`web/milkdown/package.json`、`lib/widgets/milkdown_webview_editor.dart`（1742）、`lib/models/milkdown_bridge.dart`（569）、`lib/widgets/milkdown_warmup_view.dart`（136）、`lib/services/milkdown_asset_server.dart`（146）
- 文档：`docs/milkdown-performance-baseline.md:60-68`、`docs/milkdown-step3-first-pass-results.md:29`、`docs/milkdown-migration-status.md:216`、`docs/ISSUE_FIX_PLAN_2026_08.md:50-52,132`、`docs/QA_REPORT_2026_08_25.md:97-98,143`、`docs/CHANGELOG.md:16-23,25,32,151-152,168`、`docs/milkdown-feature-gap-analysis.md:40,83-86,138-139`、`docs/SESSION_FIXES_EMULATOR_TEST_PLAN_2026_10_16.md:234-242,258,264-276`、`docs/ANDROID_FULL_FUNCTION_TEST_2026_08_10.md:84`
- git：`git log -- web/milkdown/src/main.js` = 84 次提交；`-- web/milkdown` = 100 次
- 实测：`build/mdbench/perkeystroke.mjs`（Node v22，函数从 main.js 原样 sed 切出）
