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
import '@milkdown/crepe/theme/nord.css';
import 'katex/dist/katex.min.css';
import 'prismjs/themes/prism.css';
import './style.css';

const app = document.getElementById('app');
let bridgeSeq = 0;
let editorInstance = null;
let currentMarkdown = '';
let currentBaseDirectory = '';
let currentReadOnly = true;
let isApplyingFromFlutter = false;
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
const CONTENT_CHANGE_DEBOUNCE_MS = 120;
let contentChangeTimerId = null;
let pendingContentMarkdown = null;
let uploadFailureCount = 0;
let uploadFailureWindowStart = Date.now();
let caretViewportSyncRafId = null;
const highlightParser = createRefractorParser(refractor);

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
  if (payload.colors && typeof payload.colors === 'object') {
    Object.entries(payload.colors).forEach(([k, v]) => {
      const cssVar = cssVarMap[k];
      if (!cssVar || typeof v !== 'string') return;
      root.style.setProperty(cssVar, v);
    });
  }
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
  if (payload.mode === 'light' || payload.mode === 'dark') {
    root.setAttribute('data-theme-mode', payload.mode);
  }
};

const updateViewportMetrics = () => {
  const root = document.documentElement;
  const vv = window.visualViewport;
  if (!vv) {
    root.style.setProperty('--ushio-viewport-height', `${window.innerHeight}px`);
    root.style.setProperty('--ushio-keyboard-inset', '0px');
    return;
  }
  const viewportHeight = Math.max(0, vv.height);
  const keyboardInset = Math.max(0, window.innerHeight - (vv.height + vv.offsetTop));
  root.style.setProperty('--ushio-viewport-height', `${viewportHeight}px`);
  root.style.setProperty('--ushio-keyboard-inset', `${keyboardInset}px`);
  if (keyboardInset > 0) {
    scheduleCaretIntoUpperViewport();
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
  const lines = markdown.split('\n');
  const outline = [];
  let inCodeBlock = false;
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    const trimmed = line.trim();
    if (/^\s*```/.test(trimmed)) {
      inCodeBlock = !inCodeBlock;
      continue;
    }
    if (inCodeBlock) continue;

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
      const nextTrimmed = lines[index + 1].trim();
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

const ensureCaretInUpperViewport = () => {
  if (currentReadOnly) return;
  if (getKeyboardInset() <= 0) return;
  const active = document.activeElement instanceof Element ? document.activeElement : null;
  if (!active?.closest('.ProseMirror')) return;
  const selection = window.getSelection();
  const range = selection && selection.rangeCount > 0 ? selection.getRangeAt(0) : null;
  const targetNode = range?.startContainer?.parentElement
    ?? range?.commonAncestorContainer?.parentElement
    ?? active;
  if (!(targetNode instanceof Element)) return;
  const vv = window.visualViewport;
  const viewportHeight = Math.max(1, vv?.height ?? window.innerHeight);
  const desiredTop = viewportHeight * 0.28;
  const rect = targetNode.getBoundingClientRect();
  if (rect.top >= desiredTop - 20 && rect.top <= viewportHeight * 0.5) return;
  const scroller = document.scrollingElement || document.documentElement || document.body;
  const delta = rect.top - desiredTop;
  if (Math.abs(delta) < 4) return;
  if (scroller && typeof scroller.scrollTo === 'function') {
    const currentTop = scroller.scrollTop ?? window.pageYOffset ?? 0;
    scroller.scrollTo({ top: Math.max(0, currentTop + delta), behavior: 'auto' });
  } else {
    window.scrollBy(0, delta);
  }
};

const scheduleCaretIntoUpperViewport = () => {
  if (caretViewportSyncRafId != null) return;
  caretViewportSyncRafId = requestAnimationFrame(() => {
    caretViewportSyncRafId = null;
    ensureCaretInUpperViewport();
  });
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
  pendingContentMarkdown = null;
  emit('on_content_change', {
    mode: 'full',
    markdown,
  });
};

const scheduleContentChange = (markdown) => {
  pendingContentMarkdown = markdown;
  if (contentChangeTimerId != null) {
    clearTimeout(contentChangeTimerId);
  }
  contentChangeTimerId = setTimeout(() => {
    contentChangeTimerId = null;
    flushContentChange();
  }, CONTENT_CHANGE_DEBOUNCE_MS);
};

const emitOutlineUpdate = () => {
  const outline = parseMarkdownOutline(currentMarkdown).map(({ id, level, text }) => ({
    id,
    level,
    text,
  }));
  emit('on_outline_update', { outline });
};

const syncRenderedDom = () => {
  const root = app.querySelector('.milkdown') || app;
  root.querySelectorAll('img').forEach((img) => {
    const rawSrc = img.getAttribute('src') || '';
    const resolvedSrc = resolveHref(rawSrc);
    if (resolvedSrc && img.src !== resolvedSrc) {
      img.src = resolvedSrc;
    }
    if (!img.dataset.ushioErrorBound) {
      img.dataset.ushioErrorBound = '1';
      img.addEventListener('error', () => {
        emit('on_image_error', {
          src: resolvedSrc || rawSrc,
          reason: 'load_failed',
        });
      });
    }
  });

  root.querySelectorAll('a').forEach((anchor) => {
    const rawHref = anchor.getAttribute('href') || '';
    if (rawHref.startsWith('#')) return;
    const resolved = resolveHref(rawHref);
    if (resolved) {
      anchor.setAttribute('data-ushio-href', resolved);
    }
  });

  const headingOutline = parseMarkdownOutline(currentMarkdown);
  root.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((heading, index) => {
    const outlineNode = headingOutline[index];
    const text = (outlineNode?.text || heading.textContent || '').trim();
    const lineNumber = Number.isFinite(outlineNode?.lineNumber) ? outlineNode.lineNumber : index;
    heading.id = `heading-line-${lineNumber}`;
    heading.dataset.headingLine = String(lineNumber);
    heading.dataset.headingSlug = slugifyHeading(text);
  });

  root.querySelectorAll('input[type="checkbox"]').forEach((checkbox, index) => {
    checkbox.dataset.checkboxIndex = String(index);
  });

  root.querySelectorAll('.milkdown-code-block').forEach((codeBlock) => {
    const tools = codeBlock.querySelector('.tools');
    if (!(tools instanceof HTMLElement)) return;

    const languageButton = tools.querySelector('.language-button');
    if (languageButton instanceof HTMLElement) {
      languageButton.classList.add('ushio-language-trigger');
      languageButton.setAttribute('title', '代码语言');
      languageButton.setAttribute('aria-label', '代码语言');
      const picker = tools.querySelector('.language-picker');
      if (picker instanceof HTMLElement) {
        picker.classList.add('ushio-language-picker');
      }
    }

    const toolButtons = Array.from(tools.querySelectorAll('.tools-button-group button'));
    let copyButton = null;
    toolButtons.forEach((button) => {
      if (!(button instanceof HTMLButtonElement)) return;
      const text = (button.textContent || '').trim().toLowerCase();
      const title = (button.getAttribute('title') || '').trim().toLowerCase();
      if (text !== 'copy' && title !== 'copy' && title !== '复制') return;
      if (button.dataset.ushioCopyIconApplied === '1') return;
      button.dataset.ushioCopyIconApplied = '1';
      button.classList.add('ushio-copy-icon-btn');
      button.setAttribute('title', '复制');
      button.setAttribute('aria-label', '复制');
      button.innerHTML = '<svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true"><rect x="9" y="9" width="10" height="10" rx="2" ry="2" fill="none" stroke="currentColor" stroke-width="1.8"></rect><rect x="5" y="5" width="10" height="10" rx="2" ry="2" fill="none" stroke="currentColor" stroke-width="1.8"></rect></svg>';
      copyButton = button;
    });

    if (languageButton instanceof HTMLElement && copyButton instanceof HTMLElement) {
      let actionCapsule = tools.querySelector('.ushio-code-action-capsule');
      if (!(actionCapsule instanceof HTMLElement)) {
        actionCapsule = document.createElement('div');
        actionCapsule.className = 'ushio-code-action-capsule';
        tools.append(actionCapsule);
      }
      actionCapsule.append(copyButton);
      actionCapsule.append(languageButton);
      copyButton.classList.add('ushio-code-copy-action');
      languageButton.classList.add('ushio-code-language-label');
    }
  });
};

const notifyRenderComplete = () => {
  requestAnimationFrame(() => {
    syncRenderedDom();
    updateActiveMarkdownHints();
    emitOutlineUpdate();
    emit('on_render_complete', {});
  });
};

const setMarkdown = (markdown, { emitContent = false } = {}) => {
  const nextMarkdown = typeof markdown === 'string' ? markdown : '';
  if (nextMarkdown === currentMarkdown) {
    return;
  }
  if (contentChangeTimerId != null) {
    clearTimeout(contentChangeTimerId);
    contentChangeTimerId = null;
  }
  pendingContentMarkdown = null;
  currentMarkdown = nextMarkdown;
  if (!editorInstance) return;
  isApplyingFromFlutter = !emitContent;
  editorInstance.action(replaceAll(nextMarkdown));
  notifyRenderComplete();
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

const buildTableFloatingPanel = () => {
  const panel = document.createElement('div');
  panel.className = 'ushio-table-panel';
  panel.dataset.show = 'false';
  panel.append(
    buildTablePanelButton('上方加行', '在当前行上方插入', 'table_add_row_before'),
    buildTablePanelButton('下方加行', '在当前行下方插入', 'table_add_row_after'),
    buildTablePanelButton('左侧加列', '在当前列左侧插入', 'table_add_col_before'),
    buildTablePanelButton('右侧加列', '在当前列右侧插入', 'table_add_col_after'),
    buildTablePanelButton('删行', '删除当前行', 'table_delete_row'),
    buildTablePanelButton('删列', '删除当前列', 'table_delete_col'),
    buildTablePanelButton('删选区', '删除选中单元格', 'table_delete_selected'),
    buildTablePanelButton('上个单元', '跳到上一个单元格', 'table_prev_cell'),
    buildTablePanelButton('下个单元', '跳到下一个单元格', 'table_next_cell'),
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

  const buttonWidth = tableFloatingButtonElement.offsetWidth || 52;
  const buttonHeight = tableFloatingButtonElement.offsetHeight || 26;
  const panelWidth = tableFloatingPanelElement.offsetWidth || 320;
  const panelHeight = tableFloatingPanelElement.offsetHeight || 180;

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
  const appendButton = (label, title, cmd, args = null, className = '') => {
    element.append(
      buildFloatingButton(label, title, className, () => executeCommand(cmd, args ?? {})),
    );
  };
  appendButton('B', '加粗', 'toggle_bold', null, 'ushio-context-btn');
  appendButton('I', '斜体', 'toggle_italic', null, 'ushio-context-btn');
  appendButton('S', '删除线', 'toggle_strikethrough', null, 'ushio-context-btn');
  appendButton('</>', '行内代码', 'toggle_inline_code', null, 'ushio-context-btn');
  appendButton('链', '链接', 'toggle_link', { href: 'https://' }, 'ushio-context-btn');
  appendButton('图', '插入图片', 'insert_image_prompt', null, 'ushio-context-btn');
  appendButton('行+', '表格：上方加行', 'table_add_row_before', null, 'ushio-context-btn is-table-only');
  appendButton('行-', '表格：删行', 'table_delete_row', null, 'ushio-context-btn is-table-only');
  appendButton('列+', '表格：左侧加列', 'table_add_col_before', null, 'ushio-context-btn is-table-only');
  appendButton('列-', '表格：删列', 'table_delete_col', null, 'ushio-context-btn is-table-only');
  appendButton('删元', '表格：删除选中单元格', 'table_delete_selected', null, 'ushio-context-btn is-table-only');
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
  editor.blur();
  emitEditorFocus(false);
  return true;
};

const createEditor = async () => {
  const crepe = new Crepe({
    root: app,
    defaultValue: currentMarkdown,
    features: {
      [Crepe.Feature.BlockEdit]: false,
      [Crepe.Feature.Toolbar]: false,
      [Crepe.Feature.LinkTooltip]: false,
    },
  });
  crepe.editor
    .config(nord)
    .config((ctx) => {
      ctx.get(listenerCtx).markdownUpdated((_ctx, markdown, prev) => {
        if (markdown === prev) return;
        currentMarkdown = markdown;
        if (!isApplyingFromFlutter) {
          scheduleContentChange(markdown);
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
  crepe.setReadonly(currentReadOnly);
  editorInstance = crepe.editor;

  contextMenuElement = createContextMenuElement();
  app.append(contextMenuElement);
  tableFloatingButtonElement = buildTableFloatingButton();
  tableFloatingPanelElement = buildTableFloatingPanel();
  app.append(tableFloatingButtonElement);
  app.append(tableFloatingPanelElement);
  notifyRenderComplete();
  emit('on_ready', {});
};

app.addEventListener('click', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (target?.matches('a, a *')) {
    app.querySelector('.ProseMirror')?.blur();
  }
  const anchor = target?.closest('a');
  if (anchor) {
    event.preventDefault();
    const rawHref = anchor.getAttribute('href') || '';
    const resolvedHref = anchor.getAttribute('data-ushio-href') || resolveHref(rawHref);
    const anchorText = anchor.textContent?.trim() || null;
    const fallbackHref = !resolvedHref && !rawHref && anchorText ? `#${anchorText}` : '';
    emit('on_link_click', {
      href: resolvedHref || rawHref || fallbackHref,
      text: anchorText,
      title: anchor.getAttribute('title'),
      isExternal: isExternalHref(resolvedHref || rawHref || fallbackHref),
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

app.addEventListener('mousedown', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (target?.matches('a, a *, input[type="checkbox"], input[type="checkbox"] *')) {
    event.preventDefault();
  }
});

const emitCheckboxToggle = (checkbox, checked) => {
  const index = Number.parseInt(checkbox.dataset.checkboxIndex || '-1', 10);
  if (Number.isNaN(index) || index < 0) return;
  app.querySelector('.ProseMirror')?.blur();
  emit('on_checkbox_toggle', {
    index,
    checked,
  });
};

app.addEventListener('pointerdown', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  const checkbox = target?.closest('input[type="checkbox"]');
  if (!(checkbox instanceof HTMLInputElement)) return;
  if (currentReadOnly) {
    event.preventDefault();
    return;
  }
  event.preventDefault();
  event.stopPropagation();
  const nextChecked = !checkbox.checked;
  checkbox.checked = nextChecked;
  checkbox.dataset.ushioSkipNextChange = '1';
  emitCheckboxToggle(checkbox, nextChecked);
});

app.addEventListener('focusin', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (target?.closest('.ProseMirror')) {
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
  if (target.dataset.ushioSkipNextChange === '1') {
    delete target.dataset.ushioSkipNextChange;
    return;
  }
  emitCheckboxToggle(target, target.checked);
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
  clearMobileLongPress();
  mobileLongPressStartPoint = { x: event.clientX, y: event.clientY };
  mobileLongPressTimer = setTimeout(() => {
    mobileLongPressTimer = null;
    showContextMenuAt(event.clientX, event.clientY, target);
  }, 420);
});

app.addEventListener('pointermove', (event) => {
  if (event.pointerType !== 'touch' || !mobileLongPressStartPoint) return;
  const dx = Math.abs(event.clientX - mobileLongPressStartPoint.x);
  const dy = Math.abs(event.clientY - mobileLongPressStartPoint.y);
  if (dx > 14 || dy > 14) {
    clearMobileLongPress();
  }
});

app.addEventListener('pointerup', clearMobileLongPress);
app.addEventListener('pointercancel', clearMobileLongPress);
document.addEventListener('scroll', hideContextMenu, true);
document.addEventListener('selectionchange', updateActiveMarkdownHints, true);
document.addEventListener('selectionchange', () => scheduleSyncTableFloatingUi(), true);
document.addEventListener('selectionchange', scheduleCaretIntoUpperViewport, true);
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

const executeCommand = (cmd, args = {}) => {
  const startedAt = Date.now();
  if (!editorInstance) {
    emitCmdResult(cmd, false, 'editor_not_ready', startedAt);
    return;
  }
  if (currentReadOnly && cmd !== 'focus_editor' && cmd !== 'blur_editor') {
    emitCmdResult(cmd, false, 'readonly', startedAt);
    return;
  }
  try {
    if (cmd === 'focus_editor') {
      app.querySelector('.ProseMirror')?.focus();
      emitCmdResult(cmd, true, null, startedAt);
      return;
    }
    if (cmd === 'blur_editor') {
      const ok = blurEditorFocus();
      emitCmdResult(cmd, ok, ok ? null : 'not_applicable', startedAt);
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
      if (!headings.length) {
        emitCmdResult(cmd, false, 'not_found', startedAt);
        return;
      }

      let target = null;
      if (!Number.isNaN(lineNumberRaw) && lineNumberRaw >= 0) {
        target = headings.find((heading) => Number.parseInt(heading.dataset.headingLine || '-1', 10) === lineNumberRaw);
      }
      if (!(target instanceof Element) && headingSlug) {
        target = headings.find((heading) => (heading.dataset.headingSlug || '') === headingSlug);
      }
      if (!(target instanceof Element) && headingText) {
        const normalized = slugifyHeading(headingText);
        target = headings.find((heading) => (heading.dataset.headingSlug || slugifyHeading(heading.textContent || '')) === normalized);
      }
      if (!(target instanceof Element) && !Number.isNaN(headingIndexRaw) && headingIndexRaw >= 0) {
        target = headings[Math.min(headingIndexRaw, headings.length - 1)];
      }
      if (!(target instanceof Element)) {
        emitCmdResult(cmd, false, 'not_found', startedAt);
        return;
      }
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
window.addEventListener('resize', updateViewportMetrics);
window.addEventListener('orientationchange', updateViewportMetrics);
window.visualViewport?.addEventListener('resize', updateViewportMetrics);
window.visualViewport?.addEventListener('scroll', updateViewportMetrics);
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

  if (m.type === 'init_doc') {
    const payload = m.payload && typeof m.payload === 'object' ? m.payload : {};
    currentBaseDirectory = typeof payload.baseDirectory === 'string' ? payload.baseDirectory : '';
    currentReadOnly = payload.readOnly !== false;
    const markdown = typeof payload.markdown === 'string' ? payload.markdown : '';
    currentMarkdown = markdown;
    if (editorInstance) {
      setMarkdown(markdown);
    } else {
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
};
