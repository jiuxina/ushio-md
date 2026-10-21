# Milkdown 性能基线采样规范（Step 2）

> 目标：统一性能采样方法、指标定义、记录格式与通过阈值，确保不同设备/版本下结果可复测、可对比。  
> 适用范围：`MilkdownWebViewEditor` 编辑页 + 全屏预览核心链路。

## 1. 采样前置条件

为降低噪音，采样前需满足：

1. 使用 release/profile 包（禁止 debug 包）。
2. 关闭开发者调试悬浮层与性能覆盖层。
3. 每台设备固定电量区间（建议 >50%）与常温环境。
4. 同一轮采样内保持网络环境一致（Wi-Fi 或离线模式固定）。
5. 每项指标至少采样 5 次，取中位数（P50）与 P95。

## 2. 文档规模定义（小 / 中 / 大）

使用固定样本文档，避免“每次随机内容”导致偏差：

- **小文档（S）**：约 200~400 行，少量标题/列表，1 张以内图片。
- **中文档（M）**：约 1,000~1,500 行，含多级标题、任务列表、2~5 张图片、至少 1 个表格。
- **大文档（L）**：约 3,000+ 行，含长列表、多表格、多图片、代码块混排。

> 要求：同一设备同一轮采样必须使用同一份 S/M/L 文档，不得中途替换。

## 3. 指标定义与采样方式

### 3.1 首屏可编辑时间（TTI-Edit）

- **定义**：从进入编辑页开始，到用户可稳定输入且首个字符成功回写 `on_content_change` 的耗时。
- **采样方式**：
  1. 冷启动进入目标文档；
  2. 进入编辑页后立即开始计时；
  3. 输入固定字符（例如 `a`）；
  4. 以字符可见且回写事件成功作为结束点。
- **统计**：记录 5 次，输出 P50/P95。

### 3.2 长文档输入响应（Input Latency）

- **定义**：在 L 文档中连续输入时，“按键触发”到“字符渲染可见”的延迟。
- **采样方式**：
  1. 光标定位到文档中部与尾部各 1 处；
  2. 连续输入 30 秒（固定节奏）；
  3. 记录平均延迟与最大延迟。
- **统计**：输出 Avg / P95 / Max。

### 3.3 滚动流畅度（Scroll Smoothness）

- **定义**：在 M/L 文档快速滚动场景下的帧稳定性与卡顿情况。
- **采样方式**：
  1. 从文档顶部快速滑到底部，再回到中部；
  2. 每次持续约 15 秒，执行 3 轮；
  3. 记录卡顿次数（明显掉帧/停顿）与主观评级（流畅/可接受/不可接受）。
- **统计**：输出每轮卡顿次数与综合结论。

## 4. 通过阈值（首版）

> 以下阈值用于迁移收官的初版门槛；后续可在 Step 3 首轮实测后微调。

- **TTI-Edit**
  - S 文档：P95 ≤ 1200ms
  - M 文档：P95 ≤ 1800ms
  - L 文档：P95 ≤ 2600ms

- **Input Latency（L 文档）**
  - Avg ≤ 120ms
  - P95 ≤ 220ms
  - Max ≤ 350ms

- **Scroll Smoothness（M/L 文档）**
  - 单轮明显卡顿次数 ≤ 3 次
  - 主观评级不得出现“不可接受”

若任一核心指标超阈值，则判定该设备组合为 **回归风险**，需进入问题登记与阻断评审。

## 5. 记录模板（统一格式）

| 日期 | 设备 | Android | WebView | 文档规模 | TTI-Edit(P50/P95) | Input(Avg/P95/Max) | Scroll卡顿次数 | 结论 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-__-__ | Device A | 14 | 13x.xx | S/M/L | __ / __ ms | __ / __ / __ ms | __ | 通过/风险 |

### 5.1 首轮实测（2026-10-18，路线 A Phase 0 基线）

这是本阈值表定义以来**第一次**有真机数据回填（此前 `milkdown-step3-first-pass-results.md:29` 一直为 `N/A（阻塞）`）。

采样条件：AVD `codex_mdreader_test`（`emulator-5554`），Android 12 / API 32，x86_64，1080×2400，**swiftshader GPU**；`flutter build apk --profile --target-platform android-x64`（versionCode 4104，DEBUGGABLE）；插桩见 `web/milkdown/src/perf.mjs`，取数 `node tools/collect_perf.mjs --parse <log>`。
语料：`PerfS.md` = 50,004 字符（84KB 文件，1359 顶层块）；`PerfL.md` = 500,073 字符（827KB 文件，>512KB 故走渐进渲染）。

| 文档 | TTI-Edit（实测） | 阈值 | `crepe.create()` | 首次 `syncRenderedDom` | 首次收尾合计 | 判定 |
| --- | --- | --- | --- | --- | --- | --- |
| S（50K 字符） | **≈23.5s** | P95 ≤1.2s | **21,943.7ms** | **1,288ms** | 1,521.7ms（hints 179.4 + outline 24 + history 30.3） | **阻断（超阈 ≈19×）** |
| L（500K 字符） | >55s 未收尾 | P95 ≤2.6s | 4,598.9ms（仅先解析 2048 字符） | 55s 内未出现 settle 样本 | — | **阻断** |

L 文档的 `create()` 反而更快，是因为渐进渲染把首次解析截到 2048 字符，代价变成随后**连环 `replaceAll`**：首个 `chain` 样本停在 `chars=6277 / topBlocks=155`，其串行成本 22.7ms（`stripGhost` 18.6 + `wrapHtml` 3.6 + `preprocessImg` 0.4）。

桌面 Chromium 对照（同一 `dist` 构建，非设备，用于看 scaling）：507,668 字符 / 13,038 顶层块 → `crepe.create()` **68,918.7ms**；6 次 `chain`（`totalMs` 11.0–16.9）但 **0 次 `settle`**，即 `notifyRenderComplete` 的 rAF 从未跑完，`chain` 事件间隔 5s / 45s / 120s。

**结论（修正了对瓶颈的估计）**：每停顿的**字符串扫描链不是主要成本**（实测 11–23ms）；支配项是 **`crepe.create()` 的整篇解析建树** 与 **`syncRenderedDom` 的整棵 DOM 遍历**（50K 字符 / 1359 块就要 1.3s，且随块数线性以上恶化）。路线 A 的 Phase 2/3 优先级因此高于 Phase 1。

未取到的指标与原因：

