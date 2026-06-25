# Milkdown 编辑器输入与交互问题修复计划

## 概览

共 11 个问题，分 4 个阶段修复。阶段内按依赖关系排序，前序修复完成后再处理后续项。

| 阶段 | 目标 | 涉及问题 | 预估工时 |
|------|------|----------|----------|
| P0 - 紧急 | 修复文档状态损坏和数据丢失 | #1 #2 #3 | 6-8h |
| P1 - 高优 | 修复核心交互体验 | #4 #5 | 4-5h |
| P2 - 中等 | 修复快捷键和状态一致性 | #6 #7 #8 | 4-5h |
| P3 - 改善 | 修复边缘场景 | #9 #10 #11 | 2-3h |

总计预估：16-21h

---

## P0 - 紧急修复（文档状态损坏）

### #1 Flutter 侧撤销/重做在预览模式下破坏 Milkdown 文档

**根因**：`_undoEditHistory()` / `_redoEditHistory()` 修改 `_textController.text` 后触发 `setState`，但没有调用 `suppressNextReload()`，导致 `didUpdateWidget` 中 `_sendInitDoc()` 被触发，ProseMirror 的 `replaceAll` 替换整个文档，光标和历史记录全部丢失。

**文件**：`lib/screens/editor_screen.dart`

**修复方案**：在预览模式下，撤销/重做应路由到 ProseMirror 的命令系统，而非操作 Flutter 侧的 `_textController`。

```
修改点 1: _undoEditHistory()
  - 判断 _mode == EditorMode.preview
  - 如果是预览模式：调用 _previewWebViewController.execCmd('undo')
  - 如果是编辑模式：保持现有逻辑

修改点 2: _redoEditHistory()
  - 同上，路由到 execCmd('redo')
```

**验证方法**：预览模式下编辑内容 -> Ctrl+Z 撤销 -> 确认光标位置保留、可继续撤销多步。

---

### #2 双重撤销栈不同步

**根因**：Flutter 的 `_editHistory`（全文快照）和 ProseMirror 的 `history` 插件（增量事务）完全独立，没有同步机制。ProseMirror 撤销后内容变化同步回 Flutter 被记录为新快照，污染 Flutter 撤销栈。

**文件**：`lib/screens/editor_screen.dart`

**修复方案**：在预览模式下，完全依赖 ProseMirror 的撤销栈，Flutter 侧的 `_editHistory` 仅用于编辑模式。

```
修改点 1: _onTextChanged() 中的 _recordHistorySnapshot()
  - 增加来源标记，区分"来自 Milkdown 回传"和"来自编辑模式用户输入"
  - 来自 Milkdown 回传的变更不记录到 _editHistory

修改点 2: _handleMilkdownContentChange()
  - 在调用 _onTextChanged() 前设置 _isApplyingHistory = true（或引入新标记）
  - 确保 Milkdown 回传的内容变更不会在 Flutter 侧创建历史快照

修改点 3: 工具栏撤销/重做按钮的 canUndo/canRedo 状态
  - 预览模式下通过桥接获取 ProseMirror 的 canUndo/canRedo 状态
  - 或在 on_cmd_result 中维护预览模式下的撤销可用性
```

**验证方法**：预览模式下编辑 -> 撤销多步 -> 切换到编辑模式 -> 确认编辑模式撤销栈正确。

---

### #3 内容安全检查器损坏合法 Markdown

**根因**：`_ContentSanitizer.sanitizeMarkdown()` 用正则表达式在原始 Markdown 文本上做替换，不理解 Markdown 结构（代码块、行内代码等）。`<script>`、`<iframe>`、`onclick=` 等出现在代码块中会被误删。

**文件**：`lib/widgets/milkdown_webview_editor.dart`

**修复方案**：移除源文本级别的清理。Milkdown/ProseMirror 本身不会执行脚本标签，已有足够的安全隔离。如果仍需保留防护层，改为仅在渲染输出上做（不修改 Markdown 源文本）。

```
修改点 1: _sendInitDoc() 中移除 sanitizeMarkdown 调用
  - 删除 containsDangerousContent 检查和 sanitizeMarkdown 调用
  - 删除相关的 _logError 警告日志
  - 保留 _ContentSanitizer.sanitizeUrl() 用于 URL 安全检查（插入图片等场景）

修改点 2（可选保留）: 如果需要保留审计日志
  - 将 containsDangerousContent 检查改为仅记录日志，不修改内容
  - 记录但不干预，方便排查问题但不损坏用户内容
```

**验证方法**：创建包含 `` ```html `` 代码块的 Markdown -> 保存 -> 重新打开 -> 确认代码块内容完整。

---

## P1 - 高优修复（核心交互体验）

### #4 GestureDetector 的 onDoubleTap 导致 300ms 点击延迟

**根因**：`_buildEditorWithGesture()` 中的 `GestureDetector(onDoubleTap: ...)` 包裹整个 Milkdown WebView。Flutter 的双击检测在第一次点击后等待约 300ms 判断是否有第二次点击，导致所有单击事件延迟。

**文件**：`lib/screens/editor_screen.dart`

**修复方案**：用 `onTapDown` + 手动时间戳判断替代 `onDoubleTap`，消除手势竞技场的等待。

```
修改点 1: _buildEditorWithGesture() 重构
  - 移除 GestureDetector.onDoubleTap
  - 添加 _lastTapDownTime 变量
  - 使用 GestureDetector.onTapDown：
    1. 记录当前时间
    2. 如果距上次 tapDown < 300ms，视为双击 -> 切换专注模式
    3. 否则立即放行事件给子组件（无延迟）
  - 保留 behavior: HitTestBehavior.translucent

