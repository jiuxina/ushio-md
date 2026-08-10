import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/app_style.dart';
import '../../../widgets/app_surface.dart';

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
  });

  String get _displayFileName =>
      fileName.replaceAll('.markdown', '').replaceAll('.md', '');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          _buildHeaderIconButton(
            context,
            icon: Icons.arrow_back,
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _AdaptiveFileName(
                  fileName: _displayFileName,
                  fullFilePath: fullFilePath,
                ),
                const SizedBox(height: 4),
                _AdaptiveWordCount(
                  wordCount: wordCount,
                  isAutoSaving: isAutoSaving,
                  lastSaveTime: lastSaveTime,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildSaveButton(context),
          if (canUndo || canRedo) ...[
            const SizedBox(width: 6),
            _buildUndoRedoIndicators(context),
          ],
          if (onMore != null) ...[
            const SizedBox(width: 8),
            _buildHeaderIconButton(
              context,
              icon: Icons.more_vert,
              onPressed: onMore!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: AppSurface(
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.all(10),
        color: appStyle.scaledSurfaceColor(
          Theme.of(context).colorScheme,
          alpha: 0.82,
        ),
        prominent: appStyle.useBorderlessButtons,
        child: Icon(icon, size: 20, color: context.appIconColor),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appStyle = theme.extension<AppStyleTheme>()!;
    final iconColor = isSaving
        ? colorScheme.primary
        : isModified
        ? colorScheme.secondary
        : context.appMutedIconColor;

    return Tooltip(
      message: isSaving ? '保存中' : '保存',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isSaving ? null : onSave,
          child: AppSurface(
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.all(12),
            color: appStyle.scaledSurfaceColor(colorScheme, alpha: 0.82),
            prominent: appStyle.useBorderlessButtons,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isSaving
                  ? SizedBox(
                      key: const ValueKey('saving'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(
                      Icons.save,
                      key: ValueKey('save-$isModified'),
                      size: 20,
                      color: iconColor,
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
      color: colorScheme.outline,
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
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isAutoSaving
                        ? style?.copyWith(color: colorScheme.primary)
                        : style,
                  ),
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
    final glyphs = title.runes.length;
    final lineCount = glyphs <= 10 ? 1 : 2;
    final displayTitle = _formatTitle(title);
    final sizeScale = glyphs <= 10
        ? 1.0
        : glyphs <= 14
        ? 0.94
        : glyphs <= 18
        ? 0.88
        : 0.82;

    return LayoutBuilder(
      builder: (context, constraints) {
        final lineHeight =
            (baseStyle.fontSize ?? 16) * (baseStyle.height ?? 1.1);
        final maxHeight = lineHeight * lineCount + 2;

        return GestureDetector(
          onTap: () {
            if (fullFilePath != null && fullFilePath!.isNotEmpty) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.description, size: 20),
                      SizedBox(width: 8),
                      Text('文件路径', style: TextStyle(fontSize: 16)),
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
              minHeight: lineHeight,
              maxHeight: maxHeight,
              maxWidth: constraints.maxWidth,
            ),
            child: Text(
              displayTitle,
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              style: baseStyle.copyWith(
                fontSize: (baseStyle.fontSize ?? 16) * sizeScale,
              ),
              strutStyle: StrutStyle(
                fontSize: (baseStyle.fontSize ?? 16) * sizeScale,
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
    final chars = title.runes.toList();
    if (chars.length <= 10) {
      return title;
    }

    final firstLine = String.fromCharCodes(chars.take(10));
    final secondLine = String.fromCharCodes(chars.skip(10).take(10));
    return '$firstLine\n$secondLine';
  }
}
