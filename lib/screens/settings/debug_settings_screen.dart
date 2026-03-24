import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/debug_probe_service.dart';
import '../../utils/app_style.dart';
import '../../widgets/app_background.dart';

class DebugSettingsScreen extends StatelessWidget {
  const DebugSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('调试'),
          centerTitle: true,
        ),
        body: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(
                  context,
                  '调试开关',
                  Icons.bug_report,
                  [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用调试模式'),
                      subtitle: const Text('记录 Bridge 消息、命令执行和问题诊断数据'),
                      value: settings.debugEnabled,
                      onChanged: (v) => settings.setDebugEnabled(v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  '代码块语言标识调试',
                  Icons.code,
                  [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('采集当前编辑器诊断信息'),
                      subtitle: const Text('会读取代码块工具条位置、pre[data-language] 伪元素等信息'),
                      trailing: TextButton(
                        onPressed: () async {
                          final ok = await DebugProbeService.instance
                              .requestCodeBlockLanguageProbe();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? '已请求采集，请返回日志区查看 on_debug_report'
                                  : '当前没有活跃编辑器，请先打开一个 Markdown 文件'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Text('采集'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  '日志',
                  Icons.article_outlined,
                  [
                    Row(
                      children: [
                        Text('共 ${settings.debugLogs.length} 条'),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final all = settings.debugLogs.join('\n');
                            await Clipboard.setData(ClipboardData(text: all));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('日志已复制到剪贴板'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Text('复制'),
                        ),
                        TextButton(
                          onPressed: settings.clearDebugLogs,
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(minHeight: 160, maxHeight: 360),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: settings.debugLogs.isEmpty
                          ? Text(
                              '暂无日志。开启调试后进入编辑器操作，再回来查看。',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          : SingleChildScrollView(
                              child: SelectableText(
                                settings.debugLogs.reversed.join('\n'),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
