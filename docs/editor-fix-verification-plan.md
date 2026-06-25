# Milkdown 编辑器修复验证计划

## 前置信息

- **应用包名**: `com.ushiomd`
- **主 Activity**: `com.ushiomd.MainActivity`
- **应用显示名**: 汐
- **构建命令**: 在项目根目录 `F:\xm\mdreader` 执行 `flutter build apk --debug`（debug 包便于 logcat 调试）
- **APK 输出路径**: `build/app/outputs/flutter-apk/app-debug.apk`
- **安装命令**: `adb install -r <apk路径>`
- **logcat 过滤**: `adb logcat -s flutter:V` 查看 Flutter 日志

## 测试准备

### P0: 构建与安装

```bash
# 1. 构建 debug APK
cd F:\xm\mdreader
flutter build apk --debug

# 2. 确认 MuMu 模拟器已连接
adb devices

# 3. 安装应用
adb install -r build\app\outputs\flutter-apk\app-debug.apk

# 4. 启动应用
adb shell am start -n com.ushiomd/.MainActivity
```

### P1: 准备测试用 Markdown 文件

在模拟器上创建一个包含各种元素的测试文件，用于触发各修复场景：

```bash
adb shell "cat > /sdcard/Documents/test_editor_fixes.md << 'TESTEOF'
# 测试文档

## 复选框测试
- [ ] 未完成任务一
- [x] 已完成任务二
- [ ] 未完成任务三

## 格式测试
这是**粗体**文字，这是*斜体*文字，这是~~删除线~~文字。

## 列表测试
- 无序列表项 1
- 无序列表项 2

1. 有序列表项 1
2. 有序列表项 2

## 代码块
\`\`\`dart
void main() {
  print('Hello World');
}
\`\`\`

## 长文本（用于滚动和键盘测试）
第一行文本，用于测试键盘弹出时的滚动行为。
第二行文本。
第三行文本。
第四行文本。
第五行文本。
第六行文本。
第七行文本。
第八行文本。
第九行文本。
第十行文本。
第十一行文本。
第十二行文本。
第十三行文本。
第十四行文本。
第十五行文本。
TESTEOF"
```

### P2: 开始 logcat 监控

```bash
# 在后台持续监控 Flutter 日志
adb logcat -s flutter:V | grep -E "CHECKBOX|WEBVIEW|EDITOR|UNDO|REDO"
```

---

## 测试用例

---

### 测试 #1: 预览模式撤销/重做路由到 ProseMirror

**对应修复**: Fix #1
**严重程度**: P0 - Critical

**前置条件**: 应用已安装，已有一个包含文本的 .md 文件

**操作步骤**:
1. 打开应用，进入文件列表
2. 打开一个已有的 .md 文件（或使用测试文件）
3. 确认当前处于**预览模式**（Milkdown 渲染状态，不是纯文本编辑）
4. 在编辑器中点击任意位置使 WebView 获得焦点
5. 通过 ADB 输入一些文字（或在模拟器软键盘上输入）
6. 执行撤销操作：按 Ctrl+Z（如果有外接键盘）或通过工具栏撤销按钮
7. 观察编辑器行为

**ADB 辅助命令**:
```bash
# 查看 logcat 中是否有 ProseMirror 相关的 execCmd 调用
adb logcat -s flutter:V | grep -i "execCmd\|undo\|redo"
```

**预期结果**:
- 撤销操作应该通过 ProseMirror 的历史插件执行（走 `execCmd('undo')` 路径）
- 编辑器中的内容应正确回退一步
- 不应出现 Flutter 侧 `_editHistory` 栈的越界错误
- logcat 中应出现 "已撤销" 反馈日志

**失败标志**:
- 编辑器内容没有变化
- logcat 中出现 `RangeError` 或 `Index out of range` 错误
- 编辑器白屏或崩溃

---

### 测试 #2: Milkdown 回传不污染 Flutter 撤销栈

**对应修复**: Fix #2
**严重程度**: P0 - Critical

**操作步骤**:
1. 打开 .md 文件，处于预览模式
2. 在 Milkdown 编辑器中连续输入 3-5 段不同内容
3. 等待每次输入后内容同步回 Flutter（约 500ms 间隔）
4. 执行撤销操作（Ctrl+Z 或工具栏按钮）

**ADB 辅助命令**:
```bash
# 监控 _isApplyingHistory 守卫是否生效
adb logcat -s flutter:V | grep -i "applyingHistory\|_onTextChanged\|history"
```

