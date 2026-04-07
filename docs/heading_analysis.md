# 标题解析问题深度分析

## 问题现象

根据 V1.4.3 release notes:
> 文档内容中有2个以上的有效标题语法时(井号+空格),那么在他们之间的内容可能会解析错误。

## 代码审查发现

### ✅ 已实现的正确机制

**文件**: `web/milkdown/src/main.js`

**第1435-1472行 - heading ID生成逻辑**:
```javascript
const headingOutline = parseMarkdownOutline(currentMarkdown);
const consumedOutlineIndexes = new Set();

root.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((heading, index) => {
  const headingText = (heading.textContent || '').trim();
  const headingLevel = Number.parseInt((heading.tagName || '').replace(/^H/i, ''), 10);
  
  // 智能匹配:优先匹配相同文本和级别的未使用标题
  if (!outlineMatchesHeading || consumedOutlineIndexes.has(outlineIndex)) {
    outlineIndex = headingOutline.findIndex((candidate, candidateIndex) => (
      !consumedOutlineIndexes.has(candidateIndex)
      && candidate.level === headingLevel
      && candidate.text === headingText
    ));
  }
  
  // 使用行号确保唯一性
  heading.id = `heading-line-${lineNumber}`;
  heading.dataset.headingLine = String(lineNumber);
  heading.dataset.headingSlug = slugifyHeading(text);
  
  // 标记为已使用
  if (outlineIndex >= 0) {
    consumedOutlineIndexes.add(outlineIndex);
  }
});
```

**第221-258行 - parseMarkdownOutline函数**:
```javascript
const parseMarkdownOutline = (markdown) => {
  const lines = (typeof markdown === 'string' ? markdown : '').split('\n');
  const outline = [];
  let activeFence = null;

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index] || '';
    const trimmed = line.trim();

    // 跳过代码块
    const fenceMatch = trimmed.match(/^(`{3,}|~{3,})/);
    if (fenceMatch) {
      // ... fence处理逻辑
      continue;
    }

    if (activeFence) continue;

    // 匹配ATX风格标题
    const atxMatch = trimmed.match(/^(#{1,6})\s+(.+?)(?:\s+#+\s*)?$/);
    if (!atxMatch) continue;
    
    outline.push({
      id: `line-${index}`,
      lineNumber: index,
      level: atxMatch[1].length,
      text: atxMatch[2].trim(),
    });
  }

  return outline;
};
```

### ✅ 正则表达式正确性

**ATX标题匹配**:
```javascript
/^(#{1,6})\s+(.+?)(?:\s+#+\s*)?$/
```

- `^(#{1,6})` - 行首1-6个#
- `\s+` - 至少一个空格
- `(.+?)` - 标题文本(非贪婪)
- `(?:\s+#+\s*)?$` - 可选的尾部#号

**测试用例**:
```markdown
# 标题一        ✅ 匹配: level=1, text="标题一"
## 标题二       ✅ 匹配: level=2, text="标题二"  
###标题三       ❌ 不匹配(缺少空格)
####    标题四   ✅ 匹配(多个空格也OK)
```

## 问题根源推断

既然ID生成和outline解析都正确,问题可能在于:

### 1. Milkdown内部解析器问题

**Milkdown版本**: 7.19.1 (2024年版本)

**可能的问题点**:
- preset-commonmark的解析器在处理多个标题时的状态管理
- ProseMirror文档模型在多个heading节点间的转换
- 输入规则(input rule)在识别标题语法时的边界情况

**相关Issue**:
- Milkdown #1798: CommonMark标准下输入标题的问题
- Milkdown #1553: Backspace键在二级及以上标题的异常行为

### 2. 边界情况

可能的触发场景:

#### 场景A: 连续标题无内容
```markdown
# 标题一
## 标题二
### 标题三
```
- 可能在标题间缺少内容块导致解析器状态混乱

#### 场景B: 标题后紧跟特殊块
```markdown
# 标题一
```code
```
## 标题二
```
- 代码块、表格、引用等特殊块可能影响标题边界识别

#### 场景C: 混合标题语法
```markdown
# 标题一
标题二
=======
### 标题三
```
- ATX(#前缀)和Setext(下划线)风格混合可能导致解析不一致

### 3. Flutter-Dart通信问题

**可能的问题**:
- WebView与Flutter之间的markdown同步延迟
- 内容更新时的事件顺序问题
- 大文档的分块处理问题

## 建议的调试步骤

### 第一步: 复现问题
创建测试文档验证问题:
```markdown
# 第一个标题

第一个标题下的内容。

## 第二个标题

第二个标题下的内容。

### 第三个标题

这是第三个标题下的内容。

中间有一些普通文本。

#### 第四个标题

这是第四个标题下的内容。
```

### 第二步: 检查Milkdown版本
```bash
cd web/milkdown
npm list @milkdown/core @milkdown/preset-commonmark
```

### 第三步: 查看Milkdown更新日志
检查7.19.1之后的版本是否修复了标题相关bug:
- https://github.com/Milkdown/milkdown/releases
- 搜索"heading", "title", "parser"关键词

### 第四步: 启用调试日志
在`main.js`中添加日志:
```javascript
root.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((heading, index) => {
  console.log('[Heading]', {
    index,
    text: heading.textContent,
    id: heading.id,
    lineNumber: heading.dataset.headingLine,
    slug: heading.dataset.headingSlug,
  });
});
```

### 第五步: 检查ProseMirror状态
在Milkdown编辑器中检查文档结构:
```javascript
// 在控制台执行
editorInstance?.ctx?.get(editorViewCtx)?.state?.doc?.content?.forEach((node, offset) => {
  if (node.type.name === 'heading') {
    console.log('Heading node:', {
      level: node.attrs.level,
      text: node.textContent,
      offset,
    });
  }
});
```

## 临时缓解方案

### 方案A: 确保标题间有内容
建议用户在标题之间至少添加一个段落:

```markdown
# 标题一

至少一个空行或内容。

## 标题二
```

### 方案B: 统一使用ATX风格
避免混合使用Setext风格的标题:

❌ 不要使用:
```markdown
标题
====
```

✅ 使用:
```markdown
# 标题
```

### 方案C: 添加显式分隔
在可疑位置添加HTML注释:
```markdown
# 标题一

<!-- break -->

## 标题二
```

## 后续行动

1. **升级Milkdown**: 检查最新版本(可能7.5.x或更高)是否修复
2. **报告Bug**: 如果在新版本仍存在,向Milkdown提交Issue
3. **添加测试**: 创建自动化测试用例验证多标题场景
4. **监控日志**: 收集用户报告的具体场景和错误信息
