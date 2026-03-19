# WebView + Milkdown 迁移与升级计划：详细设计与实施方案（LLD）

> 目标：将编辑器内核从“纯 Flutter UI + 静态 Web 预览”升级为“Flutter 外壳 + WebView(Milkdown) 一体化内核”，并保证协议可扩展、主题可融合、图片可落地。

---

## 1) 前端工程化与 Milkdown 初始化代码（Vite + TS）

### 1.1 `package.json`（依赖清单）

> 说明：下述版本为稳定可用基线。若项目已有统一版本策略（如 Renovate/锁版本），以仓库规范为准。

```json
{
  "name": "ushio-milkdown-webview",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@milkdown/core": "7.5.0",
    "@milkdown/ctx": "7.5.0",
    "@milkdown/preset-gfm": "7.5.0",
    "@milkdown/plugin-math": "7.5.0",
    "@milkdown/plugin-listener": "7.5.0",
    "@milkdown/theme-nord": "7.5.0",
    "@milkdown/prose": "7.5.0",
    "@milkdown/utils": "7.5.0",
    "@milkdown/plugin-prism": "7.5.0",
    "katex": "0.16.11",
    "lodash-es": "4.17.21"
  },
  "devDependencies": {
    "typescript": "5.8.2",
    "vite": "6.3.2",
    "vite-plugin-singlefile": "2.2.0"
  }
}
```

### 1.2 `vite.config.ts`（打包单文件 `index.html`）

```ts
import { defineConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';

export default defineConfig({
  base: './',
  plugins: [
    viteSingleFile({
      removeViteModuleLoader: true,
      useRecommendedBuildConfig: true
    })
  ],
  build: {
    target: 'es2020',
    cssCodeSplit: false,
    assetsInlineLimit: 1024 * 1024 * 20,
    chunkSizeWarningLimit: 4096,
    rollupOptions: {
      output: {
        inlineDynamicImports: true,
        manualChunks: undefined
      }
    }
  }
});
```

### 1.3 `main.ts`（Milkdown 极简初始化 + 500ms 防抖回传）

```ts
import { Editor, rootCtx, defaultValueCtx } from '@milkdown/core';
import { listener, listenerCtx } from '@milkdown/plugin-listener';
import { gfm } from '@milkdown/preset-gfm';
import { math } from '@milkdown/plugin-math';
import { prism } from '@milkdown/plugin-prism';
import { nord } from '@milkdown/theme-nord';
import debounce from 'lodash-es/debounce';
import 'katex/dist/katex.min.css';
import './style.css';

type FlutterBridge = {
  callHandler?: (name: string, ...args: unknown[]) => Promise<unknown>;
};

declare global {
  interface Window {
    flutter_inappwebview?: FlutterBridge;
    __USHIO_BRIDGE__?: {
      postToFlutter: (msg: Record<string, unknown>) => void;
      setMarkdown: (md: string) => void;
      exec: (payload: Record<string, unknown>) => void;
    };
  }
}

const postToFlutter = (msg: Record<string, unknown>) => {
  if (!window.flutter_inappwebview?.callHandler) return;
  window.flutter_inappwebview.callHandler('bridge', msg).catch(() => {});
};

const debouncedChange = debounce((markdown: string) => {
  postToFlutter({
    v: 1,
    source: 'web',
    target: 'flutter',
    type: 'on_content_change',
    requestId: crypto.randomUUID?.() ?? `${Date.now()}`,
    ts: Date.now(),
    payload: {
      mode: 'full',
      markdown
    }
  });
}, 500);

const editor = Editor.make()
  .config((ctx) => {
    ctx.set(rootCtx, document.querySelector('#app') as HTMLElement);
    ctx.set(defaultValueCtx, '');
    ctx.get(listenerCtx).markdownUpdated((_ctx, markdown, prev) => {
      if (markdown === prev) return;
      debouncedChange(markdown);
    });
  })
  .use(nord)
  .use(gfm)
  .use(math)
  .use(prism)
  .use(listener);

let editorReady = false;
let setMarkdownFromFlutter: ((md: string) => void) | null = null;
let execFromFlutter: ((payload: Record<string, unknown>) => void) | null = null;

editor.create().then((instance) => {
  editorReady = true;
  setMarkdownFromFlutter = (md: string) => {
    instance.action((ctx) => {
      ctx.set(defaultValueCtx, md);
    });
  };
  execFromFlutter = (payload: Record<string, unknown>) => {
    // 示例：在这里根据 cmd 路由到 ProseMirror transaction 或 Milkdown command
    // const cmd = payload.cmd as string;
  };
});

window.__USHIO_BRIDGE__ = {
  postToFlutter,
  setMarkdown: (md: string) => {
    if (!editorReady || !setMarkdownFromFlutter) return;
    setMarkdownFromFlutter(md);
  },
  exec: (payload: Record<string, unknown>) => {
    if (!editorReady || !execFromFlutter) return;
    execFromFlutter(payload);
  }
};
```

