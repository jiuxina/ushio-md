import {
  Editor,
  commandsCtx,
  defaultValueCtx,
  editorViewCtx,
  editorViewOptionsCtx,
  rootCtx,
} from '@milkdown/core';
import { listener, listenerCtx } from '@milkdown/plugin-listener';
import { history, redoCommand, undoCommand } from '@milkdown/plugin-history';
import { math } from '@milkdown/plugin-math';
import { slashFactory, SlashProvider } from '@milkdown/plugin-slash';
import { tooltipFactory, TooltipProvider } from '@milkdown/plugin-tooltip';
import {
  commonmark,
  createCodeBlockCommand,
  insertImageCommand,
  wrapInBlockquoteCommand,
  wrapInBulletListCommand,
  wrapInHeadingCommand,
  wrapInOrderedListCommand,
  toggleEmphasisCommand,
  toggleStrongCommand,
} from '@milkdown/preset-commonmark';
import { insertTableCommand } from '@milkdown/preset-gfm';
import { prism } from '@milkdown/plugin-prism';
import { gfm } from '@milkdown/preset-gfm';
import { Plugin } from '@milkdown/prose/state';
import { nord } from '@milkdown/theme-nord';
import { replaceAll } from '@milkdown/utils';
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
let tooltipProvider = null;
let slashProvider = null;

const tooltip = tooltipFactory('ushio-tooltip');
const slash = slashFactory('ushio-slash');

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

