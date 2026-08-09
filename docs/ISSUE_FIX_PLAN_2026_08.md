# Open Issues 修复计划（2026-08-09）

## 1. Issue 总览

当前仓库 `jiuxina/ushio-md` 共有 6 个 open issue，其中 3 个属于可立即落地的缺陷/体验问题，3 个属于功能或平台诉求。

| Issue | 标题 | 类型 | 提出人 | 优先级 |
| --- | --- | --- | --- | --- |
| #119 | 内容过多容易卡顿 | Bug + 性能 + 功能 | Shi369 | P0 |
| #117 | 正在加载内容，渲染速度慢 | 性能 | 456vv | P0 |
| #118 | 引用块外观改善 | UI | Jason-019 | P1 |
| #112 | [feat.] 支持 git | 功能 | yhzcake | P2 待评估 |
| #110 | Synchronous support S3 | 功能 | Inverstar | P2 待评估 |
| #109 | Linux 适配 | 平台 | 4YStudio | P2 待评估 |

## 2. #119 评论中确认的缺陷

#119 没有正文描述，但评论区补充了 3 个严重 Bug 和 1 个需求：

1. **Bug A：键盘遮挡内容**。字数较多时，键盘弹出后挡住文章，文章无法向下滚动，正在输入的内容在屏幕上不可见。
2. **Bug B：特殊符号被篡改**。正文包含 `–` 等特殊符号时，点击预览再切回编辑，原文被篡改，出现内容混乱和大量空行。
3. **Bug C：重命名后文件消失**。新建文件后重命名，如果没有手动输入 `.md` 后缀，文件会从文件列表消失；退出重进也无法恢复。
4. **需求：自定义模板**。用户希望新增模板功能，可自定义模板内容，下次写文章时套用。

## 3. 根因分析与代码定位

### 3.1 Bug C：重命名后文件消失（根因明确，修复成本低）

- 重命名对话框在 [lib/utils/file_actions.dart](F:/xm/mdreader/lib/utils/file_actions.dart:1007) 中只显示 `suffixText: '.md'`，但返回的是用户输入的原始文本，并不会把后缀写进结果。
- 确认后调用 `FileService.sanitizeFileName()` 得到 `newPath`，随后直接 `file.rename(newPath)`（[file_actions.dart](F:/xm/mdreader/lib/utils/file_actions.dart:1083)）。`sanitizeFileName` 只清理非法字符，不保证补 `.md`。
- 服务层已经提供了正确实现：`FileService.renameFile` 会在缺少扩展名时自动补 `.md`（[file_service.dart](F:/xm/mdreader/lib/services/file_service.dart:586)），但对话框没有复用它。
- 文件列表按 `.md`/`.markdown` 过滤，因此没有后缀的文件重命名后立即“消失”。

### 3.2 Bug A：键盘遮挡与无法滚动

- `AndroidManifest.xml` 已配置 `windowSoftInputMode="adjustResize"`，方向正确。
- `didChangeMetrics()` 里只在 `EditorMode.edit` 且编辑框有焦点时滚动到光标（[editor_screen.dart](F:/xm/mdreader/lib/screens/editor_screen.dart:1208)）；Milkdown WebView（默认的 `EditorMode.preview`）没有对应的滚动/光标可见性处理。
- 编辑器区域只在 `_mode == EditorMode.preview && _editingBlockIndex == null && keyboardInset > 0` 时垫底部 inset（[editor_screen.dart](F:/xm/mdreader/lib/screens/editor_screen.dart:2252)）；块内联编辑等分支没有保护。
- 需要验证 WebView 内容区是否随 `viewInsets` 正确收缩，以及 Milkdown 侧光标是否自动 `scrollIntoView`。

### 3.3 Bug B：特殊符号被篡改、出现大量空行

- 每次 WebView 上报 `on_content_change` 都会执行全文增量合并（[editor_screen.dart](F:/xm/mdreader/lib/screens/editor_screen.dart:1921)）：`incrementalMerge(original, newContent)`。
- 增量合并按块解析全文（[markdown_incremental_merge.dart](F:/xm/mdreader/lib/utils/markdown_incremental_merge.dart:47)），块与块之间用 `join('\n')` 拼接，blank 块自身又包含换行，容易在边界处产生额外空行。
- 特殊符号（如 `–`、中文引号、省略号）在 Milkdown 序列化与本地块解析之间可能触发语义比较/块边界误判，导致合并结果被替换或膨胀。
- 目前没有针对该合并器的 roundtrip 回归测试。

### 3.4 性能：#117 渲染慢、#119 长文卡顿

- `_handleMilkdownContentChange` 对每次按键都执行全文 parse + 块匹配，长文档（如 15000+ 字符）为 O(全文) 开销，这是卡顿的最直接嫌疑。
- 每次内容变化都会更新 `_textController.text` 并触发整屏 rebuild，包含 WebView 组件树。
- WebView 侧每次序列化都输出完整 Markdown，Flutter 侧再全量合并，缺少节流/防抖。

