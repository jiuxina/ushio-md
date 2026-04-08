import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/file_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/my_files_service.dart';
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
  final GlobalKey<_FolderBrowserWrapperState> _browserKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWorkspace();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

    await _myFilesService.initWorkspace();
    final path = await _myFilesService.getWorkspacePath();
    if (mounted) setState(() => _rootPath = path);
  }

  /// 刷新浏览器页面
  void _refreshBrowser() {
    _browserKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_rootPath == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return _FolderBrowserWrapper(
      key: _browserKey,
      folderPath: _rootPath!,
      showBackButton: false,
    );
  }
}

/// 包装 FolderBrowserScreen 以支持刷新
class _FolderBrowserWrapper extends StatefulWidget {
  final String folderPath;
  final bool showBackButton;

  const _FolderBrowserWrapper({
    super.key,
    required this.folderPath,
    this.showBackButton = false,
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
    );
  }
}
