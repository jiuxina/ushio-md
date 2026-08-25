import {
  commandsCtx,
  editorViewCtx,
} from '@milkdown/core';
import { Crepe } from '@milkdown/crepe';
import { automd } from '@milkdown/plugin-automd';
import { clipboard } from '@milkdown/plugin-clipboard';
import { cursor } from '@milkdown/plugin-cursor';
import { emoji } from '@milkdown/plugin-emoji';
import { highlight, highlightPluginConfig } from '@milkdown/plugin-highlight';
import { listener, listenerCtx } from '@milkdown/plugin-listener';
import { history, redoCommand, undoCommand } from '@milkdown/plugin-history';
import { redoDepth, undoDepth } from '@milkdown/prose/history';
import { indent } from '@milkdown/plugin-indent';
import { math } from '@milkdown/plugin-math';
import { trailing } from '@milkdown/plugin-trailing';
import { upload, uploadConfig } from '@milkdown/plugin-upload';
import {
  insertHrCommand,
  createCodeBlockCommand,
  insertImageCommand,
  toggleInlineCodeCommand,
  toggleLinkCommand,
  wrapInBlockquoteCommand,
  wrapInBulletListCommand,
  wrapInHeadingCommand,
  wrapInOrderedListCommand,
  toggleEmphasisCommand,
  toggleStrongCommand,
} from '@milkdown/preset-commonmark';
import { insertTableCommand } from '@milkdown/preset-gfm';
import {
  addColAfterCommand,
  addColBeforeCommand,
  addRowAfterCommand,
  addRowBeforeCommand,
  deleteSelectedCellsCommand,
  goToNextTableCellCommand,
  goToPrevTableCellCommand,
  toggleStrikethroughCommand,
} from '@milkdown/preset-gfm';
import { deleteColumn, deleteRow, isInTable } from '@milkdown/prose/tables';
import { createParser as createRefractorParser } from 'prosemirror-highlight/refractor';
import { refractor } from 'refractor/all';
import { nord } from '@milkdown/theme-nord';
import { replaceAll } from '@milkdown/utils';
// CodeMirror themes for code block syntax highlighting
import { oneDark } from '@codemirror/theme-one-dark';
import { githubDark, githubLight } from '@uiw/codemirror-theme-github';
import { nord as nordTheme } from '@uiw/codemirror-theme-nord';
import { material } from '@uiw/codemirror-theme-material';
import '@milkdown/crepe/theme/nord.css';
import 'katex/dist/katex.min.css';
import 'prismjs/themes/prism.css';
import './style.css';

const app = document.getElementById('app');
let bridgeSeq = 0;
let editorInstance = null;
let crepeInstance = null;
let currentMarkdown = '';
let currentBaseDirectory = '';
// NOTE: currentReadOnly is only true for offscreen screenshot-rendering instances
// (see file_actions.dart _shareAsImageDirectly). Users never see a read-only UI.
// The main editor always uses readOnly=false. Do NOT file UX bugs about "read-only mode".
let currentReadOnly = true;
let isApplyingFromFlutter = false;
let initializingEditor = false;
let initializingEditorTimer = null;
let editorUserInputListenerAttached = false;
let createEditorPromise = null;
let contextMenuElement = null;
let tableFloatingButtonElement = null;
let tableFloatingPanelElement = null;
let mobileLongPressTimer = null;
let mobileLongPressStartPoint = null;
const pendingUploadResolvers = new Map();
const cmdFailureAggregate = new Map();
const MAX_UPLOAD_FILES = 6;
const MAX_UPLOAD_FILE_BYTES = 8 * 1024 * 1024;
const MAX_UPLOAD_TOTAL_BYTES = 20 * 1024 * 1024;

// Code block theme state
// Theme IDs: auto, oneDark, oneLight, githubDark, githubLight, nord, material
let currentCodeBlockTheme = 'auto';
let currentThemeMode = 'light';

// CodeMirror theme mapping
const CODE_BLOCK_THEMES = {
  oneDark: oneDark,
  githubDark: githubDark,
  githubLight: githubLight,
  nord: nordTheme,
  material: material,
};

// Get the effective CodeMirror theme based on current settings
const getEffectiveCodeBlockTheme = () => {
  const themeId = currentCodeBlockTheme;
  if (themeId === 'auto') {
    // Follow app theme mode
    return currentThemeMode === 'dark' ? CODE_BLOCK_THEMES.oneDark : null;
  }
  if (themeId === 'oneLight') {
    // oneLight is not available as a separate package, use default (null) for light
    return null;
  }
  return CODE_BLOCK_THEMES[themeId] || null;
};
// Adaptive debounce: larger files get longer debounce to reduce save frequency
// Small (< 10KB): 80ms, Medium (10-50KB): 150ms, Large (> 50KB): 300ms
const calculateAdaptiveDebounceMs = (markdownLength) => {
  if (markdownLength < 10000) return 80;
  if (markdownLength < 50000) return 150;
  return 300;
};
let contentChangeTimerId = null;
let pendingContentMarkdown = null;
let pendingContentMode = 'full';
let uploadFailureCount = 0;
let uploadFailureWindowStart = Date.now();
let searchHighlightRanges = [];
let searchHighlightActiveIndex = -1;

let caretViewportSyncRafId = null;
let suppressNextCaretViewportSync = false;
let checkboxInteractionGuardUntil = 0;
let editorTouchScrollSuppressUntil = 0;
let viewportScrollSuppressUntil = 0;
let lastKeyboardInsetPx = 0;
let lastUserScrollAt = 0;
let lastEditorInteractionAt = 0;
let editorTouchTracking = null;
// IME composition state - prevent viewport sync during composition
let isComposing = false;
// NOTE: Custom code language popup has been removed. Users change code language
// by clicking the language label in the code block toolbar and typing directly.
let codeLanguageUiDebugSeq = 0;
const codeLanguageDisplayCache = new Map();
const highlightParser = createRefractorParser(refractor);
// Register 'html-block' as an alias of 'html' for prosemirror-highlight
// This prevents "Unknown language: html-block" errors
try {
  if (refractor.languages.html) {
    refractor.languages['html-block'] = refractor.languages.html;
  }
} catch (_) { /* ignore */ }
const KNOWN_CODE_LANGUAGES = Object.keys(refractor.languages)
  .filter((name) => typeof name === 'string' && /^[a-z0-9_+-]+$/i.test(name))
  .sort((a, b) => a.localeCompare(b));
const GHOST_CODE_LANGUAGE_MARKER_RE = /^[^\s`~]{1,40}$/;
const LOCAL_FILE_SCHEME = 'ushio-local-file';
const RUNTIME_BUILD_TAG = 'lang-inline-v2-20260324-2114';
window.__USHIO_RUNTIME_TAG = RUNTIME_BUILD_TAG;
const KNOWN_CODE_LANGUAGE_MAP = new Map(
  KNOWN_CODE_LANGUAGES.map((name) => [name.trim().toLowerCase(), name]),
);

const nextRequestId = () => `${Date.now()}-${++bridgeSeq}`;

const postToFlutter = (msg) => {
  if (!window.flutter_inappwebview?.callHandler) {
    return;
  }
  window.flutter_inappwebview.callHandler('bridge', msg).catch((err) => {
    console.warn('bridge call failed', err);
  });
};

const emit = (type, payload = {}) => {
  postToFlutter({
    v: 1,
    source: 'web',
    target: 'flutter',
    type,
    requestId: nextRequestId(),
    ts: Date.now(),
    payload,
  });
};

const emitDebug = (message) => {
  emit('on_debug_log', { message });
};

const recordUploadFailure = (reason) => {
  const now = Date.now();
  if (now - uploadFailureWindowStart > 10 * 60 * 1000) {
    uploadFailureWindowStart = now;
    uploadFailureCount = 0;
  }
  uploadFailureCount += 1;
  emit('on_cmd_failure_aggregate', {
    cmd: 'upload_images',
    reason: reason || 'unknown',
    count: uploadFailureCount,
  });
};

const cssVarMap = {
  primary: '--milkdown-color-primary',
  onPrimary: '--milkdown-color-on-primary',
  secondary: '--milkdown-color-secondary',
  onSecondary: '--milkdown-color-on-secondary',
  surface: '--milkdown-color-surface',
  onSurface: '--milkdown-color-on-surface',
  background: '--milkdown-color-background',
  onBackground: '--milkdown-color-on-background',
  error: '--milkdown-color-error',
  onError: '--milkdown-color-on-error',
  outline: '--milkdown-color-outline',
  shadow: '--milkdown-color-shadow',
};

const applyTheme = (payload) => {
  if (!payload || typeof payload !== 'object') return;
  const root = document.documentElement;

  // Apply colors
  if (payload.colors && typeof payload.colors === 'object') {
    Object.entries(payload.colors).forEach(([k, v]) => {
      const cssVar = cssVarMap[k];
      if (!cssVar || typeof v !== 'string') return;
      root.style.setProperty(cssVar, v);
    });
  }

  // Apply font settings
  const font = payload.font;
  if (font && typeof font === 'object') {
    if (typeof font.body === 'string') {
      root.style.setProperty('--milkdown-font-body', font.body);
    }
    if (typeof font.mono === 'string') {
      root.style.setProperty('--milkdown-font-mono', font.mono);
    }
    if (typeof font.sizePx === 'number') {
      root.style.setProperty('--milkdown-font-size', `${font.sizePx}px`);
    }
    if (typeof font.lineHeight === 'number') {
      root.style.setProperty('--milkdown-line-height', `${font.lineHeight}`);
    }
  }

  // Apply style settings (new)
  const style = payload.style;
  if (style && typeof style === 'object') {
    if (typeof style.borderRadius === 'number') {
      root.style.setProperty('--milkdown-border-radius', `${style.borderRadius}px`);
    }
    if (typeof style.shadowOpacity === 'number') {
      root.style.setProperty('--milkdown-shadow-opacity', style.shadowOpacity);
    }
  }

  // Apply theme mode
  if (payload.mode === 'light' || payload.mode === 'dark') {
    currentThemeMode = payload.mode;
    root.setAttribute('data-theme-mode', payload.mode);
  }

  // Apply code block theme
  if (typeof payload.codeBlockTheme === 'string') {
    const previousTheme = currentCodeBlockTheme;
    currentCodeBlockTheme = payload.codeBlockTheme;
    // If theme changed and editor exists, we need to rebuild with new theme
    if (previousTheme !== currentCodeBlockTheme && editorInstance) {
      // Note: Changing CodeMirror theme requires recreating the editor
      // For now, we store the preference and it will be applied on next editor creation
      // A full implementation would require dynamic theme switching support in Crepe
      emitDebug(`[THEME] Code block theme changed: ${previousTheme} -> ${currentCodeBlockTheme}`);
    }
  }
};

const updateViewportMetrics = () => {
  const root = document.documentElement;
  const vv = window.visualViewport;
  if (!vv) {
    root.style.setProperty('--ushio-viewport-height', `${window.innerHeight}px`);
    root.style.setProperty('--ushio-keyboard-inset', '0px');
    lastKeyboardInsetPx = 0;
    return;
  }
  const viewportHeight = Math.max(0, vv.height);
  const keyboardInset = Math.max(0, window.innerHeight - (vv.height + vv.offsetTop));
  root.style.setProperty('--ushio-viewport-height', `${viewportHeight}px`);
  root.style.setProperty('--ushio-keyboard-inset', `${keyboardInset}px`);
  const keyboardInsetIncreased = keyboardInset > lastKeyboardInsetPx + 2;
  lastKeyboardInsetPx = keyboardInset;
  if (keyboardInset > 0 && keyboardInsetIncreased) {
    // 键盘弹出时，强制执行滚动（不受抑制机制影响）
    forceCaretIntoUpperViewport();
  }
};

const slugifyHeading = (input) => {
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

const parseMarkdownOutline = (markdown) => {
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

const isFenceLine = (line) => /^\s*(```|~~~)/.test((line || '').trim());

const extractGhostCodeLanguage = (line) => {
  const token = (line || '').trim();
  const arrowMatch = token.match(/^(.+?)[▾▼▿▽⌄˅∨]$/u);
  if (!arrowMatch) return '';
  const language = (arrowMatch[1] || '').trim();
  if (!language) return '';
  if (!GHOST_CODE_LANGUAGE_MARKER_RE.test(language)) return '';
  return language;
};

const isGhostCodeLanguageLine = (line) => {
  return Boolean(extractGhostCodeLanguage(line));
};

const isFenceLanguageEchoLine = (line, expectedLanguage = '') => {
  const token = (line || '').trim().toLowerCase();
  if (!token || !GHOST_CODE_LANGUAGE_MARKER_RE.test(token)) return false;
  if (KNOWN_CODE_LANGUAGES.includes(token)) return true;
  return Boolean(expectedLanguage) && token === expectedLanguage;
};

const extractFenceLanguage = (line) => {
  const trimmed = (line || '').trim();
  const match = trimmed.match(/^(```|~~~)\s*([^\s`~]+)?/);
  if (!match) return '';
  return (match[2] || '').trim().toLowerCase();
};

const extractFenceLanguageRaw = (line) => {
  const trimmed = (line || '').trim();
  const match = trimmed.match(/^(```|~~~)\s*([^\s`~]+)?/);
  if (!match) return '';
  return (match[2] || '').trim();
};

