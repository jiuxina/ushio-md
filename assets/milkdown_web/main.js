import {
  Editor,
  defaultValueCtx,
  editorViewOptionsCtx,
  rootCtx,
} from 'https://esm.sh/@milkdown/core@7.5.0';
import { listener, listenerCtx } from 'https://esm.sh/@milkdown/plugin-listener@7.5.0';
import { math } from 'https://esm.sh/@milkdown/plugin-math@7.5.0';
import { prism } from 'https://esm.sh/@milkdown/plugin-prism@7.5.0';
import { gfm } from 'https://esm.sh/@milkdown/preset-gfm@7.5.0';
import { nord } from 'https://esm.sh/@milkdown/theme-nord@7.5.0';
import { replaceAll } from 'https://esm.sh/@milkdown/utils@7.5.0';

const app = document.getElementById('app');
let bridgeSeq = 0;
let editorInstance = null;
let currentMarkdown = '';
let currentBaseDirectory = '';
let currentReadOnly = true;
let isApplyingFromFlutter = false;
let createEditorPromise = null;

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

const createEditor = async () => {
  const editor = Editor.make()
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
    })
    .use(nord)
    .use(gfm)
    .use(math)
    .use(prism)
    .use(listener);

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
    if (cmd === 'focus_editor') {
      app.querySelector('.ProseMirror')?.focus();
    }
  }
};

window.__USHIO_BRIDGE__ = {
  onFlutterMessage,
};