修改点 2: 添加 _lastTapUpWasConsumed 标记
  - 双击识别成功后设置标记
  - 避免双击识别后第一个 tap 的 onTapUp 再次触发交互
```

**验证方法**：预览模式下快速点击编辑器 -> 确认光标立即放置（无明显延迟）-> 双击切换专注模式仍然正常工作。

---

### #5 键盘遮挡 Milkdown 编辑区域

**根因**：`Scaffold(resizeToAvoidBottomInset: false)` 在键盘弹出时不收缩 body。编辑模式有手动的 `_scheduleEditScrollToCursor` 处理，但预览模式下 WebView 不知道键盘的存在。

**文件**：`lib/screens/editor_screen.dart`

**修复方案**：在预览模式下监听键盘变化，通过桥接通知 WebView 调整视口。

```
修改点 1: didChangeMetrics() 增加预览模式处理
  - 当键盘弹出（keyboardInset > _lastKeyboardInset）且 _mode == preview 时
  - 通过 execCmd 发送 'scroll_cursor_into_view' 命令
  - 或调用 JS: window.scrollTo 使光标可见

修改点 2（JS 侧）: 添加 scroll_cursor_into_view 命令处理
  - 获取 ProseMirror 当前光标位置的 DOM 坐标
  - 计算键盘遮挡区域
  - 滚动使光标位于可见区域上方

修改点 3: 备选方案 - 使用 Padding 包裹 WebView
  - 当键盘弹出时，给 WebView 添加底部 Padding
  - 使 WebView 的可视区域缩小到键盘上方
  - 注意：这可能需要重新渲染 WebView，需要测试性能影响
```

**验证方法**：预览模式下光标在文档底部 -> 点击编辑触发键盘 -> 确认光标自动滚动到可见区域。

---

## P2 - 中等修复（快捷键和状态一致性）

### #6 CallbackShortcuts 与 WebView 键盘快捷键冲突

**根因**：`CallbackShortcuts` 绑定的 Ctrl+B/I/Z/Y、Ctrl+Shift+X、Ctrl+1/2/3 等快捷键与 Milkdown JS 层的 `handleEditorShortcut` 重复。在桌面平台上通常 WebView 原生窗口先捕获事件，但依赖平台行为，可能在某些配置下出现双重触发。

**文件**：`lib/screens/editor/editor_shortcuts.dart`、`lib/screens/editor_screen.dart`

**修复方案**：在预览模式下，格式类快捷键交给 WebView 处理，Flutter 侧只保留文件操作和搜索快捷键。

```
修改点 1: buildShortcutBindings() 或调用处
  - 将快捷键分为两组：
    a. 全局组（始终生效）：Ctrl+S 保存、Ctrl+F 搜索、Escape、F3
    b. 编辑模式组（仅编辑模式生效）：Ctrl+B/I/Z/Y、Ctrl+1/2/3 等格式快捷键
  - 在 CallbackShortcuts 的 bindings 中，格式类快捷键的回调增加 _mode 判断
  - 预览模式下直接 return（让 WebView 自行处理）

修改点 2（替代方案）: 拆分为两个 CallbackShortcuts
  - 外层：全局快捷键（保存、搜索）
  - 内层：编辑模式快捷键（仅当 _mode == edit 时绑定）
```

**验证方法**：预览模式下按 Ctrl+B -> 确认文本加粗且不会闪烁（双重触发）。

---

### #7 `_suppressNextReload` 标志位竞态

**根因**：布尔标志 `_suppressNextReload` 不与特定内容变更关联。当 Milkdown 回传设置了 suppress 后，外部内容更新（版本恢复、丢弃修改）恰好修改 `_textController.text` 会消费掉该标志，导致外部更新被静默忽略。

**文件**：`lib/widgets/milkdown_webview_editor.dart`、`lib/screens/editor_screen.dart`

**修复方案**：将布尔标志改为内容版本号或 token 机制。

```
修改点 1: 将 _suppressNextReload 改为 _suppressReloadToken (int?)
  - suppressNextReload() 设置 token = ++_tokenCounter
  - didUpdateWidget 中检查 token 是否匹配当前变更
  - 外部更新（版本恢复等）设置自己的 token，不会被 Milkdown 回传消费

修改点 2（更简单）: 外部更新路径也使用 suppressNextReload
  - _restoreVersion() 中调用 suppressNextReload() 后再更新 _textController
  - _discardUnsavedChanges() 同理
  - 确保所有"不应触发 init_doc 回声"的路径都正确设置标志
