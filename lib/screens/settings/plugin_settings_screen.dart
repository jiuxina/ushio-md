// ============================================================================
// 插件设置页面
// 
// 插件管理界面，包含三个标签页：
// - 已安装：本地已安装插件列表
// - 官方市场：从 GitHub 获取官方插件
// - 社区市场：预留接口
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../providers/plugin_provider.dart';
import '../../plugins/plugin_manifest.dart';
import '../../plugins/plugin_security.dart';
import '../../plugins/marketplace/plugin_marketplace.dart';
import '../../plugins/marketplace/community_marketplace_interface.dart';
import '../../widgets/app_background.dart';

/// 插件设置页面
class PluginSettingsScreen extends StatefulWidget {
  const PluginSettingsScreen({super.key});

  @override
  State<PluginSettingsScreen> createState() => _PluginSettingsScreenState();
}

class _PluginSettingsScreenState extends State<PluginSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OfficialMarketplace _marketplace = OfficialMarketplace();
  
  List<MarketplacePluginInfo>? _marketplacePlugins;
  bool _isLoadingMarketplace = false;
  String? _marketplaceError;
  
  /// 正在安装的插件 ID 集合
  final Set<String> _installingPlugins = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // 监听 Tab 切换，自动加载官方市场
    _tabController.addListener(() {
      if (_tabController.index == 1 && _marketplacePlugins == null && !_isLoadingMarketplace) {
        _loadMarketplacePlugins();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载官方市场插件列表
  Future<void> _loadMarketplacePlugins() async {
    final pluginProvider = context.read<PluginProvider>();
    
    // 首次访问检查网络权限
    if (!pluginProvider.networkAccessAllowed) {
      final allowed = await PluginSecurity.showNetworkAccessWarning(context);
      if (!allowed) return;
      await pluginProvider.setNetworkAccessAllowed(true);
    }
    
    setState(() {
      _isLoadingMarketplace = true;
      _marketplaceError = null;
    });
    
    try {
      final plugins = await _marketplace.fetchPlugins();
      if (mounted) {
        setState(() {
          _marketplacePlugins = plugins;
          _isLoadingMarketplace = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _marketplaceError = e.toString();
          _isLoadingMarketplace = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('插件'),
          bottom: TabBar(
            controller: _tabController,
            onTap: (index) {
              if (index == 1 && _marketplacePlugins == null && !_isLoadingMarketplace) {
                _loadMarketplacePlugins();
              }
            },
            tabs: const [
              Tab(text: '已安装'),
              Tab(text: '官方市场'),
              Tab(text: '社区市场'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildInstalledTab(),
            _buildOfficialMarketTab(),
            _buildCommunityMarketTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _importLocalPlugin,
          icon: const Icon(Icons.add),
          label: const Text('导入本地插件'),
        ),
      ),
    );
  }

  /// 导入本地插件
  Future<void> _importLocalPlugin() async {
    final pluginProvider = context.read<PluginProvider>();
    final result = await pluginProvider.installFromLocalFile(context);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// 构建已安装标签页
  Widget _buildInstalledTab() {
    return Consumer<PluginProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (provider.installedPlugins.isEmpty) {
          return _buildEmptyState(
            icon: Icons.extension_off,
            title: '暂无已安装插件',
            subtitle: '点击下方按钮导入本地插件，或从官方市场安装',
          );
        }
        
        return RefreshIndicator(
          onRefresh: provider.refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.installedPlugins.length + 1, // +1 for header
            itemBuilder: (context, index) {
              // 首行显示检查更新按钮
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: _checkPluginUpdates,
                    icon: const Icon(Icons.update),
                    label: const Text('一键检查更新'),
                  ),
                );
              }
              final plugin = provider.installedPlugins[index - 1];
              return _buildPluginCard(plugin, isInstalled: true);
            },
          ),
        );
      },
    );
  }

  /// 构建官方市场标签页
  Widget _buildOfficialMarketTab() {
    if (_isLoadingMarketplace) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_marketplaceError != null) {
      return _buildEmptyState(
        icon: Icons.error_outline,
        title: '加载失败',
        subtitle: _marketplaceError!,
        action: ElevatedButton(
          onPressed: _loadMarketplacePlugins,
          child: const Text('重试'),
        ),
      );
    }
    
    if (_marketplacePlugins == null) {
      return _buildEmptyState(
        icon: Icons.cloud_download,
        title: '官方插件市场',
        subtitle: '点击加载官方插件列表',
        action: ElevatedButton(
          onPressed: _loadMarketplacePlugins,
          child: const Text('加载'),
        ),
      );
    }
    
    if (_marketplacePlugins!.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox,
        title: '暂无可用插件',
        subtitle: '官方插件市场正在筹备中',
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => _marketplace.fetchPlugins(forceRefresh: true).then((plugins) {
        setState(() => _marketplacePlugins = plugins);
      }),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _marketplacePlugins!.length,
        itemBuilder: (context, index) {
          final plugin = _marketplacePlugins![index];
          return _buildMarketplacePluginCard(plugin);
        },
      ),
    );
  }

  /// 构建社区市场标签页
  Widget _buildCommunityMarketTab() {
    return _buildEmptyState(
      icon: Icons.people,
      title: CommunityMarketplacePlaceholder.title,
      subtitle: CommunityMarketplacePlaceholder.message,
    );
  }

  /// 构建已安装插件卡片
  Widget _buildPluginCard(PluginManifest plugin, {bool isInstalled = false}) {
    // 构建本地图标路径
    String? iconPath;
    if (plugin.iconPath != null && plugin.installPath != null) {
      final path = '${plugin.installPath}/${plugin.iconPath}';
      if (File(path).existsSync()) {
        iconPath = path;
      }
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: iconPath != null
                      ? Image.file(
                          File(iconPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.extension,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.extension,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plugin.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'v${plugin.version} · ${plugin.author}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isInstalled)
                  Switch(
                    value: plugin.isEnabled,
                    onChanged: (value) => _togglePlugin(plugin, value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              plugin.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (plugin.permissions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: plugin.permissions.map((perm) {
                  final isDangerous = PluginPermission.isDangerous(perm);
                  return Chip(
                    label: Text(
                      PluginPermission.getDescription(perm),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDangerous ? Colors.white : null,
                      ),
                    ),
                    backgroundColor: isDangerous 
                        ? Colors.orange.shade700 
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            if (isInstalled) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 使用说明按钮
                  if (_hasReadme(plugin))
                    TextButton.icon(
                      onPressed: () => _showReadmeDialog(plugin),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('使用说明'),
                    ),
                  TextButton.icon(
                    onPressed: () => _uninstallPlugin(plugin),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('卸载'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建市场插件卡片
  Widget _buildMarketplacePluginCard(MarketplacePluginInfo plugin) {
    final pluginProvider = context.read<PluginProvider>();
    final isInstalled = pluginProvider.installedPlugins.any((p) => p.id == plugin.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: plugin.iconUrl != null && plugin.iconUrl!.isNotEmpty
                      ? Image.network(
                          plugin.iconUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.extension,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        )
                      : Icon(
                          Icons.extension,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plugin.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'v${plugin.version} · ${plugin.author}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isInstalled)
                  Chip(
                    label: const Text('已安装'),
                    backgroundColor: Colors.green.shade100,
                    labelStyle: TextStyle(color: Colors.green.shade700),
                  )
                else if (_installingPlugins.contains(plugin.id))
                  const SizedBox(
                    width: 80,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  FilledButton(
                    onPressed: () => _installFromMarketplace(plugin),
                    child: const Text('安装'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              plugin.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (plugin.hasDangerousPermissions) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '需要危险权限',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ],
            // 使用说明按钮
            if (plugin.readmeUrl != null && plugin.readmeUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showMarketplaceReadmeDialog(plugin),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('使用说明'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }

  /// 切换插件启用状态
  Future<void> _togglePlugin(PluginManifest plugin, bool enabled) async {
    final pluginProvider = context.read<PluginProvider>();
    
    if (enabled) {
      await pluginProvider.enablePlugin(context, plugin.id);
    } else {
      await pluginProvider.disablePlugin(plugin.id);
    }
  }

  /// 卸载插件
  Future<void> _uninstallPlugin(PluginManifest plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认卸载'),
        content: Text('确定要卸载插件 "${plugin.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('卸载'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      final pluginProvider = context.read<PluginProvider>();
      await pluginProvider.uninstallPlugin(plugin.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('插件 "${plugin.name}" 已卸载')),
        );
      }
    }
  }

  /// 从市场安装插件
  Future<void> _installFromMarketplace(MarketplacePluginInfo plugin) async {
    // 标记开始安装
    setState(() {
      _installingPlugins.add(plugin.id);
    });
    
    try {
      final pluginProvider = context.read<PluginProvider>();
      
      // 直接使用 plugins.json 中提供的 downloadUrl，而不是固定格式的 URL
      final downloadUrl = plugin.downloadUrl.isNotEmpty 
          ? plugin.downloadUrl 
          : _marketplace.getDownloadUrl(plugin.id);
      final result = await pluginProvider.installFromUrl(context, downloadUrl);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      // 标记安装结束
      if (mounted) {
        setState(() {
          _installingPlugins.remove(plugin.id);
        });
      }
    }
  }

  /// 检查已安装插件是否有更新
  Future<void> _checkPluginUpdates() async {
    final pluginProvider = context.read<PluginProvider>();
    
    // 首先确保网络权限
    if (!pluginProvider.networkAccessAllowed) {
      final allowed = await PluginSecurity.showNetworkAccessWarning(context);
      if (!allowed) return;
      await pluginProvider.setNetworkAccessAllowed(true);
    }
    
    if (!mounted) return;
    
    // 显示检查中对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在检查插件更新...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      // 获取市场插件列表
      final marketplacePlugins = await _marketplace.fetchPlugins(forceRefresh: true);
      
      // 比较版本
      final updates = <Map<String, dynamic>>[];
      for (final installed in pluginProvider.installedPlugins) {
        final marketPlugin = marketplacePlugins.where((p) => p.id == installed.id).firstOrNull;
        if (marketPlugin != null && _isNewerVersion(marketPlugin.version, installed.version)) {
          updates.add({
            'installed': installed,
            'market': marketPlugin,
          });
        }
      }
      
      if (!mounted) return;
      Navigator.of(context).pop(); // 关闭检查对话框
      
      if (updates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 12),
                Text('所有插件均为最新版本'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showUpdatesDialog(updates);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('检查更新失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// 比较版本号，判断 v1 是否比 v2 新
  bool _isNewerVersion(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }
    
    for (int i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return true;
      if (parts1[i] < parts2[i]) return false;
    }
    return false;
  }
  
  /// 显示可更新插件对话框
  void _showUpdatesDialog(List<Map<String, dynamic>> updates) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.update, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text('发现 ${updates.length} 个更新'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: updates.length,
            itemBuilder: (context, index) {
              final update = updates[index];
              final installed = update['installed'] as PluginManifest;
              final market = update['market'] as MarketplacePluginInfo;
              
              return ListTile(
                leading: const Icon(Icons.extension),
                title: Text(installed.name),
                subtitle: Text('${installed.version} → ${market.version}'),
                trailing: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _installFromMarketplace(market);
                  },
                  child: const Text('更新'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 检查已安装插件是否有 README 文件
  bool _hasReadme(PluginManifest plugin) {
    if (plugin.installPath == null) {
      return false;
    }
    
    // 如果 manifest 中指定了 readme 路径，直接检查
    if (plugin.readmePath != null) {
      final readmePath = '${plugin.installPath}/${plugin.readmePath}';
      if (File(readmePath).existsSync()) {
        return true;
      }
    }
    
    // 否则尝试常见的 README 文件名
    final commonReadmeNames = ['README.md', 'readme.md', 'README.MD', 'Readme.md'];
    for (final name in commonReadmeNames) {
      final path = '${plugin.installPath}/$name';
      if (File(path).existsSync()) {
        return true;
      }
    }
    
    return false;
  }
  
  /// 获取已安装插件的 README 文件路径
  String? _findReadmePath(PluginManifest plugin) {
    if (plugin.installPath == null) return null;
    
    // 优先使用 manifest 中指定的路径
    if (plugin.readmePath != null) {
      final path = '${plugin.installPath}/${plugin.readmePath}';
      if (File(path).existsSync()) {
        return path;
      }
    }
    
    // 尝试常见的 README 文件名
    final commonReadmeNames = ['README.md', 'readme.md', 'README.MD', 'Readme.md'];
    for (final name in commonReadmeNames) {
      final path = '${plugin.installPath}/$name';
      if (File(path).existsSync()) {
        return path;
      }
    }
    
    return null;
  }

  /// 显示已安装插件的 README 弹窗（本地文件）
  Future<void> _showReadmeDialog(PluginManifest plugin) async {
    final readmePath = _findReadmePath(plugin);
    if (readmePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未找到使用说明文件'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    final file = File(readmePath);
    
    String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('读取使用说明失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    if (mounted) {
      _showReadmeContent(plugin.name, content);
    }
  }

  /// 显示市场插件的 README 弹窗（从网络加载）
  Future<void> _showMarketplaceReadmeDialog(MarketplacePluginInfo plugin) async {
    if (plugin.readmeUrl == null || plugin.readmeUrl!.isEmpty) return;
    
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('加载使用说明...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    String content;
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(plugin.readmeUrl!));
      final response = await request.close();
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      content = await response.transform(utf8.decoder).join();
      httpClient.close();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载使用说明失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    if (mounted) {
      Navigator.of(context).pop(); // 关闭加载对话框
      _showReadmeContent(plugin.name, content);
    }
  }

  /// 显示 README 内容弹窗
  void _showReadmeContent(String pluginName, String content) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$pluginName - 使用说明',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // 内容区域 - 使用 Markdown 渲染
              Flexible(
                child: Markdown(
                  data: content,
                  selectable: true,
                  padding: const EdgeInsets.all(16),
                  styleSheet: MarkdownStyleSheet(
                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                    h1: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    h2: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    h3: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    code: TextStyle(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 4,
                        ),
                      ),
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
              // 底部按钮
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