### 3.5 UI：#118 引用块间距

- issue 截图经视觉理解桥转述：引用块为青色左侧竖线，文字与边框已有一定间距，但用户认为“边界和文字部分缺乏呼吸空间”。
- 编辑端 CSS 的引用块 `padding-left: 0.2em`，明显偏小（[web/milkdown/src/style.css](F:/xm/mdreader/web/milkdown/src/style.css:104)）。
- Flutter 预览端 `blockquotePadding` 为 `fromLTRB(16, 8, 8, 8)`（[markdown_preview.dart](F:/xm/mdreader/lib/widgets/markdown_preview.dart:186)），与 WebView 端表现不一致，需要同步调整。

## 4. 修复计划

### Phase 1（P0，预计 1-2 天）：#119 三个 Bug + #117 性能

1. **重命名补全 `.md` 后缀**
   - 修改 [file_actions.dart](F:/xm/mdreader/lib/utils/file_actions.dart:1007) 的重命名流程：sanitize 后若不以 `.md`/`.markdown` 结尾则追加 `.md`，或直接改用 `FileService.renameFile`。
   - 同步检查文件列表与编辑页两处重命名入口，以及文件夹重命名是否受影响。
   - 在 `test/services/file_service_test.dart` 增加“无后缀重命名自动补 `.md`”测试。

2. **键盘遮挡修复**
   - 统一在 build 层把 `keyboardInset` 应用到 WebView 编辑区域，不再限定 `_editingBlockIndex == null`。
   - 在 Milkdown bridge 增加“光标可见”处理：键盘弹出或光标移动时调用 `scrollIntoView`，或由 Flutter 在 `didChangeMetrics` 中通知 WebView 滚动。
   - Android 模拟器上验证：长文 + 中文输入法弹出后，当前行始终可见且可继续滚动。

3. **特殊符号/空行篡改修复**
   - 为 `markdown_incremental_merge` 增加 roundtrip 测试：`–`、`—`、中文引号、省略号、连续空行、引用/列表混合、长文。
   - 修正 blank 块 join 拼接和语义比较逻辑，避免空行膨胀。
   - 如果全文合并本身不可靠，改为内容变化时仅合并 changed range，切回源码/保存时再做全量归并。

4. **长文性能优化**
   - 给 `_handleMilkdownContentChange` 增加防抖（复用 `lib/utils/debouncer.dart`），把增量合并从每次按键降低到输入停顿后执行。
   - 避免每次内容变化都触发整屏 rebuild：把增量合并结果与 WebView 组件隔离，或对超大文档暂时关闭增量合并。
   - WebView 侧对 `on_content_change` 做节流，减少完整 Markdown 序列化次数。

### Phase 2（P1，0.5-1 天）：#118 引用块外观

1. 将 [style.css](F:/xm/mdreader/web/milkdown/src/style.css:104) 中引用块 `padding-left` 从 `0.2em` 提升到约 `0.8em-1em`，并增加适当上下内边距与行距。
2. 同步调整 [markdown_preview.dart](F:/xm/mdreader/lib/widgets/markdown_preview.dart:177) 的 `blockquotePadding`，保证编辑与预览观感一致。
3. 视觉验证：Android 模拟器截图 + Flutter 预览截图对比，确保文字与左边框有明显呼吸空间且不破坏引用块语义。

### Phase 3（P2，功能/平台，需单独排期）

- #119 附加需求：文档模板（自定义模板内容、新建时套用）。
- #112：支持 Git 远程仓库。
- #110：S3 加密同步。
- #109：Linux 适配。

这些属于功能开发或平台工程，建议按独立需求拆分后再排期，不阻塞 P0/P1 缺陷修复。

## 5. 验证清单

- [ ] `flutter analyze` 无新增告警
- [ ] `flutter test` 全量通过，含新增的 rename 与 incremental merge roundtrip 测试
- [ ] Android 模拟器安装后验证：
  - 长文 + 中文输入法弹出时当前行可见、可滚动
  - 含 `–`、中文引号、连续空行的文档预览/编辑往返内容一致
  - 新建文件重命名不带 `.md` 时文件仍显示，且自动带 `.md`
  - 引用块左右/上下间距符合预期
- [ ] 记录长文档（15000+ 字符）输入延迟改善数据

## 6. 相关文件索引

- `lib/utils/file_actions.dart`：重命名对话框与文件操作入口
- `lib/services/file_service.dart`：`renameFile` / `sanitizeFileName`
- `lib/screens/editor_screen.dart`：键盘 inset、预览/编辑切换、增量合并调用
- `lib/utils/markdown_incremental_merge.dart`：块级增量合并
- `lib/widgets/milkdown_webview_editor.dart`：Milkdown WebView 桥接
- `web/milkdown/src/style.css`：WebView 端引用块样式
- `lib/widgets/markdown_preview.dart`：Flutter 端预览样式
- `test/services/file_service_test.dart`、`test/models/milkdown_bridge_test.dart`：现有测试入口
