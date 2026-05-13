import 'package:flutter/material.dart';

import '../../../models/document_version.dart';
import '../../../utils/line_diff_calculator.dart';

// ============================================================================
// DiffViewOverlay — 行级 Diff 对比覆盖层
//
// 并排显示两个版本的文档差异，支持同步滚动、版本信息、diff 统计、
// 回退和创建新文档操作。
//
// 使用方式：
//   showDiffViewOverlay(
//     context: context,
//     oldVersion: previousVersion,
//     newVersion: currentVersion,
//     oldContent: oldContent,
//     newContent: newContent,
//     onRestore: (version) { ... },
//     onCreateNewDoc: (version) { ... },
//   );
// ============================================================================

/// 显示 DiffViewOverlay 覆盖层。
///
/// 返回一个 [OverlayEntry] 引用，可用于手动移除。
OverlayEntry showDiffViewOverlay({
  required BuildContext context,
  required DocumentVersion oldVersion,
  required DocumentVersion newVersion,
  required String oldContent,
  required String newContent,
  required void Function(DocumentVersion version) onRestore,
  required void Function(DocumentVersion version) onCreateNewDoc,
}) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => DiffViewOverlay(
      oldVersion: oldVersion,
      newVersion: newVersion,
      oldContent: oldContent,
      newContent: newContent,
      // 回退到新版本 vk（不是旧版本 vk-1）
      onRestore: () => onRestore(newVersion),
      onCreateNewDoc: () => onCreateNewDoc(newVersion),
      onClose: () => entry.remove(),
    ),
  );
  Overlay.of(context).insert(entry);
  return entry;
}

// ============================================================================
// DiffViewOverlay Widget
// ============================================================================

/// 行级 Diff 对比覆盖层组件。
///
/// 并排显示 [oldContent] 与 [newContent] 的逐行差异，支持：
/// - 顶部版本信息栏与 diff 统计
/// - 左右同步滚动的并排对比
/// - 底部操作栏（关闭、回退、创建新文档）
/// - 加载与错误状态
class DiffViewOverlay extends StatefulWidget {
  /// 旧版本（基准版本）
  final DocumentVersion oldVersion;

  /// 新版本（当前版本）
  final DocumentVersion newVersion;

  /// 旧版本的文档内容
  final String oldContent;

  /// 新版本的文档内容
  final String newContent;

  /// 关闭回调
  final VoidCallback onClose;

  /// 回退到旧版本的回调
  final VoidCallback onRestore;

  /// 创建新文档的回调
  final VoidCallback onCreateNewDoc;

  const DiffViewOverlay({
    super.key,
    required this.oldVersion,
    required this.newVersion,
    required this.oldContent,
    required this.newContent,
    required this.onClose,
    required this.onRestore,
    required this.onCreateNewDoc,
  });

  @override
  State<DiffViewOverlay> createState() => _DiffViewOverlayState();
}

