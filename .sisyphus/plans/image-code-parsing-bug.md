# Fix Image/Code Block Parsing Bug

## TL;DR

> **Quick Summary**: Fix index-based matching bug in `syncRenderedDom()` that causes images to show broken and code block language identifiers to be incorrect when surrounded by headings/links. Replace array index matching with position-based matching.
> 
> **Deliverables**:
> - Test infrastructure using Node.js built-in `node:test`
> - Unit tests for matching functions
> - Fixed `syncRenderedDom()` function with reliable position-based matching
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 2 waves
> **Critical Path**: Test Setup → Unit Tests → Fix Implementation → Verification

---

## Context

### Original Request
用户报告：在 Milkdown 编辑器中，当图片或代码块的上文和下文都有标题或链接时，图片显示裂图，代码块语言标识解析错误。

### Interview Summary
**Key Discussions**:
- Bug 触发条件：图片/代码块的**上下文同时存在**标题或链接语法内容
- 表现：代码块有语法高亮但语言标识错误
- 测试策略：TDD（测试驱动开发）

**Research Findings**:
- 根因：`syncRenderedDom()` 使用数组索引匹配 markdown 文本顺序和 DOM 顺序
- 当存在标题/链接时，remark AST 转换可能改变 DOM 节点顺序，导致索引错位
- 代码块语言匹配同样受此影响

### Metis Review
**Identified Gaps** (addressed):
- 缺少测试基础设施 → 添加 `node:test`
- 未考虑边界情况（数量不匹配、空语言标识）→ 添加边界测试
- 可能的范围蔓延 → 明确 guardrails

---

## Work Objectives

### Core Objective
修复 `syncRenderedDom()` 中的索引匹配逻辑，确保图片和代码块始终正确解析，不受上下文影响。

### Concrete Deliverables
- `web/milkdown/test/sync-rendered-dom.test.js` - 单元测试文件
- `web/milkdown/src/main.js` - 修复后的 `syncRenderedDom()` 函数

### Definition of Done
- [ ] 单元测试覆盖：标题+图片+链接场景
- [ ] 单元测试覆盖：标题+代码块+链接场景
- [ ] 所有测试通过
- [ ] 原有问题场景验证通过

### Must Have
- 图片 `data-ushio-src` 属性正确匹配 markdown 中的图片源
- 代码块语言标识正确显示

### Must NOT Have (Guardrails)
- 不得修改 markdown 解析逻辑或 remark 插件
- 不得修改 DOM 渲染行为（仅修改匹配逻辑）
- 不得添加新依赖（使用 Node.js 内置测试框架）
- 不得重构相邻代码（heading 匹配逻辑保持不变）
- 不得添加超出最小需求的测试基础设施

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: NO (需要创建)
- **Automated tests**: YES (TDD)
- **Framework**: `node:test` + `node:assert` (Node.js 内置，零依赖)

### QA Policy
Every task MUST include agent-executed QA scenarios.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately - 测试基础设施 + 测试用例):
├── Task 1: 添加 Node.js 测试配置 [quick]
├── Task 2: 编写图片匹配单元测试 [quick]
└── Task 3: 编写代码块语言匹配单元测试 [quick]

Wave 2 (After Wave 1 - 实现 + 验证):
├── Task 4: 重构图片匹配逻辑 [unspecified-high]
├── Task 5: 重构代码块语言匹配逻辑 [unspecified-high]
└── Task 6: 集成测试 + 回归验证 [unspecified-high]