const emitOutlineUpdate = () => {
  const lines = currentMarkdown.split('\n');
  const outline = [];
  lines.forEach((line, index) => {
    const match = line.match(/^(#{1,6})\s+(.+)$/);
    if (!match) return;
    outline.push({
      id: `line-${index}`,
      level: match[1].length,
      text: match[2].trim(),
    });
  });
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

  root.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((heading, index) => {
    heading.id = `heading-${index}`;
  });

  root.querySelectorAll('input[type="checkbox"]').forEach((checkbox, index) => {
    checkbox.dataset.checkboxIndex = String(index);
  });
};

const notifyRenderComplete = () => {
  requestAnimationFrame(() => {
    syncRenderedDom();
    emitOutlineUpdate();
    emit('on_render_complete', {});
  });
};

const setMarkdown = (markdown, { emitContent = false } = {}) => {
  const nextMarkdown = typeof markdown === 'string' ? markdown : '';
  currentMarkdown = nextMarkdown;
  if (!editorInstance) return;
  isApplyingFromFlutter = !emitContent;
  editorInstance.action(replaceAll(nextMarkdown));
  notifyRenderComplete();
};

const showBootstrapError = (error) => {
  app.innerHTML = `<div style="padding:16px;font-family:sans-serif;color:#dc2626;line-height:1.6;">Milkdown 初始化失败：${String(error)}</div>`;
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

const removeTrailingSlashTrigger = (view) => {
  const { state } = view;
  const { selection } = state;
  if (!selection.empty) return;
  const { $from } = selection;
  if ($from.parentOffset <= 0) return;
  const prevChar = $from.parent.textBetween($from.parentOffset - 1, $from.parentOffset, undefined, '\uFFFC');
  if (prevChar !== '/') return;
  const from = $from.pos - 1;
  const to = $from.pos;
  view.dispatch(state.tr.delete(from, to));
};

const runSlashAction = (actionId) => {
  if (!editorInstance || currentReadOnly) return;
  editorInstance.action((ctx) => {
    const commands = ctx.get(commandsCtx);
    const view = ctx.get(editorViewCtx);
    removeTrailingSlashTrigger(view);
    switch (actionId) {
      case 'h1':
        commands.call(wrapInHeadingCommand.key, 1);
        break;
      case 'h2':
        commands.call(wrapInHeadingCommand.key, 2);
        break;
      case 'h3':
        commands.call(wrapInHeadingCommand.key, 3);
        break;
      case 'bullet':
        commands.call(wrapInBulletListCommand.key);
        break;
      case 'ordered':
        commands.call(wrapInOrderedListCommand.key);
        break;
      case 'quote':
        commands.call(wrapInBlockquoteCommand.key);
        break;
      case 'code':
        commands.call(createCodeBlockCommand.key);
        break;
      case 'table':
        commands.call(insertTableCommand.key, { row: 3, col: 3 });
        break;
      default:
        break;
    }
  });
  slashProvider?.hide();
  notifyRenderComplete();
};

const createTooltipElement = () => {
  const element = document.createElement('div');
  element.className = 'ushio-tooltip';
  element.append(
    buildFloatingButton('B', '加粗', '', () => executeCommand('toggle_bold')),
    buildFloatingButton('I', '斜体', '', () => executeCommand('toggle_italic')),
  );
  return element;
};

const createSlashElement = () => {
  const element = document.createElement('div');
  element.className = 'ushio-slash';
  const actions = [
    ['h1', '标题 1'],
    ['h2', '标题 2'],
    ['h3', '标题 3'],
    ['bullet', '无序列表'],
    ['ordered', '有序列表'],
    ['quote', '引用'],
    ['code', '代码块'],
    ['table', '表格'],
  ];
  actions.forEach(([id, label]) => {
    element.append(
      buildFloatingButton(label, label, 'ushio-slash-btn', () => runSlashAction(id)),
    );
  });
  return element;
};

const createEditor = async () => {
  const editor = Editor.make()
    .config(nord)
    .config((ctx) => {
      ctx.set(rootCtx, app);
      ctx.set(defaultValueCtx, currentMarkdown);
      ctx.update(editorViewOptionsCtx, (prev) => ({
        ...prev,
        editable: () => !currentReadOnly,
      }));
      ctx.get(listenerCtx).markdownUpdated((_ctx, markdown, prev) => {
        if (markdown === prev) return;
        currentMarkdown = markdown;
        if (!isApplyingFromFlutter) {
          emit('on_content_change', {
            mode: 'full',
            markdown,
          });
        }
        isApplyingFromFlutter = false;
        notifyRenderComplete();
      });
      ctx.set(tooltip.key, {
        view: () => {
          tooltipProvider = new TooltipProvider({
            content: createTooltipElement(),
            debounce: 120,
            offset: 12,
          });
          return {
            update: tooltipProvider.update,
            destroy: () => {
              tooltipProvider?.destroy();
              tooltipProvider = null;
            },
          };
        },
      });
      ctx.set(slash.key, {
        view: () => {
          slashProvider = new SlashProvider({
            content: createSlashElement(),
            debounce: 80,
            offset: 8,
            trigger: '/',
          });
          return {
            update: slashProvider.update,
            destroy: () => {
              slashProvider?.destroy();
              slashProvider = null;
            },
          };
        },
      });
    })
    .use(commonmark)
    .use(gfm)
    .use(math)
    .use(prism)
    .use(listener)
    .use(history)
    .use(tooltip)
    .use(slash);

  editorInstance = await editor.create();
  notifyRenderComplete();
  emit('on_ready', {});
};

app.addEventListener('click', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  const anchor = target?.closest('a');
  if (anchor) {
    event.preventDefault();
    const rawHref = anchor.getAttribute('href') || '';
    const resolvedHref = anchor.getAttribute('data-ushio-href') || resolveHref(rawHref);
    emit('on_link_click', {
      href: resolvedHref || rawHref,
      text: anchor.textContent?.trim() || null,
      title: anchor.getAttribute('title'),
      isExternal: isExternalHref(resolvedHref || rawHref),
    });
    return;
  }
});

app.addEventListener('change', (event) => {
  const target = event.target;
  if (!(target instanceof HTMLInputElement) || target.type !== 'checkbox') return;
  const index = Number.parseInt(target.dataset.checkboxIndex || '-1', 10);
  if (Number.isNaN(index) || index < 0) return;
  emit('on_checkbox_toggle', {
    index,
    checked: target.checked,
  });
});

const ensureEditor = () => {
  createEditorPromise ??= createEditor();
  return createEditorPromise;
};

const emitCmdResult = (cmd, ok, reason = null) => {
  emit('on_cmd_result', {
    cmd,
    ok,
    reason,
  });
};

const executeCommand = (cmd, args = {}) => {
  if (!editorInstance) {
    emitCmdResult(cmd, false, 'editor_not_ready');
    return;
  }
  if (currentReadOnly && cmd !== 'focus_editor') {
    emitCmdResult(cmd, false, 'readonly');
    return;
  }
  try {
    if (cmd === 'focus_editor') {
      app.querySelector('.ProseMirror')?.focus();
      emitCmdResult(cmd, true);
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
      emitCmdResult(cmd, ok, ok ? null : 'not_applicable');
      return;
    }
    if (cmd === 'toggle_bold' || cmd === 'toggle_italic' || cmd === 'insert_table' || cmd === 'insert_image') {
      let ok = false;
      editorInstance.action((ctx) => {
        const commands = ctx.get(commandsCtx);
        if (cmd === 'toggle_bold') {
          ok = commands.call(toggleStrongCommand.key);
          return;
        }
        if (cmd === 'toggle_italic') {
          ok = commands.call(toggleEmphasisCommand.key);
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
        if (cmd === 'insert_image') {
          const src = resolveInsertImageSrc(args?.src);
          if (!src) {
            ok = false;
            return;
          }
          const alt = typeof args?.alt === 'string' ? args.alt : '';
          ok = commands.call(insertImageCommand.key, { src, alt });
        }
      });
      emitCmdResult(cmd, ok, ok ? null : cmd === 'insert_image' ? 'invalid_args_or_not_applicable' : 'not_applicable');
      if (ok) {
        notifyRenderComplete();
      }
      return;
    }
    emitCmdResult(cmd, false, 'unsupported_cmd');
  } catch (error) {
    console.error('exec_cmd failed', cmd, error);
    emitCmdResult(cmd, false, `exec_failed:${String(error)}`);
  }
};

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
      emitCmdResult('', false, 'invalid_cmd');
      return;
    }
    executeCommand(cmd, args);
  }
};

window.__USHIO_BRIDGE__ = {
  onFlutterMessage,
};