const collectFenceLanguages = (markdown) => {
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

const collectMarkdownImageSources = (markdown) => {
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

const stripGhostCodeLanguageMarkers = (markdown) => {
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

const scrollNodeToViewport = (node, topOffset = 32) => {
  if (!(node instanceof Element)) return false;
  const vv = window.visualViewport;
  const viewportHeight = Math.max(1, vv?.height ?? window.innerHeight);
  const offset = Number.isFinite(topOffset) ? Math.max(0, topOffset) : 32;
  const targetTop = Math.max(24, viewportHeight * 0.28 - offset);
  const rect = node.getBoundingClientRect();
  const deltaY = rect.top - targetTop;
  const scroller = document.scrollingElement || document.documentElement || document.body;
  if (scroller && typeof scroller.scrollTo === 'function') {
    const currentTop = scroller.scrollTop ?? window.pageYOffset ?? 0;
    scroller.scrollTo({ top: Math.max(0, currentTop + deltaY), behavior: 'auto' });
  } else {
    window.scrollBy(0, deltaY);
  }
  node.classList.add('heading-flash');
  setTimeout(() => node.classList.remove('heading-flash'), 700);
  return true;
};

const ensureCaretInUpperViewport = ({ allowDuringComposition = false } = {}) => {
  if (currentReadOnly) return;
  // Skip viewport sync during IME composition to prevent janky animations
  if (!allowDuringComposition && isComposing) return;
  if (Date.now() < editorTouchScrollSuppressUntil || Date.now() < viewportScrollSuppressUntil) return;
  if (Date.now() - lastEditorInteractionAt > 1200) return;
  const active = document.activeElement instanceof Element ? document.activeElement : null;
  if (!active?.closest('.ProseMirror')) return;

  const selection = window.getSelection();
  const anchorNode = selection?.anchorNode ?? null;
  const anchorElement = anchorNode instanceof Element ? anchorNode : anchorNode?.parentElement;
  if (anchorElement?.closest('.milkdown-image-block')) return;

  let caretTop = null;
  let selectionIsImage = false;
  editorInstance?.action((ctx) => {
    const view = ctx.get(editorViewCtx);
    const { state } = view;
    const selectedNodeName = state.selection?.node?.type?.name;
    selectionIsImage = selectedNodeName === 'image';
    if (selectionIsImage) return;
    const pos = state.selection?.$from?.pos;
    if (!Number.isFinite(pos)) return;
    try {
      const coords = view.coordsAtPos(pos);
      if (coords && Number.isFinite(coords.top)) {
        caretTop = coords.top;
      }
    } catch (_) {
      caretTop = null;
    }
  });
  if (selectionIsImage) return;

  const vv = window.visualViewport;
  const viewportHeight = Math.max(1, vv?.height ?? window.innerHeight);
  const fallbackRectTop = anchorElement?.getBoundingClientRect?.().top;
  const currentTop = Number.isFinite(caretTop) ? caretTop : fallbackRectTop;
  if (!Number.isFinite(currentTop)) return;

  // 使用类似纯文本编辑器的预测性滚动逻辑
  const fontSize = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--milkdown-font-size')) || 16;
  const lineHeight = fontSize * 1.5; // 与Flutter端保持一致

  // 获取键盘高度和工具栏高度
  const keyboardInset = getKeyboardInset();
  const toolbarHeight = 56.0;

  // 预留输入法遮挡的安全距离
  const imeSafeMargin = 80.0;
  const bottomOffset = keyboardInset + toolbarHeight + imeSafeMargin;

  // 视口可见区域（排除键盘和工具栏遮挡）
  const visibleBottom = viewportHeight - bottomOffset;

  // 顶部安全边距：当光标接近顶部时提前滚动
  const topMargin = 100.0;
  // 底部预测边距：光标距离底部遮挡区域这个距离时就开始滚动
  const predictiveBottomMargin = lineHeight * 2;

  const scroller = document.scrollingElement || document.documentElement || document.body;
  const scrollTop = scroller.scrollTop ?? window.pageYOffset ?? 0;

  // 计算滚动目标位置
  let targetScrollTop = null;

  if (currentTop < topMargin) {
    // 光标接近顶部，向下滚动使光标显示在顶部边距以下
    targetScrollTop = scrollTop - (topMargin - currentTop) - lineHeight;
  } else if (currentTop > visibleBottom - predictiveBottomMargin) {
    // 光标即将进入底部遮挡区域，提前向上滚动
    targetScrollTop = scrollTop + (currentTop - visibleBottom + predictiveBottomMargin) + lineHeight;
  }

  if (targetScrollTop !== null && Math.abs(targetScrollTop - scrollTop) >= 4) {
    const maxScroll = Math.max(0, (scroller.scrollHeight || 0) - viewportHeight);
    const clampedTop = Math.max(0, Math.min(targetScrollTop, maxScroll));
    if (scroller && typeof scroller.scrollTo === 'function') {
      scroller.scrollTo({ top: clampedTop, behavior: 'auto' });
    } else {
      window.scrollBy(0, clampedTop - scrollTop);
    }
  }
};

const scheduleCaretIntoUpperViewport = () => {
  // Skip during IME composition
  if (isComposing) return;
  if (Date.now() < checkboxInteractionGuardUntil) return;
  if (Date.now() < editorTouchScrollSuppressUntil) return;
  if (Date.now() < viewportScrollSuppressUntil) return;
  if (Date.now() - lastUserScrollAt < 600) return;
  if (Date.now() - lastEditorInteractionAt > 1200) return;
  if (caretViewportSyncRafId != null) return;
  caretViewportSyncRafId = requestAnimationFrame(() => {
    caretViewportSyncRafId = null;
    ensureCaretInUpperViewport();
  });
};

// 强制执行光标滚动（绕过抑制机制），用于键盘弹出时
const forceCaretIntoUpperViewport = () => {
  // 重置抑制状态，允许滚动
  editorTouchScrollSuppressUntil = 0;
  viewportScrollSuppressUntil = 0;
  lastUserScrollAt = 0;
  // 直接执行，不使用RAF延迟
  ensureCaretInUpperViewport({ allowDuringComposition: true });
};

const suppressCaretViewportSync = (durationMs = 900) => {
  const until = Date.now() + Math.max(0, durationMs);
  editorTouchScrollSuppressUntil = Math.max(editorTouchScrollSuppressUntil, until);
  viewportScrollSuppressUntil = Math.max(viewportScrollSuppressUntil, until);
};

const guardEditorFocusAfterCheckboxToggle = () => {
  checkboxInteractionGuardUntil = Date.now() + 420;
  const selection = window.getSelection();
  selection?.removeAllRanges();
  blurEditorFocus();
};

const ensureFileBaseUrl = (baseDirectory) => {
  if (typeof baseDirectory !== 'string' || !baseDirectory.trim()) return null;
  if (baseDirectory.startsWith('file://')) {
    return baseDirectory.endsWith('/') ? baseDirectory : `${baseDirectory}/`;
  }
  const normalized = baseDirectory.replace(/\\/g, '/');
  const withLeading = normalized.startsWith('/') ? normalized : `/${normalized}`;
  return `file://${withLeading.endsWith('/') ? withLeading : `${withLeading}/`}`;
};

const applyHorizontalScrollClass = (element) => {
  if (!(element instanceof Element)) return;
  element.classList.add('ushio-horizontal-scroll');
};

const guessPathColumnIndexes = (table) => {
  if (!(table instanceof HTMLTableElement)) return new Set();
  const firstRow = table.querySelector('tr');
  if (!(firstRow instanceof HTMLTableRowElement)) return new Set();
  const cells = Array.from(firstRow.querySelectorAll('th,td'));
  const indexes = new Set();
  cells.forEach((cell, index) => {
    const title = (cell.textContent || '').trim().toLowerCase();
    if (!title) return;
    if (
      title.includes('path')
      || title.includes('file path')
      || title.includes('filepath')
      || title.includes('文件路径')
      || title.includes('路径')
    ) {
      indexes.add(index);
    }
  });
  return indexes;
};

const markTablePathColumns = (table) => {
  if (!(table instanceof HTMLTableElement)) return;
  const pathColumns = guessPathColumnIndexes(table);
  if (!pathColumns.size) return;
  table.querySelectorAll('tr').forEach((row) => {
    const cells = Array.from(row.querySelectorAll('th,td'));
    cells.forEach((cell, index) => {
      if (pathColumns.has(index)) {
        cell.classList.add('ushio-path-column');
      } else {
        cell.classList.remove('ushio-path-column');
      }
    });
  });
};

const lockViewportZoom = () => {
  const meta = document.querySelector('meta[name="viewport"]');
  if (meta) {
    meta.setAttribute('content', 'width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no');
  }
  let lastTouchEndAt = 0;
  document.addEventListener('touchmove', (event) => {
    if (event.touches.length > 1) {
      event.preventDefault();
    }
  }, { passive: false });
  document.addEventListener('touchend', (event) => {
    const now = Date.now();
    if (now - lastTouchEndAt <= 280) {
      event.preventDefault();
    }
    lastTouchEndAt = now;
  }, { passive: false });
  window.addEventListener('gesturestart', (event) => event.preventDefault(), { passive: false });
  window.addEventListener('gesturechange', (event) => event.preventDefault(), { passive: false });
  window.addEventListener('gestureend', (event) => event.preventDefault(), { passive: false });
  window.addEventListener('wheel', (event) => {
    if (event.ctrlKey || event.metaKey) {
      event.preventDefault();
    }
  }, { passive: false });
};

const applyReadOnlyState = () => {
  if (currentReadOnly) {
    app.setAttribute('data-ushio-read-only', 'true');
  } else {
    app.removeAttribute('data-ushio-read-only');
  }
};

const attachHorizontalWheelScroll = () => {
  const candidates = app.querySelectorAll('.milkdown-table-block, .ProseMirror pre');
  candidates.forEach((container) => {
    if (!(container instanceof HTMLElement) || container.dataset.ushioWheelBound === '1') return;
    container.dataset.ushioWheelBound = '1';
    container.addEventListener('wheel', (event) => {
      const deltaX = Math.abs(event.deltaX);
      const deltaY = Math.abs(event.deltaY);
      if (deltaY <= deltaX) return;
      const canScrollX = container.scrollWidth > container.clientWidth + 1;
      if (!canScrollX) return;
      const next = container.scrollLeft + event.deltaY;
      const before = container.scrollLeft;
      container.scrollLeft = next;
      if (container.scrollLeft !== before) {
        event.preventDefault();
      }
    }, { passive: false });
  });
};

const isExternalHref = (href) => {
  if (typeof href !== 'string') return false;
  return /^(https?:|mailto:|tel:|content:|data:)/i.test(href);
};

const resolveHref = (href) => {
  if (typeof href !== 'string' || !href) return '';
  if (href.startsWith('#') || isExternalHref(href) || href.startsWith('file://')) {
    return href;
  }
  if (href.startsWith('/')) {
    return `file://${href}`;
  }
  const baseUrl = ensureFileBaseUrl(currentBaseDirectory);
  if (!baseUrl) return href;
  try {
    return new URL(href, baseUrl).toString();
  } catch (_) {
    return href;
  }
};

const resolveInsertImageSrc = (src) => {
  if (typeof src !== 'string') return '';
  const trimmed = src.trim();
  if (!trimmed) return '';
  if (trimmed.startsWith('file://') || isExternalHref(trimmed)) return trimmed;
  if (trimmed.startsWith('/')) return `file://${trimmed}`;
  const baseUrl = ensureFileBaseUrl(currentBaseDirectory);
  if (!baseUrl) return trimmed;
  try {
    return new URL(trimmed, baseUrl).toString();
  } catch (_) {
    return trimmed;
  }
};

const sanitizeImageSource = (src) => {
  if (typeof src !== 'string') return '';
  const trimmed = src.trim();
  if (!trimmed) return '';
  const markdownTitleMatch = trimmed.match(/^(\S+)\s+["'“”][\s\S]*["'“”]$/);
  if (markdownTitleMatch && markdownTitleMatch[1]) {
    return markdownTitleMatch[1].trim();
  }
  const firstSpace = trimmed.indexOf(' ');
  if (firstSpace > 0) {
    const suffix = trimmed.slice(firstSpace + 1).trim();
    if (suffix.startsWith('"') || suffix.startsWith("'") || suffix.startsWith('“')) {
      return trimmed.slice(0, firstSpace).trim();
    }
  }
  return trimmed;
};

const decodeFileUriPath = (value) => {
  if (typeof value !== 'string' || !value.startsWith('file://')) return '';
  try {
    return decodeURIComponent(new URL(value).pathname || '');
  } catch (_) {
    return value.replace(/^file:\/\//i, '');
  }
};

const normalizeLocalFsPath = (value) => {
  if (typeof value !== 'string') return '';
  const normalized = value.trim().replace(/\\/g, '/');
  if (!normalized) return '';
  if (/^\/[A-Za-z]:\//.test(normalized)) {
    return normalized.slice(1);
  }
  return normalized;
};

const normalizeBaseDirectoryPath = (baseDirectory) => {
  if (typeof baseDirectory !== 'string' || !baseDirectory.trim()) return '';
  const trimmed = baseDirectory.trim();
  if (trimmed.startsWith('file://')) {
    return normalizeLocalFsPath(decodeFileUriPath(trimmed));
  }
  return normalizeLocalFsPath(trimmed);
};

const toAbsoluteLocalPath = (pathLike) => {
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

const buildLocalFileProxyUrl = (absolutePath) => {
  if (typeof absolutePath !== 'string' || !absolutePath) return '';
  return `${LOCAL_FILE_SCHEME}://local?path=${encodeURIComponent(absolutePath)}`;
};

const resolveImageSrc = (src) => {
  const sanitized = sanitizeImageSource(src);
  if (!sanitized) return '';
  if (sanitized.startsWith(`${LOCAL_FILE_SCHEME}://`)) {
    return sanitized;
  }
  if (isExternalHref(sanitized) || sanitized.startsWith('data:') || sanitized.startsWith('blob:')) {
    return sanitized;
  }
  const absolutePath = toAbsoluteLocalPath(sanitized);
  if (!absolutePath) {
    return resolveHref(sanitized);
  }
  const proxyUrl = buildLocalFileProxyUrl(absolutePath);
  return proxyUrl || resolveHref(sanitized);
};

const BLOCK_HTML_TAGS = new Set([
  'article',
  'aside',
  'blockquote',
  'div',
  'dl',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hr',
  'li',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'tbody',
  'td',
  'tfoot',
  'th',
  'thead',
  'tr',
  'ul',
]);

const DANGEROUS_HTML_TAGS = new Set([
  'script',
  'style',
  'iframe',
  'object',
  'embed',
  'meta',
  'link',
  'base',
]);

const sanitizeHtmlAttributeValue = (name, value) => {
  if (typeof value !== 'string') return '';
  const trimmed = value.trim();
  if (!trimmed) return '';
  const lower = trimmed.toLowerCase();
  if (name === 'href' || name === 'src' || name === 'xlink:href') {
    if (lower.startsWith('javascript:')) return '';
  }
  return trimmed;
};

const sanitizeHtmlFragment = (fragment) => {
  const walk = (node) => {
    if (!(node instanceof Element)) return;
    const tag = (node.tagName || '').toLowerCase();
    if (DANGEROUS_HTML_TAGS.has(tag)) {
      node.remove();
      return;
    }
    Array.from(node.attributes || []).forEach((attr) => {
      const attrName = (attr.name || '').toLowerCase();
      if (!attrName) return;
      if (attrName.startsWith('on')) {
        node.removeAttribute(attr.name);
        return;
      }
      const sanitizedValue = sanitizeHtmlAttributeValue(attrName, attr.value);
      if (!sanitizedValue) {
        node.removeAttribute(attr.name);
      } else if (sanitizedValue !== attr.value) {
        node.setAttribute(attr.name, sanitizedValue);
      }
    });
    Array.from(node.children || []).forEach((child) => walk(child));
  };
  Array.from(fragment.children || []).forEach((child) => walk(child));
};

const renderRawHtmlNodes = (root) => {
  root.querySelectorAll('span[data-type="html"]').forEach((htmlNode) => {
    if (!(htmlNode instanceof HTMLElement)) return;
    const rawValue = htmlNode.dataset.value || '';
    if (!rawValue.trim()) {
      htmlNode.textContent = '';
      htmlNode.classList.remove('ushio-html-block');
      htmlNode.classList.add('ushio-html-inline');
      htmlNode.dataset.ushioHtmlRenderedValue = '';
      return;
    }
    if (htmlNode.dataset.ushioHtmlRenderedValue === rawValue) return;

    const template = document.createElement('template');
    template.innerHTML = rawValue;
    sanitizeHtmlFragment(template.content);

    htmlNode.textContent = '';
    htmlNode.append(template.content.cloneNode(true));
    const hasBlockChild = Array.from(htmlNode.children || []).some((child) => (
      child instanceof HTMLElement && BLOCK_HTML_TAGS.has((child.tagName || '').toLowerCase())
    ));
    htmlNode.classList.toggle('ushio-html-block', hasBlockChild);
    htmlNode.classList.toggle('ushio-html-inline', !hasBlockChild);
    htmlNode.dataset.ushioHtmlRenderedValue = rawValue;
  });
};

/**
 * Pre-process markdown to wrap block-level HTML elements as fenced code blocks
 * with language "html-block". This allows Crepe to parse them (as code blocks)
 * while enabling DOM post-processing to render them as real HTML.
 */
const HTML_BLOCK_TAG_PATTERN = /^\s*<(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)(\s|>|$)/i;
const HTML_BLOCK_CLOSE_TAG_PATTERN = /^\s*<\/(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)>/i;

const wrapHtmlBlocksInCodeFence = (markdown) => {
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

/**
 * CSS injection + overlay approach for rendering HTML blocks.
 * ProseMirror detects DOM mutations and re-renders, wiping inline styles
 * and inserted siblings. To avoid this:
 * 1. A persistent CSS <style> rule hides html-block code blocks (survives re-renders)
 * 2. Rendered HTML is placed in an overlay OUTSIDE ProseMirror's DOM tree
 * 3. Overlay items are positioned absolutely over the hidden code blocks
 */
let htmlBlockHideStyleInjected = false;
let htmlOverlayContainer = null;
const htmlOverlayContentCache = new Map(); // blockIndex -> contentHash

const getHtmlBlockLanguage = (block) => {
  if (!(block instanceof HTMLElement)) return '';
  const candidates = [
    block.querySelector('.tools .language-button')?.dataset?.language,
    block.querySelector('.tools .language-button')?.textContent,
    block.querySelector('.tools [data-language]')?.dataset?.language,
    block.querySelector('pre')?.getAttribute('data-language'),
    block.querySelector('code')?.getAttribute('data-language'),
  ];
  return candidates
    .map((value) => (typeof value === 'string' ? value.trim().toLowerCase() : ''))
    .find((value) => value) || '';
};

const isHtmlBlockCodeNode = (block) => getHtmlBlockLanguage(block) === 'html-block';

const setImportantStyleIfNeeded = (element, property, value) => {
  if (!(element instanceof HTMLElement)) return;
  if (
    element.style.getPropertyValue(property) === value
    && element.style.getPropertyPriority(property) === 'important'
  ) {
    return;
  }
  element.style.setProperty(property, value, 'important');
};

const injectHtmlBlockHideStyle = () => {
  if (htmlBlockHideStyleInjected) return;
  const style = document.createElement('style');
  style.id = 'ushio-html-block-hide';
  // Keep raw html-block code nodes invisible while preserving layout space for
  // the rendered overlay. Attribute and :has() selectors survive NodeView churn
  // better than relying on a single class.
  style.textContent = `
    .milkdown .milkdown-code-block[data-ushio-html-block="1"],
    .milkdown .milkdown-code-block.ushio-html-block-target,
    .milkdown .milkdown-code-block:has(pre[data-language="html-block"]),
    .milkdown .milkdown-code-block:has(code[data-language="html-block"]),
    .milkdown .milkdown-code-block:has(.tools [data-language="html-block"]) {
      visibility: hidden !important;
      overflow: hidden !important;
      opacity: 0 !important;
      pointer-events: none !important;
    }
  `;
  document.head.appendChild(style);
  htmlBlockHideStyleInjected = true;
};

const ensureHtmlOverlay = () => {
  if (htmlOverlayContainer && htmlOverlayContainer.parentNode) return htmlOverlayContainer;
  const milkdownEl = app.querySelector('.milkdown');
  if (!milkdownEl) return null;
  // Make .milkdown a positioning context
  milkdownEl.style.position = 'relative';
  // Create overlay as a CHILD of .milkdown but OUTSIDE .ProseMirror
  htmlOverlayContainer = document.createElement('div');
  htmlOverlayContainer.id = 'ushio-html-overlay';
  htmlOverlayContainer.style.cssText = 'position:absolute;top:0;left:0;width:100%;pointer-events:none;z-index:10;';
  milkdownEl.appendChild(htmlOverlayContainer);
  return htmlOverlayContainer;
};

/**
 * Hide a .milkdown-code-block element that contains html-block content.
 * Uses inline !important styles to override any CSS that ProseMirror may reset.
 * The max-height is set to a large value initially; it will be corrected by
 * renderHtmlBlockCodeNodes once the overlay height is known.
 */
const hideHtmlBlockCodeNode = (block) => {
  if (!(block instanceof HTMLElement)) return;
  if (!isHtmlBlockCodeNode(block)) return;
  if (block.dataset.ushioHtmlBlockHidden !== '1') {
    block.dataset.ushioHtmlBlockHidden = '1';
  }
  if (block.dataset.ushioHtmlBlock !== '1') {
    block.dataset.ushioHtmlBlock = '1';
  }
  if (!block.classList.contains('ushio-html-block-target')) {
    block.classList.add('ushio-html-block-target');
  }
  setImportantStyleIfNeeded(block, 'visibility', 'hidden');
  setImportantStyleIfNeeded(block, 'overflow', 'hidden');
  setImportantStyleIfNeeded(block, 'opacity', '0');
  setImportantStyleIfNeeded(block, 'pointer-events', 'none');
};

/**
 * Start a MutationObserver on .milkdown to continuously hide html-block code blocks.
 * This is needed because ProseMirror re-renders NodeViews, which recreates the
 * code block wrapper elements and strips previously applied inline styles/classes.
 */
let htmlBlockObserver = null;
const startHtmlBlockObserver = () => {
  if (htmlBlockObserver) return;
  const milkdownEl = app.querySelector('.milkdown');
  if (!milkdownEl) return;

  // Initial pass: hide any existing html-block code blocks already in the DOM
  milkdownEl.querySelectorAll('.milkdown-code-block').forEach(hideHtmlBlockCodeNode);

  let rafId = null;
  const scheduleHidePass = () => {
    if (rafId != null) return;
    rafId = requestAnimationFrame(() => {
      rafId = null;
      milkdownEl.querySelectorAll('.milkdown-code-block').forEach(hideHtmlBlockCodeNode);
    });
  };

  htmlBlockObserver = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      if (mutation.type === 'attributes') {
        const targetBlock = mutation.target instanceof HTMLElement
          ? mutation.target.closest('.milkdown-code-block')
          : null;
        hideHtmlBlockCodeNode(targetBlock);
        scheduleHidePass();
        continue;
      }
      for (const node of mutation.addedNodes) {
        if (!(node instanceof HTMLElement)) continue;
        if (node.classList?.contains('milkdown-code-block')) {
          hideHtmlBlockCodeNode(node);
        }
        node.querySelectorAll?.('.milkdown-code-block').forEach(hideHtmlBlockCodeNode);
      }
    }
  });
  htmlBlockObserver.observe(milkdownEl, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['class', 'style', 'data-language', 'data-ushio-html-block'],
  });
};

const renderHtmlBlockCodeNodes = (root) => {
  injectHtmlBlockHideStyle();
  const overlay = ensureHtmlOverlay();
  if (!overlay) return;
  startHtmlBlockObserver();

  const milkdownEl = root.closest('.milkdown') || app.querySelector('.milkdown');
  if (!milkdownEl) return;
  const milkdownRect = milkdownEl.getBoundingClientRect();

  const allBlocks = root.querySelectorAll('.milkdown-code-block');
  let htmlBlockIndex = 0;

  allBlocks.forEach((block) => {
    if (!(block instanceof HTMLElement)) return;

    if (!isHtmlBlockCodeNode(block)) return;

    hideHtmlBlockCodeNode(block);

    // Read content
    const cmLines = block.querySelectorAll('.cm-line');
    let rawHtml;
    if (cmLines.length > 0) {
      rawHtml = Array.from(cmLines).map((line) => line.textContent || '').join('\n');
    } else {
      const cmContent = block.querySelector('.cm-content');
      rawHtml = cmContent?.textContent || '';
    }
    if (!rawHtml.trim()) { htmlBlockIndex++; return; }

    // Content hash to avoid unnecessary re-renders
    const contentHash = rawHtml.length + ':' + rawHtml.substring(0, 200);
    const idx = htmlBlockIndex;
    htmlBlockIndex++;

    // Calculate position relative to .milkdown container. getBoundingClientRect
    // remains accurate with visibility:hidden, so the raw code never flashes.
    const blockRect = block.getBoundingClientRect();
    const top = blockRect.top - milkdownRect.top + milkdownEl.scrollTop;
    const left = blockRect.left - milkdownRect.left + milkdownEl.scrollLeft;
    const width = blockRect.width;

    // Check if overlay item already exists for this index
    let overlayItem = overlay.querySelector(`[data-html-block-index="${idx}"]`);
    const needsUpdate = !overlayItem || htmlOverlayContentCache.get(idx) !== contentHash;

    if (needsUpdate) {
      if (overlayItem) overlayItem.remove();

      const template = document.createElement('template');
      template.innerHTML = rawHtml;
      sanitizeHtmlFragment(template.content);

      overlayItem = document.createElement('div');
      overlayItem.className = 'ushio-html-block';
      overlayItem.setAttribute('data-html-block-index', String(idx));
      overlayItem.style.cssText = `position:absolute;top:${top}px;left:${left}px;width:${width}px;pointer-events:auto;`;
      overlayItem.append(template.content.cloneNode(true));
      overlay.appendChild(overlayItem);
      htmlOverlayContentCache.set(idx, contentHash);
    } else {
      // Just update position
      overlayItem.style.top = `${top}px`;
      overlayItem.style.left = `${left}px`;
      overlayItem.style.width = `${width}px`;
    }

    // Measure the overlay's rendered height, then hide the code block with inline !important.
    // Use the overlay height so the block reserves proper space in the document flow.
    const overlayHeight = overlayItem.offsetHeight;
    hideHtmlBlockCodeNode(block);
    if (overlayHeight > 0) {
      block.style.setProperty('height', `${overlayHeight}px`, 'important');
      block.style.setProperty('min-height', `${overlayHeight}px`, 'important');
      block.style.setProperty('max-height', `${overlayHeight}px`, 'important');
    } else {
      block.style.removeProperty('height');
      block.style.removeProperty('min-height');
      block.style.setProperty('max-height', '0', 'important');
    }
    block.style.setProperty('overflow', 'hidden', 'important');
  });

  // Remove overlay items for blocks that no longer exist
  const activeIndices = new Set();
  let idx2 = 0;
  allBlocks.forEach((block) => {
    if (!(block instanceof HTMLElement)) return;
    if (!isHtmlBlockCodeNode(block)) return;
    activeIndices.add(String(idx2));
    idx2++;
  });
  overlay.querySelectorAll('[data-html-block-index]').forEach((item) => {
    if (!activeIndices.has(item.getAttribute('data-html-block-index'))) {
      item.remove();
      htmlOverlayContentCache.delete(Number(item.getAttribute('data-html-block-index')));
    }
  });
};

/**
 * Post-process DOM to find consecutive block-level HTML spans and render
 * them as a single HTML block. This handles multi-tag HTML like <table>
 * which Milkdown splits into individual span[data-type="html"] nodes.
 */
const renderBlockHtmlGroups = (root) => {
  const htmlSpans = root.querySelectorAll('span[data-type="html"]');
  if (htmlSpans.length === 0) return;

  // First pass: hide orphan block-level close tags (e.g., </table>)
  // These are leftovers from Milkdown parsing raw HTML and should never be visible
  htmlSpans.forEach((span) => {
    if (!(span instanceof HTMLElement)) return;
    const rawValue = (span.dataset.value || '').trim();
    if (HTML_BLOCK_CLOSE_TAG_PATTERN.test(rawValue) && !span.dataset.ushioBlockHtmlHidden) {
      span.style.display = 'none';
      span.dataset.ushioBlockHtmlHidden = 'orphan-close';
    }
  });

  // Group consecutive HTML spans that belong to the same parent paragraph
  let i = 0;
  while (i < htmlSpans.length) {
    const span = htmlSpans[i];
    if (!(span instanceof HTMLElement)) { i++; continue; }
    const rawValue = (span.dataset.value || '').trim();

    // Check if this span starts a block-level HTML tag
    if (!HTML_BLOCK_TAG_PATTERN.test(rawValue) || !rawValue.startsWith('<')) {
      i++;
      continue;
    }

    // Collect consecutive HTML spans in the same parent
    const parent = span.parentElement;
    const group = [span];
    let j = i + 1;
    while (j < htmlSpans.length) {
      const next = htmlSpans[j];
      if (!(next instanceof HTMLElement) || next.parentElement !== parent) break;
      group.push(next);
      j++;
    }

    // Combine all data-values in the group
    const combinedHtml = group.map((s) => s.dataset.value || '').join('\n');

    // Check if the combined HTML contains a complete block-level element
    if (!/<(table|thead|tbody|tfoot|tr|th|td|div|section|article|aside|header|footer|nav|figure|figcaption|details|summary|main|form|fieldset|dl|address)(\s|>)/i.test(combinedHtml)) {
      i = j;
      continue;
    }

    // Skip if already rendered with same content
    if (span.dataset.ushioBlockHtmlRenderedValue === combinedHtml) {
      i = j;
      continue;
    }

    const template = document.createElement('template');
    template.innerHTML = combinedHtml;
    sanitizeHtmlFragment(template.content);

    // Render the combined HTML into the first span
    span.textContent = '';
    span.append(template.content.cloneNode(true));
    span.classList.add('ushio-html-block');
    span.dataset.ushioBlockHtmlRenderedValue = combinedHtml;

    // Hide the remaining spans in the group
    for (let k = 1; k < group.length; k++) {
      group[k].style.display = 'none';
      group[k].dataset.ushioBlockHtmlHidden = 'true';
    }

    i = j;
  }
};

const readFileAsDataUrl = (file) => new Promise((resolve, reject) => {
  const reader = new FileReader();
  reader.onerror = () => reject(reader.error ?? new Error('file_read_failed'));
  reader.onload = () => resolve(typeof reader.result === 'string' ? reader.result : '');
  reader.readAsDataURL(file);
});

const createUploadImageNode = (schema, item) => {
  const srcRaw = typeof item?.src === 'string' ? item.src.trim() : '';
  if (!srcRaw) return null;
  const src = resolveInsertImageSrc(srcRaw);
  if (!src) return null;
  const alt = typeof item?.alt === 'string' ? item.alt : '';
  const imageNodeType = schema.nodes?.image;
  if (!imageNodeType) return null;
  return imageNodeType.create({ src, alt });
};

const customUploadHandler = async (files, schema) => {
  const pipelineStartedAt = Date.now();
  let stage = 'validate';
  const normalizedFiles = Array.from(files ?? []);
  if (normalizedFiles.length <= 0) return [];
  try {
    if (normalizedFiles.length > MAX_UPLOAD_FILES) {
      throw new Error('upload_too_many_files');
    }
    let totalBytes = 0;
    const filePayload = [];
    stage = 'encode';
    const encodeStartedAt = Date.now();
    for (const file of normalizedFiles) {
      const size = Number.isFinite(file.size) ? file.size : 0;
      if (size <= 0) {
        throw new Error('upload_empty_file');
      }
      if (size > MAX_UPLOAD_FILE_BYTES) {
        throw new Error('upload_file_too_large');
      }
      totalBytes += size;
      if (totalBytes > MAX_UPLOAD_TOTAL_BYTES) {
        throw new Error('upload_total_too_large');
      }
      filePayload.push({
        name: file.name ?? '',
        type: file.type ?? '',
        size,
        dataUrl: await readFileAsDataUrl(file),
      });
    }
    emit('on_cmd_metric', {
      cmd: 'upload_encode',
      ok: true,
      durationMs: Math.max(0, Date.now() - encodeStartedAt),
    });
    const requestId = nextRequestId();
    let timeoutId = null;
    const resultPromise = new Promise((resolve, reject) => {
      pendingUploadResolvers.set(requestId, { resolve, reject });
      timeoutId = setTimeout(() => {
        if (!pendingUploadResolvers.has(requestId)) return;
        pendingUploadResolvers.delete(requestId);
        reject(new Error('upload_timeout'));
      }, 120000);
    });
    emit('on_upload_images_request', { requestId, files: filePayload });
    stage = 'await_result';
    const waitStartedAt = Date.now();
    try {
      const result = await resultPromise;
      emit('on_cmd_metric', {
        cmd: 'upload_bridge_wait',
        ok: true,
        durationMs: Math.max(0, Date.now() - waitStartedAt),
      });
      stage = 'apply_result';
      const applyStartedAt = Date.now();
      if (!result || typeof result !== 'object') return [];
      const images = Array.isArray(result.images) ? result.images : [];
      const nodes = images
        .map((item) => createUploadImageNode(schema, item))
        .filter(Boolean);
      emit('on_cmd_metric', {
        cmd: 'upload_apply_result',
        ok: true,
        durationMs: Math.max(0, Date.now() - applyStartedAt),
      });
      emit('on_cmd_metric', {
        cmd: 'upload_pipeline',
        ok: true,
        durationMs: Math.max(0, Date.now() - pipelineStartedAt),
      });
      return nodes;
    } finally {
      if (timeoutId !== null) {
        clearTimeout(timeoutId);
      }
    }
  } catch (error) {
    emit('on_cmd_metric', {
      cmd: 'upload_pipeline',
      ok: false,
      reason: `${stage}:${String(error?.message || error)}`,
      durationMs: Math.max(0, Date.now() - pipelineStartedAt),
    });
    throw error;
  }
};

const flushContentChange = () => {
  if (pendingContentMarkdown == null) return;
  const markdown = pendingContentMarkdown;
  const mode = pendingContentMode || 'full';
  pendingContentMarkdown = null;
  pendingContentMode = 'full';
  emit('on_content_change', {
    mode,
    markdown,
  });
};

const scheduleContentChange = (markdown, { mode = 'full' } = {}) => {
  // Validate input to prevent runtime errors
  if (markdown == null || typeof markdown !== 'string') return;
  
  pendingContentMarkdown = markdown;
  pendingContentMode = mode;
  if (contentChangeTimerId != null) {
    clearTimeout(contentChangeTimerId);
  }
  // Use adaptive debounce based on file size
  const debounceMs = calculateAdaptiveDebounceMs(markdown.length);
  contentChangeTimerId = setTimeout(() => {
    contentChangeTimerId = null;
    flushContentChange();
  }, debounceMs);
};

const emitOutlineUpdate = () => {
  const outline = parseMarkdownOutline(currentMarkdown).map(({ id, level, text }) => ({
    id,
    level,
    text,
  }));
  emit('on_outline_update', { outline });
};

const findCodeBlockPosAtSelection = (state, pos) => {
  const $pos = state.doc.resolve(Math.max(0, Math.min(pos, state.doc.content.size)));
  for (let depth = $pos.depth; depth > 0; depth -= 1) {
    const node = $pos.node(depth);
    if (node?.type?.name === 'code_block') {
      return $pos.before(depth);
    }
  }
  return null;
};

const normalizeCodeLanguage = (language) => {
  if (typeof language !== 'string') return '';
  return language.trim().toLowerCase();
};

const isPlainTextLanguage = (language) => {
  const normalized = normalizeCodeLanguage(language);
  return (
    !normalized ||
    normalized === 'plain text' ||
    normalized === 'plaintext' ||
    normalized === 'none' ||
    normalized === 'text' ||
    normalized === '无语言' ||
    normalized === '纯文本'
  );
};

const getCodeLanguageButton = (codeBlock) => {
  if (!(codeBlock instanceof HTMLElement)) return null;
  const customButton = codeBlock.querySelector('.tools .ushio-language-input, .tools .ushio-language-trigger');
  if (customButton instanceof HTMLElement) return customButton;
  const nativeButton = codeBlock.querySelector('.tools .language-button');
  return nativeButton instanceof HTMLElement ? nativeButton : null;
};

const ensureCustomLanguageTrigger = (tools) => {
  if (!(tools instanceof HTMLElement)) return null;
  let trigger = tools.querySelector(':scope > .ushio-language-input');
  if (trigger instanceof HTMLElement) return trigger;

  const input = document.createElement('input');
  input.type = 'text';
  input.className = 'ushio-language-input';
  input.dataset.ushioLanguageBind = '0';
  input.value = 'plain text';
  input.placeholder = 'plain text';
  input.spellcheck = false;
  tools.append(input);
  return input;
};

const resolveCodeBlockLanguage = (codeBlock, fallback = '') => {
  if (!(codeBlock instanceof HTMLElement)) return '';

  if (editorInstance) {
    let stateLanguage = '';
    editorInstance.action((ctx) => {
      const view = ctx.get(editorViewCtx);
      const { state } = view;
      let codeBlockPos = null;
      const anchorDom = codeBlock.querySelector('.cm-content') || codeBlock.querySelector('.cm-editor') || codeBlock;
      try {
        const domPos = view.posAtDOM(anchorDom, 0);
        codeBlockPos = findCodeBlockPosAtSelection(state, domPos);
      } catch (_) {
        codeBlockPos = null;
      }
      if (codeBlockPos == null) return;
      const node = state.doc.nodeAt(codeBlockPos);
      const rawLanguage = typeof node?.attrs?.language === 'string' ? node.attrs.language : '';
      stateLanguage = normalizeCodeLanguage(rawLanguage);
    });
    if (!isPlainTextLanguage(stateLanguage)) {
      return stateLanguage;
    }
  }

  const preLanguage = normalizeCodeLanguage(codeBlock.querySelector('pre')?.getAttribute('data-language') || '');
  if (!isPlainTextLanguage(preLanguage)) {
    return preLanguage;
  }

  const fallbackLanguage = normalizeCodeLanguage(fallback);
  return isPlainTextLanguage(fallbackLanguage) ? '' : fallbackLanguage;
};

const resolveCodeLanguageForBackend = (rawLanguage) => {
  const normalized = normalizeCodeLanguage(rawLanguage);
  if (!normalized || isPlainTextLanguage(normalized)) return '';
  return KNOWN_CODE_LANGUAGE_MAP.get(normalized) || '';
};

const buildCodeLanguageCacheKey = (codeBlock, fallbackIndex = -1) => {
  if (!(codeBlock instanceof HTMLElement)) return `idx:${fallbackIndex}`;
  const text = (codeBlock.querySelector('.cm-content')?.textContent || codeBlock.querySelector('pre')?.textContent || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 160);
  return `${fallbackIndex}::${text}`;
};

const preventCodeEditorFocusJump = () => {
  const active = document.activeElement;
  if (!(active instanceof HTMLElement)) return;
  if (!active.classList.contains('ushio-language-input')) return;
  setTimeout(() => {
    const focused = document.activeElement;
    if (focused instanceof HTMLElement && focused.classList.contains('cm-content')) {
      active.focus();
      if (active instanceof HTMLInputElement) {
        const len = active.value.length;
        active.setSelectionRange(len, len);
      }
    }
  }, 0);
};

const formatCodeLanguageLabel = (language) => {
  const normalized = normalizeCodeLanguage(language);
  return isPlainTextLanguage(normalized) ? 'plain text' : normalized;
};

const resolveFallbackLanguageFromBlock = (codeBlock) => {
  if (!(codeBlock instanceof HTMLElement)) return '';
  const customTrigger = codeBlock.querySelector('.tools .ushio-language-input');
  const customDatasetLanguage = normalizeCodeLanguage(customTrigger?.dataset?.displayLanguage || customTrigger?.value || '');
  if (!isPlainTextLanguage(customDatasetLanguage)) {
    return (customTrigger?.dataset?.displayLanguage || customTrigger?.value || '').trim();
  }
  const nativeButtonText = normalizeCodeLanguage(codeBlock.querySelector('.tools .language-button')?.textContent || '');
  if (!isPlainTextLanguage(nativeButtonText)) {
    return (codeBlock.querySelector('.tools .language-button')?.textContent || '').trim();
  }
  return '';
};

const emitCodeLanguageUiDebug = (kind, payload = {}) => {
  emit('on_debug_report', {
    kind: 'codeblock_language_popup_event',
    event: kind,
    seq: ++codeLanguageUiDebugSeq,
    ...payload,
  });
};

const setCodeBlockLanguage = (codeBlock, language) => {
  if (!editorInstance || !codeBlock) return false;
  let ok = false;
  const nextLanguage = normalizeCodeLanguage(language);
  editorInstance.action((ctx) => {
    const view = ctx.get(editorViewCtx);
    const { state } = view;
    let codeBlockPos = null;

    const { $from } = state.selection;
    for (let depth = $from.depth; depth > 0; depth -= 1) {
      const node = $from.node(depth);
      if (node?.type?.name === 'code_block') {
        codeBlockPos = $from.before(depth);
        break;
      }
    }

    if (codeBlockPos == null) {
      const anchorDom = codeBlock.querySelector('.cm-content') || codeBlock.querySelector('.cm-editor') || codeBlock;
      try {
        const domPos = view.posAtDOM(anchorDom, 0);
        codeBlockPos = findCodeBlockPosAtSelection(state, domPos);
      } catch (_) {
        codeBlockPos = null;
      }
    }

    if (codeBlockPos == null) return;
    const node = state.doc.nodeAt(codeBlockPos);
    if (!node || node.type.name !== 'code_block') return;

    const currentLanguage = typeof node.attrs?.language === 'string' ? node.attrs.language.trim().toLowerCase() : '';
    if (currentLanguage === nextLanguage) {
      ok = true;
      return;
    }

    const nextAttrs = {
      ...node.attrs,
      language: nextLanguage || undefined,
    };
    view.dispatch(state.tr.setNodeMarkup(codeBlockPos, undefined, nextAttrs));
    ok = true;
  });
  return ok;
};

const updateCodeLanguageButtonLabel = (codeBlock, language) => {
  const languageButton = getCodeLanguageButton(codeBlock);
  if (!(languageButton instanceof HTMLElement)) return;

  const normalizedLanguage = normalizeCodeLanguage(language);
  const effectiveLanguage = isPlainTextLanguage(normalizedLanguage) ? '' : normalizedLanguage;
  const displayText = (languageButton.dataset.displayLanguage || '').trim();
  const label = displayText || formatCodeLanguageLabel(effectiveLanguage);
  if (languageButton instanceof HTMLInputElement) {
    languageButton.value = label;
  } else {
    languageButton.textContent = label;
  }
  languageButton.dataset.language = effectiveLanguage;
  languageButton.dataset.displayLanguage = label;
  languageButton.dataset.hasLanguage = effectiveLanguage ? 'true' : 'false';
  languageButton.setAttribute('title', `代码语言：${label}`);
  languageButton.setAttribute('aria-label', `代码语言，当前 ${label}`);
};


const syncRenderedDom = () => {
  const root = app.querySelector('.milkdown') || app;
  renderRawHtmlNodes(root);
  renderBlockHtmlGroups(root);
  renderHtmlBlockCodeNodes(root);
  const markdownImageSources = collectMarkdownImageSources(currentMarkdown);

  // Debug: Log image matching info for troubleshooting
  const domImages = root.querySelectorAll('.ProseMirror img');
  if (domImages.length !== markdownImageSources.length) {
    console.warn('[syncRenderedDom] Image count mismatch:', {
      domCount: domImages.length,
      markdownCount: markdownImageSources.length,
      markdownSources: markdownImageSources,
      domSrcs: Array.from(domImages).map((img, i) => ({
        index: i,
        src: img.getAttribute('src'),
        dataType: img.getAttribute('data-type'),
        className: img.className,
      })),
    });
  }

  root.querySelectorAll('.ProseMirror img').forEach((img, imageIndex) => {
    const rawSrc = img.getAttribute('src') || '';

    // If already a custom scheme URL, just set up event handlers and data attributes
    if (rawSrc.startsWith(`${LOCAL_FILE_SCHEME}://`)) {
      if (!img.dataset.ushioSrc) {
        img.setAttribute('data-ushio-src', rawSrc);
      }
      if (!img.dataset.ushioLoadBound) {
        img.dataset.ushioLoadBound = '1';
        img.addEventListener('load', () => {
          delete img.dataset.ushioFallbackTried;
          img.classList.remove('ushio-image-load-failed');
          img.closest('.milkdown-image-block')?.classList.remove('ushio-image-load-failed');
        });
      }
      if (!img.dataset.ushioErrorBound) {
        img.dataset.ushioErrorBound = '1';
        img.addEventListener('error', () => {
          img.classList.add('ushio-image-load-failed');
          img.closest('.milkdown-image-block')?.classList.add('ushio-image-load-failed');
          emit('on_image_error', {
            src: img.getAttribute('data-ushio-src') || rawSrc,
            reason: 'load_failed',
          });
        });
      }
      return;
    }

    const sanitizedRawSrc = sanitizeImageSource(rawSrc);
    const markdownRawSrc = sanitizeImageSource(markdownImageSources[imageIndex] || '');
    if (sanitizedRawSrc && sanitizedRawSrc !== rawSrc) {
      img.setAttribute('src', sanitizedRawSrc);
    }
    const preferredRawSrc = sanitizedRawSrc || markdownRawSrc || rawSrc;
    const resolvedSrc = resolveImageSrc(preferredRawSrc);
    const fallbackResolvedSrc = resolveImageSrc(markdownRawSrc || sanitizedRawSrc || rawSrc);
    if (fallbackResolvedSrc) {
      img.dataset.ushioFallbackSrc = fallbackResolvedSrc;
    } else {
      delete img.dataset.ushioFallbackSrc;
    }
    if (resolvedSrc && img.getAttribute('src') !== resolvedSrc) {
      img.setAttribute('src', resolvedSrc);
      img.setAttribute('data-ushio-src', resolvedSrc);
    }
    if (!img.dataset.ushioLoadBound) {
      img.dataset.ushioLoadBound = '1';
      img.addEventListener('load', () => {
        delete img.dataset.ushioFallbackTried;
        img.classList.remove('ushio-image-load-failed');
        img.closest('.milkdown-image-block')?.classList.remove('ushio-image-load-failed');
      });
    }
    if (!img.dataset.ushioErrorBound) {
      img.dataset.ushioErrorBound = '1';
      img.addEventListener('error', () => {
        const fallbackSrc = img.dataset.ushioFallbackSrc || '';
        if (
          fallbackSrc
          && img.dataset.ushioFallbackTried !== '1'
          && img.getAttribute('src') !== fallbackSrc
        ) {
          img.dataset.ushioFallbackTried = '1';
          img.setAttribute('src', fallbackSrc);
          img.setAttribute('data-ushio-src', fallbackSrc);
          return;
        }
        img.classList.add('ushio-image-load-failed');
        img.closest('.milkdown-image-block')?.classList.add('ushio-image-load-failed');
        emit('on_image_error', {
          src: img.getAttribute('data-ushio-src') || fallbackSrc || resolvedSrc || markdownRawSrc || sanitizedRawSrc || rawSrc,
          reason: 'load_failed',
        });
      });
    }
  });

  root.querySelectorAll('.ProseMirror a').forEach((anchor) => {
    if (anchor.closest('.milkdown-code-block .tools')) return;
    const rawHref = anchor.getAttribute('href') || '';
    if (!rawHref) return;
    if (rawHref.startsWith('#')) return;
    const resolved = resolveHref(rawHref);
    if (resolved) {
      anchor.setAttribute('data-ushio-href', resolved);
    }
  });

  const headingOutline = parseMarkdownOutline(currentMarkdown);
  const consumedOutlineIndexes = new Set();
  const headingIdMap = new Map(); // Track used heading IDs for uniqueness
  
  root.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((heading, index) => {
    const headingText = (heading.textContent || '').trim();
    const headingLevel = Number.parseInt((heading.tagName || '').replace(/^H/i, ''), 10);
    
    // Validate heading level
    if (!Number.isFinite(headingLevel) || headingLevel < 1 || headingLevel > 6) {
      console.warn('[Milkdown] Invalid heading level detected:', headingLevel, heading);
      return; // Skip invalid heading
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
    
    // Ensure heading ID uniqueness
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
  });

  root.querySelectorAll('.milkdown-table-block').forEach((block) => {
    applyHorizontalScrollClass(block);
    const table = block.querySelector('table');
    if (table instanceof HTMLTableElement) {
      markTablePathColumns(table);
    }
  });

  root.querySelectorAll('.ProseMirror pre').forEach((block) => {
    applyHorizontalScrollClass(block);
  });

  const fenceLanguages = collectFenceLanguages(currentMarkdown);

  // Debug: Log code block matching info for troubleshooting
  const domCodeBlocks = root.querySelectorAll('.milkdown-code-block');
  if (domCodeBlocks.length !== fenceLanguages.length) {
    console.warn('[syncRenderedDom] Code block count mismatch:', {
      domCount: domCodeBlocks.length,
      markdownCount: fenceLanguages.length,
      markdownLanguages: fenceLanguages,
      domLanguages: Array.from(domCodeBlocks).map((block, i) => ({
        index: i,
        language: block.querySelector('.language-button')?.dataset?.language || 'unknown',
      })),
    });
  }

  root.querySelectorAll('.milkdown-code-block').forEach((block, codeBlockIndex) => {
    if (!(block instanceof HTMLElement)) return;

    // Skip html-block code blocks — they are rendered as HTML and hidden by injected CSS
    if (isHtmlBlockCodeNode(block)) {
      hideHtmlBlockCodeNode(block);
      return;
    }

    // Style non-html-block code blocks for custom UI (tools positioning, etc.)
    block.style.setProperty('display', 'block', 'important');
    block.style.setProperty('position', 'relative', 'important');
    block.style.setProperty('overflow', 'visible', 'important');
    block.style.setProperty('padding-top', '8px', 'important');

    const tools = block.querySelector(':scope > .tools, .tools');
    if (!(tools instanceof HTMLElement)) return;
    tools.style.setProperty('position', 'absolute', 'important');
    tools.style.setProperty('left', 'auto', 'important');
    tools.style.setProperty('right', '8px', 'important');
    tools.style.setProperty('top', '8px', 'important');
    tools.style.setProperty('bottom', 'auto', 'important');
    tools.style.setProperty('transform', 'none', 'important');

    const nativePicker = block.querySelector('.language-picker');
    if (nativePicker instanceof HTMLElement) {
      nativePicker.style.setProperty('display', 'none', 'important');
      nativePicker.style.setProperty('visibility', 'hidden', 'important');
      nativePicker.style.setProperty('opacity', '0', 'important');
      nativePicker.style.setProperty('pointer-events', 'none', 'important');
    }

    const nativeLanguageButton = block.querySelector('.tools .language-button');
    if (nativeLanguageButton instanceof HTMLElement) {
      nativeLanguageButton.style.setProperty('display', 'none', 'important');
      nativeLanguageButton.style.setProperty('visibility', 'hidden', 'important');
      nativeLanguageButton.style.setProperty('pointer-events', 'none', 'important');
    }

    const languageButton = ensureCustomLanguageTrigger(tools);
    if (!(languageButton instanceof HTMLElement)) return;

    languageButton.classList.remove('language-button');
    languageButton.classList.add('ushio-language-input');

    const currentLanguage = resolveCodeBlockLanguage(
      block,
      languageButton.dataset.language || resolveFallbackLanguageFromBlock(block) || fenceLanguages[codeBlockIndex] || '',
    );
    const cacheKey = buildCodeLanguageCacheKey(block, codeBlockIndex);
    const displayLanguage = (
      codeLanguageDisplayCache.get(cacheKey) ||
      resolveFallbackLanguageFromBlock(block) ||
      fenceLanguages[codeBlockIndex] ||
      ''
    ).trim();
    languageButton.dataset.displayLanguage = displayLanguage || formatCodeLanguageLabel(currentLanguage);
    updateCodeLanguageButtonLabel(block, currentLanguage);

    if (languageButton.dataset.ushioLanguageBind !== '1') {
      const stopBubble = (event) => {
        event.stopPropagation();
      };

      const commit = () => {
        if (!(languageButton instanceof HTMLInputElement)) return;
        const rawInput = (languageButton.value || '').trim();
        const backendLanguage = resolveCodeLanguageForBackend(rawInput);
        const displayValue = rawInput || 'plain text';
        const applied = setCodeBlockLanguage(block, backendLanguage);
        if (applied) {
          const nextCacheKey = buildCodeLanguageCacheKey(block, codeBlockIndex);
          codeLanguageDisplayCache.set(nextCacheKey, displayValue);
          languageButton.dataset.displayLanguage = displayValue;
          updateCodeLanguageButtonLabel(block, backendLanguage);
        }
      };

      languageButton.addEventListener('pointerdown', stopBubble);
      languageButton.addEventListener('mousedown', stopBubble);
      languageButton.addEventListener('click', stopBubble);
      languageButton.addEventListener('keydown', (event) => {
        stopBubble(event);
        if (event.key === 'Enter') {
          event.preventDefault();
          commit();
          preventCodeEditorFocusJump();
          return;
        }
        if (event.key === 'Escape') {
          event.preventDefault();
          updateCodeLanguageButtonLabel(block, languageButton.dataset.language || '');
          languageButton.blur();
        }
      });
      languageButton.addEventListener('blur', commit);
      languageButton.dataset.ushioLanguageBind = '1';
    }
  });

  attachHorizontalWheelScroll();

  root.querySelectorAll('input[type="checkbox"]').forEach((checkbox, index) => {
    checkbox.dataset.checkboxIndex = String(index);
    checkbox.setAttribute('tabindex', '-1');
  });

  root.querySelectorAll('.ushio-code-actions-row').forEach((row) => {
    row.remove();
  });
};

const emitHistoryState = () => {
  if (!editorInstance) return;
  let canUndo = false;
  let canRedo = false;
  editorInstance.action((ctx) => {
    const view = ctx.get(editorViewCtx);
    const state = view?.state;
    if (!state) return;
    canUndo = undoDepth(state) > 0;
    canRedo = redoDepth(state) > 0;
  });
  emit('on_history_state', {
    canUndo,
    canRedo,
  });
};

const notifyRenderComplete = () => {
  requestAnimationFrame(() => {
    syncRenderedDom();
    updateActiveMarkdownHints();
    emitOutlineUpdate();
    emit('on_render_complete', {});
    emitHistoryState();
  });
};

const endEditorInitialization = () => {
  initializingEditor = false;
  lastEditorInteractionAt = Date.now();
  if (initializingEditorTimer != null) {
    clearTimeout(initializingEditorTimer);
    initializingEditorTimer = null;
  }
};

const markEditorInteraction = () => {
  lastEditorInteractionAt = Date.now();
};

const markEditorInitializing = () => {
  initializingEditor = true;
  if (!editorUserInputListenerAttached) {
    editorUserInputListenerAttached = true;
    ['beforeinput', 'keydown', 'compositionstart', 'paste'].forEach((eventName) => {
      app.addEventListener(eventName, endEditorInitialization, true);
    });
  }
  if (initializingEditorTimer != null) {
    clearTimeout(initializingEditorTimer);
  }
  initializingEditorTimer = setTimeout(endEditorInitialization, 1500);
};

const setMarkdown = (markdown, { emitContent = false, forceRender = false } = {}) => {
  emitDebug(`[JS] setMarkdown: len=${markdown?.length}, forceRender=${forceRender}`);
  markEditorInitializing();
  const rawMarkdown = typeof markdown === 'string' ? markdown : '';
  const nextMarkdown = rawMarkdown;
  emitDebug(`[JS] setMarkdown: nextMarkdown === currentMarkdown: ${nextMarkdown === currentMarkdown}`);
  // Skip equality check if forceRender is true (needed when switching documents)
  if (!forceRender && nextMarkdown === currentMarkdown) {
    emitDebug('[JS] setMarkdown: skipping (same content)');
    return;
  }
  if (contentChangeTimerId != null) {
    clearTimeout(contentChangeTimerId);
    contentChangeTimerId = null;
  }
  pendingContentMarkdown = null;
  currentMarkdown = nextMarkdown;
  if (!editorInstance) {
    emitDebug('[JS] setMarkdown: no editorInstance, returning');
    return;
  }
  isApplyingFromFlutter = !emitContent;
  // Pre-process: wrap HTML blocks as code fences, then resolve image URLs
  const htmlWrappedMarkdown = wrapHtmlBlocksInCodeFence(nextMarkdown);
  const preprocessedMarkdown = preprocessImageUrlsInMarkdown(htmlWrappedMarkdown);
  currentMarkdown = preprocessedMarkdown;
  emitDebug('[JS] setMarkdown: calling editorInstance.action(replaceAll)');
  editorInstance.action(replaceAll(preprocessedMarkdown, forceRender));
  emitDebug('[JS] setMarkdown: calling notifyRenderComplete');
  notifyRenderComplete();
  emitDebug('[JS] setMarkdown: done');
};

/**
 * Pre-process markdown to replace relative image URLs with custom scheme URLs
 * This ensures Milkdown renders the correct URLs from the start, avoiding
 * the browser trying to load relative URLs from localhost:8080
 */
const preprocessImageUrlsInMarkdown = (markdown) => {
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

const showBootstrapError = (error) => {
  app.innerHTML = `<div style="padding:16px;font-family:sans-serif;color:#dc2626;line-height:1.6;">Milkdown 初始化失败：${String(error)}</div>`;
};

const insertTextAtSelection = (view, text) => {
  const { state } = view;
  const { from, to } = state.selection;
  const tr = state.tr.insertText(text, from, to);
  view.dispatch(tr);
};

const buildFloatingButton = (label, title, className, onClick) => {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = `ushio-float-btn ${className}`.trim();
  btn.textContent = label;
  btn.title = title;
  btn.addEventListener('mousedown', (e) => e.preventDefault());
  btn.addEventListener('click', (e) => {
    e.preventDefault();
    onClick();
  });
  return btn;
};

// Link tooltip variables
let linkTooltipElement = null;
let linkTooltipAnchor = null;

const createLinkTooltip = () => {
  if (linkTooltipElement) return;
  const tooltip = document.createElement('div');
  tooltip.className = 'ushio-link-tooltip';
  tooltip.dataset.show = 'false';

  const preview = document.createElement('div');
  preview.className = 'ushio-link-tooltip-preview';

  const actions = document.createElement('div');
  actions.className = 'ushio-link-tooltip-actions';

  const editBtn = document.createElement('button');
  editBtn.type = 'button';
  editBtn.className = 'ushio-link-tooltip-btn';
  editBtn.title = '编辑链接';
  editBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>';
  editBtn.addEventListener('click', () => {
    if (linkTooltipAnchor instanceof HTMLAnchorElement) {
      const currentHref = linkTooltipAnchor.getAttribute('href') || '';
      const newHref = prompt('编辑链接地址:', currentHref);
      if (newHref !== null && newHref.trim()) {
        linkTooltipAnchor.setAttribute('href', newHref.trim());
        linkTooltipAnchor.setAttribute('data-ushio-href', resolveHref(newHref.trim()));
        editorInstance?.action((ctx) => {
          const view = ctx.get(editorViewCtx);
          view.dispatch(view.state.tr.setNodeMarkup(
            view.state.selection.$from.before(),
            undefined,
            { href: newHref.trim() }
          ));
        });
      }
    }
    hideLinkTooltip();
  });

  const openBtn = document.createElement('button');
  openBtn.type = 'button';
  openBtn.className = 'ushio-link-tooltip-btn';
  openBtn.title = '在新窗口打开';
  openBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path><polyline points="15 3 21 3 21 9"></polyline><line x1="10" y1="14" x2="21" y2="3"></line></svg>';
  openBtn.addEventListener('click', () => {
    if (linkTooltipAnchor instanceof HTMLAnchorElement) {
      const href = linkTooltipAnchor.getAttribute('data-ushio-href') || linkTooltipAnchor.getAttribute('href') || '';
      if (href && isExternalHref(href)) {
        window.open(href, '_blank', 'noopener,noreferrer');
      }
    }
    hideLinkTooltip();
  });

  const copyBtn = document.createElement('button');
  copyBtn.type = 'button';
  copyBtn.className = 'ushio-link-tooltip-btn';
  copyBtn.title = '复制链接';
  copyBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>';
  copyBtn.addEventListener('click', () => {
    if (linkTooltipAnchor instanceof HTMLAnchorElement) {
      const href = linkTooltipAnchor.getAttribute('data-ushio-href') || linkTooltipAnchor.getAttribute('href') || '';
      navigator.clipboard.writeText(href).then(() => {
        copyBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"></polyline></svg>';
        setTimeout(() => {
          copyBtn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>';
        }, 1500);
      });
    }
  });

  actions.append(copyBtn, editBtn, openBtn);
  tooltip.append(preview, actions);
  app.append(tooltip);
  linkTooltipElement = tooltip;
};

const hideLinkTooltip = () => {
  if (linkTooltipElement) {
    linkTooltipElement.dataset.show = 'false';
    linkTooltipAnchor = null;
  }
  linkTooltipShownByTouch = false;
};

const showLinkTooltip = (anchor) => {
  if (!(anchor instanceof HTMLAnchorElement)) return;
  createLinkTooltip();
  if (!linkTooltipElement) return;
  linkTooltipAnchor = anchor;
  const href = anchor.getAttribute('data-ushio-href') || anchor.getAttribute('href') || '';
  const preview = linkTooltipElement.querySelector('.ushio-link-tooltip-preview');
  if (preview) {
    preview.textContent = href.length > 60 ? href.substring(0, 60) + '...' : href;
    preview.title = href;
  }
  const anchorRect = anchor.getBoundingClientRect();
  const appRect = app.getBoundingClientRect();
  const tooltipWidth = 280;
  let left = anchorRect.left - appRect.left;
  let top = anchorRect.bottom - appRect.top + 8;
  if (left + tooltipWidth > appRect.width - 8) {
    left = appRect.width - tooltipWidth - 8;
  }
  if (left < 8) left = 8;
  linkTooltipElement.style.left = `${Math.max(8, left)}px`;
  linkTooltipElement.style.top = `${top}px`;
  linkTooltipElement.dataset.show = 'true';
};

const buildTableFloatingButton = () => {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'ushio-table-fab';
  button.title = '表格工具';
  button.textContent = '表格';
  button.dataset.show = 'false';
  button.addEventListener('mousedown', (e) => e.preventDefault());
  button.addEventListener('click', (e) => {
    e.preventDefault();
    if (!tableFloatingPanelElement) return;
    tableFloatingPanelElement.dataset.show =
      tableFloatingPanelElement.dataset.show === 'true' ? 'false' : 'true';
  });
  return button;
};

const buildTablePanelButton = (label, title, cmd) => {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'ushio-table-panel-btn';
  button.title = title;
  button.textContent = label;
  button.addEventListener('mousedown', (e) => e.preventDefault());
  button.addEventListener('click', (e) => {
    e.preventDefault();
    executeCommand(cmd);
    if (tableFloatingPanelElement) tableFloatingPanelElement.dataset.show = 'false';
  });
  return button;
};

const TABLE_ICONS = {
  addRowBefore: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="7" x2="12" y2="13"></line><line x1="9" y1="10" x2="15" y2="10"></line><polyline points="8 3 12 3 12 7"></polyline><polyline points="16 3 12 3 12 7"></polyline><rect x="3" y="15" width="18" height="6" rx="1"></rect></svg>',
  addRowAfter: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="17" x2="12" y2="11"></line><line x1="9" y1="14" x2="15" y2="14"></line><polyline points="8 21 12 21 12 17"></polyline><polyline points="16 21 12 21 12 17"></polyline><rect x="3" y="3" width="18" height="6" rx="1"></rect></svg>',
  addColBefore: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="7" y1="12" x2="13" y2="12"></line><line x1="10" y1="9" x2="10" y2="15"></line><polyline points="3 8 3 12 7 12"></polyline><polyline points="3 16 3 12 7 12"></polyline><rect x="15" y="3" width="6" height="18" rx="1"></rect></svg>',
  addColAfter: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="17" y1="12" x2="11" y2="12"></line><line x1="14" y1="9" x2="14" y2="15"></line><polyline points="21 8 21 12 17 12"></polyline><polyline points="21 16 21 12 17 12"></polyline><rect x="3" y="3" width="6" height="18" rx="1"></rect></svg>',
  deleteRow: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="4" y1="12" x2="20" y2="12"></line><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect></svg>',
  deleteCol: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="4" x2="12" y2="20"></line><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect></svg>',
  deleteSelected: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect></svg>',
  prevCell: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6"></polyline></svg>',
  nextCell: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>',
};

const buildTablePanelIconButton = (icon, title, cmd) => {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'ushio-table-panel-btn';
  button.title = title;
  button.setAttribute('aria-label', title);
  button.innerHTML = icon;
  button.addEventListener('mousedown', (e) => e.preventDefault());
  button.addEventListener('click', (e) => {
    e.preventDefault();
    executeCommand(cmd);
    if (tableFloatingPanelElement) tableFloatingPanelElement.dataset.show = 'false';
  });
  return button;
};

const buildTableFloatingPanel = () => {
  const panel = document.createElement('div');
  panel.className = 'ushio-table-panel';
  panel.dataset.show = 'false';
  panel.append(
    buildTablePanelIconButton(TABLE_ICONS.addRowBefore, '在上方插入行', 'table_add_row_before'),
    buildTablePanelIconButton(TABLE_ICONS.addRowAfter, '在下方插入行', 'table_add_row_after'),
    buildTablePanelIconButton(TABLE_ICONS.addColBefore, '在左侧插入列', 'table_add_col_before'),
    buildTablePanelIconButton(TABLE_ICONS.addColAfter, '在右侧插入列', 'table_add_col_after'),
    buildTablePanelIconButton(TABLE_ICONS.deleteRow, '删除当前行', 'table_delete_row'),
    buildTablePanelIconButton(TABLE_ICONS.deleteCol, '删除当前列', 'table_delete_col'),
    buildTablePanelIconButton(TABLE_ICONS.deleteSelected, '删除选中单元格', 'table_delete_selected'),
  );
  return panel;
};

const hideTableFloatingUi = () => {
  if (tableFloatingButtonElement) tableFloatingButtonElement.dataset.show = 'false';
  if (tableFloatingPanelElement) tableFloatingPanelElement.dataset.show = 'false';
};

const getKeyboardInset = () => {
  const raw = getComputedStyle(document.documentElement).getPropertyValue('--ushio-keyboard-inset');
  const parsed = Number.parseFloat(raw);
  return Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
};

const updateTableFloatingUiPosition = (table) => {
  if (!tableFloatingButtonElement || !tableFloatingPanelElement) return;
  if (!table || currentReadOnly) {
    hideTableFloatingUi();
    return;
  }
  const appRect = app.getBoundingClientRect();
  const tableRect = table.getBoundingClientRect();
  const baseLeft = tableRect.left - appRect.left + 6;
  const baseTop = tableRect.top - appRect.top + 6;
  const minMargin = 8;
  const keyboardInset = getKeyboardInset();

  const buttonWidth = tableFloatingButtonElement.offsetWidth || 72;
  const buttonHeight = tableFloatingButtonElement.offsetHeight || 36;
  const panelWidth = tableFloatingPanelElement.offsetWidth || 280;
  const panelHeight = tableFloatingPanelElement.offsetHeight || 160;

  const maxButtonLeft = Math.max(minMargin, appRect.width - buttonWidth - minMargin);
  const maxButtonTop = Math.max(minMargin, appRect.height - keyboardInset - buttonHeight - minMargin);
  const clampedButtonLeft = Math.min(Math.max(baseLeft, minMargin), maxButtonLeft);
  const clampedButtonTop = Math.min(Math.max(baseTop, minMargin), maxButtonTop);

  tableFloatingButtonElement.style.left = `${clampedButtonLeft}px`;
  tableFloatingButtonElement.style.top = `${clampedButtonTop}px`;
  tableFloatingButtonElement.dataset.show = 'true';

  const panelBaseTop = clampedButtonTop + buttonHeight + 8;
  const maxPanelLeft = Math.max(minMargin, appRect.width - panelWidth - minMargin);
  const maxPanelTop = Math.max(minMargin, appRect.height - keyboardInset - panelHeight - minMargin);
  const clampedPanelLeft = Math.min(Math.max(clampedButtonLeft, minMargin), maxPanelLeft);
  const clampedPanelTop = Math.min(Math.max(panelBaseTop, minMargin), maxPanelTop);
  tableFloatingPanelElement.style.left = `${clampedPanelLeft}px`;
  tableFloatingPanelElement.style.top = `${clampedPanelTop}px`;
};

const findCurrentTable = (sourceNode = null) => {
  const fromSource = sourceNode?.closest?.('table');
  if (fromSource) return fromSource;
  const selection = window.getSelection();
  const anchorNode = selection?.anchorNode;
  if (!anchorNode) return null;
  const anchorElement = anchorNode instanceof Element ? anchorNode : anchorNode.parentElement;
  return anchorElement?.closest?.('table') ?? null;
};

const syncTableFloatingUi = (sourceNode = null) => {
  const table = findCurrentTable(sourceNode);
  updateTableFloatingUiPosition(table);
};

let syncTableFloatingUiScheduled = false;
const scheduleSyncTableFloatingUi = (sourceNode = null) => {
  if (syncTableFloatingUiScheduled) return;
  if (!tableFloatingButtonElement || !tableFloatingPanelElement) return;
  if (currentReadOnly) {
    hideTableFloatingUi();
    return;
  }
  syncTableFloatingUiScheduled = true;
  window.requestAnimationFrame(() => {
    syncTableFloatingUiScheduled = false;
    syncTableFloatingUi(sourceNode);
  });
};

const createContextMenuElement = () => {
  const element = document.createElement('div');
  element.className = 'ushio-context-menu';

  const CONTEXT_MENU_ICONS = {
    bold: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 4h8a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"></path><path d="M6 12h9a4 4 0 0 1 4 4 4 4 0 0 1-4 4H6z"></path></svg>',
    italic: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="19" y1="4" x2="10" y2="4"></line><line x1="14" y1="20" x2="5" y2="20"></line><line x1="15" y1="4" x2="9" y2="20"></line></svg>',
    strikethrough: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="4" y1="12" x2="20" y2="12"></line><path d="M17.5 7.5c-.7-1-1.8-1.5-3-1.5-2.5 0-4 1.5-4 3.5 0 1 .4 2 1.5 2.5"></path><path d="M8.5 14c.5.7 1.3 1 2.5 1 2 0 3.5-1 3.5-3 0-.7-.3-1.3-1-2"></path></svg>',
    inlineCode: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="16 18 22 12 16 6"></polyline><polyline points="8 6 2 12 8 18"></polyline></svg>',
    link: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path></svg>',
    image: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>',
    addRowBefore: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect></svg>',
    deleteRow: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"></line><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect></svg>',
    addColBefore: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect></svg>',
    deleteCol: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect></svg>',
    deleteSelected: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect></svg>',
  };

  const appendIconButton = (icon, title, cmd, args = null, className = '') => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `ushio-float-btn ${className}`.trim();
    btn.title = title;
    btn.setAttribute('aria-label', title);
    btn.innerHTML = icon;
    btn.addEventListener('mousedown', (e) => e.preventDefault());
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      executeCommand(cmd, args ?? {});
    });
    element.append(btn);
  };

  appendIconButton(CONTEXT_MENU_ICONS.bold, '加粗', 'toggle_bold', null, 'ushio-context-btn');
  appendIconButton(CONTEXT_MENU_ICONS.italic, '斜体', 'toggle_italic', null, 'ushio-context-btn');
  appendIconButton(CONTEXT_MENU_ICONS.strikethrough, '删除线', 'toggle_strikethrough', null, 'ushio-context-btn');
  appendIconButton(CONTEXT_MENU_ICONS.inlineCode, '行内代码', 'toggle_inline_code', null, 'ushio-context-btn');
  appendIconButton(CONTEXT_MENU_ICONS.link, '链接', 'toggle_link', { href: 'https://' }, 'ushio-context-btn');
  appendIconButton(CONTEXT_MENU_ICONS.image, '插入图片', 'insert_image_prompt', null, 'ushio-context-btn');
  appendIconButton(CONTEXT_MENU_ICONS.addRowBefore, '表格：上方加行', 'table_add_row_before', null, 'ushio-context-btn is-table-only');
  appendIconButton(CONTEXT_MENU_ICONS.deleteRow, '表格：删行', 'table_delete_row', null, 'ushio-context-btn is-table-only');
  appendIconButton(CONTEXT_MENU_ICONS.addColBefore, '表格：左侧加列', 'table_add_col_before', null, 'ushio-context-btn is-table-only');
  appendIconButton(CONTEXT_MENU_ICONS.deleteCol, '表格：删列', 'table_delete_col', null, 'ushio-context-btn is-table-only');
  appendIconButton(CONTEXT_MENU_ICONS.deleteSelected, '表格：删除选中单元格', 'table_delete_selected', null, 'ushio-context-btn is-table-only');
  return element;
};

const hideContextMenu = () => {
  if (!contextMenuElement) return;
  contextMenuElement.dataset.show = 'false';
};

const updateContextMenuForTarget = (target) => {
  if (!contextMenuElement) return;
  const inTable = Boolean(target?.closest?.('table'));
  contextMenuElement.querySelectorAll('.is-table-only').forEach((button) => {
    button.toggleAttribute('hidden', !inTable);
  });
};

const showContextMenuAt = (clientX, clientY, target) => {
  if (currentReadOnly || !contextMenuElement) return;
  updateContextMenuForTarget(target);
  contextMenuElement.dataset.show = 'true';
  const appRect = app.getBoundingClientRect();
  const menuWidth = contextMenuElement.offsetWidth || 240;
  const menuHeight = contextMenuElement.offsetHeight || 160;
  const keyboardInset =
    Number.parseFloat(
      getComputedStyle(document.documentElement).getPropertyValue('--ushio-keyboard-inset'),
    ) || 0;
  const maxLeft = Math.max(8, appRect.width - menuWidth - 8);
  const maxTop = Math.max(8, appRect.height - menuHeight - keyboardInset - 8);
  const left = Math.max(8, Math.min(clientX - appRect.left, maxLeft));
  const top = Math.max(8, Math.min(clientY - appRect.top, maxTop));
  contextMenuElement.style.left = `${left}px`;
  contextMenuElement.style.top = `${top}px`;
};

const clearActiveMarkdownHints = () => {
  const root = app.querySelector('.milkdown .ProseMirror') || app.querySelector('.ProseMirror');
  if (!root) return;
  root.querySelectorAll('[data-ushio-active-node="true"]').forEach((node) => {
    node.removeAttribute('data-ushio-active-node');
  });
};

let editorFocusState = false;

const emitEditorFocus = (focused) => {
  const normalized = focused === true;
  if (editorFocusState === normalized) return;
  editorFocusState = normalized;
  emit('on_editor_focus', { focused: normalized });
};

const updateActiveMarkdownHints = () => {
  clearActiveMarkdownHints();
  const root = app.querySelector('.milkdown .ProseMirror') || app.querySelector('.ProseMirror');
  if (!root) return;
  const selection = window.getSelection();
  if (!selection || selection.rangeCount <= 0) return;
  const anchorNode = selection.anchorNode;
  if (!anchorNode || !root.contains(anchorNode)) return;
  const anchorElement = anchorNode instanceof Element ? anchorNode : anchorNode.parentElement;
  const active = anchorElement?.closest?.('h1, h2, h3, h4, h5, h6, blockquote, li, pre');
  if (active) {
    active.setAttribute('data-ushio-active-node', 'true');
  }
};

const blurEditorFocus = () => {
  const editor = app.querySelector('.ProseMirror');
  if (!(editor instanceof HTMLElement)) return false;

  const activeElement = document.activeElement instanceof HTMLElement ? document.activeElement : null;
  if (activeElement?.closest('.ProseMirror')) {
    activeElement.blur();
  }

  const focusedCodeContent = app.querySelector('.ProseMirror .cm-editor.cm-focused .cm-content');
  if (focusedCodeContent instanceof HTMLElement) {
    focusedCodeContent.blur();
  }

  editor.blur();

  const stillFocusedInEditor =
    document.activeElement instanceof HTMLElement &&
    Boolean(document.activeElement.closest('.ProseMirror'));
  if (stillFocusedInEditor) {
    app.setAttribute('tabindex', '-1');
    app.focus({ preventScroll: true });
  }

  const selection = window.getSelection();
  selection?.removeAllRanges();
  emitEditorFocus(false);
  return true;
};

const createEditor = async () => {
  // Pre-process: wrap HTML blocks as code fences, then resolve image URLs
  const htmlWrappedMarkdown = wrapHtmlBlocksInCodeFence(currentMarkdown);
  const preprocessedInitialMarkdown = preprocessImageUrlsInMarkdown(htmlWrappedMarkdown);
  
  // Get the effective CodeMirror theme
  const codeBlockTheme = getEffectiveCodeBlockTheme();
  
  const crepe = new Crepe({
    root: app,
    defaultValue: preprocessedInitialMarkdown,
    features: {
      [Crepe.Feature.BlockEdit]: false,
      [Crepe.Feature.Toolbar]: false,
      [Crepe.Feature.LinkTooltip]: false,
    },
    featureConfigs: {
      [Crepe.Feature.CodeMirror]: codeBlockTheme ? { theme: codeBlockTheme } : {},
    },
  });
  crepe.editor
    .config(nord)
    .config((ctx) => {
      ctx.get(listenerCtx).markdownUpdated((_ctx, markdown, prev) => {
        if (initializingEditor) markEditorInitializing();
        if (markdown === prev) return;
        const sanitizedMarkdown = stripGhostCodeLanguageMarkers(markdown);
        if (sanitizedMarkdown !== markdown) {
          const renderReadyMarkdown = preprocessImageUrlsInMarkdown(
            wrapHtmlBlocksInCodeFence(sanitizedMarkdown),
          );
          currentMarkdown = renderReadyMarkdown;
          if (!currentReadOnly && !isApplyingFromFlutter && !initializingEditor) {
            scheduleContentChange(sanitizedMarkdown, { mode: 'code_sanitized' });
          }
          isApplyingFromFlutter = true;
          editorInstance?.action(replaceAll(renderReadyMarkdown));
          notifyRenderComplete();
          return;
        }
        currentMarkdown = preprocessImageUrlsInMarkdown(
          wrapHtmlBlocksInCodeFence(sanitizedMarkdown),
        );
        if (!isApplyingFromFlutter && !initializingEditor) {
          scheduleContentChange(sanitizedMarkdown);
        }
        isApplyingFromFlutter = false;
        notifyRenderComplete();
      });
      ctx.set(highlightPluginConfig.key, {
        parser: highlightParser,
      });
      ctx.update(uploadConfig.key, (prev) => ({
        ...prev,
        uploader: (files, schema) => customUploadHandler(files, schema),
      }));
    })
    .use(automd)
    .use(emoji)
    .use(highlight)
    .use(math)
    .use(cursor)
    .use(upload);

  await crepe.create();
  crepeInstance = crepe;
  crepe.setReadonly(currentReadOnly);
  applyReadOnlyState();
  editorInstance = crepe.editor;

  contextMenuElement = createContextMenuElement();
  app.append(contextMenuElement);
  tableFloatingButtonElement = buildTableFloatingButton();
  tableFloatingPanelElement = buildTableFloatingPanel();
  app.append(tableFloatingButtonElement);
  app.append(tableFloatingPanelElement);
  notifyRenderComplete();
  emit('on_ready', {
    runtimeTag: RUNTIME_BUILD_TAG,
  });
};

app.addEventListener('click', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (isImageInteractionTarget(target)) {
    const img = target?.closest?.('img') || target?.querySelector?.('img');
    if (img instanceof HTMLImageElement) {
      const src = img.getAttribute('src') || '';
      const alt = img.getAttribute('alt') || '';
      const resolvedSrc = img.getAttribute('data-ushio-src') || src;
      emit('on_image_click', {
        src: resolvedSrc,
        alt: alt,
      });
      return;
    }
    // Fallback: blur editor
    const selection = window.getSelection();
    selection?.removeAllRanges();
    blurEditorFocus();
    return;
  }
  // Allow interactive elements inside HTML blocks to function natively
  // (details/summary toggle, button clicks, form inputs, etc.)
  if (target?.closest('.ushio-html-block, .ushio-html-inline')) {
    const interactiveSelector = 'details, summary, button, input, select, textarea, label';
    if (target?.matches(interactiveSelector) || target?.closest(interactiveSelector)) {
      event.stopPropagation();
      // Let native behavior happen (e.g., details/summary toggle)
      return;
    }
    // Links inside HTML blocks should still be handled by our link handler below
  }
  const checkbox = target?.closest('input[type="checkbox"]');
  if (checkbox instanceof HTMLInputElement) {
    event.preventDefault();
    event.stopPropagation();
    // DEBUG: Log checkbox click
    emitDebug(`[CHECKBOX CLICK] native checkbox found, readOnly=${currentReadOnly}`);
    if (!currentReadOnly) {
      guardEditorFocusAfterCheckboxToggle();
      suppressNextCaretViewportSync = true;
      checkbox.checked = !checkbox.checked;
      emitCheckboxToggle(checkbox, checkbox.checked);
      setTimeout(() => {
        suppressNextCaretViewportSync = false;
      }, 0);
    }
    return;
  }
  // Handle Milkdown custom checkbox component (.label-wrapper inside .milkdown-list-item-block)
  const milkdownLabelWrapper = target?.closest('.milkdown-list-item-block .label-wrapper');
  if (milkdownLabelWrapper) {
    event.preventDefault();
    event.stopPropagation();
    emitDebug(`[CHECKBOX CLICK] Milkdown label-wrapper clicked, readOnly=${currentReadOnly}`);
    // The Vue component handles the toggle internally, we just need to prevent IME
    guardEditorFocusAfterCheckboxToggle();
    return;
  }
  if (target?.matches('a, a *')) {
    app.querySelector('.ProseMirror')?.blur();
  }
  const anchor = target?.closest('a');
  if (anchor) {
    event.preventDefault();
    // On touch devices (no hover capability), first tap shows the link tooltip
    // with actions (open, edit, copy). Second tap on the same link navigates.
    // On desktop, tooltip is shown via mouseover so click navigates directly.
    const isTouchDevice = !window.matchMedia('(hover: hover)').matches;
    if (isTouchDevice && linkTooltipAnchor !== anchor) {
      showLinkTooltip(anchor);
      linkTooltipShownByTouch = true;
      return; // Don't navigate on first tap on touch
    }
    if (isTouchDevice && linkTooltipShownByTouch) {
      linkTooltipShownByTouch = false;
      // Fall through to navigate on second tap
    }
    const rawHref = anchor.getAttribute('href') || '';
    const resolvedHref = anchor.getAttribute('data-ushio-href') || resolveHref(rawHref);
    const anchorText = anchor.textContent?.trim() || null;
    const fallbackHref = !resolvedHref && !rawHref && anchorText ? `#${anchorText}` : '';
    const finalHref = resolvedHref || rawHref || fallbackHref;

    // Handle internal anchor links (#fragment) directly in JS for precise heading scroll,
    // using the same toc_jump logic that the TOC panel uses (accurate positioning)
    if (rawHref.startsWith('#') && !isExternalHref(finalHref)) {
      let headingFragment = '';
      try {
        headingFragment = decodeURIComponent(rawHref.substring(1)).trim();
      } catch (_) {
        headingFragment = rawHref.substring(1).trim();
      }
      if (headingFragment) {
        const headings = Array.from(
          (app.querySelector('.milkdown .ProseMirror') || app).querySelectorAll('h1, h2, h3, h4, h5, h6'),
        );
        let targetHeading = null;
        // Strategy 1: Match by heading slug (data-heading-slug)
        const normalizedFragment = slugifyHeading(headingFragment);
        for (const h of headings) {
          if ((h.dataset.headingSlug || '') === normalizedFragment) {
            targetHeading = h;
            break;
          }
        }
        // Strategy 2: Match by heading id
        if (!targetHeading) {
          targetHeading = headings.find((h) => h.id === headingFragment || h.id === `heading-line-${headingFragment}`);
        }
        // Strategy 3: Match by heading text
        if (!targetHeading) {
          targetHeading = headings.find((h) => slugifyHeading(h.textContent || '') === normalizedFragment);
        }
        if (targetHeading) {
          scrollNodeToViewport(targetHeading, 32);
          emitDebug(`[LINK CLICK] Internal anchor resolved to heading: "${targetHeading.textContent?.substring(0, 50)}"`);
          return;
        }
      }
      // Fallback: try to find by ID directly
      const targetEl = document.getElementById(headingFragment);
      if (targetEl) {
        scrollNodeToViewport(targetEl, 32);
        return;
      }
    }

    // DEBUG: Log anchor link click details
    emitDebug(`[LINK CLICK] rawHref="${rawHref}" resolvedHref="${resolvedHref}" finalHref="${finalHref}" text="${anchorText}"`);
    emit('on_link_click', {
      href: finalHref,
      text: anchorText,
      title: anchor.getAttribute('title'),
      isExternal: isExternalHref(finalHref),
    });
    return;
  }
  if (!target?.closest('.ushio-table-fab, .ushio-table-panel')) {
    if (tableFloatingPanelElement) {
      tableFloatingPanelElement.dataset.show = 'false';
    }
  }
  scheduleSyncTableFloatingUi(target);
});

// Link hover preview (desktop: mouseover, mobile: first tap shows tooltip)
let linkTooltipShownByTouch = false;

app.addEventListener('mouseover', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  const anchor = target?.closest('a');
  if (anchor && !currentReadOnly) {
    showLinkTooltip(anchor);
  }
});

app.addEventListener('mouseout', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  const anchor = target?.closest('a');
  if (anchor) {
    const related = event.relatedTarget instanceof Element ? event.relatedTarget : null;
    if (!related?.closest('.ushio-link-tooltip, a')) {
      hideLinkTooltip();
    }
  }
});

