/**
 * 纯 markdown 字符串扫描函数。从 main.js 原样外移（Phase 0，行为不变），
 * 不依赖 DOM、不依赖模块可变状态，供 vitest 直接测。
 */

const HTML_BLOCK_TAG_PATTERN = /^\s*<(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)(\s|>|$)/i;
export { HTML_BLOCK_TAG_PATTERN };
export const HTML_BLOCK_CLOSE_TAG_PATTERN = /^\s*<\/(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)>/i;

const GHOST_CODE_LANGUAGE_MARKER_RE = /^[^\s`~]{1,40}$/;

// 由宿主注入（main.js 用 refractor 的语言表；测试用固定表）。
// 保持与搬迁前一致的 Array.includes 语义，Set 化留到后续阶段。
let knownCodeLanguages = [];
export const setKnownCodeLanguages = (names) => {
  knownCodeLanguages = Array.isArray(names) ? names : [];
};

export const slugifyHeading = (input) => {
  if (typeof input !== 'string') return '';
  return input
    .trim()
    .toLowerCase()
    .replace(/^\d+[\.\-_\s]+/u, '')
    .replace(/[^\p{L}\p{N}\s\-]/gu, '')
    .replace(/\s+/gu, '-')
    .replace(/-+/gu, '-')
    .replace(/^-+|-+$/gu, '');
};

export const parseMarkdownOutline = (markdown) => {
  const lines = (typeof markdown === 'string' ? markdown : '').split('\n');
  const outline = [];
  let activeFence = null;

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index] || '';
    const trimmed = line.trim();

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

    const atxMatch = trimmed.match(/^(#{1,6})\s+(.+?)(?:\s+#+\s*)?$/);
    if (atxMatch) {
      outline.push({
        id: `line-${index}`,
        lineNumber: index,
        level: atxMatch[1].length,
        text: atxMatch[2].trim(),
      });
      continue;
    }

    if (trimmed && index + 1 < lines.length) {
      const nextTrimmed = (lines[index + 1] || '').trim();
      if (/^=+$/.test(nextTrimmed) || /^-+$/.test(nextTrimmed)) {
        outline.push({
          id: `line-${index}`,
          lineNumber: index,
          level: /^=+$/.test(nextTrimmed) ? 1 : 2,
          text: trimmed,
        });
        index += 1;
      }
    }
  }

  return outline;
};

export const isFenceLine = (line) => /^\s*(```|~~~)/.test((line || '').trim());

export const extractGhostCodeLanguage = (line) => {
  const token = (line || '').trim();
  const arrowMatch = token.match(/^(.+?)[▾▼▿▽⌄˅∨]$/u);
  if (!arrowMatch) return '';
  const language = (arrowMatch[1] || '').trim();
  if (!language) return '';
  if (!GHOST_CODE_LANGUAGE_MARKER_RE.test(language)) return '';
  return language;
};

export const isFenceLanguageEchoLine = (line, expectedLanguage = '') => {
  const token = (line || '').trim().toLowerCase();
  if (!token || !GHOST_CODE_LANGUAGE_MARKER_RE.test(token)) return false;
  if (knownCodeLanguages.includes(token)) return true;
  return Boolean(expectedLanguage) && token === expectedLanguage;
};

export const extractFenceLanguage = (line) => {
  const trimmed = (line || '').trim();
  const match = trimmed.match(/^(```|~~~)\s*([^\s`~]+)?/);
  if (!match) return '';
  return (match[2] || '').trim().toLowerCase();
};

export const extractFenceLanguageRaw = (line) => {
  const trimmed = (line || '').trim();
  const match = trimmed.match(/^(```|~~~)\s*([^\s`~]+)?/);
  if (!match) return '';
  return (match[2] || '').trim();
};

export const collectFenceLanguages = (markdown) => {
  if (typeof markdown !== 'string' || (!markdown.includes('```') && !markdown.includes('~~~'))) return [];
  const lines = markdown.split('\n');
  const result = [];
  let inFence = false;
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (!isFenceLine(line)) continue;
    if (!inFence) {
      result.push(extractFenceLanguageRaw(line));
    }
    inFence = !inFence;
  }
  return result;
};