- **Input Latency**：adb 无法可靠把按键送进 Milkdown 编辑态——`input tap` 落在纯文本编辑模式（截图可见原始 markdown 字面量），20 次 `input keyevent` 后 `USHIO_PERF` 样本为 0。需在编辑态重采，或改由 JS 侧自驱 `execCommand` 采样。
- **Scroll Smoothness**：未测。`longFrameObserver: true` 说明 LoAF 探针在该 WebView 可用，后续可直接取 `longestFrameMs`。

测量副产物（两个真实缺陷）：

1. `[JS ERROR] __USHIO_BRIDGE__ not defined` ×2 —— Dart 在 bundle 定义 `window.__USHIO_BRIDGE__` 之前就向页面注入了调用（开档时序竞态）。
2. `ProseMirror expects the CSS white-space property to be set, preferably to 'pre-wrap'` —— ProseMirror 官方样式前提未满足。
3. `[syncRenderedDom] Code block count mismatch` 在 50K 文档上即触发，直接证实审计里「DOM 与 markdown 按下标配对」的假设不可靠。

取数注意：profile 包**不会**出现 `[WebView Console]`（Dart 侧 `onConsoleMessage` 转发未生效），日志只在 `chromium` 标签的 `[INFO:CONSOLE]` 里；logcat 单行可能截断，解析必须用花括号配对而非单条正则。
swiftshader AVD 的渲染比真机慢 2–3×，但 `create()`/`syncRenderedDom` 是 CPU+DOM 绑定，量级结论不受影响；本机 MuMu（GPU 直通）当时未运行，故本轮用 AVD。


### 5.2 内容归因矩阵（2026-10-18，桌面 Chromium，`setdoc.replaceAllMs`）

同长度文档只换内容构成，测「整篇 `replaceAll`（解析 + 建树 + 渲染）」的成本：

| 变体 | 字符 | 顶层块 | `replaceAll` | 相对纯正文 |
| --- | --- | --- | --- | --- |
| 空文档 | 4 | 2 | 9.8ms | — |
| 正文（标题+段落+链接） | 50,032 | 1230 | 1015ms | 基准 |
| 正文 + 代码块 | 50,084 | 1233 | 1556ms | **+54%** |
| 正文 + 任务列表 | 50,008 | 1294 | 1437ms | **+42%** |
| 正文 + HTML 块 | 50,063 | 1176 | 1377ms | **+36%** |
| 正文 + 图片 | 50,002 | 1284 | 1124ms | +11% |
| 全部混合 | 50,100 | 1363 | 2290ms | **+126%** |
| 正文 200K | 200,007 | 4786 | 6226ms | 1.30ms/块 |
| 代码块 200K | 200,065 | 4791 | 11327ms | 2.36ms/块 |

读出来的三件事：

1. **成本按「顶层块数」线性以上增长**，约 0.83ms/块（50K）→ 1.30ms/块（200K）。空文档只要 9.8ms，说明开销全在内容建树，不在上下文初始化。
2. **特性有明确乘数**：代码块 +54%（每块一个 CodeMirror 6 实例）、任务列表 +42%（每项一个 list-item nodeView）、HTML 块 +36%（伪围栏路径）、图片 +11%。
3. 因此**最高杠杆的改动是「绝不整篇重建」**：Phase 2（杀掉 `code_sanitized` 分支的整篇 `replaceAll`）之外，新增一项——**开档/切档与渐进渲染也必须改成追加式**（现在 `renderStep` 每步都 `replaceAll(前缀)`，等于把已建好的树整棵推倒重建）。

设备侧对照：同一份 50K 字符文档，桌面 `crepe.create()` = 2454.5ms，AVD = 21943.7ms（**≈8.9×**）；`chain` 字符串链桌面 3.2ms / AVD 22.7ms（同比例）。所以矩阵的**相对**结论可直接用于设备，绝对值需 ×8~9。

### 5.3 测量方法教训（避免再次误读）

- **后台标签里的 `requestAnimationFrame` 完全不触发**，且 `setTimeout` 被节流到约 1s。browser-use 打开的页面 `document.hidden === true`，因此桌面侧只会看到 `boot`/`chain`/`setdoc`（同步路径），**永远看不到 `settle`**，且 `wallMs` 无意义。此前「桌面 507K 字符 6 次 chain 0 次 settle」是**测量假象**，不是产品行为；已在 `docs/milkdown-customization-audit-2026-10-18.md` §零 一并更正。
- 只有页面内 `performance.now()` 的差值可信；跨页面的墙钟时间在隐藏标签下不可用。
- 要拿 rAF 相关数据（`syncRenderedDom`、hints、caret）只能用真机前台，或让页面可见。

### 5.4 `syncRenderedDom` 幂等化改造（2026-10-18，Phase 3 首步）

改动：① 每个代码块一次 `editorInstance.action` + `view.posAtDOM` + `doc.resolve` 的反查，换成**一次文档走查**按文档序取 `code_block.attrs.language`；② 22 条 `style.setProperty(...,'important')` 全部改走 `setImportantStyleIfNeeded`（值没变就不碰 CSSOM）；③ 代码块计数不变量从「DOM 块数 vs markdown 围栏数」改成「DOM 块数 vs 文档 code_block 数」（旧口径在内联代码/嵌套场景假报警，50K 文档上就一直在报）。

同一份 50K 字符 / 123 代码块 / 529 标题 / 352 列表项文档，桌面 Chromium 连续 `sync()`：

| | 旧实现 | 新实现 |
| --- | --- | --- |
| 第 1 次 | 489.4ms | 256.0ms |
| 第 2 次 | 142.7ms | 137.8ms |
| 第 3 次 | — | **19.5ms** |
| `sync + hints + outline` | 56.0ms | 37.5ms |
| 连续两遍 DOM 指纹一致 | **否（overlay 位置漂移）** | 是 |

即**稳态从 142.7ms 降到 19.5ms（≈7×）**；但真机编辑态下 ProseMirror 会重建 NodeView、把幂等守卫重置，实际收益会落在两者之间，需设备复测（AVD 换算系数 ≈8.9×，旧稳态 1288ms）。

功能正确性断言（同一次采样）：75 个语言输入框全部解析为 `js`（文档序配对正确）、529/529 标题带 `heading-line-N` 且 `dupIds=0`、`.tools` 与内联样式仍在。

顺带查明：**`input[type="checkbox"]` 数量为 0**，而列表项块有 352 个——Crepe 的 `list-item-block` nodeView 用的是 `.label-wrapper`，所以 `syncRenderedDom` 里给 checkbox 写 `checkboxIndex` 的那段与 `emitCheckboxToggle` 主路径对任务列表根本不生效（点击走的是另一分支）。Phase 3 处置「下标假设 #5」时按此调整。