app.addEventListener('pointerdown', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (target?.closest('.ProseMirror')) markEditorInteraction();
}, true);

app.addEventListener('mousedown', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (isImageInteractionTarget(target)) {
    return;
  }
  // Allow interactive elements inside HTML blocks to function normally
  if (target?.closest('.ushio-html-block, .ushio-html-inline')) {
    const interactiveSelector = 'details, summary, button, input, select, textarea, label, a';
    if (target?.matches(interactiveSelector) || target?.closest(interactiveSelector)) {
      event.stopPropagation();
      return;
    }
  }
  // Prevent ProseMirror from handling link clicks (we handle in 'click' event)
  if (target?.matches('a, a *')) {
    event.preventDefault();
    return;
  }
  // Prevent ProseMirror from stealing focus on checkbox clicks
  if (target?.matches('input[type="checkbox"], input[type="checkbox"] *')) {
    event.preventDefault();
    event.stopPropagation();
    return;
  }
  if (target?.closest('.milkdown-list-item-block .label-wrapper')) {
    event.preventDefault();
    event.stopPropagation();
  }
});

app.addEventListener('touchstart', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (isImageInteractionTarget(target)) {
    suppressCaretViewportSync(1200);
    return;
  }
  if (target?.matches('input[type="checkbox"], input[type="checkbox"] *')) {
    event.preventDefault();
    event.stopPropagation();
    return;
  }
  // Handle Milkdown custom checkbox component
  if (target?.closest('.milkdown-list-item-block .label-wrapper')) {
    event.preventDefault();
    event.stopPropagation();
    emitDebug('[TOUCHSTART] Milkdown label-wrapper - preventing default');
  }
}, { passive: false });

