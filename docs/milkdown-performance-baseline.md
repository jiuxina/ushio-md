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

## 6. 回归判定规则

1. **通过**：所有核心指标均满足阈值。
2. **风险**：任一核心指标超阈值，但不影响基本可用性（需建问题单并跟踪）。
3. **阻断**：出现高频输入丢失、持续卡死、编辑不可用等 P0/P1 问题（需阻断发布）。

## 7. 与 Step 3 的衔接

Step 2 只负责“方法与阈值固化”；  
Step 3 才执行真机采样并把首轮实测数据回填到迁移状态文档。
