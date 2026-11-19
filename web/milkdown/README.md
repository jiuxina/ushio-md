# Ushio Milkdown Web Source

此目录用于承载 Milkdown Web 端源码与开发配置。

## Runtime Rule (Important)

- `web/milkdown/src/*` 是源码。
- `assets/milkdown_web/index.html` 是 Flutter WebView 实际加载的运行时文件。
- 仅修改源码不会直接在 App 生效，必须重新构建并同步产物。

## 当前结构

- `index.html`: 本地开发入口。
- `src/main.js`: Milkdown 初始化与 Flutter bridge 逻辑。
- `src/theme-palette.mjs`: 文档与界面浮层的颜色映射。
- `src/style.css`: 主题、浮层和基础排版样式。
- `vite.config.mjs`: 本地调试配置。
- 构建产物包含编辑器和 PDF 数学渲染两个 HTML 入口，以及独立的 JS、CSS 和字体资源，全部平铺在输出目录中。

> 运行时产物同步放在 `assets/milkdown_web/` 目录下，由 `MilkdownAssetServer` 提供给 WebView。必须同步整个构建目录，不能只复制 `index.html`。

## 构建与同步

在仓库根目录执行：

```powershell
.\scripts\sync_milkdown_web.bat
```

脚本使用 `npm ci` 安装 lockfile 中的依赖，构建到仓库 `build/` 下的独立目录，再调用 `sync_milkdown_assets.ps1` 将全部资源同步到运行时目录。旧运行时目录会移入回收站。

只验证 Web 构建时，可在 `web/milkdown/` 执行：

```powershell
npm ci
npm run build
```

## 浮层可读性

文档使用 `surface`、`background`、`onSurface` 等原有颜色；应用界面浮层使用独立的 `overlay*` 颜色。链接预览、右键菜单、表格工具、Slash 菜单及图片/代码工具的衬底和前景由 Flutter 的模态表面配色生成，避免自定义正文色或卡片透明度让操作文字难以辨认。

- `overlaySurface` 以 RGBA 传入，保留衬底透明度。
- 主文字、说明、强调色、图标和描边各有独立颜色；选中/悬停使用配套的容器及前景色。
- 缺少 `overlay*` 字段的旧调用方仍可使用 CSS 中的浅色/深色默认值。
- 这些颜色只作用于界面控件，不改变文档正文、代码高亮、HTML 内容或导出的排版。
- 浮层可用高度同时考虑浏览器可见区域与 Flutter 的键盘、顶部栏及工具栏遮挡；较长内容在剩余区域内滚动。

验证颜色桥接的最小测试：

```powershell
node node_modules/vitest/vitest.mjs run src/__tests__/theme-palette.test.mjs
```

## 常见陷阱

### 改了 `src/*` 但 App 没变化

请按顺序检查：

1. `npm run build` 是否成功。
2. 是否已通过同步脚本更新 `assets/milkdown_web/` 的全部资源。
3. 是否重新启动应用验证。

### 依赖安装不一致

发布构建请使用 `npm ci`（而非 `npm install`），确保 lockfile 驱动的可复现依赖。

## 相关文档

- 统一构建流程：`docs/build-workflow.md`