const emitCheckboxToggle = (checkbox, checked) => {
  const index = Number.parseInt(checkbox.dataset.checkboxIndex || '-1', 10);
  if (Number.isNaN(index) || index < 0) return;
  emit('on_checkbox_toggle', {
    index,
    checked,
  });
};

const isImageInteractionTarget = (target) => Boolean(
  target?.closest?.('.milkdown-image-block, .milkdown-image-block *, img'),
);

app.addEventListener('pointerdown', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (isImageInteractionTarget(target)) {
    suppressCaretViewportSync(1200);
    return;
  }
  const checkbox = target?.closest('input[type="checkbox"]');
  if (!(checkbox instanceof HTMLInputElement)) return;
  event.preventDefault();
  event.stopPropagation();
});

app.addEventListener('focusin', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (target?.matches('input[type="checkbox"]')) {
    target.blur();
    return;
  }
  if (target?.closest('.ProseMirror')) {
    if (Date.now() < checkboxInteractionGuardUntil) {
      if (target instanceof HTMLElement) target.blur();
      emitEditorFocus(false);
      return;
    }
    if (suppressNextCaretViewportSync) return;
    emitEditorFocus(true);
    scheduleCaretIntoUpperViewport();
  }
});

app.addEventListener('focusout', (event) => {
  const next = event.relatedTarget instanceof Element ? event.relatedTarget : null;
  if (next?.closest('.ProseMirror')) {
    return;
  }
  const active = document.activeElement instanceof Element ? document.activeElement : null;
  if (active?.closest('.ProseMirror')) {
    return;
  }
  emitEditorFocus(false);
});