---

## 2) 双向通信协议设计（JS Bridge Protocol）

### 2.1 统一协议头（可扩展）

```ts
export type BridgeVersion = 1;
export type BridgeSource = 'flutter' | 'web';
export type BridgeTarget = 'flutter' | 'web';

export interface BridgeEnvelope<TType extends string, TPayload> {
  v: BridgeVersion;
  source: BridgeSource;
  target: BridgeTarget;
  type: TType;
  requestId: string;
  ts: number;
  payload: TPayload;
}
```

### 2.2 Flutter -> Web（下发）

```ts
export interface InitDocPayload {
  markdown: string;
  docId?: string;
  cursor?: { from: number; to: number };
}
export type InitDocMessage = BridgeEnvelope<'init_doc', InitDocPayload>;

export interface ThemePalettePayload {
  mode: 'light' | 'dark';
  colors: {
    primary: string;
    onPrimary: string;
    secondary: string;
    onSecondary: string;
    surface: string;
    onSurface: string;
    background: string;
    onBackground: string;
    error: string;
    onError: string;
    outline: string;
    shadow: string;
  };
  font: {
    body: string;
    mono: string;
    sizePx: number;
    lineHeight: number;
  };
}
export type UpdateThemeMessage = BridgeEnvelope<'update_theme', ThemePalettePayload>;

export interface ExecCmdPayload {
  cmd:
    | 'insert_image'
    | 'undo'
    | 'redo'
    | 'toggle_bold'
    | 'toggle_italic'
    | 'insert_table'
    | 'focus_editor';
  args?: Record<string, unknown>;
}
export type ExecCmdMessage = BridgeEnvelope<'exec_cmd', ExecCmdPayload>;

export type FlutterToWebMessage =
  | InitDocMessage
  | UpdateThemeMessage
  | ExecCmdMessage;
```

### 2.3 Web -> Flutter（上报）

```ts
export interface OnContentChangePayload {
  mode: 'full' | 'delta';
  markdown?: string;
  delta?: Array<{
    op: 'retain' | 'insert' | 'delete';
    count?: number;
    text?: string;
  }>;
  selection?: { from: number; to: number };
}
export type OnContentChangeMessage = BridgeEnvelope<'on_content_change', OnContentChangePayload>;

export interface OutlineNode {
  id: string;
  level: number;
  text: string;
  from?: number;
  to?: number;
  children?: OutlineNode[];
}
export interface OnOutlineUpdatePayload {
  docId?: string;
  outline: OutlineNode[];
}
export type OnOutlineUpdateMessage = BridgeEnvelope<'on_outline_update', OnOutlineUpdatePayload>;

export interface OnLinkClickPayload {
  href: string;
  text?: string;
  title?: string;
  isExternal: boolean;
}
export type OnLinkClickMessage = BridgeEnvelope<'on_link_click', OnLinkClickPayload>;

export interface OnImageErrorPayload {
  src: string;
  reason: 'load_failed' | 'not_found' | 'forbidden' | 'decode_failed' | 'unknown';
}
export type OnImageErrorMessage = BridgeEnvelope<'on_image_error', OnImageErrorPayload>;

export type WebToFlutterMessage =
  | OnContentChangeMessage
  | OnOutlineUpdateMessage
  | OnLinkClickMessage
  | OnImageErrorMessage;
```

### 2.4 Dart 对应类骨架

