# 已知问题修复计划

> 最新 Open Issues 汇总与分阶段修复计划见
> [docs/ISSUE_FIX_PLAN_2026_08.md](ISSUE_FIX_PLAN_2026_08.md)。

## 问题概述

根据 V1.4.3 release notes,存在以下两个已知问题:

1. **云同步功能稳定性问题**: WebDAV/FTP在不同设备与网络环境下稳定性仍需持续验证
2. **标题解析问题**: 文档中有2个以上有效标题语法时(# + space),它们之间的内容可能会解析错误

---

## 问题2: 标题解析问题修复方案

### 根本原因

根据对Milkdown源代码的深入研究,问题根源在于:

1. **重复ID生成**: Milkdown默认的`headingIdGenerator`使用标题文本生成slug,当多个标题文本相同时会产生重复ID
2. **DOM渲染问题**: 重复ID导致DOM元素标识冲突,影响锚点跳转和目录导航
3. **解析器混淆**: 在某些边界情况下,重复ID可能导致解析器状态混乱

### 已知修复

- **PR #1580**: 已修复重复ID问题 (https://github.com/Milkdown/milkdown/pull/1580)
- 该PR引入了ID去重机制,自动为重复标题添加后缀 (如 `heading`, `heading-1`, `heading-2`)

### 修复步骤

#### 方案A: 升级Milkdown版本 (推荐)

1. 检查当前Milkdown版本
2. 升级到包含PR #1580修复的版本
3. 测试标题解析功能

#### 方案B: 自定义headingIdGenerator (如果无法立即升级)

在Milkdown配置中添加自定义ID生成器:

```javascript
// 在assets/milkdown_web/index.html的Milkdown初始化代码中
import { headingIdGenerator } from '@milkdown/preset-commonmark'

// 创建唯一ID生成器
const createUniqueIdGenerator = () => {
  const seen = new Map()
  return (node) => {
    const text = node.textContent.toLowerCase().trim().replace(/\s+/g, '-')
    const count = seen.get(text) || 0
    seen.set(text, count + 1)
    return count === 0 ? text : `${text}-${count}`
  }
}

// 在editor配置中使用
Editor.make()
  .config((ctx) => {
    ctx.set(headingIdGenerator.key, createUniqueIdGenerator())
    // ... 其他配置
  })
```

#### 方案C: Flutter端临时缓解措施

在Flutter代码中添加标题去重逻辑:

**位置**: `lib/screens/editor_screen.dart`

**修改点**:
1. 在`_handleOutlineUpdate`方法中添加ID去重检查
2. 为重复标题添加序号后缀

```dart
// 在 _handleOutlineUpdate 方法中
void _handleOutlineUpdate(OnOutlineUpdatePayload payload) {
  final seen = <String, int>{};
  final uniqueItems = <TocItem>[];
  
  for (final node in payload.outline) {
    final baseId = _slugifyHeading(node.text);
    final count = seen[baseId] ?? 0;
    seen[baseId] = count + 1;
    
    final uniqueId = count == 0 ? baseId : '$baseId-$count';
    uniqueItems.add(TocItem(
      level: node.level,
      title: node.title,
      lineNumber: node.lineNumber,
      anchorKey: GlobalKey(),
    ));
  }
  
  setState(() {
    _tocItems = uniqueItems;
  });
}
```

### 验证测试

创建测试文档验证修复:

```markdown
# 标题一

第一个标题下的内容。

## 子标题

子标题内容。

# 标题一

重复的标题,应该生成不同的ID。

### 三级标题

三级内容。

## 子标题

重复的子标题。
```

预期结果:
- 所有标题都能正确解析
- 目录跳转功能正常
- 无内容显示错误

---

## 问题1: 云同步稳定性问题修复方案

### 根本原因分析

云同步问题可能源于:

1. **网络超时处理不足**: 在弱网环境下缺乏重试机制
2. **并发冲突处理**: 多设备同时修改时的冲突解决策略不完善
3. **文件锁竞争**: WebDAV/FTP协议在某些服务器上的锁机制差异
4. **错误恢复不完整**: 断点续传和错误恢复机制需要加强

### 修复步骤

#### 1. 增强网络错误处理

**位置**: `lib/services/webdav_service.dart` 和 `lib/services/ftp_service.dart`

**改进点**:
- 添加指数退避重试机制
- 增加网络状态检测
- 完善超时配置

```dart
Future<T> _withRetry<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  int attempt = 0;
  Duration delay = initialDelay;
  
  while (true) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      if (attempt >= maxRetries) rethrow;
      
      await Future.delayed(delay);
      delay = Duration(
        milliseconds: (delay.inMilliseconds * 2).clamp(0, 30000),
      );
    }
  }
}
```

#### 2. 改进冲突检测

**位置**: `lib/services/cloud_sync_service.dart`

**改进点**:
- 增加文件哈希校验
- 完善冲突提示UI
- 添加手动合并工具

#### 3. 添加同步状态持久化

**改进点**:
- 记录同步历史
- 支持断点续传
- 保存失败操作队列

#### 4. 完善测试用例

创建测试场景:
- 弱网环境同步
- 大文件同步
- 并发修改冲突
- 网络中断恢复

### 验证清单

- [ ] 在2G网络下完成10KB文件同步
- [ ] 同一文件在两设备同时编辑,冲突正确提示
- [ ] 同步过程中断网络,恢复后自动继续
- [ ] 100个文件批量同步成功率 > 95%

---

## 优先级建议

### 高优先级
1. **标题解析问题** - 直接影响用户体验,修复方案明确
   - 实施方案A或B
   - 预计工作量: 2-4小时

### 中优先级  
2. **云同步稳定性** - 影响范围可控,但需要广泛测试
   - 先加强错误处理和重试机制
   - 逐步完善冲突解决
   - 预计工作量: 1-2周

---

## 参考资源

- Milkdown PR #1580: https://github.com/Milkdown/milkdown/pull/1580
- Milkdown heading-id源码: https://github.com/Milkdown/milkdown/blob/main/packages/plugins/preset-commonmark/src/node/heading.ts
- sync-heading-id-plugin: https://github.com/Milkdown/milkdown/blob/main/packages/plugins/preset-commonmark/src/plugin/sync-heading-id-plugin.ts
- 相关Issue #1798: https://github.com/Milkdown/milkdown/issues/1798
- 相关Issue #1553: https://github.com/Milkdown/milkdown/issues/1553