export const collectMarkdownImageSources = (markdown) => {
  if (typeof markdown !== 'string' || !markdown.includes('![')) return [];
  const lines = markdown.split('\n');
  const result = [];
  let activeFence = null;
  const imagePattern = /!\[[^\]]*]\(([^)\n]+)\)/g;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i] || '';
    const trimmed = line.trim();
    const fenceMatch = trimmed.match(/^(`{3,}|~{3,})/);
    if (fenceMatch) {
      const marker = fenceMatch[1] || '';
      const markerChar = marker[0] || '';
      const markerLength = marker.length;
      if (!activeFence) {
        activeFence = { markerChar, markerLength };
      } else if (activeFence.markerChar === markerChar && markerLength >= activeFence.markerLength) {
        activeFence = null;
      }
      continue;
    }
    if (activeFence) continue;

    imagePattern.lastIndex = 0;
    let match = imagePattern.exec(line);
    while (match) {
      const rawSrc = (match[1] || '').trim();
      if (rawSrc) {
        result.push(rawSrc);
      }
      match = imagePattern.exec(line);
    }
  }

  return result;
};

export const stripGhostCodeLanguageMarkers = (markdown) => {
  if (typeof markdown !== 'string') return markdown;
  if (!markdown.includes('```') && !markdown.includes('~~~')) return markdown;
  const lines = markdown.split('\n');
  const output = [];
  let inFence = false;
  let currentFenceLanguage = '';
  let currentFenceOutputIndex = -1;
  let changed = false;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];

    if (isFenceLine(line)) {
      const wasInFence = inFence;
      inFence = !inFence;
      if (!wasInFence && inFence) {
        currentFenceLanguage = extractFenceLanguage(line);
        currentFenceOutputIndex = output.length;
      }
      output.push(line);

      if (wasInFence && !inFence) {
        let j = i + 1;
        let sawGhost = false;
        let sawBlank = false;
        let detectedGhostLanguage = '';
        while (j < lines.length) {
          const next = (lines[j] || '').trim();
          if (!next) {
            sawBlank = true;
            j += 1;
            continue;
          }
          const ghostLanguage = extractGhostCodeLanguage(next);
          if (ghostLanguage) {
            sawGhost = true;
            if (!detectedGhostLanguage) {
              detectedGhostLanguage = ghostLanguage;
            }
            j += 1;
            continue;
          }
          if (isFenceLanguageEchoLine(next, currentFenceLanguage)) {
            sawGhost = true;
            if (!detectedGhostLanguage) {
              detectedGhostLanguage = next;
            }
            j += 1;
            continue;
          }
          break;
        }

        if (sawGhost) {
          changed = true;
          const normalizedGhostLanguage = (detectedGhostLanguage || '').trim();
          if (
            !currentFenceLanguage
            && normalizedGhostLanguage
            && currentFenceOutputIndex >= 0
            && currentFenceOutputIndex < output.length
          ) {
            const openingFenceLine = output[currentFenceOutputIndex] || '';
            const patchedOpeningFenceLine = openingFenceLine.replace(
              /^(\s*)(```|~~~)(.*)$/u,
              (full, leading, marker, suffix) => {
                if ((suffix || '').trim()) return full;
                return `${leading}${marker} ${normalizedGhostLanguage}`;
              },
            );
            if (patchedOpeningFenceLine !== openingFenceLine) {
              output[currentFenceOutputIndex] = patchedOpeningFenceLine;
            }
          }
          if (sawBlank && output[output.length - 1] !== '') {
            output.push('');
          }
          i = j - 1;
        }
        currentFenceOutputIndex = -1;
      }
      continue;
    }

    output.push(line);
  }

  return changed ? output.join('\n') : markdown;
};

/**
 * 找出「可以安全切开、让后半段独立解析」的偏移，供追加式渲染使用。
 *
 * 规则刻意保守：
 * 1. 只在代码围栏之外的空行之后切；
 * 2. 切点后的第一行不能是列表项——CommonMark 里 `- a\n\n- b` 是**同一个**松散列表，
 *    切成两片会变成两个列表（编号与 loose/tight 都可能变）。
 *
 * 返回 [] 表示找不到足够的切点，调用方应回退到整篇 replaceAll。
 */
/**
 * 找出「可以安全切开、让后半段独立解析」的偏移，供追加式渲染使用。
 *
 * 规则刻意保守，因为分片解析必须与整篇一次解析逐字节一致
 * （判据见 tools/append-oracle.html，实测过：只要切点紧邻列表/引用/表格，
 *  松散列表的 spread 判定就会依赖后随块，序列化回来会多或少空行）。
 *
 * 1. 只在代码围栏之外切；
 * 2. 只在空行之后切（块边界）；
 * 3. 切点**前一个块**与**后一个块**都必须是简单块（标题或段落）——
 *    列表项、引用、表格行、缩进代码一律不切。
 *
 * 返回 [] 表示找不到足够的切点，调用方应回退到整篇替换。
 */
// 列表项 / 引用 / 表格行 / 缩进代码 / setext 下划线 / 分割线，以及代码围栏本身：
// 判据实测过，紧邻这些块的切点都会让「分片解析 + 追加」的产物与整篇解析不一致
// （列表 spread 判定、围栏后多余空行）。
const APPEND_UNSAFE_BLOCK_RE = /^\s*(?:[-*+]|\d+[.)])\s|^\s*>|^\s*\||^\s{4,}|^\s*(?:={3,}|-{3,})\s*$|^\s*(?:```|~~~)/;

export const findAppendSplitPoints = (markdown, minChunkChars = 24 * 1024) => {
  if (typeof markdown !== 'string' || !markdown.length) return [];
  const total = markdown.length;
  if (total < minChunkChars * 2) return [];

  const cuts = [];
  let offset = 0;
  let lastCut = 0;
  let fence = null;
  let candidateOffset = -1;
  let candidatePrevBlockLine = '';
  let blockStartLine = '';
  let atBlockStart = true;

  while (offset < total) {
    const nl = markdown.indexOf('\n', offset);
    const lineEnd = nl < 0 ? total : nl;
    const nextOffset = nl < 0 ? total : nl + 1;
    const line = markdown.slice(offset, lineEnd);
    const trimmed = line.trim();

    const fenceMatch = trimmed.match(/^(`{3,}|~{3,})/);
    if (fenceMatch) {
      // 围栏行本身就是一个块的起始行，必须记下来：否则「前一个块是代码围栏」
      // 的判断会落空，切点就会紧贴围栏，而那样切出来的产物与整篇解析不一致。
      if (atBlockStart) blockStartLine = line;
      const marker = fenceMatch[1];
      const markerChar = marker[0];
      const markerLength = marker.length;
      if (!fence) fence = { markerChar, markerLength };
      else if (fence.markerChar === markerChar && markerLength >= fence.markerLength) fence = null;
      candidateOffset = -1;
      atBlockStart = false;
    } else if (!fence) {
      if (trimmed === '') {
        if (candidateOffset < 0) {
          candidateOffset = nextOffset;
          candidatePrevBlockLine = blockStartLine;
        }
        atBlockStart = true;
      } else {
        if (candidateOffset > 0 && candidateOffset - lastCut >= minChunkChars) {
          const prevSafe = !APPEND_UNSAFE_BLOCK_RE.test(candidatePrevBlockLine);
          const nextSafe = !APPEND_UNSAFE_BLOCK_RE.test(line);
          if (prevSafe && nextSafe) {
            cuts.push(candidateOffset);
            lastCut = candidateOffset;
          }
        }
        blockStartLine = atBlockStart ? line : (blockStartLine || line);
        candidateOffset = -1;
        atBlockStart = false;
      }
    }

    offset = nextOffset;
  }

  return cuts;
};

/**
 * Wrap top-level HTML blocks into ```html-block code fences so the markdown
 * parser keeps them verbatim, while enabling DOM post-processing to render
 * them as real HTML.
 */
export const wrapHtmlBlocksInCodeFence = (markdown) => {
  if (typeof markdown !== 'string' || !/<[a-z]/i.test(markdown)) return markdown;
  const lines = markdown.split('\n');
  const result = [];
  let activeFence = null;
  let inHtmlBlock = false;
  let htmlDepth = 0;
  let htmlBuffer = [];
  let lastContentLineIdx = -1;

  const flushHtmlBlock = () => {
    if (!inHtmlBlock || htmlBuffer.length === 0) {
      inHtmlBlock = false;
      htmlDepth = 0;
      htmlBuffer = [];
      return;
    }
    // Remove trailing blank lines from the buffer
    while (htmlBuffer.length > 0 && htmlBuffer[htmlBuffer.length - 1].trim() === '') {
      htmlBuffer.pop();
    }
    if (htmlBuffer.length === 0) {
      inHtmlBlock = false;
      htmlDepth = 0;
      return;
    }
    // Check if this is a single self-contained HTML snippet (e.g., <hr>, <br>, single-line element)
    const joined = htmlBuffer.join('\n');
    const trimmedJoined = joined.trim();
    // Only wrap if there's meaningful block-level HTML content
    if (!/<(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)/i.test(trimmedJoined)) {
      htmlBuffer.forEach((line) => result.push(line));
    } else {
      result.push('```html-block');
      htmlBuffer.forEach((line) => result.push(line));
      result.push('```');
    }
    inHtmlBlock = false;
    htmlDepth = 0;
    htmlBuffer = [];
  };

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i] || '';
    const trimmed = line.trim();

    // Track existing code fences — don't process HTML inside them
    const fenceMatch = trimmed.match(/^(`{3,}|~{3,})/);
    if (fenceMatch) {
      if (inHtmlBlock) flushHtmlBlock();
      const marker = fenceMatch[1] || '';
      const markerChar = marker[0] || '';
      const markerLength = marker.length;
      if (!activeFence) {
        activeFence = { markerChar, markerLength };
      } else if (activeFence.markerChar === markerChar && markerLength >= activeFence.markerLength) {
        activeFence = null;
      }
      result.push(line);
      continue;
    }
    if (activeFence) {
      result.push(line);
      continue;
    }

    if (!inHtmlBlock) {
      // Check if this line starts a block-level HTML element
      if (HTML_BLOCK_TAG_PATTERN.test(trimmed)) {
        // Skip if already inside an html-block code fence (idempotent guard)
        if (i > 0 && result.length > 0 && result[result.length - 1].trim() === '```html-block') {
          result.push(line);
          continue;
        }
        inHtmlBlock = true;
        htmlBuffer = [line];
        lastContentLineIdx = i;
        // Calculate depth from actual tags on this line (openTags includes the opening tag)
        const openTags = (trimmed.match(/<(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)(\s|>|$)/gi) || []).length;
        const closeTags = (trimmed.match(/<\/(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)>/gi) || []).length;
        htmlDepth = openTags - closeTags;
        if (htmlDepth <= 0 && closeTags > 0) {
          flushHtmlBlock();
        }
      } else {
        result.push(line);
      }
    } else {
      // We're inside an HTML block — track nesting depth
      const openTags = (trimmed.match(/<(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)(\s|>|$)/gi) || []).length;
      const closeTags = (trimmed.match(/<\/(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)>/gi) || []).length;
      htmlDepth += openTags - closeTags;
      htmlBuffer.push(line);
      if (trimmed !== '') lastContentLineIdx = i;

      if (htmlDepth <= 0) {
        flushHtmlBlock();
      } else if (trimmed === '' && i > lastContentLineIdx + 1) {
        // Two consecutive blank lines terminate the HTML block
        flushHtmlBlock();
      }
    }
  }
  // Flush any remaining HTML block at end of document
  if (inHtmlBlock) flushHtmlBlock();
  return result.join('\n');
};