Wave FINAL (After ALL tasks):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
```

### Dependency Matrix
- **1**: - - 4, 5, 1
- **2**: 1 - 4, 1
- **3**: 1 - 5, 1
- **4**: 2 - 6, 1
- **5**: 3 - 6, 1
- **6**: 4, 5 - F1-F4, 1

### Agent Dispatch Summary
- **Wave 1**: **3** - T1 → `quick`, T2 → `quick`, T3 → `quick`
- **Wave 2**: **3** - T4 → `unspecified-high`, T5 → `unspecified-high`, T6 → `unspecified-high`
- **FINAL**: **4** - F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 1. **添加 Node.js 测试基础设施**

  **What to do**:
  - 在 `web/milkdown/package.json` 添加测试脚本
  - 创建 `web/milkdown/test/` 目录
  - 使用 Node.js 内置 `node:test` 和 `node:assert`（零依赖）

  **Must NOT do**:
  - 不得添加 vitest、jest 等外部测试框架
  - 不得修改现有构建配置

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 简单的配置修改，无需复杂决策
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 2, 3, 4, 5
  - **Blocked By**: None

  **References**:
  - `web/milkdown/package.json` - 添加 `"test": "node --test test/*.test.js"` 脚本

  **Acceptance Criteria**:
  - [ ] `package.json` 包含 `test` 脚本
  - [ ] `test/` 目录存在
  - [ ] 运行 `npm test` 不报错（即使没有测试文件）

  **QA Scenarios**:
  ```
  Scenario: 测试脚本可执行
    Tool: Bash
    Steps:
      1. cd web/milkdown && npm test
    Expected Result: 命令执行成功，无 fatal error
    Evidence: .sisyphus/evidence/task-1-test-script.txt
  ```

  **Commit**: YES
  - Message: `test(milkdown): add node:test infrastructure`
  - Files: `web/milkdown/package.json`

- [ ] 2. **编写图片匹配单元测试**

  **What to do**:
  - 创建 `web/milkdown/test/image-matching.test.js`
  - 测试 `collectMarkdownImageSources()` 函数
  - 测试场景：
    1. 简单图片（无标题/链接）
    2. 标题 + 图片 + 链接（bug 触发场景）
    3. 多图片 + 标题穿插
    4. 图片在代码块内（应跳过）

  **Must NOT do**:
  - 不得修改 `collectMarkdownImageSources()` 函数
  - 不得引入 jsdom 或浏览器环境模拟

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 纯函数测试，逻辑清晰
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 4
  - **Blocked By**: Task 1

  **References**:
  - `web/milkdown/src/main.js:375-411` - `collectMarkdownImageSources()` 函数实现

  **Acceptance Criteria**:
  - [ ] 测试文件存在
  - [ ] 所有测试用例通过
  - [ ] 覆盖 bug 触发场景

  **QA Scenarios**:
  ```
  Scenario: 图片匹配测试通过
    Tool: Bash
    Steps:
      1. cd web/milkdown && node --test test/image-matching.test.js
    Expected Result: 所有测试通过
    Evidence: .sisyphus/evidence/task-2-image-test.txt
  ```

  **Commit**: YES
  - Message: `test(milkdown): add unit tests for image source collection`
  - Files: `web/milkdown/test/image-matching.test.js`

- [ ] 3. **编写代码块语言匹配单元测试**

  **What to do**:
  - 创建 `web/milkdown/test/codeblock-language.test.js`
  - 测试 `collectFenceLanguages()` 函数
  - 测试场景：
    1. 简单代码块
    2. 标题 + 代码块 + 链接（bug 触发场景）
    3. 多代码块 + 标题穿插
    4. 无语言标识的代码块

  **Must NOT do**:
  - 不得修改 `collectFenceLanguages()` 函数
  - 不得引入浏览器环境模拟

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 纯函数测试，逻辑清晰
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 5
  - **Blocked By**: Task 1

  **References**:
  - `web/milkdown/src/main.js:359-373` - `collectFenceLanguages()` 函数实现

  **Acceptance Criteria**:
  - [ ] 测试文件存在
  - [ ] 所有测试用例通过
  - [ ] 覆盖 bug 触发场景

  **QA Scenarios**:
  ```
  Scenario: 代码块语言测试通过
    Tool: Bash
    Steps:
      1. cd web/milkdown && node --test test/codeblock-language.test.js
    Expected Result: 所有测试通过
    Evidence: .sisyphus/evidence/task-3-codeblock-test.txt
  ```

  **Commit**: YES
  - Message: `test(milkdown): add unit tests for fence language collection`
  - Files: `web/milkdown/test/codeblock-language.test.js`

- [ ] 4. **重构图片匹配逻辑**

  **What to do**:
  - 修改 `syncRenderedDom()` 中图片匹配逻辑（main.js:1495-1544）
  - 实现基于位置的匹配：
    1. 为每个图片元素计算其在文档中的位置
    2. 使用位置信息匹配 markdown 中的图片源
  - 保留现有 fallback 逻辑和错误处理

  **Must NOT do**:
  - 不得修改 `collectMarkdownImageSources()` 函数
  - 不得修改 DOM 渲染行为
  - 不得删除现有的 `data-ushio-src` 等属性设置

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 需要理解现有逻辑并谨慎修改
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5)
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `web/milkdown/src/main.js:1491-1544` - 当前图片匹配逻辑
  - `web/milkdown/src/main.js:1561-1621` - 参考：heading 匹配模式（使用 consumed Set）

  **Acceptance Criteria**:
  - [ ] 图片匹配不再依赖数组索引
  - [ ] 单元测试仍然通过
  - [ ] 现有功能不受影响

  **QA Scenarios**:
  ```
  Scenario: 图片正确匹配（标题+图片+链接）
    Tool: Bash
    Steps:
      1. 运行单元测试
      2. 检查修改后的代码逻辑
    Expected Result: 测试通过，逻辑正确
    Evidence: .sisyphus/evidence/task-4-image-fix.txt

  Scenario: 回归测试（简单图片）
    Tool: Bash
    Steps:
      1. 测试无标题/链接的图片场景
    Expected Result: 仍然正常工作
    Evidence: .sisyphus/evidence/task-4-regression.txt
  ```

  **Commit**: YES
  - Message: `fix(milkdown): use position-based matching for images in syncRenderedDom`
  - Files: `web/milkdown/src/main.js`

- [ ] 5. **重构代码块语言匹配逻辑**

  **What to do**:
  - 修改 `syncRenderedDom()` 中代码块语言匹配逻辑（main.js:1635-1684）
  - 实现基于位置的匹配：
    1. 为每个代码块元素计算其在文档中的位置
    2. 使用位置信息匹配 markdown 中的 fence 语言
  - 保留现有 fallback 逻辑

  **Must NOT do**:
  - 不得修改 `collectFenceLanguages()` 函数
  - 不得修改代码块渲染行为
  - 不得删除现有的语言按钮逻辑

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 需要理解现有逻辑并谨慎修改
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 1, 3

  **References**:
  - `web/milkdown/src/main.js:1635-1684` - 当前代码块语言匹配逻辑

  **Acceptance Criteria**:
  - [ ] 语言匹配不再依赖数组索引
  - [ ] 单元测试仍然通过
  - [ ] 现有功能不受影响

  **QA Scenarios**:
  ```
  Scenario: 代码块语言正确匹配（标题+代码块+链接）
    Tool: Bash
    Steps:
      1. 运行单元测试
      2. 检查修改后的代码逻辑
    Expected Result: 测试通过，逻辑正确
    Evidence: .sisyphus/evidence/task-5-codeblock-fix.txt

  Scenario: 回归测试（简单代码块）
    Tool: Bash
    Steps:
      1. 测试无标题/链接的代码块场景
    Expected Result: 仍然正常工作
    Evidence: .sisyphus/evidence/task-5-regression.txt
  ```

  **Commit**: YES
  - Message: `fix(milkdown): use position-based matching for code block languages`
  - Files: `web/milkdown/src/main.js`

- [ ] 6. **集成测试 + 回归验证**

  **What to do**:
  - 创建 `web/milkdown/test/integration.test.js`
  - 测试完整的 bug 触发场景：
    ```markdown
    # qaa.md
    
    ![1.00](images/test.jpg)
    
    [链接文本](https://example.com)
    ```
  - 测试代码块场景：
    ```markdown
    # 标题
    
    ```javascript
    const x = 1;
    ```
    
    [链接文本](https://example.com)
    ```
  - 运行所有测试确保无回归

  **Must NOT do**:
  - 不得引入浏览器环境依赖

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 需要综合验证修复效果
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (after Tasks 4, 5)
  - **Blocks**: Final Verification Wave
  - **Blocked By**: Tasks 4, 5

  **References**:
  - `web/milkdown/test-parsing-bug.html` - 参考测试用例

  **Acceptance Criteria**:
  - [ ] 集成测试文件存在
  - [ ] 所有测试通过
  - [ ] Bug 场景验证通过

  **QA Scenarios**:
  ```
  Scenario: 所有测试通过
    Tool: Bash
    Steps:
      1. cd web/milkdown && npm test
    Expected Result: 所有测试通过，无失败
    Evidence: .sisyphus/evidence/task-6-all-tests.txt
  ```

  **Commit**: YES
  - Message: `test(milkdown): add integration tests for image and code block matching`
  - Files: `web/milkdown/test/integration.test.js`

---

## Final Verification Wave (MANDATORY)

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists. For each "Must NOT Have": search codebase for forbidden patterns.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run linter + tests. Review changed files for: `as any`, empty catches, console.log, unused imports.
  Output: `Lint [PASS/FAIL] | Tests [N pass/N fail] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Execute EVERY QA scenario from EVERY task.
  Output: `Scenarios [N/N pass] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: verify everything in spec was built, nothing beyond spec was built.
  Output: `Tasks [N/N compliant] | VERDICT`

---

## Commit Strategy

- **1**: `test(milkdown): add node:test infrastructure for syncRenderedDom` - package.json
- **2-3**: `test(milkdown): add unit tests for image and code block matching` - test/*.test.js
- **4-5**: `fix(milkdown): use position-based matching in syncRenderedDom` - src/main.js
- **6**: `test(milkdown): add integration tests for syncRenderedDom` - test/*.test.js

---

## Success Criteria

### Verification Commands
```bash
cd web/milkdown && node --test test/*.test.js  # Expected: all tests pass
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass
- [ ] Bug reproduction case verified fixed
