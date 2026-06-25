// ============================================================================
// 关于页面
//
// 显示应用信息、版本、开源链接、检查更新等
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../utils/constants.dart';
import '../../services/update_service.dart';
import '../../widgets/app_background.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_style.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_surface.dart';
import 'open_source_licenses_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _isCheckingUpdate = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.about),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildAppInfo(),
            const SizedBox(height: 24),
            _buildSection(l10n.link, Icons.link, [
              _buildLinkTile(
                icon: Icons.code,
                title: l10n.openSource,
                subtitle: AppConstants.githubUrl,
                onTap: () => _launchUrl(AppConstants.githubUrl),
              ),
              _buildLinkTile(
                icon: Icons.description_outlined,
                title: l10n.openSourceLicense,
                subtitle: l10n.openSourceLicenseDesc,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OpenSourceLicensesScreen(),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection(l10n.updates, Icons.system_update, [
              _buildAutoCheckToggle(),
              _buildCheckUpdateButton(),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfo() {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        boxShadow: appStyle.surfaceShadow,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: appStyle.useBorderlessButtons
            ? null
            : Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.2),
              ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('app.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppConstants.appName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            AppConstants.appDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'v${AppConstants.appVersion}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
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

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
    );
  }

  Widget _buildAutoCheckToggle() {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.update_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(l10n.autoCheckUpdate),
      subtitle: Text(l10n.autoCheckUpdateDesc),
      value: settings.autoCheckUpdate,
      onChanged: (v) => settings.setAutoCheckUpdate(v),
    );
  }

  Widget _buildCheckUpdateButton() {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _isCheckingUpdate
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.update, color: Colors.green),
      ),
      title: Text(l10n.checkForUpdates),
      subtitle: Text(l10n.checkForUpdatesDesc),
      trailing: TextButton(
        onPressed: _isCheckingUpdate ? null : _checkForUpdates,
        child: Text(l10n.search),
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);

    try {
      final updateInfo = await UpdateService.checkForUpdate(
        AppConstants.appVersion,
      );

      if (!mounted) return;

      if (updateInfo != null && updateInfo.hasUpdate) {
        _showUpdateDialog(updateInfo);
      } else {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check, color: Colors.green),
                const SizedBox(width: 12),
                Text(l10n.upToDate),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.checkUpdateFailed(e.toString())),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.update, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(l10n.foundNewVersion)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.newVersionAvailable(info.latestVersion)),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Markdown(
                data: info.changelog,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodySmall,
                  h1: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  h2: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  listBullet: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (info.downloadUrl.isNotEmpty) {
                _startDownload(info);
              } else {
                _launchUrl(AppConstants.githubUrl);
              }
            },
            child: Text(l10n.updateNow),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload(UpdateInfo info) async {
    // 显示进度对话框
    final progressNotifier = ValueNotifier<double>(0.0);
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.downloadingUpdate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      LinearProgressIndicator(value: value),
                      const SizedBox(height: 8),
                      Text('${(value * 100).toStringAsFixed(1)}%'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                l10n.downloadingWithMirror,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final success = await UpdateService.downloadAndInstallUpdate(
        info.downloadUrl,
        'update_${info.latestVersion}.apk',
        onProgress: (progress) {
          progressNotifier.value = progress;
        },
      );

      if (!mounted) return;
      Navigator.pop(context); // 关闭进度框

      if (!success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.downloadFailed)));
        // 失败后尝试跳转浏览器
        _launchUrl(info.downloadUrl);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 关闭进度框
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.updateError(e.toString()))));
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
