# Milkdown 渲染引擎迁移状态文档

## 1. 结论

**当前仓库尚未完成“完全迁移到 Milkdown 渲染引擎”。**

现状更准确地说是：

- **Milkdown 方案的设计文档已经完成**，并且仓库中已经落地了一个以 `Milkdown` 命名的 Flutter/WebView bridge 原型。
- **实际运行中的编辑器预览/渲染主路径，仍然使用现有的 `WebViewMarkdownPreview` 自研 HTML 渲染方案。**
- **Milkdown Web 编辑器组件 `MilkdownWebViewEditor` 目前未接入主编辑器页面，也没有证据表明 `assets/milkdown_web/index.html` 已真正加载 Milkdown 运行时。**
- 因此，README 中“已全部迁移完成”的表述，与当前代码状态**不一致**。

---

## 2. 本次核查范围

本次迁移状态核查基于以下仓库对象：

- Flutter 编辑器主页面与预览页面
- `WebViewMarkdownPreview` 现行渲染实现
- `MilkdownWebViewEditor` bridge 封装
- `assets/milkdown_web/index.html` Web 端实现
- `pubspec.yaml` 依赖与资源声明
- 现有测试与设计文档、README

---

## 3. 总体状态判定

| 维度 | 状态 | 判定 |
| --- | --- | --- |
| 设计方案（LLD） | 已完成 | 已有完整 Milkdown LLD 文档 |
| Flutter 侧 bridge 模型 | 部分完成 | `milkdown_bridge.dart` 已落地 |
| Flutter 侧 Milkdown WebView 组件 | 部分完成 | `MilkdownWebViewEditor` 已实现，但未接入主路径 |
| Web 端 Milkdown 运行时 | 未完成 | `index.html` 未见 Milkdown 依赖加载与 Editor 初始化 |
| 编辑器主界面接入 | 未完成 | 主编辑器仍使用 `WebViewMarkdownPreview` |
| 预览渲染主链路替换 | 未完成 | 预览与分屏仍为旧方案 |
| 依赖治理 | 未完成 | 仍保留 `flutter_markdown_plus`，且仓库无 Milkdown 前端构建工程 |
| 测试验收 | 未完成 | 仅有 bridge model 测试，缺少集成验收 |

> 结论：**迁移处于“方案完成 + 原型落地 + 主链路未切换”的阶段，不应认定为 fully migrated。**

---

## 4. 已完成事项

### 4.1 设计文档已完成

仓库已存在 Milkdown 详细设计文档 `docs/webview-milkdown-lld.md`，说明团队已经明确了目标架构、桥接协议、主题同步和 WebView 方案。

### 4.2 Flutter 侧协议模型已建立

以下能力已具备：

- 通用桥接包络 `BridgeEnvelope`
- 初始化文档载荷 `InitDocPayload`
- 主题同步载荷 `ThemePalettePayload`
- 执行命令载荷 `ExecCmdPayload`
- 图片报错、目录更新、链接点击等回调载荷

这说明 **Milkdown 通信协议层已具备基础可用性**。

### 4.3 `MilkdownWebViewEditor` 组件已实现原型

Flutter 侧已经有独立组件负责：

- 加载 `assets/milkdown_web/index.html`
- 注入初始化文档
- 下发主题
- 下发编辑命令（如 `toggle_bold` / `toggle_italic` / `insert_table`）
- 接收 `on_content_change` / `on_outline_update` / `on_link_click` / `on_image_error`

这说明 **Flutter 壳层并非空白，而是已经进入原型实现阶段**。

### 4.4 已有基础单元测试

目前已有：

- `test/models/milkdown_bridge_test.dart`：覆盖 bridge payload 序列化/反序列化
- `test/widgets/webview_markdown_preview_test.dart`：覆盖现行预览方案的数学公式检测逻辑

---

## 5. 未完成事项 / 阻塞项

### 5.1 主编辑器没有接入 `MilkdownWebViewEditor`

主编辑器页面 `lib/screens/editor_screen.dart` 中：

- 预览模式使用的是 `WebViewMarkdownPreview`
- 分屏模式右侧预览也使用 `WebViewMarkdownPreview`

仓库检索结果表明：

- `MilkdownWebViewEditor` 只有定义，没有被主界面引用
- 当前实际 UI 链路没有切到 Milkdown 组件

这意味着：**用户实际使用到的并不是 Milkdown 渲染/编辑引擎。**

### 5.2 现行渲染核心仍是 `WebViewMarkdownPreview`

`lib/widgets/webview_markdown_preview.dart` 仍在负责：

- Markdown 到 HTML 的转换
- KaTeX 条件加载判断
- 本地图片路径处理
- 复选框交互
- 目录跳转
- 截图导出
- 原地编辑映射

这表明当前主链路本质上仍是：

**Dart `markdown` 解析 + 自定义 HTML 模板 + WebView 展示**

而不是：

**Milkdown / ProseMirror 驱动的统一编辑渲染内核**

### 5.3 `assets/milkdown_web/index.html` 不是 Milkdown 运行时页面

虽然文件命名为 `milkdown_web/index.html`，但当前实现特征显示它更像一个轻量 bridge mock：

- 没有 `@milkdown/*` 包的实际加载痕迹
- 没有 Vite 构建产物引用
- 没有 `Editor.make()` / `Editor.create()` 等初始化逻辑
- DOM 主体只是一个普通 `div#app`
- 内容写入方式是 `app.textContent = text`
- `toggle_bold` / `toggle_italic` 等命令只是字符串包裹，不是文档模型级编辑

因此，这个页面**目前不是一个真正的 Milkdown 编辑器实例**。

### 5.4 仓库中不存在 Milkdown 前端构建工程