### 5.5 渐进渲染的设备级证据（2026-10-18，500K 字符，改造后）

冷启动恢复 500,073 字符文档（>512KB 阈值，走渐进渲染），logcat 采到的 `chain` 前缀规模：

```
6,277 → 31,261 → 64,556 → 131,146 → 264,133 字符
（顶层块 155 → 747 → 1532 → 3086 → 6111，t=9.2s → 95.5s 仍未跑完）
```

`renderStep` 的步长是 `max(cursor + 2048, cursor * 2 + 2048)`，即**每步都 `replaceAll(从头到 cursor 的前缀)`**，把已经建好的整棵树推倒重建。到 500K 需要 5+ 次全量重刷、累计解析量约为全文的 2 倍，且最后几步单步就要重刷 6000+ 块。这是「改追加式」的直接依据（Phase 2 新增项）。

同批样本里字符串链仍然很便宜：`chain` p50 = 11.6ms、p95 = 40.2ms（`stripGhost` 3.6 / `wrapHtml` 2.4 / `preprocessImg` 2.6 中位数），`code_sanitized` 命中 0/5 —— 说明**整篇 `replaceAll` 反馈环在这份语料上没有触发**，Phase 2 的第 1 项（杀 `code_sanitized`）优先级应让位于「渐进渲染/切档改追加式」。

**探针缺口（已修）**：`settle` 只由 `notifyRenderComplete` 采样，而渐进渲染的首帧走 `emitFirstRenderReady`，因此「0 次 settle」当时**不能**推出「遮罩清不掉」——那是测量盲区，不是结论。已给 `emitFirstRenderReady` 补上同一份收尾采样（带 `firstPaint:1` 标记）。

本轮未复测的项：50K 字符（S 档）改造后的 `syncMs` 设备值——冷启动总是恢复到上次的 L 文档，未能把编辑器稳定停在 S 文档上。桌面侧的对应数据是稳态 142.7ms → 19.5ms（§5.4）。

### 5.6 追加式渲染判据：不通过，默认关闭（2026-10-18）

为 §5.5 的前缀重刷问题实现了追加式渲染（`findAppendSplitPoints` + parser 直接出 fragment + `tr.replaceWith`，并给追加步 `setMeta('addToHistory', false)`），同时做了一件更重要的事：把「分片解析是否等价于整篇解析」固化成可复跑判据页 `web/milkdown/tools/append-oracle.html`（同一份文档分别走两条路径，序列化回来逐字节比对，并自我声明「追加模式是否真的生效」）。

判据结果（桌面 Chromium）：

| 语料 | 字符 | 追加步数 | appendMode | 整篇 work | 追加 work | 产物 |
| --- | --- | --- | --- | --- | --- | --- |
| 混合（列表/表格/引用/任务/HTML 块） | 60,618 | 2 | 1 | 1571ms | 1409ms | **一致** |
| 嵌套列表与有序子项 | 109,775 | 6 | **0（切不出来）** | 3891ms | 6662ms | 一致（走回退） |
| 代码块为主 | 89,388 | 4 | 1 | 13932ms | **24869ms** | **不一致**（围栏后多一空行） |

三条结论：

1. **安全区很窄**：只有「切点两侧都是标题/段落」才等价。列表相邻、围栏相邻都会改变结构（列表 spread 判定、围栏后多余空行），必须拒绝切分——于是代码/列表密集的文档根本切不出点。
2. **切得出来的场景收益很小**：混合文档 1571→1409ms（≈10%）；而代码文档即便切出了点，追加反而**慢 1.8 倍**（分片各自触发整视图更新，省下的重复解析被吃回去）。
3. 因此 **`appendRenderEnabled` 默认 false**。判据页保留为回归门禁：Phase 3 把「每次 dispatch 的视图更新成本」降下来之后，值得重跑一次再决定是否开启。

判据顺带修掉的一个实现漏洞：围栏行本身没被记为「块起始行」，导致「前一个块是围栏」的检查落空、切点会紧贴围栏——已由单测 `切点紧邻代码围栏时不切` 锁死（vitest 27/27）。

同时保留的独立收益（与追加式无关，默认生效）：追加步的 `addToHistory:false` 语义、`setProgressiveThreshold`/`setAppendRender` 诊断开关、以及 §5.4 的 `syncRenderedDom` 幂等化提速。

### 5.7 两次「桌面有效、真机无效」的记录（2026-10-18）

> ⚠ **本节的设备数字已被 §5.11 作废**：当时 profile 构建一直供缓存里的旧 bundle，
> 所谓「改后」测的是改前的代码。桌面数字仍有效。

同一份 50,004 字符 / 1359 顶层块文档，真机 profile 包，逐项复测：

| 收尾分段 | §5.4 前 | §5.4 后（样式幂等 + 去每块反查） | hints 改 O(1) 后 |
| --- | --- | --- | --- |
| `syncRenderedDom` | 1288ms | **1455.7ms** | **1493.6ms** |
| `activeHints` | 179.4ms | 204.7ms | 182.9ms |
| `emitOutline` | 24ms | 11.3ms | 39.6ms |
| `historyState` | 30.3ms | 16.6ms | 27.8ms |
| 收尾合计 | 1521.7ms | 1686.8ms | 1743.9ms |
| `crepe.create()` | 21943.7ms | 16110.6ms | 25241.3ms |

两条结论，都是负面的、但决定了后面怎么做：

1. **§5.4 的桌面收益没有落到真机。** 桌面那个 142.7→19.5ms 是**同一份 DOM 连续第三次 sync** 的热路径（幂等守卫全部命中，什么都不写）。真机上用户碰到的是「文档刚载入后的第一次 sync」，守卫全是冷的，每个写入都真的发生。**用户感受到的是冷路径。** 以后任何渲染侧优化，验收口径必须是冷路径。
2. **`activeHints` 的 183ms 不是被删掉的那次全 DOM 扫描**（删掉后基本没变）。更可能是 `syncRenderedDom` 写完几百处样式后，下一次 DOM 读取触发的强制布局回算被计在了 hints 名下——**这是假设，未证实**。要证实需要把 clear 与其余部分分开计时。
3. **单次采样不可信**：同一文档 `crepe.create()` 三次分别是 16.1s / 21.9s / 25.2s（±30%）。以后回填本表必须 **N≥5 取 P50/P95**，单个数字一律不写进结论。

