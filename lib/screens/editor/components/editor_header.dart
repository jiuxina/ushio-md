import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/app_style.dart';
import '../../../widgets/app_surface.dart';
import '../../../widgets/glass_header_button.dart';
import '../../../widgets/app_modal.dart';

class EditorHeader extends StatelessWidget {
  final String fileName;
  final String? fullFilePath;
  final String wordCount;
  final bool isModified;
  final bool isSaving;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback? onMore;
  final bool isAutoSaving;
  final DateTime? lastSaveTime;
  final bool isSourceMode;
  final VoidCallback? onToggleMode;

  const EditorHeader({
    super.key,
    required this.fileName,
    this.fullFilePath,
    required this.wordCount,
    required this.isModified,
    required this.isSaving,
    required this.canUndo,
    required this.canRedo,
    required this.onBack,
    required this.onSave,
    this.onMore,
    this.isAutoSaving = false,
    this.lastSaveTime,
    this.isSourceMode = false,
    this.onToggleMode,
  });

  String get _displayFileName =>
      fileName.replaceAll('.markdown', '').replaceAll('.md', '');

  /// 头部同样是浮在正文之上的覆盖层：上下各 8 的内边距 + 48 高的按钮。
  /// 正文顶部要按这个值留白，否则第一行永远压在头部下面。
  static const double reserveHeight = 8 + 48 + 8;

  static double reserveHeightFor(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textHeight =
        textScaler.scale(16) * 1.1 + textScaler.scale(13) * 1.1 + 3;
    return 16 + (textHeight > 48 ? textHeight : 48);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          GlassHeaderButton(icon: Icons.arrow_back, onPressed: onBack),
          const SizedBox(width: 8),
          Expanded(
            child: AppSurface.builder(
              role: SurfaceRole.modal,
              borderRadius: BorderRadius.circular(12),
              builder: _buildInfoContent,
            ),
          ),
          const SizedBox(width: 8),
          if (onToggleMode != null) ...[
            GlassHeaderButton(
              icon: isSourceMode ? Icons.visibility : Icons.edit,
              onPressed: onToggleMode,
              tooltip: isSourceMode
                  ? AppLocalizations.of(context)!.switchToPreview
                  : AppLocalizations.of(context)!.switchToSource,
            ),
            const SizedBox(width: 8),
          ],
          _buildSaveButton(context),
          if (canUndo || canRedo) ...[
            const SizedBox(width: 8),
            _buildUndoRedoIndicators(context),
          ],
          if (onMore != null) ...[
            const SizedBox(width: 8),
            GlassHeaderButton(icon: Icons.more_vert, onPressed: onMore!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        height: reserveHeightFor(context) - 16,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AdaptiveFileName(
              fileName: _displayFileName,
              fullFilePath: fullFilePath,
            ),
            const SizedBox(height: 1),
            _AdaptiveWordCount(
              wordCount: wordCount,
              isAutoSaving: isAutoSaving,
              lastSaveTime: lastSaveTime,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appStyle = theme.extension<AppStyleTheme>()!;

    return Tooltip(
      message: isSaving ? '保存中' : '保存',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isSaving ? null : onSave,
          child: AppSurface.builder(
            role: SurfaceRole.modal,
            borderRadius: BorderRadius.circular(12),
            alignment: Alignment.center,
            height: 48,
            width: 48,
            color: appStyle.scaledSurfaceColor(colorScheme, alpha: 0.82),
            prominent: appStyle.useBorderlessButtons,
            builder: (context) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isSaving
                  ? SizedBox(
                      key: const ValueKey('saving'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.save,
                      key: ValueKey('save-$isModified'),
                      size: 20,
                      color: isModified
                          ? Theme.of(context).colorScheme.error
                          : context.appMutedIconColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUndoRedoIndicators(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canUndo
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canRedo
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

class _AdaptiveWordCount extends StatelessWidget {
  final String wordCount;
  final bool isAutoSaving;
  final DateTime? lastSaveTime;

  const _AdaptiveWordCount({
    required this.wordCount,
    this.isAutoSaving = false,
    this.lastSaveTime,
  });

  String _formatLastSaveTime() {
    if (lastSaveTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(lastSaveTime!);

    if (diff.inSeconds < 5) return '刚刚保存';
    if (diff.inSeconds < 60) return '${diff.inSeconds}秒前保存';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前保存';
    if (diff.inHours < 24) return '${diff.inHours}小时前保存';
    return '${diff.inDays}天前保存';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.1,
    );

    final saveInfo = _formatLastSaveTime();
    final displayText = isAutoSaving
        ? '保存中...'
        : saveInfo.isNotEmpty
        ? '$wordCount · $saveInfo'
        : wordCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAutoSaving)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              Flexible(
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isAutoSaving
                      ? style?.copyWith(color: colorScheme.primary)
                      : style,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdaptiveFileName extends StatelessWidget {
  final String fileName;
  final String? fullFilePath;

  const _AdaptiveFileName({required this.fileName, this.fullFilePath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle =
        theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.1,
        ) ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.1);

    final title = fileName.trim().isEmpty ? '未命名' : fileName.trim();
    final displayTitle = _formatTitle(title);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: () {
            if (fullFilePath != null && fullFilePath!.isNotEmpty) {
              showAppDialog(
                context: context,
                builder: (context) => AlertDialog(
                  scrollable: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.description, size: 20),
                      SizedBox(width: 8),
                      Flexible(child: Text('文件路径')),
                    ],
                  ),
                  content: SelectableText(
                    fullFilePath!,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  actions: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fullFilePath!));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('路径已复制'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('复制路径'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              );
            }
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 0,
              maxWidth: constraints.maxWidth,
            ),
            child: Text(
              displayTitle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: baseStyle,
              strutStyle: StrutStyle(
                fontSize: baseStyle.fontSize,
                height: baseStyle.height,
                forceStrutHeight: true,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTitle(String title) {
    return title;
  }
}
