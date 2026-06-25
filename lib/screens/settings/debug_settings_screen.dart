import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_style.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_surface.dart';

class DebugSettingsScreen extends StatelessWidget {
  const DebugSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.debugSettings),
          centerTitle: true,
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(context, l10n.debugSwitches, Icons.bug_report, [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.enableDebugMode),
                    subtitle: Text(l10n.debugModeDescription),
                    value: settings.debugEnabled,
                    onChanged: (v) => settings.setDebugEnabled(v),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  l10n.debugLogsSection,
                  Icons.article_outlined,
                  [
                    Row(
                      children: [
                        Text(l10n.totalLogsCount(settings.debugLogs.length)),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final all = settings.debugLogs.join('\n');
                            await Clipboard.setData(ClipboardData(text: all));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.logCopiedToClipboard),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Text(l10n.copyLog),
                        ),
                        TextButton(
                          onPressed: settings.clearDebugLogs,
                          child: Text(l10n.clearLog),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 160,
                        maxHeight: 360,
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: settings.debugLogs.isEmpty
                          ? Text(
                              l10n.noLogsYet,
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : SingleChildScrollView(
                              child: SelectableText(
                                settings.debugLogs.reversed.join('\n'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontFamily: 'JetBrains Mono',
                                      height: 1.35,
                                    ),
                              ),
                            ),
                    ),
                  ],
                ),
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
    return AppSurface(
      padding: const EdgeInsets.all(16),
      color: appStyle.scaledSurfaceColor(
        Theme.of(context).colorScheme,
        alpha: 0.7,
      ),
      border: appStyle.useBorderlessButtons
          ? null
          : Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
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
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