因此 Phase 3 的目标要改写：不是「少遍历几趟 DOM」，而是**减少冷路径上真实发生的 DOM 写入量与布局抖动**（脏区驱动 + 把 `!important` 内联样式搬进持久 CSS，让首次 sync 也不再逐块写 CSSOM）。准入门禁已就位：`web/milkdown/tools/dom-oracle.html`（编辑序列后比对增量与全量的 DOM 指纹；增量未实现时它会自我声明「判据未执行」，不会假绿）。

### 5.8 CSS 搬迁被自己的噪声带否证（2026-10-18）

用新 harness `tools/coldpath-bench.html`（每次全新加载 iframe、重新解析 bundle、重新灌同一份文档，**只量第一次 sync = 冷路径**，N=5，桌面 Chromium，1306 顶层块）对「17 条逐块 `!important` 搬进持久样式表」做 A/B：

| 被测产物 | 冷 sync 中位数 | 样本 |
| --- | --- | --- |
| §5.4 + hints（从 `/oldbuild` 测） | 254.5ms | — |
| + 搬进持久 CSS | 289.1ms | 289.1 / 265.7 / 313.7 / 277.4 / 297.8 |
| 回退后（**与第一行字节相同**，从 `/dist` 测） | **275.9ms** | — |

同一份字节两次测出 254.5 与 275.9 ⇒ **本 harness 的噪声带约 ±10%（≈21ms）**，与被追的 35ms 差值同量级。

因此准确结论不是「搬 CSS 变慢了」，而是：**在 N=5 下测不出收益**。据此回退（`6a4a7d6`）——没有可证明的收益就不该增加选择器复杂度与风险，但也不能声称它造成了回归。

方法论修正（写进规矩）：

1. 要检出 ~15% 量级的变化，必须**交替采样**（同一会话里 old/new 轮流跑，抵消机器漂移）并把 N 提到 ≥10–20；单侧连测 5 次的差值不可作为结论。
2. 任何「优化」在报告里必须同时给出**同一产物的重复测量结果**作为噪声带，否则差值没有意义。
3. 冷路径那 17 条逐块 CSSOM 写入**不是瓶颈**。Phase 3 剩下的候选（脏区驱动、html overlay 的 `getBoundingClientRect`/`offsetHeight` 强制布局）如果测不出**远大于 ±10%** 的效果，就说明它不值得做。

保留物：`tools/style-baseline.html`（计算样式指纹，当初证明搬迁前后 1294618094 逐字节一致，也是这次能安全回退的依据）、`tools/coldpath-bench.html`（冷路径 N 次基准）。

### 5.9 设备会随安装次数退化（2026-10-18 晚）

同一台 AVD `emulator-5554`、同一份 50,004 字符文档，`crepe.create()` 在今天不同时刻：

| 时刻 | 冷 create |
| --- | --- |
| 第 1 次装包后 | 21943.7ms |
| 第 2 次 | 16110.6ms |
| 第 3 次 | 25241.3ms |
| 第 6 次装包后（未重启） | **53635.1ms** |

连装 6 次 profile 包不重启，设备退化到 **2–3 倍**慢。因此：

1. **任何跨「改前/改后」的设备对比，必须在同一设备状态下测**——要么两边都刚重启过，要么放弃设备口径改用桌面 harness 的相对结论。
2. 之前记的「噪声带 ±10%」是桌面口径；**设备口径在退化状态下是 ±100% 量级**，不能用来判定 15%–30% 级别的改动。
3. 结论：设备只用来做**功能与视觉验证**（截图、渲染是否正确），性能数值以桌面交替采样为准，设备只用于验证量级和趋势，且测前必须冷重启 AVD。

本轮 Phase 5 的几何修复因此以浏览器判据为准（`tools/overlay-oracle.html` 改前 FAIL / 改后 PASS，`tools/style-baseline.html` 指纹 1294618094 未变），设备侧只用于装包后的肉眼确认。

### 5.10 冷路径分段归因与布局抖动修复（2026-10-19）

给 `syncRenderedDom` 加分段打点（`perf.mjs` 的 `perfStartSections`，由 `tools/coldpath-bench.html` 输出），第一次拿到确定的归因。50,004 字符 / 1306 顶层块，冷路径（每轮重建 iframe、只量第一次 sync）：

| 段 | 改前 冷 (ms) | 占冷路径 | 改后 冷 (ms) |
| --- | --- | --- | --- |
| **`htmlOverlay`** | **212.5** | **85%** | **31.6** |
| `codeBlockPass` | 15.3 | 6% | 10.7 |
| `headingPass` | 10.7 | 4% | 9.5 |
| 其余 11 段 | 各 <3.5 | 5% | 各 <3 |
| **冷 sync 合计** | **251.2**（289.9/219.3/251.2） | — | **63.4**（76/63.4/59.8） |

**只有 6 个 HTML 块却占 85%**：`renderHtmlBlockCodeNodes` 每块都「读矩形 → 写占位高 → 读下一块矩形」，每次写都让下一次读触发整篇强制重排，布局刷新次数 = 2×块数。

改法是读写分批：读全部矩形 → 写全部 overlay 位置 → 一次读全部渲染高 → 写全部占位高 → **再读一次矩形并补写位置**（同一轮内校正）。刷新次数降为常数 3。

**判据中途抓到一次真回归，值得记下来**：把「读几何」提前到写占位高之前后，第一趟用的是还没写占位高时的几何，于是变成「两趟才收敛」——`tools/overlay-oracle.html` 的 A 组报「5 处逐趟变化」。补上第 5 步同轮校正后恢复 9/9 全绿。若没有 A 组，这个「把一帧错位换成每次收尾多一趟」的退化会被当成优化收益合进去。

设备口径注意（§5.9）：以上是桌面 Chromium 数字；换算到这台 AVD 约 ×8.9，即冷路径收尾从 ~2.2s 降到 ~0.56s，但**设备侧未复测**，不作为结论。

### 5.11 ⚠ profile 构建会一直供缓存里的旧产物（作废本文件部分设备数字）

复测 §5.10 的设备侧结论时发现：logcat 里 WebView 加载的是 `index-Bsxs16xy.js`（Phase 0 最初那个插桩版本），而仓库产物已是 `index-CIjc1Glo.js`。

根因在 `lib/widgets/milkdown_webview_editor.dart` 的 `buildMilkdownRuntimeUrl`：

```dart
final stamp = kDebugMode ? _debugUrlStamp : AppConstants.appVersion;
```

**profile / release 走的是版本号**，而整个验证过程中 `1.6.8+4104` 从未变过；资源响应又带 `max-age=31536000, immutable`，于是换产物不换版本号时，WebView 的 HTTP 缓存会一直供旧 bundle。也就是说 `?v=` **在 profile 下根本不是 cache-buster**。

