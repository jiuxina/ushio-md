import 'package:flutter/material.dart';

import '../../../models/document_version.dart';

/// 版本历史覆盖层控制器
///
/// 用于从外部控制覆盖层的关闭行为。
class VersionHistoryController {
  VoidCallback? _closeImpl;

  void _bind(VoidCallback closeImpl) {
    _closeImpl = closeImpl;
  }

  void _unbind(VoidCallback closeImpl) {
    if (_closeImpl == closeImpl) {
      _closeImpl = null;
    }
  }

  /// 关闭覆盖层
  void close() => _closeImpl?.call();
}

/// 版本历史列表覆盖层
///
/// 以底部滑入的方式展示文档的版本历史列表。
/// 支持加载、空、错误三种状态，以及版本选择、备注编辑、删除操作。
class VersionHistorySheet extends StatefulWidget {
  /// 版本列表（已按版本号降序排列）
  final List<DocumentVersion> versions;

  /// 关闭回调
  final VoidCallback onClose;

  /// 选中版本回调
  final void Function(DocumentVersion version) onVersionSelected;

  /// 删除版本回调
  final void Function(DocumentVersion version)? onVersionDeleted;

  /// 更新版本备注回调
  ///
  /// 返回 `Future<void>` 以便调用方显示加载状态和错误提示。
  final Future<void> Function(DocumentVersion version, String note)?
      onVersionNoteUpdated;

  /// 外部控制器（可选）
  final VersionHistoryController? controller;

  /// 是否正在加载
  final bool isLoading;

  /// 错误信息（为 null 时无错误）
  final String? errorMessage;

  /// 是否有未保存的修改
  final bool isModified;

  /// 点击"当前未保存修改"的回调
  final VoidCallback? onUnsavedChangesSelected;

  const VersionHistorySheet({
    super.key,
    required this.versions,
    required this.onClose,
    required this.onVersionSelected,
    this.onVersionDeleted,
    this.onVersionNoteUpdated,
    this.controller,
    this.isLoading = false,
    this.errorMessage,
    this.isModified = false,
    this.onUnsavedChangesSelected,
  });

  @override
  State<VersionHistorySheet> createState() => _VersionHistorySheetState();
}

class _VersionHistorySheetState extends State<VersionHistorySheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scrimOpacityAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
    )..forward();
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scrimOpacityAnimation = Tween<double>(begin: 0, end: 0.5).animate(curve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(curve);
    widget.controller?._bind(_startClose);
  }

  @override
  void dispose() {
    widget.controller?._unbind(_startClose);
    _controller.dispose();
    super.dispose();
  }

  /// 播放退出动画并通知父组件移除覆盖层
  void _startClose() {
    if (_isClosing) return;
    _isClosing = true;
    _controller.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  void _onVersionTap(DocumentVersion version) {
    widget.onVersionSelected(version);
    _startClose();
  }

  void _onVersionLongPress(DocumentVersion version) {
    if (widget.onVersionDeleted == null &&
        widget.onVersionNoteUpdated == null) {
      return;
    }
    _showVersionActions(version);
  }

  void _showVersionActions(DocumentVersion version) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'v${version.versionNumber}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              if (version.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    version.note,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),
              if (widget.onVersionNoteUpdated != null)
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('编辑备注'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditNoteDialog(version);
                  },
                ),
              if (widget.onVersionDeleted != null)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    '删除此版本',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(version);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditNoteDialog(DocumentVersion version) async {
    final controller = TextEditingController(text: version.note);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_note, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('编辑备注 · v${version.versionNumber}'),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '输入版本备注…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) return;

    final note = controller.text.trim();
    try {
      await widget.onVersionNoteUpdated?.call(version, note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('备注已更新'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备注更新失败：$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _confirmDelete(DocumentVersion version) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colorScheme.error),
              const SizedBox(width: 8),
              const Text('删除版本'),
            ],
          ),
          content: Text('确定要删除版本 v${version.versionNumber} 吗？\n此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onVersionDeleted?.call(version);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return GestureDetector(
          onTap: _startClose,
          child: Container(
            color: Colors.black.withValues(
              alpha: _scrimOpacityAnimation.value,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _slideAnimation,
                child: GestureDetector(
                  onTap: () {},
                  child: _buildSheet(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          Flexible(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.1),
            colorScheme.secondary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.history,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '版本历史',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (!widget.isLoading && widget.errorMessage == null)
                  Text(
                    '${widget.versions.length} 个版本',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _startClose,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // 加载状态
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('加载版本历史…'),
            ],
          ),
        ),
      );
    }

    // 错误状态
    if (widget.errorMessage != null) {
      final colorScheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                widget.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
          ),
        ),
      );
    }

    // 空状态
    if (widget.versions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                '暂无版本历史',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '保存文档时会自动创建版本快照',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // 版本列表
    return RepaintBoundary(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        // 如果有未保存修改，额外增加一个条目
        itemCount: widget.versions.length + (widget.isModified ? 1 : 0),
        itemBuilder: (context, index) {
          // 第一个条目：未保存修改
          if (widget.isModified && index == 0) {
            return _buildUnsavedChangesItem(context);
          }
          // 其他条目：版本历史
          final versionIndex = widget.isModified ? index - 1 : index;
          final version = widget.versions[versionIndex];
          return _buildVersionItem(context, version);
        },
      ),
    );
  }

  /// 构建"当前未保存修改"条目
  Widget _buildUnsavedChangesItem(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            widget.onUnsavedChangesSelected?.call();
            _startClose();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.tertiary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_note,
                    color: colorScheme.tertiary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '当前未保存修改',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.tertiary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '与最新版本对比',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.compare_arrows,
                  size: 20,
                  color: colorScheme.tertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionItem(BuildContext context, DocumentVersion version) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLatest = version.versionNumber ==
        widget.versions
            .map((v) => v.versionNumber)
            .reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onVersionTap(version),
          onLongPress: () => _onVersionLongPress(version),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLatest
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLatest
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                // 版本号标识
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isLatest
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.outlineVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'v${version.versionNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            isLatest ? colorScheme.primary : colorScheme.outline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 版本信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '版本 ${version.versionNumber}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (isLatest) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '最新',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        version.formattedTimestamp,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                      if (version.note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          version.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 文件大小
                Text(
                  _formatFileSize(version.fileSize),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
