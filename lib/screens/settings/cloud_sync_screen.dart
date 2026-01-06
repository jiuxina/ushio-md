// ============================================================================
// 云同步设置界面
// 
// WebDAV 配置和同步操作：
// - 配置 WebDAV 服务器凭据
// - 测试连接
// - 手动同步按钮
// - 自动同步开关
// - 同步状态和上次同步时间
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/webdav_service.dart';
import '../../services/my_files_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../widgets/app_background.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isTesting = false;
  bool _isSyncing = false;
  bool? _testResult;
  String? _syncError;

  late WebDAVService _webdavService;
  late CloudSyncService _cloudSyncService;

  @override
  void initState() {
    super.initState();
    _webdavService = WebDAVService();
    _cloudSyncService = CloudSyncService(
      webdavService: _webdavService,
      myFilesService: MyFilesService(),
    );
    
    // 加载现有配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      _urlController.text = settings.webdavUrl;
      _usernameController.text = settings.webdavUsername;
      _passwordController.text = settings.webdavPassword;
      
      // 如果有配置，初始化服务
      if (settings.isWebdavConfigured) {
        _webdavService.initialize(WebDAVConfig(
          url: settings.webdavUrl,
          username: settings.webdavUsername,
          password: settings.webdavPassword,
        ));
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云同步'),
        centerTitle: true,
      ),
      body: AppBackground(
        child: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    _buildCredentialsSection(),
                    const SizedBox(height: 24),
                    _buildSyncControlsSection(settings),
                    const SizedBox(height: 24),
                    _buildStatusSection(settings),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.cloud_sync,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WebDAV 云同步',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '将"我的文件"同步到云端 Ushio-MD 文件夹',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WebDAV 服务器配置',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: '服务器地址',
            hintText: 'https://dav.example.com',
            prefixIcon: const Icon(Icons.link),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.url,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入服务器地址';
            }
            if (!value.startsWith('http://') && !value.startsWith('https://')) {
              return '请输入有效的 URL（以 http:// 或 https:// 开头）';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: '用户名',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入用户名';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: '密码',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入密码';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(_isTesting ? '测试中...' : '测试连接'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saveCredentials,
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_testResult != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_testResult! ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_testResult! ? Colors.green : Colors.red).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _testResult! ? Icons.check_circle : Icons.error,
                  color: _testResult! ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Text(
                  _testResult! ? '连接成功！' : '连接失败，请检查配置',
                  style: TextStyle(
                    color: _testResult! ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSyncControlsSection(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '同步控制',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.autorenew,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '自动同步',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '保存文件时自动上传到云端',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.autoSyncEnabled,
                    onChanged: settings.isWebdavConfigured
                        ? (value) => settings.setAutoSyncEnabled(value)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: settings.isWebdavConfigured && !_isSyncing
                      ? _performSync
                      : null,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_isSyncing ? '同步中...' : '立即同步'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_syncError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _syncError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusSection(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '同步状态',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              _buildStatusRow(
                '配置状态',
                settings.isWebdavConfigured ? '已配置' : '未配置',
                settings.isWebdavConfigured ? Colors.green : Colors.orange,
              ),
              const Divider(height: 24),
              _buildStatusRow(
                '上次同步',
                settings.lastSyncTime != null
                    ? _formatDateTime(settings.lastSyncTime!)
                    : '从未同步',
                settings.lastSyncTime != null ? Colors.green : Colors.grey,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} 分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} 小时前';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    _webdavService.initialize(WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    ));

    final success = await _webdavService.testConnection();

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = success;
      });
    }
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    final settings = context.read<SettingsProvider>();
    await settings.saveWebdavCredentials(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    _webdavService.initialize(WebDAVConfig(
      url: _urlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check, color: Colors.green),
              const SizedBox(width: 12),
              const Text('配置已保存'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });

    // Step 1: 预览同步，检测冲突
    final preview = await _cloudSyncService.previewSync();
    
    if (!mounted) return;
    
    if (preview == null) {
      setState(() {
        _isSyncing = false;
        _syncError = '无法连接到服务器';
      });
      return;
    }
    
    // Step 2: 如果有变更或冲突，显示预览对话框
    List<SyncConflict>? resolvedConflicts;
    if (!preview.isEmpty) {
      final shouldProceed = await _showSyncPreviewDialog(preview);
      if (!shouldProceed) {
        setState(() => _isSyncing = false);
        return;
      }
      resolvedConflicts = preview.conflicts;
    }

    // Step 3: 执行同步
    final result = await _cloudSyncService.syncAll(resolvedConflicts: resolvedConflicts);

    if (mounted) {
      setState(() => _isSyncing = false);

      if (result.success) {
        context.read<SettingsProvider>().updateLastSyncTime();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Text('同步完成：上传 ${result.uploadedCount}，下载 ${result.downloadedCount}${result.deletedCount > 0 ? '，跳过 ${result.deletedCount}' : ''}'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        setState(() => _syncError = result.errorMessage);
      }
    }
  }
  
  /// 显示同步预览对话框
  Future<bool> _showSyncPreviewDialog(SyncPreview preview) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.sync,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('同步预览'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (preview.toUpload.isNotEmpty) ...[
                _buildPreviewSection(
                  '📤 将上传 ${preview.toUpload.length} 个文件',
                  Colors.blue,
                  preview.toUpload,
                ),
                const SizedBox(height: 12),
              ],
              if (preview.toDownload.isNotEmpty) ...[
                _buildPreviewSection(
                  '📥 将下载 ${preview.toDownload.length} 个文件',
                  Colors.green,
                  preview.toDownload,
                ),
                const SizedBox(height: 12),
              ],
              if (preview.hasConflicts) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '⚠️ ${preview.conflicts.length} 个文件存在冲突',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '这些文件在本地和云端都有修改，请选择保留哪个版本：',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ...preview.conflicts.map((c) => _buildConflictItem(c)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('开始同步'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  Widget _buildPreviewSection(String title, Color color, List<String> files) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (files.length <= 3) ...[
            const SizedBox(height: 4),
            ...files.map((f) => Text(
              f,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
          ],
        ],
      ),
    );
  }
  
  Widget _buildConflictItem(SyncConflict conflict) {
    return StatefulBuilder(
      builder: (context, setConflictState) {
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conflict.relativePath,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '本地: ${_formatConflictTime(conflict.localModified)} | 云端: ${_formatConflictTime(conflict.remoteModified)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildResolutionButton(
                      conflict,
                      ConflictResolution.keepLocal,
                      '保留本地',
                      Icons.phone_android,
                      setConflictState,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildResolutionButton(
                      conflict,
                      ConflictResolution.keepRemote,
                      '保留云端',
                      Icons.cloud,
                      setConflictState,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildResolutionButton(
                      conflict,
                      ConflictResolution.skip,
                      '跳过',
                      Icons.skip_next,
                      setConflictState,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildResolutionButton(
    SyncConflict conflict,
    ConflictResolution resolution,
    String label,
    IconData icon,
    StateSetter setConflictState,
  ) {
    final isSelected = conflict.resolution == resolution;
    return GestureDetector(
      onTap: () {
        setConflictState(() {
          conflict.resolution = resolution;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: isSelected ? Theme.of(context).colorScheme.primary : null),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatConflictTime(DateTime time) {
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