**因此本文档以下设备数字全部作废**（它们测的都是 Phase-0 那份旧代码）：§5.4 表格里「真机 sync 1288 → 1455.7 → 1493.6ms，桌面收益没落到真机」、§5.7 的同一组对比、以及「activeHints 改 O(1) 后 204.7 → 182.9ms 基本没变」——那些对比里的"改后"根本没跑到改后的代码。

用新加的 `--dart-define=MILKDOWN_URL_STAMP=<任意串>` 绕开缓存后重测（同一会话背靠背，n=3，50,004 字符 / 1359 块）：

| 真机冷路径 | 修复前（Phase-0 bundle） | 修复后（含 §5.4 + hints + box-sizing + 读写分批） |
| --- | --- | --- |
| `syncRenderedDom` | 1198.7 / 1288 / 1455.7 / 1493.6ms | **549 / ~700 / 757.1ms** |
| 收尾合计 | 1521.7 / 1686.8 / 1743.9ms | **778.6ms** |
| `activeHints` | 179.4 / 204.7 / 182.9ms | 180.3 / 325.5ms |

两组 sync 区间不重叠 ⇒ **真机约 2×**（桌面 4×，差额合理归因于 §5.9 记录的设备退化）。
`activeHints` 在扫描已改 O(1) 的情况下仍占 180–325ms，**印证 §5.7 提出的假设**：那段时间是 sync 写完样式后的强制布局回算被记在 hints 名下，不是被删掉的那次 `querySelectorAll`。

规矩补充：**任何设备侧验证 JS/渲染改动，必须先确认 logcat 里加载的 bundle 文件名与仓库一致**（`grep -o 'index-.*\.js' <log>`），否则测的是缓存里的旧代码。

### 5.12 `crepe.create()` 分段归因：成本在挂 DOM，不在解析（2026-10-19）

**做法（零侵入）**：Milkdown core 的生命周期是一串 timer（Config→Init→Schema→Parser/Serializer/Commands/Keymap→EditorState→EditorView），
每个完成时 `@milkdown/ctx` 的 `Timer.done()` 会往 `window` 派发同名 `CustomEvent`。只监听不介入即可拿到分段
（`web/milkdown/src/perf.mjs` 的 `perfStartBootPhases()`，经 `__USHIO_PERF__.boot()` 暴露，
`tools/coldpath-bench.html` 输出归因表并自检「10 个阶段是否全部派发」——没派发就是没数据，不折算成 0）。

50789 字符 / 1306 顶层块，桌面 Chromium，N=6，冷路径（每轮重建 iframe）：

| 段 | ms | 占 create 内 |
| --- | --- | --- |
| `EditorViewReady`（整棵 DOM + 每块 nodeView/Vue/CodeMirror 挂载） | **1192.8** | 56% |
| `EditorStateReady`（整篇 markdown→MDAST→Prose 建树） | **915.1** | 43% |
| Config+Init+Schema+Parser+Serializer+Commands+Keymap+PasteRule 合计 | 12.7 | 0.6% |
| create 之前的字符串预处理（wrapHtml + preprocessImages） | 2.8 | — |
| `crepe.create()` 合计 | 2509.8 | — （create 内合计 2112.5，差值 = await 让出的空隙） |

尺寸扫描（6090/12001/25060/50033 字符，同构造文档，N=4，最小二乘斜率）：

| 指标 | ms / 顶层块 | 固定开销（截距） |
| --- | --- | --- |
| `EditorStateReady` 建树 | **0.730** | 69.3ms |
| `EditorViewReady` 挂 DOM | **0.914** | 31.3ms |
| `crepe.create` 合计 | 2.013 | 81.8ms |
| 冷路径 sync | 0.069 | 4.8ms |

两项都是线性的，且挂 DOM 比建树更大。**桌面 2.0ms/块 × §5.1 的设备 8.9× ≈ 18ms/块 ⇒ 1306 块 ≈ 23s**，与真机观测到的 16–25s 对上。

同块数换内容类型（402 顶层块、约 10.3K 字符、其中 100 块是目标类型，N=5）——这是决定改法的一张表：

| 类型 | 建树 ms | 挂 DOM ms | create ms | 每块「挂 DOM」增量 | nodeView 实测 |
| --- | --- | --- | --- | --- | --- |
| plain 段落 | 131.0 | 43.8 | 190.5 | — | 0 |
| list 任务列表 | 232.4 | 271.5 | 528.5 | +2.28 | `list-item` ×200 |
| image | 194.6 | 168.4 | 396.9 | +1.25 | `image-block` ×100 |
| code 代码块 | 148.5 | **355.7** | 870.5 | **+3.12** | `code-block` ×100，其中 `cm-editor` ×100 |
| html 块 | 160.5 | **337.9** | 542.1 | **+2.94** | `code-block` ×100，其中 `cm-editor` ×100 |

结论（推翻 §5.2 那种「内容类型乘数」的读法）：

1. **块类型的差异几乎全部落在挂 DOM 段**：建树在五种类型间是平的（131→232），挂 DOM 从 43.8 跳到 355.7。
   所以「代码块 +54%」不是解析贵，是**每块一个 CodeMirror 实例 + 一个 Vue app**。
2. **代码块还有约 350ms 的异步尾巴**：`create` 合计 870.5 减去同步两段只剩 ~354ms（plain 只有 ~16ms），
   即语言装载 + `reconfigure` 重高亮。一个代码块 ≈ 3.1ms 同步 + 3.5ms 异步 ≈ 桌面 6.6ms，真机 55–60ms。