```dart
class BridgeEnvelope<T> {
  final int v;
  final String source;
  final String target;
  final String type;
  final String requestId;
  final int ts;
  final T payload;

  const BridgeEnvelope({
    required this.v,
    required this.source,
    required this.target,
    required this.type,
    required this.requestId,
    required this.ts,
    required this.payload,
  });
}

class InitDocPayload {
  final String markdown;
  final String? docId;
  final Map<String, int>? cursor;
  const InitDocPayload({required this.markdown, this.docId, this.cursor});

  Map<String, dynamic> toJson() => {
        'markdown': markdown,
        if (docId != null) 'docId': docId,
        if (cursor != null) 'cursor': cursor,
      };
}

class ThemePalettePayload {
  final String mode; // light/dark
  final Map<String, String> colors; // 12 色
  final String bodyFont;
  final String monoFont;
  final double sizePx;
  final double lineHeight;

  const ThemePalettePayload({
    required this.mode,
    required this.colors,
    required this.bodyFont,
    required this.monoFont,
    required this.sizePx,
    required this.lineHeight,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'colors': colors,
        'font': {
          'body': bodyFont,
          'mono': monoFont,
          'sizePx': sizePx,
          'lineHeight': lineHeight,
        },
      };
}

class ExecCmdPayload {
  final String cmd;
  final Map<String, dynamic>? args;
  const ExecCmdPayload({required this.cmd, this.args});
  Map<String, dynamic> toJson() => {'cmd': cmd, if (args != null) 'args': args};
}
```

---

## 3) 主题与样式无缝融合（CSS Variables 映射）

### 3.1 CSS（透明背景 + 变量占位）

```css
:root {
  --milkdown-color-primary: #4f46e5;
  --milkdown-color-on-primary: #ffffff;
  --milkdown-color-secondary: #64748b;
  --milkdown-color-on-secondary: #ffffff;
  --milkdown-color-surface: transparent;
  --milkdown-color-on-surface: #111827;
  --milkdown-color-background: transparent;
  --milkdown-color-on-background: #111827;
  --milkdown-color-error: #dc2626;
  --milkdown-color-on-error: #ffffff;
  --milkdown-color-outline: #cbd5e1;
  --milkdown-color-shadow: rgba(0, 0, 0, 0.12);
  --milkdown-font-body: "Noto Sans SC", sans-serif;
  --milkdown-font-mono: "JetBrains Mono", monospace;
  --milkdown-font-size: 16px;
  --milkdown-line-height: 1.7;
}

html,
body,
#app {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  background: transparent !important;
}

.milkdown {
  background: var(--milkdown-color-surface) !important;
  color: var(--milkdown-color-on-surface) !important;
  font-family: var(--milkdown-font-body);
  font-size: var(--milkdown-font-size);
  line-height: var(--milkdown-line-height);
}
```

### 3.2 JS（接收 `update_theme` 并动态注入变量）

```ts
type ThemeMsg = {
  type: 'update_theme';
  payload: {
    mode: 'light' | 'dark';
    colors: Record<string, string>;
    font: { body: string; mono: string; sizePx: number; lineHeight: number };
  };
};

const cssVarMap: Record<string, string> = {
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
  shadow: '--milkdown-color-shadow'
};

export function applyTheme(msg: ThemeMsg) {
  const root = document.documentElement;
  Object.entries(msg.payload.colors).forEach(([k, v]) => {
    const cssVar = cssVarMap[k];
    if (!cssVar) return;
    root.style.setProperty(cssVar, v);
  });
  root.style.setProperty('--milkdown-font-body', msg.payload.font.body);
  root.style.setProperty('--milkdown-font-mono', msg.payload.font.mono);
  root.style.setProperty('--milkdown-font-size', `${msg.payload.font.sizePx}px`);
  root.style.setProperty('--milkdown-line-height', `${msg.payload.font.lineHeight}`);
  root.setAttribute('data-theme-mode', msg.payload.mode);
}
```

---

## 4) Flutter 端核心 Widget 实现骨架（Dart）

> 依赖：`flutter_inappwebview`。  
> 目标：加载单文件 `index.html`、协议接收/下发、并解决本地相册图片插入后 WebView 可访问性问题。

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class MilkdownWebViewEditor extends StatefulWidget {
  final String initialMarkdown;
  final ValueChanged<String>? onContentChange;

  const MilkdownWebViewEditor({
    super.key,
    required this.initialMarkdown,
    this.onContentChange,
  });

  @override
  State<MilkdownWebViewEditor> createState() => _MilkdownWebViewEditorState();
}

