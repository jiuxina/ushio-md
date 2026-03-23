# Ushio Milkdown Web Source

此目录用于承载 Milkdown Web 端源码与开发配置。

## 当前结构

- `index.html`: 本地开发入口。
- `src/main.js`: Milkdown 初始化与 Flutter bridge 逻辑。
- `src/style.css`: 主题与基础排版样式。
- `vite.config.mjs`: 本地调试配置。
- `dist/index.html`: 构建产物（单文件）。

> 运行时产物当前同步放在 `assets/milkdown_web/` 目录下，由 Flutter `InAppLocalhostServer` 直接提供给 WebView 加载。

## 构建与同步（Phase A）

在仓库根目录执行：

```bash
cd /home/runner/work/ushio-md/ushio-md/web/milkdown
npm install
npm run build
cp dist/index.html /home/runner/work/ushio-md/ushio-md/assets/milkdown_web/index.html
```

说明：

- `vite-plugin-singlefile` 会将 JS/CSS 内联到 `dist/index.html`，产物可离线运行。
- `assets/milkdown_web/` 当前仅需 `index.html` 一个运行时文件。