3. **HTML 块的浪费被坐实**：产品的 `wrapHtmlBlocksInCodeFence` 把每个 html 块变成 ```html-block 代码块，
   于是给它建了一个**真 CodeMirror 编辑器和一个 Vue 组件**，再把这个 DOM 隐藏、内容改在 overlay 里显示。
   即每块 2.94ms 挂载 + 一个编辑器的全部成本，换来的是「我们根本不看它」。

因此剩下的两条路都能量化验证，且互不冲突：
延迟 CodeMirror 挂载（攻 +3.1ms/块的同步段与异步尾巴）、把 html 块改成真正的节点而不是伪代码块（攻 +2.94ms/块，顺带完成 Phase 5 的原样 round-trip）。
虚报风险登记：本表在 `document.hidden=true` 的标签页里采（§5.3），分段值是同步工作耗时不受节流影响，
但 `create` 合计里的异步尾巴会被 1s 定时器钳位放大 ⇒ **异步段数字只能当上界看**。

### 5.13 同一分段在真机复现，且比例更悬殊（2026-10-19）

profile 包 `--dart-define=MILKDOWN_URL_STAMP=bootphase`，logcat 核对加载的确实是 `index-Bn1dnKF5.js`（§5.11 的规矩）。
文档 = `build/mdbench/PerfS.md`，50004 字符 / 1359 顶层块 / 预处理后 57166 字符，冷启动自动恢复上次文档，无需点按。
两次可用采样（10 个阶段全部派发，`missing: []`）：

| 段 | 采样 1 | 采样 2 |
| --- | --- | --- |
| `EditorStateReady` 建树 | 6101.8ms | 9136.6ms |
| `EditorViewReady` 挂 DOM | **22487.5ms** | **25611.7ms** |
| 挂 DOM / 建树 | **3.68×** | **2.80×** |
| `crepe.create` 合计 | 42256.3ms | 48310.7ms |
| await 空隙（合计 − 段内合计） | 13395.7ms | 13154.9ms |
| create 之前（wrapHtml+preprocessImages+Crepe 构造+插件注册） | 150.8ms | 147.1ms |

- **桌面上挂 DOM 只比建树贵 1.25×，真机是 2.8–3.7×**：nodeView（每块一个 CodeMirror 实例 + 一个 Vue app）在设备上的边际惩罚远大于解析，
  §5.12 的结论在真机方向上被加强而不是抵消。
- **await 空隙两次都是 ~13.2s（占 create 的 27–32%）**，绝对值比两段都稳定。这段时间不属于任何同步分段，
  是 `new EditorView()` 之后各 CodeMirror 实例的异步语言装载与 `reconfigure` 重高亮尾巴。§5.12 已量到桌面代码块类型有 ~3.5ms/块的同类尾巴。
- 两次采样绝对值差 14%（42.3s → 48.3s）是 §5.9 的连装退化，**不要拿绝对值当基线**；本轮结论只用比例。
- 插桩本身不改行为：冷启动后截图核对标题/段落/行内代码/链接/任务列表勾选框渲染全部正常。

### 5.14 新判据当场抓到一个用户可见缺陷：切档后 HTML 块一片空白（2026-10-19）

为 A（HTML 块改真节点）先立的门禁 `web/milkdown/tools/html-roundtrip.html` 有四项断言：
① 输出里不出现 ```` ```html-block ````伪围栏；② 每段 HTML 原文逐字出现在输出里；
③ 为 HTML 块创建的 `.cm-editor` 数为 0；④ **切档之后** overlay 项仍然建得起来。
负例（单行 `<hr>`、围栏内的 HTML 示例、行内 `<b>`）用来防止「把 HTML 一律当块」这种过度修正——三条负例本来就 PASS，所以 6/9 的 FAIL 不是因为判据写得过严。

跑第一遍时 ④ 就是红的，而且原因不在断言本身：

- `.milkdown` **每次切档都被重建**（实测 `md1 !== md2`）。
- `ensureHtmlOverlay()` 用 `htmlOverlayContainer.parentNode` 判存活——旧容器仍挂在**已脱离文档的旧 `.milkdown`** 上，`parentNode` 非空 ⇒ 判定「还在」⇒ overlay 项全写进游离子树。
- `startHtmlBlockObserver()` 更直接：`if (htmlBlockObserver) return` ⇒ 观察者永远监听着第一个 `.milkdown`，切档后隐藏规则完全失效。
- 用户可见结果：打开带 HTML 块的文档 A 正常，再打开文档 B，**B 里每个 HTML 块的位置都是一片空白**（伪块被隐藏、overlay 在游离子树里）。
- 一开始的归因是错的：`.cm-line` 数与 `.cm-content` 字数（实测 3–5 行 / 20–83 字）证明 HTML 原文取得到，不是「CodeMirror 虚拟渲染捞不到内容」。是探针列（`source`）把这条排除掉的。

修法：两处都改成「按当前 `.milkdown` 重新认领」——overlay 容器判 `isConnected && parentNode === 当前 .milkdown`，不满足就把**同一个**容器重新 append 过去（保留已有项）；观察者记住 `observedEl`，目标换了就 `disconnect()` 后重新 `observe`，rAF 回调改为每次现取 `app.querySelector('.milkdown')`。

改后：④ 全部转绿（`1 → 1 → 1 → 1`、`2 → 2 → 2 → 2`），① 与 ③ 仍红（正是 A-2 的目标），
`overlay-oracle.html` 九项仍 PASS，`style-baseline` 指纹仍是 **1294618094**（未变）。
（该指纹在 A-2 落地后按设计发生变更，逐项归因见 §5.15。）

**这条的价值不在修了什么，而在证明「门禁必须先于改动」**：A-2 要动的就是这套 overlay 机器，
若先改实现再补判据，这个既有缺陷会被算到新改动头上，或者被新代码顺手掩盖而永远查不出来。

### 5.15 A-2：HTML 块改真节点，挂 DOM 惩罚从 +4.26ms/块降到 +0.03ms/块（2026-10-21）

§5.12/§5.13 已证明 `crepe.create()` 的大头是挂 DOM，而 HTML 块在其中最重：它被
`wrapHtmlBlocksInCodeFence` 包成伪代码块，拿到一个**完整的 CodeMirror + Vue 实例**，随后整个 DOM 被隐藏、
内容改由 overlay 显示。A-2 把它换成真正的原子节点（`web/milkdown/src/html-block-node.mjs`）：

- `remarkHtmlBlockFence`：把 mdast 的 `code`（lang=`html-block`）就地改写成私有类型 `ushioHtmlBlock`；
  走私有类型而不是抢占 `code`，是因为解析器按**注册顺序首个匹配**分派，自定义节点抢不过 commonmark 的 `code_block`。
- `ushioHtmlBlockSchema`：`atom, group:'block'`，属性 `value` 存原文；`toMarkdown` 直接回写 mdast `html`。
- `toDOM` **刻意保持** `div.milkdown-code-block[data-ushio-html-block-slot] > pre[data-language=html-block]`
  这套形状，让既有 overlay 机器（隐藏、取原文、量高、定位）一行不改；`data-ushio-html-block-slot`
  用于把它和真正的代码块区分开。

**判据（同一份 bundle，全部通过）**

- `html-roundtrip.html` **9/9 PASS**：输出无伪围栏、HTML 原文逐字保留、HTML 块带来的 `.cm-editor` 数为 0、
  切档后 overlay 仍建立；三条负例（单行 `<hr>`、真围栏内的 HTML、行内 `<b>`）保持不接管。
