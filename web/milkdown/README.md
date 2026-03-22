# Ushio Milkdown Web Source

此目录用于承载 Milkdown Web 端源码与开发配置。

## 当前结构

- `index.html`: 本地开发入口。
- `src/main.js`: Milkdown 初始化与 Flutter bridge 逻辑。
- `src/style.css`: 主题与基础排版样式。
- `vite.config.mjs`: 本地调试配置。

> 运行时产物当前同步放在 `assets/milkdown_web/` 目录下，由 Flutter `InAppLocalhostServer` 直接提供给 WebView 加载。
