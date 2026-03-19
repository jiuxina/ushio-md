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
