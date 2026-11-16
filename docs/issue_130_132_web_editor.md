# #130–#132、#134、#137 编辑器 WebView 回归记录

本轮编辑器改动集中在可复现的跨端行为：

- Flutter 在创建文档前发送头部、工具栏和键盘遮挡尺寸，Web 端只在尺寸变化时更新 CSS，并把工具栏高度纳入末行可视区。
- 光标强制避让不再受“最近一次输入已超过 1200ms”的限制；输入法组合仍跳过普通滚动，键盘尺寸变化会使用单帧合并的强制滚动。
- `markdownUpdated` 的重复收尾合并为单帧调度；只发生几何变化时跳过正文、目录和历史状态扫描。覆盖层与代码块样式写入使用幂等检查。
- 代码块使用不可变文档节点与实际 DOM 节点的身份判断是否发生变化，未受影响的代码块跳过重复配置；节点替换或样式被重置时仍完整恢复。
- WebView 暴露 `flushPendingChanges()`，在宿主进入后台前直接序列化当前 ProseMirror 文档，覆盖 Milkdown 自身约 200ms 的回传延迟和活动 CodeMirror 的最后输入。
- 忽略已经切走文档的上游延迟监听回调，并只把用户输入或编辑命令触发的事务作为未保存编辑，防止列表等节点的初始化规范化污染新文档。
- Android “全选”命令先同步当前代码块，再使用 ProseMirror `AllSelection` 选中整篇 Markdown；独立的输入框保持自己的选择范围。

`web/milkdown/tools/editor-runtime-oracle.html` 是无用户数据的合成判据页，覆盖首帧遮挡、立即取回最后输入、代码块内全选、整篇替换以及独立输入框。使用 `tools/run-editor-oracle.mjs` 可在独立的临时 Chrome 配置中运行并保存 JSON、HTML 和 PNG 结果。

2026-11-16 的验证结果：

- 即时保存、代码块内全选及切档隔离的真实 Chromium 判据通过，结果在 `build/editor-runtime-oracle-switch-final2/result.json`。
- HTML 覆盖层收敛、占位和版面跟随判据通过，结果在 `build/editor-overlay-oracle/result.json`。
- 未编辑 Markdown 的往返保真判据为 **41/41**，结果在 `build/editor-roundtrip-oracle-final/result.json`。
- 定向 Vitest 的 7 个内容缓冲、单帧调度、键盘几何和整篇选择测试通过。

固定 S/M/L 合成文档（300/1200/3200 行，约 3K/12K/33K 字符）在同一 Chromium 会话中分别采样 5 次新建和 5 次复用编辑器，修复前基准取自 Git HEAD 的独立源码副本。页面和内嵌编辑器均为可见状态，使用真实时钟。下表为新建编辑器的中位数，单位为毫秒：

| 规模 | 首屏渲染前 → 后 | 输入到绘制前 → 后 | 输入后收尾前 → 后 |
| --- | --- | --- | --- |
| S | 98.5 → 108.7 | 7.3 → 9.4 | 2.2 → 2.1 |
| M | 325.3 → 326.0 | 17.5 → 18.5 | 8.3 → 7.1 |
| L | 806.5 → 796.9 | 44.1 → 41.5 | 24.3 → 21.8 |

原始 60 组记录及 P50/P95 在 `build/editor-performance-oracle-code-cache/result.json`；可重跑的合成采样页是 `tools/editor-performance-oracle.html`。收尾阶段在中、大文档上有所下降，首屏和输入耗时存在噪声及复用场景回退，不能据此宣称整体性能门槛已经达标。这个桌面开发源码采样不能替代 Android 前台 profile 包的设备门槛，设备数据应另行记录。追加式渲染仍保持关闭，避免 Markdown 结构保真回退。