LLD 中描述了前端构建工程和 `@milkdown/*` npm 依赖，但仓库当前未发现：

- `package.json`
- `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock`
- `vite.config.*`
- 独立的 Milkdown web source tree

这说明：

- LLD 中的前端构建部分尚未真正落库；或
- 相关工程未提交到当前仓库。

无论哪种情况，都不能视为“已全部迁移完成”。

### 5.5 旧方案依赖仍然保留

`pubspec.yaml` 中仍保留：

- `flutter_markdown_plus`
- `markdown`
- `flutter_highlight`

其中：

- `flutter_markdown_plus` 仍被设置页、关于页等页面直接使用
- `markdown` 包仍被 `WebViewMarkdownPreview` 用于 Markdown → HTML 转换

这说明仓库仍处于**新旧方案并存**状态，而非 Milkdown 一统。

### 5.6 README 当前状态声明与代码不一致

README 当前写明：

- “✅ 当前迁移状态：已全部迁移完成（阶段 1～4 已在仓库内落地并完成首轮验收）”

但结合实际代码状态，该表述过于超前，容易误导维护者、测试人员和外部贡献者。

---

## 6. 模块级迁移状态

### 6.1 编辑器主界面

**状态：未迁移完成**

现状：

- 编辑模式仍然是 Flutter `TextField` / `TextEditingController` 主导
- 预览模式与分屏预览仍然走 `WebViewMarkdownPreview`
- 原地编辑逻辑仍然围绕旧预览方案的 block 映射实现

影响：

- 编辑与渲染并未共享统一文档模型
- 不能享受 Milkdown/ProseMirror 的 schema、transaction、plugin 体系

### 6.2 预览渲染层

**状态：未迁移完成**

现状：

- 仍使用 Dart 侧 Markdown 转 HTML
- HTML 由 WebView 承载
- 预览增强功能（数学公式、图片、本地链接、checkbox）都是在现有方案上追加的

影响：

- 该层仍是自定义渲染器，不是 Milkdown 渲染器

### 6.3 Web 端编辑内核

**状态：原型 / mock 阶段**

现状：

- bridge 协议有了
- 命令分发有了
- 但文档模型、selection、transaction、插件系统并不存在

影响：

- 无法证明当前 Web 端具备真正 Milkdown 编辑能力

### 6.4 Bridge 协议

**状态：部分完成**

已具备：

- 初始化文档
- 更新主题
- 执行命令
- 内容变化回调
- 目录更新回调
- 链接点击 / 图片异常回调

缺失：

- 更细粒度的 selection / transaction 同步
- 插件生命周期事件
- 文档 schema 与能力协商
- 出错恢复与版本兼容策略

### 6.5 测试与验收

**状态：未完成**

缺少：

- `MilkdownWebViewEditor` widget test / integration test
- Flutter ↔ Web bridge 端到端测试
- 实际文档编辑回归测试
- 与旧预览方案的功能对齐验收清单

---

## 7. 风险清单

### 7.1 文档与实现不一致风险

如果继续沿用“已全部迁移完成”的对外表述，会导致：

- 新开发者误判架构现状
- 后续任务拆解出现偏差
- 测试用例基线错误
- 发布说明与真实能力不一致

### 7.2 双栈并存复杂度风险

当前存在：

- 旧的 Markdown 渲染路径
- 新的 Milkdown bridge 原型路径

如果长时间并存但不设冻结边界，会导致：

- 能力重复建设
- bug 修复要维护两套逻辑
- 主题、链接、图片、数学公式等行为逐渐分叉

### 7.3 迁移“卡在原型层”风险

目前最明显的问题不是“完全没做”，而是：

**已经做了不少外围封装，但主链路尚未切换。**

这类阶段最容易出现：

- 看起来快完成
- 实际关键替换尚未发生
- 文档先于代码宣布完成

---

## 8. 建议的正式迁移口径

建议后续对内/对外统一使用如下表述：

> Milkdown 迁移目前已完成设计与 Flutter bridge 原型落地，但编辑器主链路仍运行在现有 WebViewMarkdownPreview 渲染方案上，尚未完成最终切换与验收。

这一定义更贴近真实状态，也更利于继续推进。

---

## 9. 建议的下一步工作清单

### P0：先修正文档状态

- 修正 README 中“已全部迁移完成”的表述
- 将本文件作为迁移状态基线文档
- 明确区分“LLD 目标架构”与“当前已落地实现”

### P1：完成主链路接入

- 在 `EditorScreen` 中用 `MilkdownWebViewEditor` 替换当前预览/编辑链路中的关键节点
- 明确 split / preview / full-screen 三种模式下的统一内核
- 确定文本编辑区是否仍保留 Flutter 原生编辑器，还是整体转向 Web 编辑器

### P2：补齐真正的 Milkdown 前端工程

- 提交独立 web 源码目录
- 引入 `package.json` 与锁文件
- 提交 Vite 或等效构建配置
- 在产物中真正初始化 Milkdown Editor 与所需插件

### P3：完成功能对齐

至少补齐并验收以下能力：

- GFM
- 代码高亮
- 数学公式
- 表格编辑
- 图片解析与本地路径处理
- 目录同步
- 链接点击处理
- 主题变量同步
- undo / redo

### P4：补齐验收测试

建议新增：

- bridge 协议端到端测试
- `MilkdownWebViewEditor` 集成测试
- 预览/分屏/全屏回归测试
- 核心 Markdown 样例快照测试

---

## 10. 当前最终判定

**最终判定：未完全迁移。**

更准确的阶段描述是：

**“Milkdown 迁移已完成方案设计与局部原型实现，但尚未完成主渲染链路切换、前端运行时落地和最终验收。”**