**预期结果**:
- 撤销操作只回退一步（不是回退到文档初始状态）
- 连续多次撤销应该逐步回退每一步编辑
- 不应出现"撤销一步却回退到很久之前状态"的异常

**失败标志**:
- 一次撤销就清空了所有内容
- 撤销栈中出现重复的快照
- logcat 中出现 `_isApplyingHistory` 未正确重置的日志

---

### 测试 #3: 内容清理器不再损坏合法 Markdown

**对应修复**: Fix #3
**严重程度**: P0 - Critical

**操作步骤**:
1. 创建或打开一个包含以下"敏感但合法"内容的 .md 文件：
   - 包含 `<script>` 字样的代码说明文本（如：`在HTML中，<script> 标签用于...`）
   - 包含 `<div>` 等 HTML 标签的文档说明
   - 包含 `javascript:` 字样的链接说明（如：`javascript:void(0) 是一个空操作`）
   - 包含 `<img onerror="...">` 的 Markdown 安全讲解内容
2. 在预览模式下打开该文件
3. 检查渲染后的内容是否完整

**ADB 辅助命令**:
```bash
# 确认没有触发内容清理警告
adb logcat -s flutter:V | grep -i "危险内容\|sanitize\|清理"
```

**预期结果**:
- 所有原始 Markdown 内容完整保留，没有被正则替换或删除
- logcat 中**不出现**"检测到潜在危险内容"的警告
- WebView 中的 Milkdown 渲染正常（Milkdown/ProseMirror 本身有 XSS 防护）

**失败标志**:
- 文档中的 `<script>` 等字样被替换或移除
- 出现"已自动清理"的日志
- 文档内容被截断

---

### 测试 #4: 双击手势不再阻塞单击响应

**对应修复**: Fix #4
**严重程度**: P1 - High

**操作步骤**:
1. 打开 .md 文件，处于预览模式
2. 单击编辑器区域，观察 WebView 是否立即获得焦点
3. 记录从单击到编辑器响应的延迟感
4. 快速双击编辑器区域，观察是否触发"专注模式"切换
5. 再次双击退出专注模式

**ADB 辅助命令**:
```bash
# 监控专注模式切换日志
adb logcat -s flutter:V | grep -i "专注模式\|focusMode\|focus_mode"

# 截图对比（可选）
adb shell screencap -p /sdcard/before_tap.png
```

**预期结果**:
- **单击**：WebView 应立即响应（无明显延迟，< 50ms 感知延迟）
- **双击**（两次点击间隔 < 400ms）：应触发专注模式切换，底部出现 SnackBar 提示
- **三连击**：只触发一次双击（第二次双击被 `_lastTapDownTime = null` 阻止）
- 不再出现"单击后等 300ms 才响应"的现象

**失败标志**:
- 单击仍有明显延迟（~300ms）
- 双击无法触发专注模式
- 单击触发了专注模式（误判）

---

### 测试 #5: 预览模式键盘弹出时 WebView 自适应

**对应修复**: Fix #5
**严重程度**: P1 - High

**操作步骤**:
1. 打开包含长文本的 .md 文件，处于预览模式
2. 点击编辑器底部区域的文字，触发软键盘弹出
3. 观察编辑器区域是否被键盘遮挡
4. 在键盘可见状态下输入内容，检查光标是否可见
5. 收起键盘，检查编辑器是否恢复原始大小

**ADB 辅助命令**:
```bash
# 截图对比键盘弹出前后
adb shell screencap -p /sdcard/keyboard_hidden.png
# （手动触发键盘后）
adb shell screencap -p /sdcard/keyboard_visible.png
```

**预期结果**:
- 键盘弹出时，WebView 内容区**自动收缩**到键盘上方
- 编辑器底部内容不被键盘遮挡
- 键盘收起后，WebView 恢复原始大小
- 工具栏正确浮动在键盘上方（不与编辑器重叠）

**失败标志**:
- WebView 内容被键盘遮挡
- 键盘弹出后编辑器白屏
- 工具栏位置异常（与键盘重叠或跑到屏幕外）

---

### 测试 #6: 预览模式格式快捷键不双重执行

**对应修复**: Fix #6
**严重程度**: P2 - Medium

**前置条件**: 模拟器需要有外接键盘（或使用 ADB keyevent 模拟）

**操作步骤**:
1. 打开 .md 文件，处于预览模式
2. 选中一段文字（长按拖动选择）
3. 按 Ctrl+B（加粗快捷键）
4. 观察文字的加粗状态

