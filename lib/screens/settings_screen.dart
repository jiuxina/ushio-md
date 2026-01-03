import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                  ]
                : [
                    const Color(0xFFf8f9ff),
                    const Color(0xFFf0f4ff),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Consumer<SettingsProvider>(
                  builder: (context, settings, child) {
                    return ListView(
                      padding: const EdgeInsets.all(AppConstants.paddingMedium),
                      children: [
                        // Theme section
                        _buildSectionHeader(context, '外观', Icons.palette),
                        _buildGlassCard(
                          context,
                          child: Column(
                            children: [
                              ListTile(
                                leading: _buildIconBox(context, Icons.dark_mode, Colors.purple),
                                title: const Text('主题'),
                                trailing: SegmentedButton<ThemeMode>(
                                  segments: const [
                                    ButtonSegment(
                                      value: ThemeMode.light,
                                      icon: Icon(Icons.light_mode, size: 18),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.system,
                                      icon: Icon(Icons.settings_suggest, size: 18),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.dark,
                                      icon: Icon(Icons.dark_mode, size: 18),
                                    ),
                                  ],
                                  selected: {settings.themeMode},
                                  onSelectionChanged: (modes) {
                                    settings.setThemeMode(modes.first);
                                  },
                                  style: const ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Editor section
                        _buildSectionHeader(context, '编辑器', Icons.edit),
                        _buildGlassCard(
                          context,
                          child: Column(
                            children: [
                              ListTile(
                                leading: _buildIconBox(context, Icons.text_fields, Colors.blue),
                                title: const Text('字体大小'),
                                subtitle: Text('${settings.fontSize.toInt()} px'),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Slider(
                                  value: settings.fontSize,
                                  min: 12,
                                  max: 24,
                                  divisions: 12,
                                  label: '${settings.fontSize.toInt()}',
                                  onChanged: (value) => settings.setFontSize(value),
                                ),
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: _buildIconBox(context, Icons.save, Colors.green),
                                title: const Text('自动保存'),
                                subtitle: Text(
                                  settings.autoSave
                                      ? '每 ${settings.autoSaveInterval} 秒自动保存'
                                      : '已关闭',
                                ),
                                value: settings.autoSave,
                                onChanged: (value) => settings.setAutoSave(value),
                              ),
                              if (settings.autoSave) ...[
                                const Divider(height: 1),
                                ListTile(
                                  leading: _buildIconBox(context, Icons.timer, Colors.orange),
                                  title: const Text('自动保存间隔'),
                                  trailing: DropdownButton<int>(
                                    value: settings.autoSaveInterval,
                                    items: const [
                                      DropdownMenuItem(value: 10, child: Text('10 秒')),
                                      DropdownMenuItem(value: 30, child: Text('30 秒')),
                                      DropdownMenuItem(value: 60, child: Text('1 分钟')),
                                      DropdownMenuItem(value: 300, child: Text('5 分钟')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        settings.setAutoSaveInterval(value);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Storage section
                        _buildSectionHeader(context, '存储', Icons.folder),
                        _buildGlassCard(
                          context,
                          child: Consumer<FileProvider>(
                            builder: (context, fileProvider, child) {
                              return ListTile(
                                leading: _buildIconBox(context, Icons.history, Colors.red),
                                title: const Text('清除最近文件'),
                                subtitle: Text('${fileProvider.recentFiles.length} 个文件'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: fileProvider.recentFiles.isEmpty
                                    ? null
                                    : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            title: const Text('清除最近文件'),
                                            content: const Text('确定要清除所有最近文件记录吗？'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, false),
                                                child: const Text('取消'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, true),
                                                child: const Text('清除'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          fileProvider.clearRecentFiles();
                                        }
                                      },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // About section
                        _buildSectionHeader(context, '关于', Icons.info),
                        _buildGlassCard(
                          context,
                          child: Column(
                            children: [
                              ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      'app.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                title: const Text(
                                  AppConstants.appName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: const Text('版本 ${AppConstants.appVersion}'),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: _buildIconBox(context, Icons.code, Colors.blue),
                                title: const Text('使用 Flutter 构建'),
                                subtitle: const Text(AppConstants.appDescription),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: _buildIconBox(context, Icons.person, Colors.teal),
                                title: const Text('作者'),
                                subtitle: const Text(AppConstants.appAuthor),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: _buildIconBox(context, Icons.open_in_new, Colors.purple),
                                title: const Text('GitHub 开源仓库'),
                                subtitle: const Text('查看源代码和提交反馈'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _launchUrl(AppConstants.githubUrl),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            '设置',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _buildIconBox(BuildContext context, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