app.addEventListener('change', (event) => {
  const target = event.target;
  if (!(target instanceof HTMLInputElement) || target.type !== 'checkbox') return;
  event.preventDefault();
  event.stopPropagation();
});

app.addEventListener('focusin', (event) => {
  const target = event.target;
  if (!(target instanceof HTMLInputElement) || target.type !== 'checkbox') return;
  target.blur();
});

app.addEventListener('contextmenu', (event) => {
  if (currentReadOnly) return;
  const target = event.target instanceof Element ? event.target : null;
  const inEditor = Boolean(target?.closest('.ProseMirror'));
  if (!inEditor) {
    hideContextMenu();
    return;
  }
  event.preventDefault();
  showContextMenuAt(event.clientX, event.clientY, target);
});

const clearMobileLongPress = () => {
  if (mobileLongPressTimer != null) {
    clearTimeout(mobileLongPressTimer);
    mobileLongPressTimer = null;
  }
  mobileLongPressStartPoint = null;
};

app.addEventListener('pointerdown', (event) => {
  if (event.pointerType !== 'touch' || currentReadOnly) return;
  const target = event.target instanceof Element ? event.target : null;
  if (!target?.closest('.ProseMirror')) return;
  suppressCaretViewportSync(1200);
  editorTouchTracking = { x: event.clientX, y: event.clientY };
  clearMobileLongPress();
  mobileLongPressStartPoint = { x: event.clientX, y: event.clientY };
  mobileLongPressTimer = setTimeout(() => {
    mobileLongPressTimer = null;
    showContextMenuAt(event.clientX, event.clientY, target);
  }, 420);
});

