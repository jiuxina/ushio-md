// ============================================================================
// 编辑器设置页面
//
// 设置字体大小、自动保存等编辑器相关选项
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_background.dart';
import '../../utils/app_style.dart';

class EditorSettingsScreen extends StatelessWidget {
  const EditorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.editorSettings),
          centerTitle: true,
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(context, l10n.fontSize, Icons.format_size, [
                  _buildFontSizeSlider(context, settings, l10n),
                ]),

                const SizedBox(height: 16),

                _buildSection(context, l10n.autoSave, Icons.save, [
                  _buildAutoSaveToggle(context, settings, l10n),
                  if (settings.autoSave) ...[
                    const SizedBox(height: 16),
                    _buildAutoSaveIntervalSelector(context, settings, l10n),
                  ],
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.scaledSurfaceColor(
          Theme.of(context).colorScheme,
          alpha: 0.7,
        ),
        border: appStyle.useBorderlessButtons
            ? null
            : Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFontSizeSlider(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.current(settings.fontSize.toInt())),
            Text(
              l10n.sampleText,
              style: TextStyle(fontSize: settings.fontSize), // 限制示例最大大小以免溢出
            ),
          ],
        ),
        Slider(
          value: settings.fontSize,
          min: 6,
          max: 80,
          divisions: 74,
          label: '${settings.fontSize.toInt()}',
          onChanged: (v) => settings.setFontSize(v),
        ),
      ],
    );
  }

  Widget _buildAutoSaveToggle(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.enableAutoSave),
        Switch(
          value: settings.autoSave,
          onChanged: (v) => settings.setAutoSave(v),
        ),
      ],
    );
  }

  Widget _buildAutoSaveIntervalSelector(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final intervals = [15, 30, 60, 120, 180, 300, 600];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.saveInterval),
        DropdownButton<int>(
          value: intervals.contains(settings.autoSaveInterval)
              ? settings.autoSaveInterval
              : 30, // 默认回退
          underline: const SizedBox(),
          borderRadius: BorderRadius.circular(12),
          items: intervals.map((i) {
            String label;
            if (i < 60) {
              label = '$i ${l10n.seconds}';
            } else {
              label = '${i ~/ 60} ${l10n.minutes}';
            }
            return DropdownMenuItem(value: i, child: Text(label));
          }).toList(),
          onChanged: (value) {
            if (value != null) settings.setAutoSaveInterval(value);
          },
        ),
      ],
    );
  }
}
