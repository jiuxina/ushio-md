// ============================================================================
// 主题设置页面（第三层）
//
// 包含：主题模式、语言、主题色、界面字体颜色、编辑器文字颜色、按钮样式、卡片透明度、浅色/深色主题方案、莫奈取色
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_background.dart';
import 'appearance_settings_mixin.dart';
import 'monet_settings_screen.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen>
    with AppearanceSettingsMixin {
  @override
  void initState() {
    super.initState();
    initAppearanceMixin();
  }

  @override
  void dispose() {
    disposeAppearanceMixin();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.themeSettings),
          centerTitle: true,
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            initBrightnessValues(settings);
            initParticleSpeedValue(settings);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 莫奈取色入口
                _buildMonetEntry(settings, l10n),

                const SizedBox(height: 16),

                // 主题模式
                buildSection(l10n.themeMode, Icons.brightness_6, [
                  buildThemeModeSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                // 语言
                buildSection(l10n.language, Icons.language, [
                  buildLanguageSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                // 主题色
                buildSection(l10n.themeColor, Icons.color_lens, [
                  buildThemeColorSelector(settings),
                ]),

                const SizedBox(height: 16),

                // 界面字体颜色
                buildSection(l10n.uiFontColor, Icons.text_fields, [
                  buildUiFontColorSelector(settings),
                ]),

                const SizedBox(height: 16),

                // 编辑器文字颜色
                buildSection(l10n.editorFontColor, Icons.edit_note, [
                  buildEditorFontColorSelector(settings),
                ]),

                const SizedBox(height: 16),

                // 按钮样式
                buildSection(l10n.buttonStyle, Icons.smart_button_outlined, [
                  buildButtonStyleSelector(settings, l10n),
                ]),

                const SizedBox(height: 16),

                // 卡片透明度
                buildSection(l10n.cardOpacity, Icons.opacity_rounded, [
                  buildCardOpacitySlider(settings, l10n),
                  const SizedBox(height: 12),
                  buildCardColorSelector(settings, l10n),
                ]),

                // 浅色主题方案（仅在浅色模式下显示）
                if (settings.themeMode == ThemeMode.light) ...[
                  const SizedBox(height: 16),
                  buildSection(l10n.lightTheme, Icons.light_mode, [
                    buildLightThemeSelector(settings),
                  ]),
                ],

                // 深色主题方案（仅在深色模式下显示）
                if (settings.themeMode == ThemeMode.dark) ...[
                  const SizedBox(height: 16),
                  buildSection(l10n.darkTheme, Icons.dark_mode, [
                    buildDarkThemeSelector(settings),
                  ]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建莫奈取色入口
  Widget _buildMonetEntry(SettingsProvider settings, AppLocalizations l10n) {
    final monetEnabled = settings.monetEnabled;
    final activeConfig = settings.activeMonetConfig;
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const MonetSettingsScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: appStyle.surfaceDecoration(
          borderRadius: BorderRadius.circular(16),
          color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: monetEnabled && activeConfig != null
                      ? [
                          activeConfig.scheme.lightScheme.primary,
                          activeConfig.scheme.lightScheme.secondary,
                          activeConfig.scheme.lightScheme.tertiary,
                        ]
                      : [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                          Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                monetEnabled ? Icons.palette : Icons.palette_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.monetSettings,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (monetEnabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.monetActive,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    monetEnabled && activeConfig != null
                        ? activeConfig.name
                        : l10n.monetEnabledDesc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