app.addEventListener('pointermove', (event) => {
  if (event.pointerType !== 'touch') return;
  if (editorTouchTracking) {
    const dragX = Math.abs(event.clientX - editorTouchTracking.x);
    const dragY = Math.abs(event.clientY - editorTouchTracking.y);
    if (dragX > 6 || dragY > 6) {
      lastUserScrollAt = Date.now();
      suppressCaretViewportSync(1400);
    }
  }
  if (!mobileLongPressStartPoint) return;
  const dx = Math.abs(event.clientX - mobileLongPressStartPoint.x);
  const dy = Math.abs(event.clientY - mobileLongPressStartPoint.y);
  if (dx > 14 || dy > 14) {
    clearMobileLongPress();
  }
});

app.addEventListener('pointerup', (event) => {
  if (event.pointerType === 'touch') {
    editorTouchTracking = null;
    suppressCaretViewportSync(1000);
  }
  clearMobileLongPress();
});
app.addEventListener('pointercancel', (event) => {
  if (event.pointerType === 'touch') {
    editorTouchTracking = null;
    suppressCaretViewportSync(1000);
  }
  clearMobileLongPress();
});
document.addEventListener('scroll', () => {
  lastUserScrollAt = Date.now();
  suppressCaretViewportSync(1000);
  hideContextMenu();
  hideLinkTooltip();
}, true);