**ADB 辅助命令**:
```bash
# 模拟 Ctrl+B（Android 上 META_CTRL + KEYCODE_B）
adb shell input keyevent --longpress KEYCODE_CTRL_LEFT KEYCODE_B

# 监控 execCmd 调用
adb logcat -s flutter:V | grep -i "toggle_bold\|execCmd\|onApplyAction"
```

**预期结果**:
- 文字只被加粗一次（不是加粗后立即又被取消加粗）
- Flutter 侧的 `onApplyAction` 在预览模式下应被跳过（logcat 中无相关日志）
- ProseMirror 侧正确处理了加粗操作

**失败标志**:
- 文字被加粗后又取消（双重执行的结果 = 不变）
- 文字被加粗了两次（样式叠加异常）
- logcat 中出现 Flutter 侧的 `_applyToolbarAction` 被调用的日志

---

### 测试 #7: suppressNextReload token 过期机制

**对应修复**: Fix #7
**严重程度**: P2 - Medium

**操作步骤**:
1. 打开 .md 文件，处于预览模式
2. 触发一次复选框切换操作（这会调用 `suppressNextReload()`）
3. 等待 3 秒以上（超过 token 的 2 秒 TTL）
4. 通过外部修改文件内容（如用其他工具修改文件后保存）
5. 观察 WebView 是否正确重新加载

**ADB 辅助命令**:
```bash
# 监控 suppress token 相关日志
adb logcat -s flutter:V | grep -i "suppress\|reload\|init_doc"

# 模拟外部文件修改
adb shell "echo '# 外部修改的内容' >> /sdcard/Documents/test_editor_fixes.md"
```

**预期结果**:
- 复选框切换后立即触发的 rebuild 被正确抑制（WebView 不闪烁/重载）
- 超过 2 秒后的外部文件修改能正确触发 WebView 重载（token 已过期，不被误抑制）
- logcat 中不出现"stale suppression"（陈旧的抑制被错误消费）

**失败标志**:
- 外部文件修改后 WebView 不更新（token 未过期就被消费了，或者 TTL 太长）
- 复选框切换后 WebView 闪烁重载（token 未被正确消费）

---

### 测试 #8: 返回键 blur_editor 超时降级

**对应修复**: Fix #8
**严重程度**: P2 - Medium

**操作步骤**:
1. 打开 .md 文件，处于预览模式
2. 点击编辑器使 Milkdown 获得焦点（底部工具栏应出现）
3. 按返回键，观察是否先退出编辑器焦点
4. 再按返回键，观察是否弹出保存提示或正常返回

**ADB 辅助命令**:
```bash
# 模拟返回键
adb shell input keyevent KEYCODE_BACK

# 监控 blur_editor 和降级计时器
adb logcat -s flutter:V | grep -i "blur_editor\|blurFallback\|on_editor_focus"
```

**预期结果**:
- **第一次返回键**：WebView 编辑器失焦（`blur_editor` 命令发送），底部工具栏收起
- **第二次返回键**：如果文件未修改，直接返回文件列表；如果已修改，弹出保存确认
- 即使 WebView 未响应 `blur_editor`，800ms 后编辑器也会自动失焦，不会卡死

**失败标志**:
- 按返回键无任何反应（用户被卡住）
- 需要多次按返回键才能退出
- 应用崩溃或 ANR（Application Not Responding）

---

### 测试 #9: 复选框索引防御性检查

**对应修复**: Fix #9
**严重程度**: P3 - Low

**操作步骤**:
1. 打开包含多个复选框的测试文件
2. 逐个点击复选框，观察切换行为
3. 快速连续点击不同复选框（测试索引不同步场景）

**ADB 辅助命令**:
```bash
# 监控复选框切换日志
adb logcat -s flutter:V | grep -i "CHECKBOX"
```

**预期结果**:
- 每次点击正确切换对应的复选框（[ ] ↔ [x]）
- 如果索引越界（WebView 和 Flutter 侧状态不同步），logcat 中出现"复选框索引越界"警告，操作被安全忽略
- 不会出现数组越界异常或应用崩溃

**失败标志**:
- 点击复选框 A 却切换了复选框 B
- logcat 出现 `RangeError` 或 `IndexError`
- 应用崩溃

---

### 测试 #10: 应用切后台不中断 inline edit

**对应修复**: Fix #10
**严重程度**: P3 - Low

**操作步骤**:
1. 打开 .md 文件，处于预览模式
2. 触发 inline edit 模式（如果支持，通过点击某个 block 进入局部编辑）
3. 在 inline edit 活跃状态下，按 Home 键将应用切到后台
4. 等待几秒后切回应用
5. 检查 inline edit 状态