```

**验证方法**：预览模式下正在编辑 -> 执行版本恢复 -> 确认编辑器显示恢复后的内容。

---

### #8 返回键处理可能卡死

**根因**：当 `_isMilkdownEditorFocused` 为 true 时，返回键只调用 `blur_editor`。如果该命令静默失败，焦点状态永远不会改变，用户无法退出。

**文件**：`lib/screens/editor_screen.dart`

**修复方案**：添加超时降级机制。

```
修改点 1: onPopInvokedWithResult 中的 blur 逻辑
  - 调用 blur_editor 后启动 500ms 超时定时器
  - 超时后如果 _isMilkdownEditorFocused 仍为 true，强制设为 false
  - 记录日志以便排查 JS 命令失败的原因

修改点 2: 连续按返回键的处理
  - 如果距离上次 blur_editor 调用 < 1s 且仍然 focused，直接强制失焦并继续退出流程
```

**验证方法**：预览模式编辑中 -> 按返回键 -> 确认第一次失焦、第二次正常退出。模拟 JS 桥接故障 -> 确认超时后仍可退出。

---

## P3 - 改善（边缘场景）

### #9 复选框索引可能不匹配

**根因**：`toggleCheckboxInText` 通过线性扫描文本统计复选框索引，如果 `incrementalMerge` 改变了复选框数量，WebView 传来的索引可能指向错误的复选框。

**文件**：`lib/screens/editor/models/editor_patterns.dart`、`lib/screens/editor_screen.dart`

**修复方案**：在切换复选框前，用当前 `_textController.text` 重新计算索引映射。

```
修改点 1: _toggleCheckbox() 增加防御性检查
  - 在执行切换前，计算当前文本中的复选框总数
  - 如果 index >= 总数，记录警告日志并跳过（不切换）
  - 可选：与 WebView 同步一次最新内容后再切换

修改点 2: 增强正则匹配
  - 支持 * [ ] 和 + [ ] 语法（除了现有的 - [ ]）
  - 确保 Flutter 侧和 Milkdown 侧的复选框计数逻辑一致
```

**验证方法**：包含多个复选框的文档 -> 在编辑过程中切换不同位置的复选框 -> 确认每个都切换正确。

---

### #10 内联编辑失焦自动完成

**根因**：`_onInlineEditFocusChanged()` 在焦点丢失时自动调用 `_finishInlineEdit()`。用户切换到其他应用时会意外"完成"编辑。

**文件**：`lib/screens/editor_screen.dart`

**修复方案**：区分"用户主动离开"和"应用失焦"。

```
修改点 1: 监听 WidgetsBindingObserver.didChangeAppLifecycleState
  - 当应用进入 paused/inactive 状态时，设置 _appInBackground = true
  - _onInlineEditFocusChanged() 中检查该标记
  - 如果 _appInBackground 为 true，不调用 _finishInlineEdit()
  - 应用恢复前台时重置标记

修改点 2（更简单）: 延迟完成
  - 失焦后启动 1s 定时器
  - 如果 1s 内焦点恢复，取消完成
  - 超时后才真正执行 _finishInlineEdit()
```

**验证方法**：内联编辑中 -> 切换到其他应用 -> 切回来 -> 确认编辑状态保留。

---

### #11 Listener 在滚动时触发不必要的 setState

**根因**：`Listener` 的 `onPointerMove` 在每次滚动事件中触发 `_onUserInteraction()` -> `setState()`。虽然有 `_floatingButtonsVisible` 守卫，但快速滚动时仍有大量 Timer 操作。

**文件**：`lib/screens/editor_screen.dart`

**修复方案**：对指针事件做节流处理。

```
修改点 1: _onUserInteraction() 增加节流
  - 添加 _lastInteractionTime 变量
  - 如果距上次交互 < 200ms，跳过本次处理
  - 仅处理首次交互和末次交互（通过 Timer 延迟处理 pointerUp）

修改点 2: 区分 pointerDown 和 pointerMove
  - pointerDown 和 pointerUp 正常处理
  - pointerMove 使用节流（滚动期间不需要频繁触发隐藏/显示）
```

**验证方法**：快速滚动编辑器 -> 使用 DevTools Performance 面板确认无频繁的 setState 调用。

---

## 依赖关系图

```
#1 (撤销路由) ──> #2 (撤销栈同步) ──> #6 (快捷键冲突)
                                          │
#3 (安全检查器) ──────────────────────────> │ (独立)
                                          │
#4 (点击延迟) ──────────────────────────> │ (独立)
                                          │
#5 (键盘遮挡) ──────────────────────────> │ (独立)
                                          │
#7 (suppress 竞态) ──> #8 (返回键卡死) ──>│
                                          │
#9 (复选框) ──── #10 (内联编辑) ──── #11 (Listener) (独立)
```

建议严格按 P0 -> P1 -> P2 -> P3 顺序执行。P0 中的 #1 和 #2 强相关，应一起修复。P2 中的 #6 依赖 #1/#2 的修复结果（预览模式下撤销路由到 ProseMirror 后，快捷键冲突的处理方式也会改变）。