// IME composition event handlers - prevent viewport sync during composition
document.addEventListener('compositionstart', () => {
  isComposing = true;
}, true);
document.addEventListener('compositionend', () => {
  isComposing = false;
  // 组合结束后立即同步一次光标位置，避免中文输入时光标被键盘遮挡
  requestAnimationFrame(() => ensureCaretInUpperViewport());
}, true);

document.addEventListener('selectionchange', () => {
  updateActiveMarkdownHints();
  const active = document.activeElement instanceof Element ? document.activeElement : null;
  if (active?.closest('.ProseMirror')) {
    scheduleCaretIntoUpperViewport();
  }
}, true);
document.addEventListener('selectionchange', () => scheduleSyncTableFloatingUi(), true);
document.addEventListener('scroll', () => scheduleSyncTableFloatingUi(), true);
document.addEventListener('pointerdown', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (!target?.closest('.ushio-context-menu')) {
    hideContextMenu();
  }
  if (!target?.closest('.ushio-table-fab, .ushio-table-panel')) {
    if (tableFloatingPanelElement) {
      tableFloatingPanelElement.dataset.show = 'false';
    }
  }
  if (!target?.closest('.ushio-link-tooltip')) {
    hideLinkTooltip();
  }
});

const ensureEditor = () => {
  createEditorPromise ??= createEditor();
  return createEditorPromise;
};

const handleEditorShortcut = (event) => {
  if (currentReadOnly) return;
  if (event.key === 'Escape') {
    const focusedNode = document.activeElement instanceof Element ? document.activeElement : null;
    if (focusedNode?.closest('.ProseMirror')) {
      event.preventDefault();
      blurEditorFocus();
      return;
    }
  }
  const key = (event.key || '').toLowerCase();
  const withPrimary = event.metaKey || event.ctrlKey;
  if (!withPrimary || event.altKey) return;

  if (key === 'b') {
    event.preventDefault();
    executeCommand('toggle_bold');
    return;
  }
  if (key === 'i') {
    event.preventDefault();
    executeCommand('toggle_italic');
    return;
  }
  if (key === 'k') {
    event.preventDefault();
    executeCommand('toggle_link', { href: 'https://' });
    return;
  }
  if (key === 'e') {
    event.preventDefault();
    executeCommand('toggle_inline_code');
    return;
  }
  if (key === 'x' && event.shiftKey) {
    event.preventDefault();
    executeCommand('toggle_strikethrough');
    return;
  }
  if (key === 'z') {
    event.preventDefault();
    executeCommand(event.shiftKey ? 'redo' : 'undo');
    return;
  }
  if (key === 'y') {
    event.preventDefault();
    executeCommand('redo');
    return;
  }
  if (key === '1' || key === '2' || key === '3') {
    event.preventDefault();
    executeCommand('set_heading', { level: Number.parseInt(key, 10) });
    return;
  }
  if (key === '7' && event.shiftKey) {
    event.preventDefault();
    executeCommand('toggle_ordered_list');
    return;
  }
  if (key === '8' && event.shiftKey) {
    event.preventDefault();
    executeCommand('toggle_bullet_list');
    return;
  }
  if (key === '.' && event.shiftKey) {
    event.preventDefault();
    executeCommand('toggle_blockquote');
    return;
  }
  if (key === 'm' && event.shiftKey) {
    event.preventDefault();
    executeCommand('insert_math_block');
    return;
  }
};

const emitCmdTelemetry = (cmd, ok, reason = null, durationMs = null) => {
  emit('on_cmd_metric', {
    cmd,
    ok,
    reason,
    durationMs,
  });
  if (!ok) {
    const key = `${cmd || 'unknown'}::${reason || 'unknown'}`;
    const nextCount = (cmdFailureAggregate.get(key) ?? 0) + 1;
    cmdFailureAggregate.set(key, nextCount);
    emit('on_cmd_failure_aggregate', {
      cmd: cmd || 'unknown',
      reason: reason || 'unknown',
      count: nextCount,
    });
  }
};

const emitCmdResult = (cmd, ok, reason = null, startedAt = null) => {
  const durationMs = Number.isFinite(startedAt) ? Math.max(0, Date.now() - startedAt) : null;
  emit('on_cmd_result', {
    cmd,
    ok,
    reason,
  });
  emitCmdTelemetry(cmd, ok, reason, durationMs);
};

const collectCodeBlockLanguageDebugReport = () => {
  const codeBlocks = Array.from((app.querySelector('.milkdown .ProseMirror') || app).querySelectorAll('.milkdown-code-block'));
  return codeBlocks.map((block, index) => {
    const tools = block.querySelector('.tools');
    const pre = block.querySelector('pre');
    const languageButton = getCodeLanguageButton(block);
    const blockRect = block.getBoundingClientRect();
    const toolsRect = tools?.getBoundingClientRect?.();
    const preComputed = pre ? window.getComputedStyle(pre) : null;
    const beforeStyle = pre ? window.getComputedStyle(pre, '::before') : null;
    const afterStyle = pre ? window.getComputedStyle(pre, '::after') : null;
    const toolsStyle = tools ? window.getComputedStyle(tools) : null;
    return {
      index,
      blockClass: block.className || '',
      languageAttr: pre?.getAttribute('data-language') || '',
      blockRect: {
        top: Math.round(blockRect.top),
        right: Math.round(blockRect.right),
        bottom: Math.round(blockRect.bottom),
        left: Math.round(blockRect.left),
        width: Math.round(blockRect.width),
        height: Math.round(blockRect.height),
      },
      toolsExists: Boolean(tools),
      languageTriggerExists: Boolean(languageButton),
      languageTriggerClass: languageButton?.className || '',
      languageTriggerText: (languageButton?.textContent || '').trim(),
      languageTriggerDataset: languageButton
        ? {
            hasLanguage: languageButton.dataset.hasLanguage || '',
            language: languageButton.dataset.language || '',
            rewired: languageButton.dataset.ushioLanguageRewired || '',
            bound: languageButton.dataset.ushioLanguageBind || '',
          }
        : null,
      toolsRect: toolsRect
        ? {
            top: Math.round(toolsRect.top),
            right: Math.round(toolsRect.right),
            bottom: Math.round(toolsRect.bottom),
            left: Math.round(toolsRect.left),
            width: Math.round(toolsRect.width),
            height: Math.round(toolsRect.height),
          }
        : null,
      toolsComputed: toolsStyle
        ? {
            position: toolsStyle.position,
            top: toolsStyle.top,
            right: toolsStyle.right,
            bottom: toolsStyle.bottom,
            left: toolsStyle.left,
            transform: toolsStyle.transform,
          }
        : null,
      preComputed: preComputed
        ? {
            position: preComputed.position,
          }
        : null,
      preBefore: beforeStyle
        ? {
            content: beforeStyle.content,
            display: beforeStyle.display,
            top: beforeStyle.top,
            right: beforeStyle.right,
            bottom: beforeStyle.bottom,
            left: beforeStyle.left,
          }
        : null,
      preAfter: afterStyle
        ? {
            content: afterStyle.content,
            display: afterStyle.display,
            top: afterStyle.top,
            right: afterStyle.right,
            bottom: afterStyle.bottom,
            left: afterStyle.left,
          }
        : null,
    };
  });
};

