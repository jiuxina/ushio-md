# 标题解析问题修复实施方案

## 执行摘要

经过深入分析,发现当前代码已经实现了heading ID去重机制(使用行号确保唯一性),因此release notes中提到的"标题之间内容解析错误"问题可能源于:

1. **Milkdown内部解析器的边界情况**
2. **特定markdown模式触发的问题**
3. **用户操作时的状态同步问题**

本文档提供可立即执行的修复方案。

---

## 问题诊断

### 已排除的问题

✅ **Heading ID重复** - 已通过行号机制解决
- 代码位置: `web/milkdown/src/main.js:1469`
- 实现: `heading.id = heading-line-${lineNumber}`
- 每个heading的ID基于行号,天然唯一

✅ **Outline解析错误** - parseMarkdownOutline函数正确
- 代码位置: `web/milkdown/src/main.js:221-258`
- 正确识别ATX风格标题: `/^(#{1,6})\s+(.+?)(?:\s+#+\s*)?$/`
- 正确跳过代码块内的标题

### 待确认的问题场景

需要实际测试以下场景来定位问题:

#### 场景1: 连续标题无空行
```markdown
# 标题一
## 标题二
### 标题三
```

#### 场景2: 标题后紧跟代码块
```markdown
# 标题
```code
```

#### 场景3: 标题间特殊字符
```markdown
# 标题一
---
## 标题二
```

---

## 修复方案

### 方案A: 添加防御性检查 (推荐立即实施)

在`web/milkdown/src/main.js`中增强heading处理逻辑:

**修改位置**: 第1435-1472行

**修改内容**:

```javascript
const headingOutline = parseMarkdownOutline(currentMarkdown);
const consumedOutlineIndexes = new Set();
const headingIdMap = new Map(); // 新增: 跟踪已使用的heading ID