class _MilkdownWebViewEditorState extends State<MilkdownWebViewEditor> {
  InAppWebViewController? _controller;
  final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
    documentRoot: 'assets/milkdown_web',
    port: 18765,
  );

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
    }
    _localhostServer.start();
  }

  @override
  void dispose() {
    _localhostServer.close();
    super.dispose();
  }

  Future<void> _sendMessage(Map<String, dynamic> msg) async {
    final encoded = jsonEncode(msg);
    await _controller?.evaluateJavascript(
      source: '''
        (function() {
          const m = $encoded;
          // 你可以在 web 侧提供 window.__USHIO_BRIDGE__.onFlutterMessage
          if (window.__USHIO_BRIDGE__ && window.__USHIO_BRIDGE__.onFlutterMessage) {
            window.__USHIO_BRIDGE__.onFlutterMessage(m);
          }
        })();
      ''',
    );
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('http://localhost:18765/index.html'),
      ),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        allowFileAccess: true,
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        disableContextMenu: true,
        supportZoom: false,
        builtInZoomControls: false,
        displayZoomControls: false,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;

        // JS -> Flutter 统一入口
        controller.addJavaScriptHandler(
          handlerName: 'bridge',
          callback: (args) async {
            if (args.isEmpty || args.first is! Map) return null;
            final map = Map<String, dynamic>.from(args.first as Map);
            final type = map['type'] as String?;
            switch (type) {
              case 'on_content_change':
                final payload = map['payload'] as Map?;
                final markdown = payload?['markdown'] as String?;
                if (markdown != null) widget.onContentChange?.call(markdown);
                break;
              case 'on_outline_update':
                // TODO: 同步目录树到 Flutter TOC 面板
                break;
              case 'on_link_click':
                // TODO: 由 Flutter 决定内部跳转 / 外部浏览器
                break;
              case 'on_image_error':
                // TODO: 记录日志并可触发降级占位图
                break;
            }
            return {'ok': true};
          },
        );
      },
      onLoadStop: (controller, _) async {
        // Flutter -> Web: 初始化文档
        await _sendMessage({
          'v': 1,
          'source': 'flutter',
          'target': 'web',
          'type': 'init_doc',
          'requestId': DateTime.now().microsecondsSinceEpoch.toString(),
          'ts': DateTime.now().millisecondsSinceEpoch,
          'payload': {'markdown': widget.initialMarkdown}
        });
      },

      // 关键难点：本地相册图片加载方案
      // 推荐：InAppLocalhostServer + 拷贝图片到 app 可控目录，再以 http://localhost:port/xxx 访问
      // 若必须直接访问 file:/// 也可拦截并映射，但兼容性与权限管理更复杂。
      shouldInterceptRequest: (controller, request) async {
        final uri = request.request.url;
        if (uri == null) return null;

        // 示例：自定义 appimg://<id> -> 实际本地文件 bytes
        if (uri.scheme == 'appimg') {
          final file = File('/data/user/0/com.example.app/files/images/${uri.host}');
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            return WebResourceResponse(
              data: bytes,
              contentType: 'image/png',
              statusCode: 200,
              reasonPhrase: 'OK',
            );
          }
          return WebResourceResponse(
            data: Uint8List(0),
            contentType: 'text/plain',
            statusCode: 404,
            reasonPhrase: 'Not Found',
          );
        }
        return null;
      },
    );
  }
}
```

### 4.1 图片插入落地建议（推荐路径）

1. Flutter 选择相册图片后，复制到应用私有目录（如 `.../files/md_images/`）。  
2. 通过 `InAppLocalhostServer` 暴露目录，生成 `http://localhost:18765/md_images/xxx.png`。  
3. 发送 `exec_cmd: insert_image`，参数中传 `src` 为该本地 HTTP 地址。  
4. Web 侧渲染 `<img>` 时无需额外权限弹窗，路径稳定、可控、可缓存。

---

## 5) Android 平台级体验调优策略

### 5.1 软键盘与光标遮挡

```dart
// 页面级：允许键盘抬起时 Flutter 布局收缩
return Scaffold(
  resizeToAvoidBottomInset: true,
  body: MilkdownWebViewEditor(...),
);
```

```ts
// Web 侧：在 selection/change/输入后确保光标所在块进入可视区
function ensureCaretVisible() {
  const sel = window.getSelection();
  if (!sel || !sel.rangeCount) return;
  const node = sel.anchorNode instanceof Element ? sel.anchorNode : sel.anchorNode?.parentElement;
  node?.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'smooth' });
}

document.addEventListener('selectionchange', () => {
  requestAnimationFrame(ensureCaretVisible);
});
```

### 5.2 禁用 Web 原生长按菜单/放大镜（由 Flutter 接管）

```dart
initialSettings: InAppWebViewSettings(
  disableContextMenu: true,
  // Android 长按文本选择控制（部分能力依赖系统 WebView 版本）
  // 可结合 CSS user-select 与 JS touch 事件进一步限制。
),
```

