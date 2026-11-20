// ============================================================================
// 更新下载代理管理面板
//
// 代理条目完全由用户手动维护，列表顺序即下载时的尝试顺序。
// ============================================================================

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/update_service.dart';
import '../../utils/app_style.dart';
import '../../utils/constants.dart';
import '../../widgets/app_modal.dart';

class UpdateProxiesSheet extends StatefulWidget {
  const UpdateProxiesSheet({
    super.key,
    required this.proxies,
    required this.onChanged,
  });

  final List<String> proxies;
  final ValueChanged<List<String>> onChanged;

  static Future<void> show(
    BuildContext context, {
    required List<String> proxies,
    required ValueChanged<List<String>> onChanged,
  }) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          UpdateProxiesSheet(proxies: proxies, onChanged: onChanged),
    );
  }

  @override
  State<UpdateProxiesSheet> createState() => _UpdateProxiesSheetState();
}

class _UpdateProxiesSheetState extends State<UpdateProxiesSheet> {
  late final List<String> _items = List<String>.of(widget.proxies);

  Future<void> _openEditor({int? editIndex}) async {
    final result = await showAppDialog<String>(
      context: context,
      builder: (_) => _ProxyEditorDialog(
        initialValue: editIndex == null ? '' : _items[editIndex],
        others: [
          for (int i = 0; i < _items.length; i++)
            if (i != editIndex) _items[i],
        ],
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (editIndex == null) {
        _items.add(result);
      } else {
        _items[editIndex] = result;
      }
    });
    widget.onChanged(List<String>.of(_items));
  }

  void _remove(int index) {
    setState(() => _items.removeAt(index));
    widget.onChanged(List<String>.of(_items));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 14),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.updateProxies,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.updateProxiesHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.updateProxyExampleNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AppConstants.proxyUrlExample,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    l10n.updateProxiesEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: colorScheme.outlineVariant),
                  itemBuilder: (context, index) => _buildRow(index),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.addUpdateProxy),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(int index) {
    final l10n = AppLocalizations.of(context)!;
    final item = _items[index];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(
        Icons.dns_outlined,
        size: 20,
        color: context.appMutedIconColor,
      ),
      title: Text(
        item,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: l10n.edit,
            onPressed: () => _openEditor(editIndex: index),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: l10n.delete,
            onPressed: () => _remove(index),
          ),
        ],
      ),
    );
  }
}

/// 新增 / 编辑单条代理前缀，校验通过才回传归一化后的地址
class _ProxyEditorDialog extends StatefulWidget {
  const _ProxyEditorDialog({required this.initialValue, required this.others});

  final String initialValue;
  final List<String> others;

  @override
  State<_ProxyEditorDialog> createState() => _ProxyEditorDialogState();
}

class _ProxyEditorDialogState extends State<_ProxyEditorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final normalized = UpdateService.normalizeProxyPrefix(_controller.text);

    if (normalized == null) {
      setState(() => _error = l10n.updateProxyInvalid);
      return;
    }
    final duplicated = widget.others.any(
      (other) => other.toLowerCase() == normalized.toLowerCase(),
    );
    if (duplicated) {
      setState(() => _error = l10n.updateProxyDuplicate);
      return;
    }

    Navigator.pop(context, normalized);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.initialValue.isEmpty
            ? l10n.addUpdateProxy
            : l10n.editUpdateProxy,
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 1,
        maxLines: 2,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          hintText: AppConstants.proxyUrlExample,
          helperText: l10n.updateProxiesHint,
          errorText: _error,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
