# Ushio Milkdown Web Source

此目录用于承载 Milkdown Web 端源码与开发配置。

## Runtime Rule (Important)

- `web/milkdown/src/*` 是源码。
- `assets/milkdown_web/index.html` 是 Flutter WebView 实际加载的运行时文件。
- 仅修改源码不会直接在 App 生效，必须重新构建并同步产物。

## 当前结构

- `index.html`: 本地开发入口。
- `src/main.js`: Milkdown 初始化与 Flutter bridge 逻辑。
- `src/style.css`: 主题与基础排版样式。
- `vite.config.mjs`: 本地调试配置。
- `dist/index.html`: 构建产物（单文件）。

> 运行时产物当前同步放在 `assets/milkdown_web/` 目录下，由 Flutter `InAppLocalhostServer` 直接提供给 WebView 加载。

## 构建与同步（Phase A）

在 `web/milkdown/` 执行：

```bash
npm install
npm run build
```

在仓库根目录同步产物（Windows）：

```bat
copy /Y web\milkdown\dist\index.html assets\milkdown_web\index.html
```

推荐发布方式：

```bat
build_abi_release.bat
```

该脚本已内置：Node 检查 -> Web 构建 -> 产物同步 -> Flutter ABI release 打包。

说明：

- `vite-plugin-singlefile` 会将 JS/CSS 内联到 `dist/index.html`，产物可离线运行。
- `assets/milkdown_web/` 当前仅需 `index.html` 一个运行时文件。

## 常见陷阱

### 改了 `src/*` 但 App 没变化

请按顺序检查：

1. `npm run build` 是否成功。
2. 是否已复制 `dist/index.html` 到 `assets/milkdown_web/index.html`。
3. 是否重新启动应用验证。

### 依赖安装不一致

发布构建请使用 `npm ci`（而非 `npm install`），确保 lockfile 驱动的可复现依赖。

## 相关文档

- 统一构建流程：`docs/build-workflow.md`
