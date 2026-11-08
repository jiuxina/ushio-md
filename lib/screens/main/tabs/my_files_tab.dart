import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../providers/file_provider.dart';
import '../../../utils/debug_log.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/my_files_service.dart';
import '../../../utils/capsule_nav_insets.dart';
import '../../folder_browser_screen.dart';

class MyFilesTab extends StatefulWidget {
  final FileProvider fileProvider;

  const MyFilesTab({super.key, required this.fileProvider});

  @override
  State<MyFilesTab> createState() => _MyFilesTabState();
}

class _MyFilesTabState extends State<MyFilesTab> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final MyFilesService _myFilesService = MyFilesService();
  String? _rootPath;

  /// 工作区初始化失败的原因；有值时不再显示转圈，而是给重试入口
  String? _initError;
  final GlobalKey<_FolderBrowserWrapperState> _browserKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.fileProvider.addListener(_onFileProviderChanged);
    _initWorkspace();
  }

  @override
  void dispose() {
    widget.fileProvider.removeListener(_onFileProviderChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresh the browser when FileProvider notifies (e.g. after file creation/deletion)
  void _onFileProviderChanged() {
    if (mounted) {
      _refreshBrowser();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用从后台恢复时，刷新文件列表
    if (state == AppLifecycleState.resumed) {
      _refreshBrowser();
    }
  }

  Future<void> _initWorkspace() async {
    // Set SettingsProvider so MyFilesService can access custom workspace base path
    final settings = context.read<SettingsProvider>();
    _myFilesService.setSettingsProvider(settings);

    String? path;
    Object? failure;
    try {
      await _myFilesService.initWorkspace();
      path = await _myFilesService.getWorkspacePath();
    } catch (e) {
      failure = e;
      appDebugLog('MyFilesTab: 初始化工作区失败: $e');
    }
    if (!mounted) return;

    if (path == null) {
      // 连工作区都拿不到时不能一直转圈，退到应用私有目录，
      // 至少让用户能新建和编辑文件。
      try {
        final privateDir = await getApplicationDocumentsDirectory();
        final fallback =
            '${privateDir.path}${Platform.pathSeparator}${_myFilesService.getWorkspaceName()}';
        await Directory(fallback).create(recursive: true);
        path = fallback;
      } catch (e) {
        appDebugLog('MyFilesTab: 回退应用私有目录也失败: $e');
      }
    }
    if (!mounted) return;

    setState(() {
      _rootPath = path;
      _initError = path == null ? '$failure' : null;
    });
  }

  /// 刷新浏览器页面
  void _refreshBrowser() {
    _browserKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_rootPath == null) {
      if (_initError == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '无法打开文件目录\n$_initError',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _initError = null;
                    _rootPath = null;
                  });
                  _initWorkspace();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return _FolderBrowserWrapper(
      key: _browserKey,
      folderPath: _rootPath!,
      showBackButton: false,
      bottomPadding: capsuleTabBarBottomInset(context),
    );
  }
}

/// 包装 FolderBrowserScreen 以支持刷新
class _FolderBrowserWrapper extends StatefulWidget {
  final String folderPath;
  final bool showBackButton;
  final double bottomPadding;

  const _FolderBrowserWrapper({
    super.key,
    required this.folderPath,
    this.showBackButton = false,
    this.bottomPadding = 0,
  });

  @override
  State<_FolderBrowserWrapper> createState() => _FolderBrowserWrapperState();
}

class _FolderBrowserWrapperState extends State<_FolderBrowserWrapper> {
  final GlobalKey<FolderBrowserScreenState> _browserKey = GlobalKey();

  /// 刷新文件列表
  void refresh() {
    _browserKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FolderBrowserScreen(
      key: _browserKey,
      folderPath: widget.folderPath,
      showBackButton: widget.showBackButton,
      bottomPadding: widget.bottomPadding,
    );
  }
}