root.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((heading, index) => {
  const headingText = (heading.textContent || '').trim();
  const headingLevel = Number.parseInt((heading.tagName || '').replace(/^H/i, ''), 10);
  
  // 验证headingLevel有效性
  if (!Number.isFinite(headingLevel) || headingLevel < 1 || headingLevel > 6) {
    console.warn('[Milkdown] Invalid heading level detected:', headingLevel, heading);
    return; // 跳过无效heading
  }
  
  let outlineIndex = index;
  let outlineNode = headingOutline[outlineIndex];
  const outlineMatchesHeading = outlineNode
    && outlineNode.text === headingText
    && outlineNode.level === headingLevel;

  if (!outlineMatchesHeading || consumedOutlineIndexes.has(outlineIndex)) {
    outlineIndex = headingOutline.findIndex((candidate, candidateIndex) => (
      !consumedOutlineIndexes.has(candidateIndex)
      && candidate.level === headingLevel
      && candidate.text === headingText
    ));
    if (outlineIndex < 0) {
      outlineIndex = headingOutline.findIndex((_, candidateIndex) => !consumedOutlineIndexes.has(candidateIndex));
    }
    outlineNode = outlineIndex >= 0 ? headingOutline[outlineIndex] : null;
  }

  if (outlineIndex >= 0) {
    consumedOutlineIndexes.add(outlineIndex);
  }

  const text = (outlineNode?.text || headingText).trim();
  const previousLineNumber = Number.parseInt(heading.dataset.headingLine || '', 10);
  let lineNumber = Number.isFinite(outlineNode?.lineNumber)
    ? outlineNode.lineNumber
    : Number.isFinite(previousLineNumber)
      ? previousLineNumber
      : index;
  
  // 新增: 确保heading ID唯一性
  let baseId = `heading-line-${lineNumber}`;
  let finalId = baseId;
  let counter = 1;
  
  while (headingIdMap.has(finalId)) {
    finalId = `${baseId}-${counter}`;
    counter++;
  }
  
  heading.id = finalId;
  heading.dataset.headingLine = String(lineNumber);
  heading.dataset.headingSlug = slugifyHeading(text);
  
  headingIdMap.set(finalId, {
    index,
    text,
    level: headingLevel,
    lineNumber,
  });
  
  // 新增: 调试日志(生产环境可移除)
  if (process.env.NODE_ENV === 'development') {
    console.log('[Heading]', {
      id: finalId,
      text,
      level: headingLevel,
      lineNumber,
      outlineIndex,
    });
  }
});
```

**优点**:
- 防御性检查确保heading ID绝对唯一
- 添加调试日志便于追踪问题
- 不影响现有功能

**风险**: 低

---

### 方案B: 增强parseMarkdownOutline函数

**修改位置**: `web/milkdown/src/main.js:221-258`

**修改内容**:

```javascript
const parseMarkdownOutline = (markdown) => {
  const lines = (typeof markdown === 'string' ? markdown : '').split('\n');
  const outline = [];
  let activeFence = null;
  let inBlockquote = false; // 新增: 追踪引用块
  let inList = false; // 新增: 追踪列表

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index] || '';
    const trimmed = line.trim();

    // 处理代码块
    const fenceMatch = trimmed.match(/^(`{3,}|~{3,})/);
    if (fenceMatch) {
      const marker = fenceMatch[1] || '';
      const markerChar = marker[0] || '';
      const markerLength = marker.length;
      if (!activeFence) {
        activeFence = { markerChar, markerLength };
        continue;
      }
      if (activeFence.markerChar === markerChar && markerLength >= activeFence.markerLength) {
        activeFence = null;
      }
      continue;
    }

    if (activeFence) continue;

    // 新增: 跟踪引用块和列表
    if (trimmed.startsWith('>')) {
      inBlockquote = true;
    } else if (trimmed === '' || !trimmed.startsWith('>')) {
      inBlockquote = false;
    }

    if (/^[-*+]\s/.test(trimmed) || /^\d+\.\s/.test(trimmed)) {
      inList = true;
    } else if (trimmed === '') {
      inList = false;
    }

    // 新增: 不在引用块和列表中才识别标题
    if (inBlockquote || inList) continue;

    // 匹配ATX标题
    const atxMatch = trimmed.match(/^(#{1,6})\s+(.+?)(?:\s+#+\s*)?$/);
    if (!atxMatch) continue;
    
    const headingText = atxMatch[2].trim();
    
    // 新增: 验证标题文本有效性
    if (!headingText || headingText.length === 0) {
      continue;
    }
    
    outline.push({
      id: `line-${index}`,
      lineNumber: index,
      level: atxMatch[1].length,
      text: headingText,
    });
  }

  return outline;
};
```

**优点**:
- 增强边界情况处理
- 避免在引用块和列表中误识别标题
- 验证标题文本有效性

**风险**: 中等(需要充分测试)

---

### 方案C: 升级Milkdown到最新版本

**当前版本**: 7.19.1

**升级步骤**:

```bash
cd web/milkdown

# 检查最新版本
npm outdated @milkdown/core @milkdown/preset-commonmark

# 升级所有Milkdown包
npm install @milkdown/core@latest \
  @milkdown/crepe@latest \
  @milkdown/plugin-automd@latest \
  @milkdown/plugin-clipboard@latest \
  @milkdown/plugin-cursor@latest \
  @milkdown/plugin-emoji@latest \
  @milkdown/plugin-highlight@latest \
  @milkdown/plugin-history@latest \
  @milkdown/plugin-indent@latest \
  @milkdown/plugin-listener@latest \
  @milkdown/plugin-math@latest \
  @milkdown/plugin-trailing@latest \
  @milkdown/plugin-upload@latest \
  @milkdown/preset-commonmark@latest \
  @milkdown/preset-gfm@latest \
  @milkdown/theme-nord@latest \
  @milkdown/utils@latest

# 重新构建
npm run build

# 同步到Flutter assets
copy /Y dist\index.html ..\..\assets\milkdown_web\index.html
```

**检查变更**:
- 查看Milkdown CHANGELOG中的heading相关修复
- 测试新版本的兼容性
- 验证所有功能正常

**优点**:
- 可能包含官方修复
- 获得最新功能和安全更新

**风险**: 高(需要完整回归测试)

---

## 测试验证计划

### 测试文档

使用项目根目录的 `test_heading_parse.md` 文件进行测试。

### 测试步骤

1. **启动应用**:
```bash
flutter run
```

2. **打开测试文件**:
   - 在应用中打开 `test_heading_parse.md`

3. **验证项目**:
   - [ ] 所有标题正确渲染
   - [ ] 目录(TOC)显示所有标题
   - [ ] 点击目录项可跳转到正确位置
   - [ ] 编辑标题时无渲染错误
   - [ ] 相同文本的标题有不同ID
   - [ ] 标题间的内容正确显示

4. **开发者工具检查**:
```javascript
// 在Chrome DevTools Console中执行
document.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(h => {
  console.log(h.tagName, h.id, h.textContent);
});
```

预期输出: 每个heading都有唯一的ID,格式为 `heading-line-{数字}`

5. **ProseMirror状态检查**:
```javascript
// 获取编辑器状态
const editorState = crepeInstance?.ctx?.get(editorViewCtx)?.state;
editorState?.doc?.content?.forEach((node, offset) => {
  if (node.type.name === 'heading') {
    console.log('Heading:', {
      level: node.attrs.level,
      text: node.textContent.substring(0, 50),
      offset,
    });
  }
});
```

---

## 实施建议

### 立即执行 (优先级: 高)

1. **实施方案A** - 添加防御性检查
   - 风险低,收益明确
   - 可立即合并到主分支
   - 提供调试信息便于定位问题

2. **创建测试用例**
   - 使用 `test_heading_parse.md`
   - 在多个设备上测试
   - 记录问题场景

### 短期执行 (1-2周)

3. **收集用户反馈**
   - 发布测试版本
   - 收集具体问题场景
   - 记录复现步骤

4. **实施方案B** - 增强解析器
   - 充分测试后再合并
   - 重点关注边界情况

### 长期规划 (1-2月)

5. **评估方案C** - 升级Milkdown
   - 创建单独分支测试
   - 完整回归测试
   - 验证所有功能

---

## 已知限制

1. **Setext风格标题**: 当前代码主要支持ATX风格(#前缀),Setext风格(下划线)支持有限
2. **复杂嵌套**: 极深层级的标题嵌套可能有性能问题
3. **大文档**: 超大markdown文件(>10MB)可能需要优化

---

## 相关资源

- **Milkdown GitHub**: https://github.com/Milkdown/milkdown
- **Milkdown Docs**: https://milkdown.dev/
- **PR #1580**: https://github.com/Milkdown/milkdown/pull/1580 (heading ID去重)
- **Issue #1798**: https://github.com/Milkdown/milkdown/issues/1798 (CommonMark兼容)
- **Issue #1553**: https://github.com/Milkdown/milkdown/issues/1553 (标题编辑问题)

---

## 变更历史

- 2026-04-07: 创建文档,分析问题根因,提供修复方案
- 待更新: 实施后的测试结果和用户反馈