```css
html, body, .milkdown {
  -webkit-touch-callout: none; /* 禁用 iOS/Android 长按菜单 */
}

.milkdown [contenteditable="true"] {
  -webkit-user-select: text; /* 仍允许正常文本编辑选择 */
  user-select: text;
}
```

```ts
// 如需彻底接管上下文菜单，可在特定区域阻止长按默认行为
document.addEventListener(
  'contextmenu',
  (e) => {
    e.preventDefault();
  },
  { passive: false }
);
```

---

## 实施顺序建议（对应四阶段迁移）

1. **先协议后 UI**：先打通 `init_doc` / `on_content_change`，确认数据闭环。  
2. **再主题融合**：完成 `update_theme -> CSS Variables`，保证视觉一致。  
3. **再命令系统**：引入 `exec_cmd`（撤销/重做/插图/格式命令）。  
4. **最后平台细节**：图片资源路由、键盘滚动、长按菜单接管与性能压测。  

这套 LLD 的重点是“协议稳定 + 主题可注入 + 资源可控”，可在不破坏 Flutter 外壳架构的前提下持续迭代 Milkdown 内核能力。

---

## 以下是以上内容的评论

### 🚨 避坑指南（AI 代码中需要微调的 3 个关键点）

AI 虽然强大，但在某些库的最新 API 细节和 Android 平台的玄学问题上，仍有一点点瑕疵，**你在真正写代码时请务必修正以下三点**：

#### ⚠️ 坑点 1：Milkdown v7 的动态内容替换 API 有误
在 **1.3 `main.ts`** 中，AI 给出的从 Flutter 接收 Markdown 并更新编辑器的代码是：
```typescript
// AI 的错误写法
setMarkdownFromFlutter = (md: string) => {
  instance.action((ctx) => {
    ctx.set(defaultValueCtx, md); // 这里有问题！
  });
};
```
**修正原因：** 在 Milkdown v7 中，`defaultValueCtx` 只在编辑器**初次创建**时生效。如果编辑器已经 Ready，你要全量替换内容，不能重置这个 Context，而应该调用 ProseMirror 的事务（Transaction）或内置命令。
**正确写法（复制替换这一段）：**
```typescript
import { replaceAll } from '@milkdown/utils';

// ... 
setMarkdownFromFlutter = (md: string) => {
  instance.action(replaceAll(md));
};
```

#### ⚠️ 坑点 2：Android 光标滚动的防抖与触发时机
在 **5.1 软键盘与光标遮挡** 中，AI 建议监听 `selectionchange` 并调用 `scrollIntoView`。
**修正原因：** `selectionchange` 触发频率极高（你每打一个字母都会触发）。如果你在 Android WebView 里一直执行 `scrollIntoView`，页面会发生剧烈的神经质抖动（Jitter）。
**正确写法：** 
ProseMirror 底层其实自己有一套极其优秀的光标滚动机制。你不需要手写 `scrollIntoView`，你只需要确保 Flutter 层的 `resizeToAvoidBottomInset: true` 是开启的。如果一定要手动干预，应该监听 Android 窗口 resize 事件（即键盘弹出时），而不是光标变化事件：
```typescript
// 建议替换为监听窗口大小变化（通常代表键盘弹出/收起）
window.addEventListener('resize', () => {
    // 稍微延迟，等待 Android 键盘完全弹出
    setTimeout(() => {
        const sel = window.getSelection();
        if (!sel || !sel.rangeCount) return;
        const node = sel.anchorNode instanceof Element ? sel.anchorNode : sel.anchorNode?.parentElement;
        node?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }, 200);
});
```

#### ⚠️ 坑点 3：InAppLocalhostServer 的端口冲突风险
在 Dart 代码中，AI 硬编码了 `port: 18765`。
**修正原因：** 在极少数 Android 手机上，某个特定端口可能被后台进程占用，导致 Server 启动失败。
**建议：** 最好使用动态端口分配，或者捕获异常。`InAppLocalhostServer` 实际上支持不传端口让系统自动分配空闲端口，然后你再获取它。
```dart
// 建议的做法
final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
  documentRoot: 'assets/milkdown_web',
  // 不传 port 或传 0，系统会自动分配
);

// 在 initState 中 start 后，获取真实端口
await _localhostServer.start();
int port = _localhostServer.port;
// 随后 WebView 加载 http://localhost:$port/index.html
```