**ADB 辅助命令**:
```bash
# 切到后台
adb shell input keyevent KEYCODE_HOME

# 等 3 秒后切回
sleep 3
adb shell am start -n com.ushiomd/.MainActivity

# 监控生命周期和 inline edit 日志
adb logcat -s flutter:V | grep -i "lifecycle\|inlineEdit\|editingBlock\|AppLifecycleState"
```

**预期结果**:
- 切到后台时，inline edit 内容**不丢失**（`_finishInlineEdit` 不被触发）
- 切回前台后，如果焦点已丢失，inline edit 在 300ms 延迟后安全收尾（内容被保存）
- 不会出现"切后台后编辑内容丢失"的情况

**失败标志**:
- 切回应用后 inline edit 的内容丢失
- 切回后出现重复的编辑内容
- 应用崩溃

---

### 测试 #11: 指针事件节流

**对应修复**: Fix #11
**严重程度**: P3 - Low

**操作步骤**:
1. 打开 .md 文件，处于预览模式
2. 在编辑器区域内快速滑动（模拟滚动浏览长文档）
3. 观察浮动按钮（如工具栏按钮）的显示/隐藏行为
4. 停止滑动，等待浮动按钮出现

**ADB 辅助命令**:
```bash
# 模拟快速滑动
adb shell input swipe 500 1500 500 500 100
adb shell input swipe 500 1500 500 500 100
adb shell input swipe 500 1500 500 500 100

# 监控浮动按钮状态
adb logcat -s flutter:V | grep -i "floatingButton\|floating_button\|userInteraction"
```

**预期结果**:
- 快速滑动期间，`_onUserInteraction` 被节流（100ms 内的重复调用被跳过）
- 浮动按钮在滑动期间保持隐藏
- 停止滑动后约 2 秒，浮动按钮平滑出现
- 不出现按钮闪烁或卡顿

**失败标志**:
- 滑动期间按钮闪烁（频繁 setState 导致）
- 滑动结束后按钮永远不出现
- logcat 中出现大量密集的 `userInteraction` 日志（说明节流未生效）

---

## 综合稳定性测试

### S1: 编辑-预览模式切换压力测试

```bash
# 操作步骤：
# 1. 打开测试文件
# 2. 反复在编辑模式和预览模式之间切换 10 次
# 3. 每次切换后输入/修改一些内容
# 4. 检查最终内容是否与输入一致
```

**预期**: 无崩溃，内容完整，撤销栈正常

### S2: 长时间编辑稳定性

```bash
# 操作步骤：
# 1. 打开测试文件，进入预览模式
# 2. 持续编辑 5 分钟（混合输入、删除、撤销、重做、复选框切换）
# 3. 观察是否有内存泄漏或卡顿
```

**预期**: 无 ANR，无 OOM，无明显卡顿

---

## 结果报告模板

每个测试用例请按以下格式记录结果：

```
## 测试 #N: [测试名称]
- **状态**: ✅ 通过 / ❌ 失败 / ⚠️ 部分通过 / 🚫 无法执行
- **测试时间**: YYYY-MM-DD HH:MM
- **观察到的行为**: （描述实际发生了什么）
- **logcat 关键日志**: （粘贴相关的 logcat 输出）
- **截图/录屏**: （如有）
- **备注**: （特殊情况说明）
```

---

## 优先级排序建议

建议按以下顺序执行测试（从最关键到最次要）：

| 顺序 | 测试编号 | 优先级 | 原因 |
|------|---------|--------|------|
| 1 | #1, #2 | P0 | 撤销/重做是最核心的编辑功能，状态损坏会导致数据丢失 |
| 2 | #3 | P0 | 内容清理器会静默损坏用户文档 |
| 3 | #8 | P2 | 返回键卡死会直接影响用户体验 |
| 4 | #4 | P1 | 单击延迟影响日常交互体感 |
| 5 | #5 | P1 | 键盘遮挡影响编辑可用性 |
| 6 | #6 | P2 | 格式快捷键双重执行影响编辑效率 |
| 7 | #7 | P2 | token 机制是防御性改进，正常场景不易触发 |
| 8 | #9 | P3 | 复选框索引防御，边界场景 |
| 9 | #10 | P3 | inline edit 后台保持，低频场景 |
| 10 | #11 | P3 | 性能优化，功能不受影响 |
| 11 | S1, S2 | 综合 | 稳定性兜底 |
