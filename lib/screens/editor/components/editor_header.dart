import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onPressed: onBack,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fileName.replaceAll('.md', '').replaceAll('.markdown', ''),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isModified)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '未保存',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  wordCount,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          _buildSaveButton(context),
          if (onMore != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onPressed: onMore,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
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
        color: isModified ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isModified
            ? null
            : Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
        boxShadow: isModified
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isSaving ? null : onSave,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSaving)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isModified ? Colors.white : null,
                    ),
                  )
                else
                  Icon(
                    Icons.save,
                    size: 18,
                    color: isModified ? Colors.white : null,
                  ),
                const SizedBox(width: 8),
                Text(
                  '保存',
                  style: TextStyle(
                    color: isModified ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