const executeCommand = (cmd, args = {}) => {
  const startedAt = Date.now();
  if (!editorInstance) {
    emitCmdResult(cmd, false, 'editor_not_ready', startedAt);
    return;
  }
  if (currentReadOnly && cmd !== 'focus_editor' && cmd !== 'blur_editor' && cmd !== 'debug_codeblock_language_report' && cmd !== 'scroll_caret_into_view') {
    emitCmdResult(cmd, false, 'readonly', startedAt);
    return;
  }
  try {
    if (cmd === 'focus_editor') {
      app.querySelector('.ProseMirror')?.focus({ preventScroll: true });
      emitCmdResult(cmd, true, null, startedAt);
      return;
    }
    if (cmd === 'blur_editor') {
      const ok = blurEditorFocus();
      emitCmdResult(cmd, ok, ok ? null : 'not_applicable', startedAt);
      return;
    }
    if (cmd === 'scroll_caret_into_view') {
      forceCaretIntoUpperViewport();
      emitCmdResult(cmd, true, null, startedAt);
      return;
    }
    if (cmd === 'debug_codeblock_language_report') {
      const report = collectCodeBlockLanguageDebugReport();
      emit('on_debug_report', {
        kind: 'codeblock_language_marker',
        source: typeof args?.source === 'string' ? args.source : 'unknown',
        runtimeTag: RUNTIME_BUILD_TAG,
        blockCount: report.length,
        report,
      });
      emitCmdResult(cmd, true, null, startedAt);
      return;
    }
    if (cmd === 'undo' || cmd === 'redo') {
      let ok = false;
      editorInstance.action((ctx) => {
        const commands = ctx.get(commandsCtx);
        ok = cmd === 'undo'
          ? commands.call(undoCommand.key)
          : commands.call(redoCommand.key);
      });
      emitCmdResult(cmd, ok, ok ? null : 'not_applicable', startedAt);
      emitHistoryState();
      return;
    }
    if (
      cmd === 'toggle_bold' ||
      cmd === 'toggle_italic' ||
      cmd === 'toggle_strikethrough' ||
      cmd === 'toggle_inline_code' ||
      cmd === 'toggle_link' ||
      cmd === 'set_heading' ||
      cmd === 'toggle_blockquote' ||
      cmd === 'toggle_bullet_list' ||
      cmd === 'toggle_ordered_list' ||
      cmd === 'insert_code_block' ||
      cmd === 'insert_math_block' ||
      cmd === 'insert_table' ||
      cmd === 'insert_hr' ||
      cmd === 'table_next_cell' ||
      cmd === 'table_prev_cell' ||
      cmd === 'table_add_row_before' ||
      cmd === 'table_add_row_after' ||
      cmd === 'table_add_col_before' ||
      cmd === 'table_add_col_after' ||
      cmd === 'table_delete_row' ||
      cmd === 'table_delete_col' ||
      cmd === 'table_delete_selected' ||
      cmd === 'insert_image' ||
      cmd === 'insert_emoji' ||
      cmd === 'insert_image_prompt'
    ) {
      let ok = false;
      let insertImagePromptRequestId = null;
      let insertImagePromptTimeoutId = null;
      editorInstance.action((ctx) => {
        const commands = ctx.get(commandsCtx);
        const view = ctx.get(editorViewCtx);
        if (cmd === 'toggle_bold') {
          ok = commands.call(toggleStrongCommand.key);
          return;
        }
        if (cmd === 'toggle_italic') {
          ok = commands.call(toggleEmphasisCommand.key);
          return;
        }
        if (cmd === 'toggle_strikethrough') {
          ok = commands.call(toggleStrikethroughCommand.key);
          return;
        }
        if (cmd === 'toggle_inline_code') {
          ok = commands.call(toggleInlineCodeCommand.key);
          return;
        }
        if (cmd === 'toggle_link') {
          const href = typeof args?.href === 'string' ? args.href.trim() : '';
          const title = typeof args?.title === 'string' ? args.title.trim() : '';
          ok = commands.call(toggleLinkCommand.key, {
            href: href || 'https://',
            title,
          });
          return;
        }
        if (cmd === 'set_heading') {
          const levelRaw = Number.parseInt(args?.level, 10);
          const level = Number.isNaN(levelRaw) ? 1 : Math.max(1, Math.min(levelRaw, 6));
          ok = commands.call(wrapInHeadingCommand.key, level);
          return;
        }
        if (cmd === 'toggle_blockquote') {
          ok = commands.call(wrapInBlockquoteCommand.key);
          return;
        }
        if (cmd === 'toggle_bullet_list') {
          ok = commands.call(wrapInBulletListCommand.key);
          return;
        }
        if (cmd === 'toggle_ordered_list') {
          ok = commands.call(wrapInOrderedListCommand.key);
          return;
        }
        if (cmd === 'insert_code_block') {
          const language = typeof args?.language === 'string' ? args.language.trim() : '';
          ok = commands.call(createCodeBlockCommand.key, language || undefined);
          return;
        }
        if (cmd === 'insert_math_block') {
          insertTextAtSelection(view, '$$\n\n$$');
          ok = true;
          return;
        }
        if (cmd === 'insert_hr') {
          ok = commands.call(insertHrCommand.key);
          return;
        }
        if (cmd === 'insert_table') {
          const row = Number.parseInt(args?.row, 10);
          const col = Number.parseInt(args?.col, 10);
          ok = commands.call(insertTableCommand.key, {
            row: Number.isNaN(row) || row <= 0 ? 3 : row,
            col: Number.isNaN(col) || col <= 0 ? 3 : col,
          });
          return;
        }
        if (cmd === 'table_next_cell') {
          ok = commands.call(goToNextTableCellCommand.key);
          return;
        }
        if (cmd === 'table_prev_cell') {
          ok = commands.call(goToPrevTableCellCommand.key);
          return;
        }
        if (cmd === 'table_add_row_before') {
          ok = commands.call(addRowBeforeCommand.key);
          return;
        }
        if (cmd === 'table_add_row_after') {
          ok = commands.call(addRowAfterCommand.key);
          return;
        }
        if (cmd === 'table_add_col_before') {
          ok = commands.call(addColBeforeCommand.key);
          return;
        }
        if (cmd === 'table_add_col_after') {
          ok = commands.call(addColAfterCommand.key);
          return;
        }
        if (cmd === 'table_delete_selected') {
          ok = commands.call(deleteSelectedCellsCommand.key);
          return;
        }
        if (cmd === 'table_delete_row') {
          const { state, dispatch } = view;
          ok = isInTable(state) ? deleteRow(state, dispatch) : false;
          return;
        }
        if (cmd === 'table_delete_col') {
          const { state, dispatch } = view;
          ok = isInTable(state) ? deleteColumn(state, dispatch) : false;
          return;
        }
        if (cmd === 'insert_image') {
          const src = resolveInsertImageSrc(args?.src);
          if (!src) {
            ok = false;
            return;
          }
          const alt = typeof args?.alt === 'string' ? args.alt : '';
          ok = commands.call(insertImageCommand.key, { src, alt });
          return;
        }
        if (cmd === 'insert_emoji') {
          const emojiText = typeof args?.emoji === 'string' ? args.emoji : '😀';
          insertTextAtSelection(view, emojiText || '😀');
          ok = true;
          return;
        }
        if (cmd === 'insert_image_prompt') {
          insertImagePromptRequestId = nextRequestId();
          insertImagePromptTimeoutId = setTimeout(() => {
            const pending = pendingUploadResolvers.get(insertImagePromptRequestId);
            if (!pending) return;
            pendingUploadResolvers.delete(insertImagePromptRequestId);
            pending.reject(new Error('insert_image_timeout'));
          }, 120000);
          pendingUploadResolvers.set(insertImagePromptRequestId, {
            resolve: (result) => {
              if (insertImagePromptTimeoutId != null) {
                clearTimeout(insertImagePromptTimeoutId);
              }
              const images = Array.isArray(result?.images) ? result.images : [];
              const item = images.find((x) => typeof x?.src === 'string' && x.src.trim().length > 0);
              if (!item) {
                emitCmdResult(cmd, false, 'insert_image_cancelled_or_invalid', startedAt);
                return;
              }
              const src = resolveInsertImageSrc(item.src);
              if (!src) {
                emitCmdResult(cmd, false, 'insert_image_invalid_src', startedAt);
                return;
              }
              const alt = typeof item.alt === 'string' ? item.alt : '';
              let inserted = false;
              editorInstance.action((innerCtx) => {
                const innerCommands = innerCtx.get(commandsCtx);
                inserted = innerCommands.call(insertImageCommand.key, { src, alt });
              });
              emitCmdResult(cmd, inserted, inserted ? null : 'not_applicable', startedAt);
              if (inserted) {
                notifyRenderComplete();
              }
            },
            reject: (error) => {
              if (insertImagePromptTimeoutId != null) {
                clearTimeout(insertImagePromptTimeoutId);
              }
              emitCmdResult(cmd, false, String(error?.message || 'insert_image_failed'), startedAt);
            },
          });
          emit('on_insert_image_request', { requestId: insertImagePromptRequestId });
          return;
        }
      });
      if (cmd === 'insert_image_prompt') {
        return;
      }
      emitCmdResult(
        cmd,
        ok,
        ok
          ? null
          : (cmd === 'insert_image' || cmd === 'insert_image_prompt')
            ? 'invalid_args_or_not_applicable'
            : 'not_applicable',
        startedAt,
      );
      if (ok) {
        notifyRenderComplete();
      }
      return;
    }

    // Define search highlight functions BEFORE they are used
    const clearSearchHighlights = () => {
      const root = app.querySelector('.milkdown .ProseMirror') || app.querySelector('.ProseMirror');
      if (!root) return;
      root.querySelectorAll('.ushio-search-highlight, .ushio-search-highlight-active').forEach((span) => {
        const parent = span.parentNode;
        while (span.firstChild) {
          parent?.insertBefore(span.firstChild, span);
        }
        span.remove();
        // Normalize the parent to merge adjacent text nodes
        if (parent instanceof HTMLElement) {
          parent.normalize();
        }
      });
      searchHighlightRanges = [];
      searchHighlightActiveIndex = -1;
    };

    const highlightSearchMatches = (query, options = {}) => {
      clearSearchHighlights();
      if (!query || typeof query !== 'string' || !query.trim()) return;

      const root = app.querySelector('.milkdown .ProseMirror') || app.querySelector('.ProseMirror');
      if (!root) return;

      const trimmedQuery = query.trim();
      if (!trimmedQuery) return;

      const caseSensitive = options.caseSensitive === true;
      const wholeWord = options.wholeWord === true;
      const useRegex = options.useRegex === true;

      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      const textNodes = [];
      while (walker.nextNode()) {
        textNodes.push(walker.currentNode);
      }

      const ranges = [];

      // Build match function based on options
      const findMatches = (text, textNode) => {
        const matches = [];

        if (useRegex) {
          // Regular expression search
          try {
            const regex = new RegExp(trimmedQuery, caseSensitive ? 'g' : 'gi');
            let match;
            while ((match = regex.exec(text)) !== null) {
              matches.push({ start: match.index, end: match.index + match[0].length });
            }
          } catch (e) {
            // Invalid regex
          }
        } else if (wholeWord) {
          // Whole word matching
          try {
            const wordPattern = new RegExp(
              '\\b' + trimmedQuery.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b',
              caseSensitive ? 'g' : 'gi'
            );
            let match;
            while ((match = wordPattern.exec(text)) !== null) {
              matches.push({ start: match.index, end: match.index + match[0].length });
            }
          } catch (e) {
            // Invalid pattern (e.g., query ends with backslash)
          }
        } else {
          // Standard substring search
          const searchText = caseSensitive ? text : text.toLowerCase();
          const searchQuery = caseSensitive ? trimmedQuery : trimmedQuery.toLowerCase();
          let from = 0;
          while (from < searchText.length) {
            const idx = searchText.indexOf(searchQuery, from);
            if (idx < 0) break;
            matches.push({ start: idx, end: idx + searchQuery.length });
            from = idx + searchQuery.length;
          }
        }

        return matches;
      };

      textNodes.forEach((textNode) => {
        const text = textNode.textContent || '';
        const matches = findMatches(text, textNode);

        matches.forEach(({ start, end }) => {
          const range = document.createRange();
          range.setStart(textNode, start);
          range.setEnd(textNode, end);
          ranges.push(range);
        });
      });

      // Highlight all matches
      ranges.forEach((range) => {
        try {
          const span = document.createElement('span');
          span.className = 'ushio-search-highlight';
          range.surroundContents(span);
        } catch (e) {
          // Skip if range crosses element boundaries
        }
      });

      searchHighlightRanges = ranges;
      searchHighlightActiveIndex = -1;
    };

    const highlightSearchActive = (index) => {
      const root = app.querySelector('.milkdown .ProseMirror') || app.querySelector('.ProseMirror');
      if (!root) return;

      // Remove previous active highlight
      root.querySelectorAll('.ushio-search-highlight-active').forEach((span) => {
        span.classList.remove('ushio-search-highlight-active');
        span.classList.add('ushio-search-highlight');
      });

      if (index < 0) return;

      // Add active highlight to current match
      const highlights = root.querySelectorAll('.ushio-search-highlight');
      if (index < highlights.length) {
        highlights[index].classList.remove('ushio-search-highlight');
        highlights[index].classList.add('ushio-search-highlight-active');
      }

      searchHighlightActiveIndex = index;
    };

    if (cmd === 'search_jump') {
      const query = typeof args?.query === 'string' ? args.query.trim() : '';
      const occurrenceRaw = Number.parseInt(args?.occurrence, 10);
      const occurrence = Number.isNaN(occurrenceRaw) ? 0 : occurrenceRaw;
      if (!query) {
        emitCmdResult(cmd, false, 'invalid_args', startedAt);
        return;
      }
      const root = app.querySelector('.milkdown .ProseMirror') || app.querySelector('.ProseMirror');
      if (!root) {
        emitCmdResult(cmd, false, 'editor_not_ready', startedAt);
        return;
      }
      const lowerQuery = query.toLowerCase();
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      const ranges = [];
      while (walker.nextNode()) {
        const textNode = walker.currentNode;
        const text = textNode?.textContent ?? '';
        const lowerText = text.toLowerCase();
        let from = 0;
        while (from < lowerText.length) {
          const idx = lowerText.indexOf(lowerQuery, from);
          if (idx < 0) break;
          const range = document.createRange();
          range.setStart(textNode, idx);
          range.setEnd(textNode, idx + query.length);
          ranges.push(range);
          from = idx + query.length;
        }
      }
      if (!ranges.length) {
        emitCmdResult(cmd, false, 'not_found', startedAt);
        return;
      }
      const targetIndex = Math.max(0, Math.min(ranges.length - 1, occurrence));
      const target = ranges[targetIndex];
      const selection = window.getSelection();
      selection?.removeAllRanges();
      selection?.addRange(target);
      const node = target.startContainer.parentElement ?? target.commonAncestorContainer.parentElement;
      scrollNodeToViewport(node, Number.parseFloat(args?.topOffset) || 32);
      emitCmdResult(cmd, true, null, startedAt);
      highlightSearchActive(occurrence);
      return;
    }

    if (cmd === 'search_highlight') {
      const query = typeof args?.query === 'string' ? args.query.trim() : '';
      const options = {
        caseSensitive: args?.caseSensitive === true,
        wholeWord: args?.wholeWord === true,
        useRegex: args?.useRegex === true,
      };
      highlightSearchMatches(query, options);
      emitCmdResult(cmd, true, null, startedAt);
      return;
    }

    if (cmd === 'search_clear') {
      clearSearchHighlights();
      emitCmdResult(cmd, true, null, startedAt);
      return;
    }

    if (cmd === 'toc_jump') {
      const headingText = typeof args?.headingText === 'string' ? args.headingText.trim() : '';
      const headingSlug = typeof args?.headingSlug === 'string' ? args.headingSlug.trim() : '';
      const lineNumberRaw = Number.parseInt(args?.lineNumber, 10);
      const headingIndexRaw = Number.parseInt(args?.headingIndex, 10);
      const topOffsetRaw = Number.parseFloat(args?.topOffset);
      const topOffset = Number.isFinite(topOffsetRaw) ? topOffsetRaw : 32;
      const headings = Array.from(
        (app.querySelector('.milkdown .ProseMirror') || app).querySelectorAll('h1, h2, h3, h4, h5, h6'),
      );
      
      // DEBUG: Log TOC jump parameters
      emitDebug(`[TOC JUMP] headingText="${headingText}" headingSlug="${headingSlug}" lineNumber=${lineNumberRaw} headingIndex=${headingIndexRaw} headings=${headings.length}`);
      
      if (!headings.length) {
        emitDebug('[TOC JUMP] No headings found');
        emitCmdResult(cmd, false, 'not_found', startedAt);
        return;
      }

      let target = null;
      if (!Number.isNaN(lineNumberRaw) && lineNumberRaw >= 0) {
        target = headings.find((heading) => Number.parseInt(heading.dataset.headingLine || '-1', 10) === lineNumberRaw);
        emitDebug(`[TOC JUMP] Search by lineNumber: found=${!!target}`);
      }
      if (!(target instanceof Element) && headingSlug) {
        target = headings.find((heading) => (heading.dataset.headingSlug || '') === headingSlug);
        emitDebug(`[TOC JUMP] Search by headingSlug: found=${!!target}`);
      }
      if (!(target instanceof Element) && headingText) {
        const normalized = slugifyHeading(headingText);
        target = headings.find((heading) => (heading.dataset.headingSlug || slugifyHeading(heading.textContent || '')) === normalized);
        emitDebug(`[TOC JUMP] Search by headingText (normalized="${normalized}"): found=${!!target}`);
      }
      if (!(target instanceof Element) && !Number.isNaN(headingIndexRaw) && headingIndexRaw >= 0) {
        target = headings[Math.min(headingIndexRaw, headings.length - 1)];
        emitDebug(`[TOC JUMP] Fallback to headingIndex: found=${!!target}`);
      }
      if (!(target instanceof Element)) {
        emitDebug('[TOC JUMP] Target not found');
        emitCmdResult(cmd, false, 'not_found', startedAt);
        return;
      }
      emitDebug(`[TOC JUMP] Scrolling to target: "${target.textContent?.substring(0, 50)}"`);
      scrollNodeToViewport(target, topOffset);
      emitCmdResult(cmd, true, null, startedAt);
      return;
    }
    if (cmd === 'upload_images_result') {
      const requestId = typeof args?.requestId === 'string' ? args.requestId : '';
      if (!requestId) {
        emitCmdResult(cmd, false, 'invalid_args', startedAt);
        return;
      }
      const pending = pendingUploadResolvers.get(requestId);
      if (!pending) {
        emitCmdResult(cmd, false, 'request_not_found', startedAt);
        return;
      }
      pendingUploadResolvers.delete(requestId);
      const reason = typeof args?.reason === 'string' ? args.reason : '';
      const failureReason = typeof args?.failureReason === 'string' ? args.failureReason : '';
      const failureCountRaw = Number.parseInt(args?.failureCount, 10);
      const failureCount = Number.isNaN(failureCountRaw) ? 0 : failureCountRaw;
      if (failureReason && failureCount > 0) {
        emit('on_cmd_failure_aggregate', {
          cmd: 'upload_images',
          reason: failureReason,
          count: failureCount,
        });
      }
      if (reason) {
        pending.reject(new Error(reason));
        recordUploadFailure(reason);
        emitCmdResult(cmd, false, reason, startedAt);
        return;
      }
      pending.resolve({
        images: Array.isArray(args?.images) ? args.images : [],
      });
      emitCmdResult(cmd, true, null, startedAt);
      return;
    }
    emitCmdResult(cmd, false, 'unsupported_cmd', startedAt);
  } catch (error) {
    console.error('exec_cmd failed', cmd, error);
    emitCmdResult(cmd, false, `exec_failed:${String(error)}`, startedAt);
  }
};

updateViewportMetrics();
lockViewportZoom();
window.addEventListener('resize', updateViewportMetrics);
window.addEventListener('orientationchange', updateViewportMetrics);
window.visualViewport?.addEventListener('resize', updateViewportMetrics);
document.addEventListener('keydown', handleEditorShortcut, true);

const onFlutterMessage = (message) => {
  let m = message;
  if (typeof message === 'string') {
    try {
      m = JSON.parse(message);
    } catch (err) {
      console.warn('invalid flutter bridge message', err);
      return;
    }
  }
  if (!m || typeof m !== 'object') return;

  emitDebug(`[JS] onFlutterMessage: type=${m.type}`);

  if (m.type === 'init_doc') {
    emitDebug('[JS] init_doc received');
    const payload = m.payload && typeof m.payload === 'object' ? m.payload : {};
    currentBaseDirectory = typeof payload.baseDirectory === 'string' ? payload.baseDirectory : '';
    currentReadOnly = payload.readOnly !== false;
    applyReadOnlyState();
    const markdown =
      typeof payload.markdown === 'string' ? payload.markdown : '';
    emitDebug(`[JS] init_doc: markdown length=${markdown.length}, editorInstance=${!!editorInstance}`);
    // Always update and render, even if markdown appears the same
    // (needed when switching between documents)
    currentMarkdown = markdown;
    if (editorInstance) {
      crepeInstance?.setReadonly?.(currentReadOnly);
      emitDebug('[JS] init_doc: calling setMarkdown with forceRender=true');
      // Force re-render by resetting currentMarkdown before setMarkdown
      setMarkdown(markdown, { forceRender: true });
      emitDebug('[JS] init_doc: setMarkdown done');
    } else {
      emitDebug('[JS] init_doc: no editorInstance, calling ensureEditor');
      markEditorInitializing();
      ensureEditor().catch((error) => {
        console.error('Failed to initialize Milkdown', error);
        showBootstrapError(error);
        emit('on_image_error', {
          src: 'milkdown_bootstrap',
          reason: `init_failed:${String(error)}`,
        });
      });
    }
    return;
  }

  if (m.type === 'update_theme') {
    applyTheme(m.payload);
    return;
  }

  if (m.type === 'exec_cmd') {
    const cmd = m.payload && m.payload.cmd;
    const args = m.payload && typeof m.payload === 'object' ? m.payload.args : null;
    if (typeof cmd !== 'string' || !cmd) {
      emitCmdResult('', false, 'invalid_cmd', Date.now());
      return;
    }
    executeCommand(cmd, args);
  }
};

window.__USHIO_BRIDGE__ = {
  onFlutterMessage,
  emitDebug,
};

// 通知 Flutter 端 JS Bridge 已就绪
if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
  window.flutter_inappwebview.callHandler('onBridgeReady');
}

// Prevent bfcache (back-forward cache) from restoring page without re-running JS
// This ensures JavaScript is always executed when the page is loaded
window.addEventListener('pageshow', (event) => {
  if (event.persisted) {
    console.log('[USHIO] Page restored from bfcache, forcing reload to re-execute JS');
    window.location.reload();
  }
});
