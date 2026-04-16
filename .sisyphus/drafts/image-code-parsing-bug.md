# Draft: Image/Code Block Parsing Bug Fix

## Requirements (confirmed)
- **Core Issue**: Images show broken and code block language identifiers fail to parse when surrounded by headings or links
- **Trigger Condition**: Image/code block must have BOTH above AND below content that uses heading or link syntax
- **Minimum Reproduction**: 
  ```markdown
  # qaa.md
  
  ![1.00](images/JPEG_20260416_225916_5684911853037735770.jpg)
  
  [链接文本](https://example.com)
  ```
- **Expected Behavior**: Images and code blocks should ALWAYS parse correctly regardless of surrounding context

## Technical Decisions
- Technology stack: Flutter + WebView hybrid app using Milkdown v7.19.1 (Crepe editor)
- Parsing pipeline: Markdown → Remark AST → ParserState → ProseMirror document

## Research Findings

### Architecture
1. **Flutter WebView Host**: `lib/widgets/milkdown_webview_editor.dart`
2. **Web Editor Entry**: `web/milkdown/src/main.js` - Initializes Crepe editor
3. **Parsing Flow**:
   - `setMarkdown()` applies pre-processing: `neutralizeSetextHeadingSyntax()` + `stripGhostCodeLanguageMarkers()`
   - Markdown → Remark AST → Milkdown ParserState → ProseMirror document

### Key Files Identified
1. **Image Parsing**: 
   - `milkdown/packages/plugins/preset-commonmark/src/node/image.ts` - Inline image schema
   - `milkdown/packages/components/src/image-block/schema.ts` - Block image schema (priority 100)
   - `milkdown/packages/components/src/image-block/remark-plugin.ts` - Transforms paragraph+image → image-block

2. **Code Block Parsing**:
   - `milkdown/packages/plugins/preset-commonmark/src/node/code-block.ts` - Code block schema

3. **Link Parsing**:
   - `milkdown/packages/plugins/preset-commonmark/src/mark/link.ts` - Link mark with openMark/closeMark

4. **Heading Parsing**:
   - `milkdown/packages/plugins/preset-commonmark/src/node/heading.ts` - Heading node

5. **Parser State**:
   - `milkdown/packages/transformer/src/parser/state.ts` - State machine with `#marks` tracking

6. **Pre-processing**:
   - `web/milkdown/src/main.js:280-320` - `neutralizeSetextHeadingSyntax()`
   - `web/milkdown/src/main.js:413-502` - `stripGhostCodeLanguageMarkers()`

### Potential Bug Locations

1. **remarkImageBlockPlugin** (`image-block/remark-plugin.ts:17-19`):
   ```typescript
   if (node.children?.length !== 1) return
   const firstChild = node.children?.[0]
   if (!firstChild || firstChild.type !== 'image') return
   ```
   - Only transforms paragraphs with EXACTLY 1 child that is an image
   - If AST structure changes when surrounded by headings/links, this could fail

2. **ParserState `#marks` management** (`state.ts:147-158`):
   - Link mark uses `openMark()` and `closeMark()` 
   - If marks aren't properly closed, subsequent parsing could be affected
   - Note: `closeNode()` resets marks to `Mark.none` (line 106)

3. **Pre-processing functions** in `main.js`:
   - `neutralizeSetextHeadingSyntax()` modifies lines with `=` or `-` underlines
   - Could potentially affect adjacent content if not careful

4. **Priority-based matching** (`state.ts:67-79`):
   - `image-block` has priority 100 vs default 50
   - Schema registration order in `composed/schema.ts`

### Test File Exists
- `web/milkdown/test-parsing-bug.html` - Contains test cases for the bug

## Open Questions (ANSWERED)
- ✅ Parsing library: Remark (unified ecosystem) → Milkdown transformer
- ✅ State management: ParserState maintains `#marks` stack
- ✅ Custom plugins: remarkImageBlockPlugin, remarkHtmlTransformer
- ✅ Affects both images AND code blocks: Yes, same trigger condition

## ROOT CAUSE CONFIRMED ✅

### The Bug
In `syncRenderedDom()` (main.js:1491-1737), the code uses **array index matching** between:
1. Data collected from **markdown text order** (`collectMarkdownImageSources`, `collectFenceLanguages`)
2. Elements queried from **DOM order** (`querySelectorAll`)

### Why It Fails
When headings/links are present in the document:
- Remark AST transformations (e.g., `remarkImageBlockPlugin`) may change the DOM node order
- The markdown text order remains unchanged
- **Index mismatch occurs** → wrong `src` for images, wrong `language` for code blocks

### Evidence
```javascript
// Line 1494-1498: Image matching by index
const markdownImageSources = collectMarkdownImageSources(currentMarkdown);
root.querySelectorAll('.ProseMirror img').forEach((img, imageIndex) => {
  const markdownRawSrc = sanitizeImageSource(markdownImageSources[imageIndex] || '');
  //                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  //                                            INDEX MATCHING - WRONG!

// Line 1635, 1672-1675: Code block language matching by index  
const fenceLanguages = collectFenceLanguages(currentMarkdown);
// ...
const currentLanguage = resolveCodeBlockLanguage(
  block,
  ... || fenceLanguages[codeBlockIndex] || '',
  //      ^^^^^^^^^^^^^^^^^^^^^^^^^
  //      INDEX MATCHING - WRONG!
```

### Why "上下文都有标题或链接" Triggers It
- When headings/links surround images/code blocks, remark plugins may transform the AST
- This can reorder nodes in the DOM relative to the markdown text order
- The index-based matching then fails

## Solution Approach
Replace index-based matching with **position-based** or **attribute-based** matching:
1. **For images**: Match by comparing `img.src` with markdown sources, or use DOM position
2. **For code blocks**: Use DOM position to find corresponding markdown fence, or rely on existing `data-language` attribute

## Scope Boundaries
- INCLUDE: Fix index-based matching in `syncRenderedDom()`
- INCLUDE: Implement reliable mapping between markdown data and DOM elements
- INCLUDE: Add unit tests for the fix
- EXCLUDE: Changing markdown syntax
- EXCLUDE: Modifying remark plugins
- EXCLUDE: UI redesign
