// AUTO-GENERATED for equivalence testing from `git show HEAD:web/milkdown/src/main.js`
// (Phase 0 refactor safety net). Do not edit by hand: regenerate from git instead.
import { refractor } from 'refractor';

export const KNOWN_CODE_LANGUAGES = Object.keys(refractor.languages)
  .filter((name) => typeof name === 'string' && /^[a-z0-9_+-]+$/i.test(name))
  .sort((a, b) => a.localeCompare(b));
export const GHOST_CODE_LANGUAGE_MARKER_RE = /^[^\s`~]{1,40}$/;
export const LOCAL_FILE_SCHEME = 'ushio-local-file';
export let currentBaseDirectory = '';
export const setCurrentBaseDirectory = (v) => { currentBaseDirectory = v; };


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

export const isGhostCodeLanguageLine = (line) => {
  return Boolean(extractGhostCodeLanguage(line));
};

export const isFenceLanguageEchoLine = (line, expectedLanguage = '') => {
  const token = (line || '').trim().toLowerCase();
  if (!token || !GHOST_CODE_LANGUAGE_MARKER_RE.test(token)) return false;
  if (KNOWN_CODE_LANGUAGES.includes(token)) return true;
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


export const decodeFileUriPath = (value) => {
  if (typeof value !== 'string' || !value.startsWith('file://')) return '';
  try {
    return decodeURIComponent(new URL(value).pathname || '');
  } catch (_) {
    return value.replace(/^file:\/\//i, '');
  }
};

export const normalizeLocalFsPath = (value) => {
  if (typeof value !== 'string') return '';
  const normalized = value.trim().replace(/\\/g, '/');
  if (!normalized) return '';
  if (/^\/[A-Za-z]:\//.test(normalized)) {
    return normalized.slice(1);
  }
  return normalized;
};

export const normalizeBaseDirectoryPath = (baseDirectory) => {
  if (typeof baseDirectory !== 'string' || !baseDirectory.trim()) return '';
  const trimmed = baseDirectory.trim();
  if (trimmed.startsWith('file://')) {
    return normalizeLocalFsPath(decodeFileUriPath(trimmed));
  }
  return normalizeLocalFsPath(trimmed);
};

export const toAbsoluteLocalPath = (pathLike) => {
  if (typeof pathLike !== 'string') return '';
  const raw = pathLike.trim();
  if (!raw) return '';
  if (raw.startsWith('file://')) {
    return normalizeLocalFsPath(decodeFileUriPath(raw));
  }
  if (/^[A-Za-z]:[\\/]/.test(raw)) {
    return normalizeLocalFsPath(raw);
  }
  if (raw.startsWith('/')) return raw;
  const base = normalizeBaseDirectoryPath(currentBaseDirectory);
  if (!base) return '';
  const normalizedBase = base.replace(/\/+$/, '');
  const normalizedRaw = raw.replace(/\\/g, '/').replace(/^\.\//, '');
  return `${normalizedBase}/${normalizedRaw}`;
};

export const buildLocalFileProxyUrl = (absolutePath) => {
  if (typeof absolutePath !== 'string' || !absolutePath) return '';
  return `${LOCAL_FILE_SCHEME}://local?path=${encodeURIComponent(absolutePath)}`;
};


export const HTML_BLOCK_TAG_PATTERN = /^\s*<(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)(\s|>|$)/i;
export const HTML_BLOCK_CLOSE_TAG_PATTERN = /^\s*<\/(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)>/i;

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

export const preprocessImageUrlsInMarkdown = (markdown) => {
  if (typeof markdown !== 'string' || !markdown.includes('![')) return markdown;
  if (!currentBaseDirectory) return markdown;

  const lines = markdown.split('\n');
  const result = [];
  let activeFence = null;
  const imagePattern = /(!\[[^\]]*]\()([^)\n]+)(\))/g;

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
      result.push(line);
      continue;
    }
    if (activeFence) {
      result.push(line);
      continue;
    }

    // Replace relative image URLs with custom scheme URLs
    const processedLine = line.replace(imagePattern, (match, prefix, src, suffix) => {
      const trimmedSrc = src.trim();
      // Skip if already a custom scheme URL, external URL, data URI, or absolute path
      if (trimmedSrc.startsWith(LOCAL_FILE_SCHEME + '://')) return match;
      if (trimmedSrc.startsWith('http://') || trimmedSrc.startsWith('https://')) return match;
      if (trimmedSrc.startsWith('data:')) return match;
      if (trimmedSrc.startsWith('blob:')) return match;
      if (trimmedSrc.startsWith('/')) return match;
      if (/^[A-Za-z]:[\\/]/.test(trimmedSrc)) return match;

      // Convert relative path to custom scheme URL
      const absolutePath = toAbsoluteLocalPath(trimmedSrc);
      if (!absolutePath) return match;
      const proxyUrl = buildLocalFileProxyUrl(absolutePath);
      if (!proxyUrl) return match;

      return `${prefix}${proxyUrl}${suffix}`;
    });
    result.push(processedLine);
  }

  return result.join('\n');
};
