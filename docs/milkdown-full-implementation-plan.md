# Milkdown 官方全量能力实现计划（基于差异对照表）

> 基准文档：`/home/runner/work/ushio-md/ushio-md/docs/milkdown-feature-gap-analysis.md`  
> 目标：分阶段补齐“官方已具备、当前项目未实现或仅部分实现”的能力。  
> 约束：保持 Flutter ↔ Web Bridge 协议兼容，按最小可回滚批次推进。

---

## 总体阶段与执行顺序

- [x] **Step 1：依赖与基线收敛（已完成）**
  - 将 Milkdown 核心依赖升级到官方最新稳定线（v7.19.1，`plugin-math` 为官方可用最新 7.5.9）。
  - 重新生成 web lockfile，重建单文件运行时产物并同步到 `assets/milkdown_web/index.html`。
  - 验证 `web/milkdown` 构建通过，保持现有 bridge 与命令行为不变。

- [x] **Step 2：接入官方 `plugin-history` 并替换当前部分实现（已完成）**
  - 从“直接调用 `@milkdown/prose/history`”迁移到官方 history 插件封装。
  - 保持 `exec_cmd -> undo/redo -> on_cmd_result` 回执协议不变。
  - 补单测/回归用例，确保撤销重做行为一致。

- [x] **Step 3：接入官方 `plugin-tooltip`（已完成）**
  - 落地基础 tooltip 体验（链接/格式化提示能力）并与现有样式融合。
  - 校验只读态与编辑态的 tooltip 行为差异。

- [x] **Step 4：接入官方 `plugin-slash`（已完成）**
  - 实现最小可用斜杠菜单（标题、列表、表格、引用、代码块、图片等常用项）。
  - 与现有工具栏命令体系并存，避免功能冲突。

- [x] **Step 5：接入官方 `plugin-block`（已完成）**
  - 打通块级操作增强能力，验证与目录跳转/高亮动画共存。

- [x] **Step 6：接入官方 `plugin-indent`（已完成）**
  - 补齐列表/引用缩进能力并验证键盘行为与历史记录兼容性。

- [x] **Step 7：接入官方 `plugin-trailing`（已完成）**
  - 优化文末可输入体验，验证大文档与长列表场景。

- [ ] **Step 8：接入官方 `plugin-clipboard`**
  - 对齐复制粘贴行为，确保 WebView 环境与原有交互一致。

- [ ] **Step 9：接入官方 `plugin-upload` 并桥接现有图片流**
  - 将现有 Flutter 文件选择 + `insert_image` 能力接入 upload 插件链路。
  - 统一本地路径、相对路径、外链路径策略与错误回执。

- [ ] **Step 10：补齐测试、文档与发布验收**
  - 增补桥接消息分发、命令结果、关键插件交互回归测试。
  - 更新迁移状态文档、README 升级说明、设备回归清单。
  - 固化“升级检查 + 回滚准则 + 兼容性矩阵”。

---

## Step 1 完成记录（本次已落地）

### 已执行变更

1. 升级 `web/milkdown/package.json` 依赖版本：
   - `@milkdown/core`: `7.19.1`
   - `@milkdown/plugin-listener`: `7.19.1`
   - `@milkdown/plugin-prism`: `7.19.1`
   - `@milkdown/preset-commonmark`: `7.19.1`
   - `@milkdown/preset-gfm`: `7.19.1`
   - `@milkdown/theme-nord`: `7.19.1`
   - `@milkdown/utils`: `7.19.1`
   - `@milkdown/plugin-math`: `7.5.9`（官方可用最新，npm 标记 deprecated）

2. 刷新锁文件并重建产物：
   - 更新 `web/milkdown/package-lock.json`
   - 构建 `web/milkdown/dist/index.html`
   - 同步到运行时：`assets/milkdown_web/index.html`

3. 清理构建临时目录追踪风险：
   - `.gitignore` 新增 `web/milkdown/node_modules/` 与 `web/milkdown/dist/`。

### 已完成验证

- 在 `web/milkdown` 执行 `npm run build` 通过（升级后构建成功）。
