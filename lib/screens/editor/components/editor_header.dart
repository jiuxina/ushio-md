import 'package:flutter/material.dart';

import '../../../utils/app_style.dart';

class EditorHeader extends StatelessWidget {
  final String fileName;
  final String wordCount;
  final bool isModified;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback? onMore;

  const EditorHeader({
    super.key,
    required this.fileName,
    required this.wordCount,
    required this.isModified,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
    this.onMore,
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
                _AdaptiveFileName(fileName: _displayFileName),
                const SizedBox(height: 4),
                Text(
                  wordCount,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildSaveButton(context),
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
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: appStyle.surfaceDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
          prominent: appStyle.useBorderlessButtons,
        ),
        child: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
<<<<<<< beta
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return Container(
      decoration: BoxDecoration(
        gradient: isModified
            ? LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              )
            : null,
        color: isModified
            ? null
            : (appStyle.useBorderlessButtons
                  ? appStyle.strongSurface
                  : Theme.of(context).colorScheme.surface),
        borderRadius: BorderRadius.circular(12),
        border: isModified ? null : appStyle.surfaceBorder(),
        boxShadow: isModified
            ? appStyle.prominentShadow
            : (appStyle.useBorderlessButtons ? appStyle.surfaceShadow : null),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
=======
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isSaving
        ? colorScheme.primary
        : isModified
            ? Colors.orange
            : colorScheme.outline;

    return Tooltip(
      message: isSaving ? '保存中' : '保存',
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.8),
>>>>>>> main
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isSaving ? null : onSave,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isSaving
                    ? SizedBox(
                        key: const ValueKey('saving'),
                        width: 18,
                        height: 18,
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
      ),
    );
  }
}

class _AdaptiveFileName extends StatelessWidget {
  final String fileName;

  const _AdaptiveFileName({required this.fileName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.1,
        ) ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.1,
        );

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
        final lineHeight = (baseStyle.fontSize ?? 16) * (baseStyle.height ?? 1.1);
        final maxHeight = lineHeight * lineCount + 2;

        return ConstrainedBox(
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
