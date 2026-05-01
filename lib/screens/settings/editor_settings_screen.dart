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

                _buildSection(context, l10n.lineHeight, Icons.format_line_spacing, [
                  _buildLineHeightSlider(context, settings, l10n),
                ]),

                const SizedBox(height: 16),

                _buildSection(context, l10n.letterSpacing, Icons.text_fields, [
                  _buildLetterSpacingSlider(context, settings, l10n),
                ]),

                const SizedBox(height: 16),

                _buildSection(context, l10n.paragraphSpacing, Icons.format_line_spacing, [
                  _buildParagraphSpacingSlider(context, settings, l10n),
                ]),

                const SizedBox(height: 16),

                _buildSection(context, l10n.startupBehavior, Icons.launch, [
                  _buildStartupBehaviorSelector(context, settings, l10n),
                ]),

                const SizedBox(height: 16),

                _buildSection(context, l10n.defaultEncoding, Icons.text_snippet, [
                  _buildEncodingSelector(context, settings, l10n),
                ]),

                const SizedBox(height: 16),

                _buildSection(context, l10n.autoSave, Icons.save, [
                  _buildAutoSaveToggle(context, settings, l10n),
                  if (settings.autoSave) ...[
                    const SizedBox(height: 16),
                    _buildAutoSaveIntervalSelector(context, settings, l10n),
                  ],
                ]),

                const SizedBox(height: 16),

                _buildSection(context, l10n.permanentFloatingButtons, Icons.smart_button, [
                  _buildPermanentFloatingButtonsToggle(context, settings, l10n),
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

  Widget _buildLineHeightSlider(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.lineHeightDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(settings.lineHeight.toStringAsFixed(1)),
          ],
        ),
        Slider(
          value: settings.lineHeight,
          min: 1.0,
          max: 2.5,
          divisions: 15,
          label: settings.lineHeight.toStringAsFixed(1),
          onChanged: (v) => settings.setLineHeight(v),
        ),
      ],
    );
  }

  Widget _buildLetterSpacingSlider(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.letterSpacingDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(settings.letterSpacing.toStringAsFixed(1)),
          ],
        ),
        Slider(
          value: settings.letterSpacing,
          min: -2.0,
          max: 10.0,
          divisions: 60,
          label: settings.letterSpacing.toStringAsFixed(1),
          onChanged: (v) => settings.setLetterSpacing(v),
        ),
      ],
    );
  }

  Widget _buildParagraphSpacingSlider(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.paragraphSpacingDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.current(settings.paragraphSpacing.toInt())),
          ],
        ),
        Slider(
          value: settings.paragraphSpacing,
          min: 0,
          max: 40,
          divisions: 40,
          label: '${settings.paragraphSpacing.toInt()}',
          onChanged: (v) => settings.setParagraphSpacing(v),
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

  Widget _buildPermanentFloatingButtonsToggle(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.permanentFloatingButtons),
            DropdownButton<String>(
              value: settings.floatingButtonsMode,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: [
                DropdownMenuItem(
                  value: 'auto',
                  child: Text(l10n.floatingButtonsAuto),
                ),
                DropdownMenuItem(
                  value: 'always',
                  child: Text(l10n.floatingButtonsAlways),
                ),
                DropdownMenuItem(
                  value: 'never',
                  child: Text(l10n.floatingButtonsNever),
                ),
              ],
              onChanged: (value) {
                if (value != null) settings.setFloatingButtonsMode(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _getFloatingButtonsModeDesc(settings.floatingButtonsMode, l10n),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  String _getFloatingButtonsModeDesc(String mode, AppLocalizations l10n) {
    switch (mode) {
      case 'auto':
        return l10n.floatingButtonsAutoDesc;
      case 'always':
        return l10n.floatingButtonsAlwaysDesc;
      case 'never':
        return l10n.floatingButtonsNeverDesc;
      default:
        return l10n.floatingButtonsAutoDesc;
    }
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

  Widget _buildStartupBehaviorSelector(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.startupRestoreLastDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.onOpen),
            DropdownButton<String>(
              value: settings.startupBehavior,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: [
                DropdownMenuItem(
                  value: 'restore',
                  child: Text(l10n.startupRestoreLast),
                ),
                DropdownMenuItem(
                  value: 'blank',
                  child: Text(l10n.startupShowBlank),
                ),
              ],
              onChanged: (value) {
                if (value != null) settings.setStartupBehavior(value);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEncodingSelector(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.encodingDesc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.defaultEncoding),
            DropdownButton<String>(
              value: settings.defaultEncoding,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: [
                DropdownMenuItem(
                  value: 'utf8',
                  child: Text(l10n.encodingUtf8),
                ),
                DropdownMenuItem(
                  value: 'gbk',
                  child: Text(l10n.encodingGbk),
                ),
              ],
              onChanged: (value) {
                if (value != null) settings.setDefaultEncoding(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}