- `overlay-oracle.html` **十项 PASS**，含 A 收敛、B1 占位高 == 渲染高（293/292.69）、D1–D3
  **文档中间删除 HTML 块**后数量/内容/贴合全部正确——Phase 5 最后一项覆盖由此关闭；
  新增的 E 在 **450ms 后**再量一次稳态（原因见本节末尾的异步抹高缺陷）。
- `npx vitest run` **27/27 PASS**。
- 文件里已存在的旧 ```` ```html-block ```` 围栏仍能正确解析渲染（幂等用例），下次保存时按原文写回，
  **不会再向用户的 .md 写入伪围栏**。

**样式基线按设计重新锚定**：`style-baseline` 指纹 **1294618094 → 280916608**。这不是放过，而是逐项归因后重锚：

- 12 个真实代码块：分组哈希 **2971102492 与改前完全一致**，逐块哈希也逐一相同 ⇒ 代码块样式零回归。
- 6 个 HTML 块：块级计算样式（display/position/padding-top/visibility/opacity/几何全为隐藏态）与改前相同，
  变的是 `.tools` / `.language-picker` / `.language-button` 三个子元素从「存在但隐藏」变成 `null`——
  这正是「不再建 CodeMirror」的直接结果。

**同机同时段 A/B（桌面 Chromium，N=5 中位数，402 个顶层块，其中 100 个是 HTML 块；plain 作对照）**

| 段 | plain 改前 → 改后 | html 改前 → 改后 |
| --- | --- | --- |
| 建树（EditorStateReady） | 113.9 → 120.9 ms | 149.8 → 123.1 ms |
| 挂 DOM（EditorViewReady） | 39.9 → 39.6 ms | **466.2 → 42.9 ms** |
| crepe.create 合计 | 167.6 → 170.8 ms | **687.7 → 177.6 ms** |
| 冷路径 sync | 5.7 → 5.3 ms | 44.1 → 29.9 ms |
| HTML 块持有的 `.cm-editor` | — | **100 → 0** |

plain 两次相差 ≤4%，可视为噪声；据此归一：

- 挂 DOM 的 HTML 边际惩罚 **+4.26 ms/块 → +0.03 ms/块**（约 1/140）。
- `crepe.create` 的 HTML 边际惩罚 **+5.20 ms/块 → +0.07 ms/块**。
- 冷路径 sync 仍比 plain 多 **+0.25 ms/块**（38.4 → 24.6 ms/100 块）——这部分没有消失也不该消失：
  它是在 overlay 里真正解析并排版 HTML 的成本，属于有效工作。
- 自检行里 html 的 `codeBlock=100` 是**刻意的**（槽复用该类名接住 overlay 机器）；`codeMirror=0` 才是本轮的断言。

**真机复测（`build/mdbench/PerfS.md`，50004 字符 / 1359 顶层块 / 70 代码块 + 44 HTML 块）**

首次安装（新启动的 AVD）冷启动，logcat 核对加载的是 `index-CICxSTMF.js`：

| 段 | §5.13（改前） | A-2（改后） |
| --- | --- | --- |
| 建树 `EditorStateReady` | 6101.8 / 9136.6 ms | 2233.6 ms |
| 挂 DOM `EditorViewReady` | 22487.5 / 25611.7 ms | 5601.4 ms |
| `crepe.create` 合计 | 42256.3 / 48310.7 ms | **9993.2 ms** |
| await 空隙 | 13395.7 / 13154.9 ms | **2044.1 ms** |
| 空隙占 create | 31.7% / 27.2% | **20.5%** |

CodeMirror 实例从 114 个（70 代码 + 44 HTML 伪块）降到 70 个；异步空隙占 create 的比例与
空隙/挂 DOM 的比值都同步下降（0.60 → 0.36），方向上支持 §5.13 把空隙归因于 CodeMirror 的异步尾巴。

**但这组数字不能当受控 A/B**：改前是 10-19 的旧启动，改后是新启动 + 首次安装；同日第二次安装后
（`index-C4TaLf8u.js`）同一文档变成 create 23534.8 / 挂 DOM 13360.6 / 空隙 5930.5ms，正好落在
§5.9 记录的「连装退化 2–3×」区间（2.35×），说明绝对值主要被设备状态支配。**只用比例与方向，不用绝对值。**

`syncdetail`：冷路径 sync 350ms，其中 overlay 渲染 194.3ms（44 块，约 4.4ms/块），代码块收尾 74.3ms（70 块）。
控制台不再出现 `Unknown language` —— HTML 块不再以 `html-block` 这个未注册语言创建编辑器。

**A-2 落地后又抓到一个先于它的缺陷：占位高会被异步重渲染抹掉**

设备截图发现 HTML 块下方多出一截空白。探针定位：sync 写入的 `height/min-height/max-height` 在
sync 返回后 **20ms 内**连同 `box-sizing` 一起消失，块元素本身被替换（`s===later` 为 false）。
原因是 ProseMirror 在收尾之后异步重渲染节点，整块重建 DOM；隐藏观察者只恢复了四条隐藏样式，
没有恢复高度。于是占位高退回槽内 `<pre>` 的自然高度：一行 HTML 的块 59.19px 被撑到 107.56px，
多出 48px/块（`PerfS.md` 有 44 个 HTML 块）。

这个缺陷**不是 A-2 引入的**：旧实现同样把高度写在内联样式上，同样会被抹掉；
只是旧伪块的天然高度（CodeMirror 三行）与被渲染内容更接近，空白没那么显眼。
A–D 四组判据都「sync 完立刻同步读」，所以从 §5.10 起一直没抓到。

修法：`htmlBlockPlaceholderHeights` 按 **内容哈希**（长度 + 前 200 字符）记住每块的渲染高；
`hideHtmlBlockCodeNode` 在每次观察者重建隐藏样式时把高度幂等补回（`setImportantStyleIfNeeded`，
值相同就不写，不会触发观察者自激）。按内容而不是序号记，块被重排或删除都不会错配。
判据新增 **E：等 450ms 后再量一次**，要求占位高与 overlay 仍逐项相等、top 仍贴合。
改前 E 会红（107.56 vs 59.19），改后 `450ms 后 5 项仍逐项贴合`。
`style-baseline` 指纹仍为 **280916608**（同步路径未受影响），`html-roundtrip` 9/9、`vitest` 27/27 不变。

**顺手修掉两条会掩盖真问题的假告警**

- 代码块不变量改为 `.milkdown-code-block:not([data-ushio-html-block-slot])`：槽复用类名却不对应 `code_block`，
  否则 A-2 一落地这条不变量就永久报警。
- 图片不变量排除 `.ProseMirror-separator`：文档以非文本块结尾时 ProseMirror 会塞一个无 `src` 的
  `<img class="ProseMirror-separator">`，旧代码把它当图片，导致「图片数不匹配」在没有任何图片的文档上也会触发。
  该假告警**先于 A-2 存在**，本轮用运行时探针确认后才改。

### 5.16 输入延迟设备采样：每停顿 ~0.49s，大头是 DOM 收尾而不是字符串链（2026-10-21）

**口径**：profile 包（`MILKDOWN_URL_STAMP=lat`，logcat 核对 bundle 为 `index-Dmq9nS3k.js`），
文档 `build/mdbench/PerfS.md`（50004 字符 / 1359 顶层块 / 70 代码块 / 44 HTML 块）。
在 **WYSIWYG 编辑器**里聚焦后，用 `adb shell input text` 每 2s 输入 1 个 ASCII 字符（3 个一轮）；
200ms 的 listener debounce 会把一轮合并成一次 `markdownUpdated`，正好对应「打字每停顿」的场景。
设备是已经历过多次安装的 AVD（本轮冷启动 `crepe.create` 31.6s），**绝对值被设备状态放大，只看分段比例**。

两轮稳态样本：

| 指标 | 样本 1 | 样本 2 |
| --- | --- | --- |
| 字符串链 `chain.totalMs` | 19.8 | 43.1 |
| DOM 收尾 `syncdetail` 合计 | 401.1 | 429.3 |
| ├ HTML overlay 定位 | **218.5** | **286.6** |
| ├ 代码块样式收尾 | 103.0 | 91.3 |
| ├ 标题 / 图片扫描 | 23.0 / 22.8 | 16.7 / ~0 |
| `settle` 合计（sync+outline+history） | **489.3** | **488.0** |
| ├ sync | 404.9 | 430.1 |
| ├ outline | 27.2 | 41.0 |
| └ history | 57.0 | 16.8 |
| key → settle 观测间隔 | 2196 | 7932 |

- **每停顿的主线程工作是 ~0.49s，两轮几乎相同**；字符串预处理只占 20–43ms，
  §3.2 那条「每键全文扫描」已经不是瓶颈（与桌面量级一致）。
- **最大单项是 HTML overlay 的定位**（218–287ms，44 块 ≈ 5–6.5ms/块）：
  A-2 之后它不再建 CodeMirror，但每轮仍要对整篇做两轮读矩形 + 写样式；
  在 1359 块的文档上，这些读写会反复触发布局。
- 第二项是代码块样式收尾（91–103ms / 70 块），属于纯样式状态机，和 CodeMirror 挂载成本无关。
- `sinceKeyMs` 2.2s / 7.9s 含 debounce 与设备排队，**不是纯输入延迟**；
  `longestFrameMs` 20–25s 是切换编辑模式时的 WebView 重载，已排除，不计入本轮结论。
- 结论：下一步优化输入延迟应打 **overlay 的几何重算**（只在几何真正变化时重排、合并读写），
  而不是继续压字符串扫描；这与冷启动优化（代码块挂载）是两条独立的线。

### 5.17 代码块 CodeMirror 延迟挂载：离屏不建（2026-10-21）

Crepe 的 `CodeMirrorBlock` 在 NodeView 构造函数里就 `new EditorView(...)`，即使整块在屏幕外。
`web/milkdown/src/lazy-code-block.mjs` 包了一层 NodeView：先用 `<pre>` 显示源码占位，
满足任一条件才调用 Crepe 原来的节点工厂挂载——进入视口（`IntersectionObserver`，rootMargin 400px）、
指针按下、或被 PM `selectNode`。挂载后所有 UI/交互（语言选择器、复制、编辑、搜索）仍由 Crepe 自己处理；
包装层保持与真实 NodeView 相同的契约（无 `contentDOM`、`stopEvent` 恒真、`ignoreMutation` 恒真）。
首屏另有一次性几何兜底：构造后等一拍按 `getBoundingClientRect` 挂载视口内的块，避免 IO 首个回调延迟。

**桌面 A/B（`coldpath-bench.html?kinds=code&blocks=400&n=5`，402 顶层块 / 100 代码块；改前为 HEAD 构建）**

| 指标 | 改前 | 改后 |
| --- | --- | --- |
| 建树 `EditorStateReady` | 160.0 ms | 201.8 ms |
| 挂 DOM `EditorViewReady` | **476.2 ms** | **58.6 ms** |
| `crepe.create` 合计 | **1058.5 ms** | **280.9 ms** |
| 冷路径 sync | 37.4 ms | 11.5 ms |
| `cm-editor` 实例 | 100 | **3** |

挂 DOM −87.7%，create −73.5%；建树的 +26% 与改动无关（同文档、同解析路径），按噪声处理。

**判据**：新增 `tools/codeblock-lazy.html` —— A 初始只挂载视口附近（12 块里 5 挂载/7 占位）、
B 滚动到末尾后挂载（后台标签页里 IO 不派发，自报 SKIP，不算 PASS）、C 点按占位立即挂载、
D 挂载后 CM 内容与语言选择器完好、E 序列化不因挂载而变。
`style-baseline` 在测量前调用 `mountAllCodeBlocks()` 把所有块挂上，指纹仍为 **280916608**（零样式回归）；
`html-roundtrip` 9/9、`overlay-oracle` 10/10、`init-gate` 3/3、`roundtrip-fidelity` 22/40 不变、`vitest` 27/27。
`@milkdown/components` 改为直接依赖，lockfile 已同步（`npm ci` 可复现）。

**设备状态说明**：本轮在同一 AVD 上第 4 次安装后冷启动 `crepe.create` = 41.5s（前一版 31.6s、首装 9.99s），
是 §5.9 的连装退化，绝对值不可用于比较；文档渲染正常。计划中的冷重启复测因宿主休眠导致时钟跳跃、
adb 反复掉线而未完成；**滚动触发的挂载没有真机视觉证据**（后台标签页 IO 不派发，adb 滑动在编辑态会变成选字），
点按挂载与功能完好由判据 C/D/E 覆盖。若要在真机补验：冷启动后滚到章节 7/14，确认代码块出现行号与高亮。

## 6. 回归判定规则

1. **通过**：所有核心指标均满足阈值。
2. **风险**：任一核心指标超阈值，但不影响基本可用性（需建问题单并跟踪）。
3. **阻断**：出现高频输入丢失、持续卡死、编辑不可用等 P0/P1 问题（需阻断发布）。

## 7. 与 Step 3 的衔接

Step 2 只负责“方法与阈值固化”；  
Step 3 才执行真机采样并把首轮实测数据回填到迁移状态文档。
