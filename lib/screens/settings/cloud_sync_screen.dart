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
import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../services/webdav_service.dart';
import '../../services/ftp_service.dart';
import '../../services/sync_service_interface.dart';
import '../../services/my_files_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../widgets/app_background.dart';
import '../../utils/app_style.dart';
import '../../widgets/app_surface.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _formKey = GlobalKey<FormState>();

  // WebDAV 控制器
  final _urlController = TextEditingController();
  final _webdavUsernameController = TextEditingController();
  final _webdavPasswordController = TextEditingController();

  // FTP 控制器
  final _ftpUrlController = TextEditingController();
  final _ftpUsernameController = TextEditingController();
  final _ftpPasswordController = TextEditingController();

  // 共用控制器
  final _folderNameController = TextEditingController();
  final _remotePathController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isTesting = false;
  bool _isSyncing = false;
  bool? _testResult;
  String? _syncError;

  late SyncServiceInterface _syncService;
  late CloudSyncService _cloudSyncService;
  String _selectedSyncType = 'webdav'; // 默认 WebDAV

  @override
  void initState() {
    super.initState();

    // 初始化服务（先用默认配置初始化，避免late变量访问错误）
    _syncService = WebDAVService();
    _cloudSyncService = CloudSyncService(
      syncService: _syncService,
      myFilesService: MyFilesService(),
    );

    // 加载现有配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();

      // 加载同步类型
      _selectedSyncType = settings.syncType;

      // 加载 WebDAV 配置
      _urlController.text = settings.webdavUrl;
      _webdavUsernameController.text = settings.webdavUsername;
      // 密码不从 settings 直接读取，保持空或显示占位符
      final webdavCreds = settings.getWebdavCredentials();
      _webdavPasswordController.text = webdavCreds['password'] ?? '';

      // 加载 FTP 配置
      _ftpUrlController.text = settings.ftpUrl;
      _ftpUsernameController.text = settings.ftpUsername;
      // 密码不从 settings 直接读取，保持空或显示占位符
      final ftpCreds = settings.getFtpCredentials();
      _ftpPasswordController.text = ftpCreds['password'] ?? '';

      // 加载共用配置
      _folderNameController.text = settings.syncFolderName;
      _remotePathController.text = settings.syncRemotePath;

      // 初始化服务
      _initializeSyncService();
    });
  }

  void _initializeSyncService() {
    final settings = context.read<SettingsProvider>();

    if (_selectedSyncType == 'webdav') {
      final webdavService = WebDAVService();
      if (settings.isWebdavConfigured) {
        webdavService.setRemoteWorkspaceName(settings.syncFolderName);
        webdavService.setRemotePathPrefix(settings.syncRemotePath);
        final creds = settings.getWebdavCredentials();
        webdavService.initialize(
          WebDAVConfig(
            url: creds['url']!,
            username: creds['username']!,
            password: creds['password']!,
          ),
        );
      }
      _syncService = webdavService;
    } else {
      final ftpService = FTPService();
      if (settings.isFtpConfigured) {
        ftpService.setRemoteWorkspaceName(settings.syncFolderName);
        ftpService.setRemotePathPrefix(settings.syncRemotePath);
        final creds = settings.getFtpCredentials();
        ftpService.initialize(
          FTPConfig(
            host: settings.ftpHost,
            port: settings.ftpPort,
            username: creds['username']!,
            password: creds['password']!,
          ),
        );
      }
      _syncService = ftpService;
    }

    // Create MyFilesService and set SettingsProvider to ensure it uses custom workspace base path
    final myFilesService = MyFilesService();
    myFilesService.setSettingsProvider(settings);

    _cloudSyncService = CloudSyncService(
      syncService: _syncService,
      myFilesService: myFilesService,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    _ftpUrlController.dispose();
    _ftpUsernameController.dispose();
    _ftpPasswordController.dispose();
    _folderNameController.dispose();
    _remotePathController.dispose();
    _cloudSyncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // 允许用户在同步时返回，同步将在后台继续
        if (_isSyncing) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('同步将在后台继续')),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: AppBackground(
        wrapWithSafeArea: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(l10n.cloudSync),
            centerTitle: true,
          ),
          body: Consumer<SettingsProvider>(
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
      ),
    );
  }

  Widget _buildInfoCard() {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final fullPath = settings.getFullSyncPath();
    final syncTypeName = _selectedSyncType == 'webdav' ? l10n.webdav : l10n.ftp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        boxShadow: appStyle.surfaceShadow,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: appStyle.useBorderlessButtons
            ? null
            : Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
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
                  '$syncTypeName ${l10n.cloudSync}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '将"我的文件"同步到云端 $fullPath 文件夹',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cloudSyncConfig,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // 同步类型选择器
        DropdownButtonFormField<String>(
          value: _selectedSyncType,
          decoration: InputDecoration(
            labelText: l10n.syncServiceType,
            prefixIcon: const Icon(Icons.sync_alt),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            DropdownMenuItem(value: 'webdav', child: Text(l10n.webdav)),
            DropdownMenuItem(value: 'ftp', child: Text(l10n.ftp)),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedSyncType = value;
                _testResult = null; // 重置测试结果
              });
              _initializeSyncService();
            }
          },
        ),
        const SizedBox(height: 16),

        // 根据选择的类型显示不同的配置字段
        if (_selectedSyncType == 'webdav') ..._buildWebDAVFields(),
        if (_selectedSyncType == 'ftp') ...[
          // FTP 安全警告
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '⚠️ FTP 不加密传输，密码和文件内容可能被窃取。建议使用 WebDAV (HTTPS)。此功能将在未来版本移除。',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._buildFTPFields(),
        ],

        // 共用字段
        const SizedBox(height: 16),
        TextFormField(
          controller: _folderNameController,
          decoration: InputDecoration(
            labelText: l10n.cloudFolderName,
            hintText: 'Ushio-MD',
            prefixIcon: const Icon(Icons.folder),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            helperText: l10n.folderNameHelper,
            helperMaxLines: 2,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.enterFolderName;
            }
            if (value.contains('/') || value.contains('\\')) {
              return l10n.folderNameNoSlashes;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _remotePathController,
          decoration: InputDecoration(
            labelText: l10n.cloudPathPrefix,
            hintText: '例如：/storage/emulated/0/ 或 /documents/',
            prefixIcon: const Icon(Icons.folder_open),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            helperText: '${l10n.cloudPathHelper}${_folderNameController.text}',
          ),
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
                label: Text(_isTesting ? l10n.testing : l10n.testConnection),
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
                label: Text(l10n.saveConfig),
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
              color: (_testResult! ? Colors.green : Colors.red).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_testResult! ? Colors.green : Colors.red).withValues(
                  alpha: 0.3,
                ),
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
                  _testResult! ? l10n.connectionSuccess : l10n.connectionFailed,
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

  List<Widget> _buildWebDAVFields() {
    final l10n = AppLocalizations.of(context)!;
    return [
      TextFormField(
        controller: _urlController,
        decoration: InputDecoration(
          labelText: l10n.serverAddress,
          hintText: 'https://dav.example.com',
          prefixIcon: const Icon(Icons.link),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        keyboardType: TextInputType.url,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return l10n.enterServerAddress;
          }
          if (!value.startsWith('http://') && !value.startsWith('https://')) {
            return l10n.enterValidUrl;
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _webdavUsernameController,
        decoration: InputDecoration(
          labelText: l10n.username,
          prefixIcon: const Icon(Icons.person),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return l10n.enterUsername;
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _webdavPasswordController,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          labelText: l10n.password,
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return l10n.enterPassword;
          }
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildFTPFields() {
    final l10n = AppLocalizations.of(context)!;
    return [
      TextFormField(
        controller: _ftpUrlController,
        decoration: InputDecoration(
          labelText: l10n.ftpServerAddress,
          hintText: 'ftp://192.168.124.6:2121',
          prefixIcon: const Icon(Icons.dns),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          helperText: l10n.ftpFormatHelper,
        ),
        keyboardType: TextInputType.url,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return l10n.enterFtpServer;
          }
          // 验证格式
          final trimmed = value.trim();
          if (!trimmed.startsWith('ftp://')) {
            return l10n.addressShouldStartWithFtp;
          }
          // 尝试解析主机和端口
          String cleanUrl = trimmed.substring(6).replaceAll(RegExp(r'/+$'), '');
          if (cleanUrl.isEmpty) {
            return l10n.enterValidHost;
          }
          if (cleanUrl.contains(':')) {
            final parts = cleanUrl.split(':');
            if (parts.length != 2) {
              return l10n.invalidFormat;
            }
            final port = int.tryParse(parts[1]);
            if (port == null || port < 1 || port > 65535) {
              return l10n.portRange;
            }
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _ftpUsernameController,
        decoration: InputDecoration(
          labelText: l10n.username,
          prefixIcon: const Icon(Icons.person),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return l10n.enterUsername;
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _ftpPasswordController,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          labelText: l10n.password,
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return l10n.enterPassword;
          }
          return null;
        },
      ),
    ];
  }

  Widget _buildSyncControlsSection(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.syncControls,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        AppSurface(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          border: appStyle.useBorderlessButtons
              ? null
              : Border.all(
                  color: Theme.of(
                    context,
                  ).dividerColor.withValues(alpha: 0.5),
                ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
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
                        Text(
                          l10n.autoSync,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          l10n.autoSyncDescription,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.autoSyncEnabled,
                    onChanged: settings.isSyncConfigured
                        ? (value) => settings.setAutoSyncEnabled(value)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 同步进度条
              ValueListenableBuilder<SyncProgress?>(
                valueListenable: _cloudSyncService.progressNotifier,
                builder: (context, progress, child) {
                  if (progress == null || !_isSyncing) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  progress.operation == 'upload'
                                      ? Icons.upload
                                      : Icons.download,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    progress.currentFile,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${progress.processedFiles}/${progress.totalFiles}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress.percentage / 100,
                                minHeight: 8,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${progress.percentage.toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: settings.isSyncConfigured && !_isSyncing
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
                  label: Text(_isSyncing ? l10n.syncing : l10n.syncNow),
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
    final l10n = AppLocalizations.of(context)!;
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final syncTypeName = settings.syncType == 'webdav' ? l10n.webdav : l10n.ftp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.syncStatus,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        AppSurface(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          border: appStyle.useBorderlessButtons
              ? null
              : Border.all(
                  color: Theme.of(
                    context,
                  ).dividerColor.withValues(alpha: 0.5),
                ),
          child: Column(
            children: [
              _buildStatusRow(
                l10n.syncService,
                syncTypeName,
                Theme.of(context).colorScheme.primary,
              ),
              const Divider(height: 24),
              _buildStatusRow(
                l10n.configStatus,
                settings.isSyncConfigured
                    ? l10n.configured
                    : l10n.notConfigured,
                settings.isSyncConfigured ? Colors.green : Colors.orange,
              ),
              const Divider(height: 24),
              _buildStatusRow(
                l10n.lastSync,
                settings.lastSyncTime != null
                    ? _formatDateTime(settings.lastSyncTime!)
                    : l10n.neverSynced,
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return l10n.justNow;
    } else if (diff.inHours < 1) {
      return l10n.minutesAgo(diff.inMinutes);
    } else if (diff.inDays < 1) {
      return l10n.hoursAgo(diff.inHours);
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

    _syncService.setRemoteWorkspaceName(_folderNameController.text.trim());
    _syncService.setRemotePathPrefix(_remotePathController.text.trim());

    if (_selectedSyncType == 'webdav') {
      (_syncService as WebDAVService).initialize(
        WebDAVConfig(
          url: _urlController.text.trim(),
          username: _webdavUsernameController.text.trim(),
          password: _webdavPasswordController.text,
        ),
      );
    } else {
      // 解析 FTP URL
      final ftpUrl = _ftpUrlController.text.trim();
      String host = '';
      int port = 21;

      if (ftpUrl.isNotEmpty) {
        String cleanUrl = ftpUrl;
        if (cleanUrl.startsWith('ftp://')) {
          cleanUrl = cleanUrl.substring(6);
        }
        cleanUrl = cleanUrl.replaceAll(RegExp(r'/+$'), '');

        if (cleanUrl.contains(':')) {
          final parts = cleanUrl.split(':');
          host = parts[0];
          port = int.tryParse(parts[1]) ?? 21;
        } else {
          host = cleanUrl;
        }
      }

      (_syncService as FTPService).initialize(
        FTPConfig(
          host: host,
          port: port,
          username: _ftpUsernameController.text.trim(),
          password: _ftpPasswordController.text,
        ),
      );
    }

    final success = await _syncService.testConnection();

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

    // 保存同步类型
    await settings.setSyncType(_selectedSyncType);

    // 保存对应的凭据
    if (_selectedSyncType == 'webdav') {
      await settings.setWebdavUrl(_urlController.text.trim());
      await settings.setWebdavUsername(_webdavUsernameController.text.trim());
      await settings.setWebdavPassword(_webdavPasswordController.text);
    } else {
      await settings.setFtpUrl(_ftpUrlController.text.trim());
      await settings.setFtpUsername(_ftpUsernameController.text.trim());
      await settings.setFtpPassword(_ftpPasswordController.text);
    }

    // 保存共用配置
    await settings.setSyncFolderName(_folderNameController.text.trim());
    await settings.setSyncRemotePath(_remotePathController.text.trim());

    // 重新初始化服务
    _initializeSyncService();

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check, color: Colors.green),
              const SizedBox(width: 12),
              Text(l10n.configSaved),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _isSyncing = false;
        _syncError = l10n.cannotConnectServer;
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
    final result = await _cloudSyncService.syncAll(
      resolvedConflicts: resolvedConflicts,
    );

    if (mounted) {
      setState(() => _isSyncing = false);
      final l10n = AppLocalizations.of(context)!;

      if (result.success) {
        context.read<SettingsProvider>().updateLastSyncTime();
        final deleted = result.deletedCount > 0
            ? '，跳过 ${result.deletedCount}'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                Text(
                  l10n.syncComplete(
                    result.uploadedCount,
                    result.downloadedCount,
                    deleted,
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
          builder: (dialogContext) {
            final l10n = AppLocalizations.of(dialogContext)!;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.sync,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.syncPreview),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (preview.toUpload.isNotEmpty) ...[
                      _buildPreviewSection(
                        l10n.willUpload(preview.toUpload.length),
                        Colors.blue,
                        preview.toUpload,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (preview.toDownload.isNotEmpty) ...[
                      _buildPreviewSection(
                        l10n.willDownload(preview.toDownload.length),
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
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.conflictWarning(
                                    preview.conflicts.length,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.conflictDescription,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            ...preview.conflicts.map(
                              (c) => _buildConflictItem(c),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.sync, size: 18),
                  label: Text(l10n.startSync),
                ),
              ],
            );
          },
        ) ??
        false;
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
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          if (files.length <= 3) ...[
            const SizedBox(height: 4),
            ...files.map(
              (f) => Text(
                f,
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConflictItem(SyncConflict conflict) {
    final l10n = AppLocalizations.of(context)!;
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
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.localVersion}: ${_formatConflictTime(conflict.localModified)} | ${l10n.cloudVersion}: ${_formatConflictTime(conflict.remoteModified)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildResolutionButton(
                      conflict,
                      ConflictResolution.keepLocal,
                      l10n.keepLocal,
                      Icons.phone_android,
                      setConflictState,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildResolutionButton(
                      conflict,
                      ConflictResolution.keepRemote,
                      l10n.keepRemote,
                      Icons.cloud,
                      setConflictState,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildResolutionButton(
                      conflict,
                      ConflictResolution.skip,
                      l10n.skip,
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
            Icon(
              icon,
              size: 16,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
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