class _DiffViewOverlayState extends State<DiffViewOverlay>
    with SingleTickerProviderStateMixin {
  // ==================== 动画 ====================
  late final AnimationController _animController;
  late final Animation<double> _scrimOpacity;
  late final Animation<Offset> _slideAnimation;
  bool _isClosing = false;

  // ==================== Diff 计算 ====================
  DiffResult? _diffResult;
  bool _isLoading = true;
  String? _errorMessage;

  // ==================== 滚动同步 ====================
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  bool _isSyncingScroll = false;

  @override
  void initState() {
    super.initState();

    // 初始化动画（与 toc_overlay.dart 一致的参数）
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 160),
    )..forward();
    final curve = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scrimOpacity = Tween<double>(begin: 0, end: 0.5).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curve);

    // 异步计算 diff
    _computeDiff();
  }

  @override
  void dispose() {
    _animController.dispose();
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  // ==================== Diff 计算 ====================

  /// diff 计算的行数阈值，超过此阈值可能影响性能
  static const int _diffLineThreshold = 1000;

  Future<void> _computeDiff() async {
    try {
      // 使用 Future.delayed 让 UI 先渲染 loading 状态
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      // 检查文档大小，超过阈值时提示用户
      final oldLineCount = widget.oldContent.split('\n').length;
      final newLineCount = widget.newContent.split('\n').length;
      if (oldLineCount > _diffLineThreshold || newLineCount > _diffLineThreshold) {
        if (mounted) {
          setState(() {
            _errorMessage = '文档较大（${oldLineCount > newLineCount ? oldLineCount : newLineCount} 行），差异计算可能较慢';
          });
        }
        // 延迟一下再计算，让用户看到提示
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final result = calculateLineDiff(widget.oldContent, widget.newContent);

      if (mounted) {
        setState(() {
          _diffResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '计算差异时出错：$e';
          _isLoading = false;
        });
      }
    }
  }

  // ==================== 滚动同步 ====================

  /// 左侧滚动通知处理
  bool _onLeftScroll(ScrollNotification notification) {
    if (_isSyncingScroll) return false;
    if (notification is ScrollUpdateNotification) {
      _syncScroll(_leftScrollController, _rightScrollController);
    }
    return false;
  }

  /// 右侧滚动通知处理
  bool _onRightScroll(ScrollNotification notification) {
    if (_isSyncingScroll) return false;
    if (notification is ScrollUpdateNotification) {
      _syncScroll(_rightScrollController, _leftScrollController);
    }
    return false;
  }

  void _syncScroll(ScrollController source, ScrollController target) {
    if (!source.hasClients || !target.hasClients) return;
    _isSyncingScroll = true;
    final offset = source.offset;
    // 钳制偏移量到目标的有效范围内
    final clampedOffset = offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if (target.hasClients && target.offset != clampedOffset) {
      target.jumpTo(clampedOffset);
    }
    _isSyncingScroll = false;
  }

  // ==================== 关闭动画 ====================

  void _startClose() {
    if (_isClosing) return;
    _isClosing = true;
    _animController.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  // ==================== 格式化工具 ====================

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ==================== 构建方法 ====================

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return GestureDetector(
          onTap: _startClose,
          child: Container(
            color: Colors.black.withValues(alpha: _scrimOpacity.value),
            child: SlideTransition(
              position: _slideAnimation,
              child: GestureDetector(
                onTap: () {}, // 阻止点击穿透
                child: _buildContent(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 顶部信息栏
            _buildInfoBar(context),
            const SizedBox(height: 8),
            // Diff 统计栏
            if (_diffResult != null) _buildStatsBar(context),
            const SizedBox(height: 8),
            // 对比区域
            Expanded(child: _buildCompareArea(context)),
            const SizedBox(height: 8),
            // 底部操作栏
            _buildActionBar(context),
          ],
        ),
      ),
    );
  }

  // ==================== 顶部信息栏 ====================

  Widget _buildInfoBar(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.compare_arrows,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '版本对比',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${widget.oldVersion.versionNumber} → v${widget.newVersion.versionNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _startClose,
                tooltip: '关闭',
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 版本信息行
          Row(
            children: [
              _buildVersionChip(
                context,
                '旧版本 v${widget.oldVersion.versionNumber}',
                widget.oldVersion.formattedTimestamp,
                _formatFileSize(widget.oldVersion.fileSize),
                colors.errorContainer,
                colors.onErrorContainer,
              ),
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: colors.outline,
              ),
              _buildVersionChip(
                context,
                '新版本 v${widget.newVersion.versionNumber}',
                widget.newVersion.formattedTimestamp,
                _formatFileSize(widget.newVersion.fileSize),
                colors.primaryContainer,
                colors.onPrimaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionChip(
    BuildContext context,
    String title,
    String time,
    String size,
    Color bgColor,
    Color fgColor,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            Text(
              size,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Diff 统计栏 ====================

  Widget _buildStatsBar(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final result = _diffResult!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            '+${result.addedCount}',
            '新增',
            Colors.green,
          ),
          _buildStatItem(
            context,
            '-${result.removedCount}',
            '删除',
            Colors.red,
          ),
          _buildStatItem(
            context,
            '${result.unchangedCount}',
            '未变',
            colors.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  // ==================== 并排对比区域 ====================

  Widget _buildCompareArea(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }
    if (_errorMessage != null) {
      return _buildErrorState(context);
    }
    if (_diffResult == null || _diffResult!.lines.isEmpty) {
      return _buildEmptyState(context);
    }
    return _buildSideBySideView(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '正在计算差异...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colors.error,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _startClose,
              icon: const Icon(Icons.close),
              label: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            '两个版本内容完全相同',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBySideView(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lines = _diffResult!.lines;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 列标题
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: colors.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '旧版本 (v${widget.oldVersion.versionNumber})',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: colors.outlineVariant,
                ),
                Expanded(
                  child: Text(
                    '新版本 (v${widget.newVersion.versionNumber})',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // 左右同步滚动区域
          Expanded(
            child: Row(
              children: [
                // 左侧（旧版本）
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onLeftScroll,
                    child: ListView.builder(
                      controller: _leftScrollController,
                      padding: EdgeInsets.zero,
                      itemCount: lines.length,
                      itemBuilder: (context, index) => _buildDiffLine(
                        context,
                        lines[index],
                        isLeft: true,
                      ),
                    ),
                  ),
                ),
                // 分隔线
                Container(
                  width: 1,
                  color: colors.outlineVariant,
                ),
                // 右侧（新版本）
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onRightScroll,
                    child: ListView.builder(
                      controller: _rightScrollController,
                      padding: EdgeInsets.zero,
                      itemCount: lines.length,
                      itemBuilder: (context, index) => _buildDiffLine(
                        context,
                        lines[index],
                        isLeft: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 单行 Diff 渲染 ====================

  Widget _buildDiffLine(
    BuildContext context,
    DiffLine line, {
    required bool isLeft,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // 根据行类型确定内容和样式
    String displayContent;
    Color bgColor;
    Color textColor;
    int? lineNumber;

    switch (line.type) {
      case DiffLineType.added:
        if (isLeft) {
          // 左侧显示空白占位
          displayContent = '';
          bgColor = Colors.transparent;
          textColor = colors.outline;
          lineNumber = null;
        } else {
          displayContent = line.content;
          bgColor = Colors.green.withValues(alpha: 0.12);
          textColor = colors.onSurface;
          lineNumber = line.newLineNumber;
        }
      case DiffLineType.removed:
        if (isLeft) {
          displayContent = line.content;
          bgColor = Colors.red.withValues(alpha: 0.12);
          textColor = colors.onSurface;
          lineNumber = line.oldLineNumber;
        } else {
          // 右侧显示空白占位
          displayContent = '';
          bgColor = Colors.transparent;
          textColor = colors.outline;
          lineNumber = null;
        }
      case DiffLineType.unchanged:
        displayContent = line.content;
        bgColor = Colors.transparent;
        textColor = colors.onSurface;
        lineNumber = isLeft ? line.oldLineNumber : line.newLineNumber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      color: bgColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 行号
          SizedBox(
            width: 40,
            child: Text(
              lineNumber != null ? '$lineNumber' : '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.outline,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // 类型标记
          SizedBox(
            width: 16,
            child: Text(
              _lineTypePrefix(line.type, isLeft),
              style: TextStyle(
                color: _lineTypeColor(line.type, colors),
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 内容
          Expanded(
            child: Text(
              displayContent,
              style: TextStyle(
                color: textColor,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  String _lineTypePrefix(DiffLineType type, bool isLeft) {
    switch (type) {
      case DiffLineType.added:
        return isLeft ? '' : '+';
      case DiffLineType.removed:
        return isLeft ? '-' : '';
      case DiffLineType.unchanged:
        return ' ';
    }
  }

  Color _lineTypeColor(DiffLineType type, ColorScheme colors) {
    switch (type) {
      case DiffLineType.added:
        return Colors.green.shade700;
      case DiffLineType.removed:
        return Colors.red.shade700;
      case DiffLineType.unchanged:
        return colors.outline;
    }
  }

  // ==================== 底部操作栏 ====================

  Widget _buildActionBar(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 关闭按钮
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _startClose,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('关闭'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 回退按钮
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onRestore,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('回退'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 创建新文档按钮
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onCreateNewDoc,
              icon: const Icon(Icons.note_add, size: 18),
              label: const Text('新文档'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
