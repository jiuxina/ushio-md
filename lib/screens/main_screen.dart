import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/editor_navigation_helper.dart';
import '../widgets/app_background.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/milkdown_webview_editor.dart';
import '../widgets/themed_feedback.dart';
import 'main/tabs/home_tab.dart';
import 'main/tabs/my_files_tab.dart';
import 'main/tabs/history_tab.dart';
import 'main/tabs/settings_tab.dart';
import 'main/components/permission_screen.dart';
import '../services/update_service.dart';
import '../utils/debug_log.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;

  // PageController for swipe gesture with follow-through effect
  late PageController _pageController;

  // Intent subscription
  StreamSubscription? _intentSub;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initialize();
    _setupIntentListener();
  }

  void _setupAnimations() {
    // 初始化PageController用于跟手滑动
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _setupIntentListener() {
    // 监听分享意图 (热启动)
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        _handleSharedFiles(value);
      },
      onError: (err) {
        appDebugLog("getIntentDataStream error: $err");
      },
    );

    // 获取启动时的分享意图 (冷启动)
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      _handleSharedFiles(value);
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    final file = files.first;
    final path = file.path;

    if (path.isEmpty) return;

    appDebugLog("Received shared file: $path");

    // 确保文件存在
    if (File(path).existsSync()) {
      // 添加到最近文件并打开编辑器
      // 需要在下一帧执行，确保上下文准备好
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final fileProvider = context.read<FileProvider>();
        fileProvider.addToRecentFiles(path);

        EditorNavigationHelper.openEditor(context, path);
      });
    }
  }

  Future<void> _initialize() async {
    final fileProvider = context.read<FileProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    await fileProvider.initialize();
    await settingsProvider.initialize();
    await _runFirstLaunchWarmupIfNeeded();
    unawaited(warmUpMilkdownWebAssets());
    if (mounted) setState(() {});

    // 延迟2秒后检查更新（避免阻塞启动流程）
    if (settingsProvider.autoCheckUpdate) {
      Future.delayed(const Duration(seconds: 2), _checkUpdateOnStartup);
    }
  }

  Future<void> _runFirstLaunchWarmupIfNeeded() async {
    final l10n = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    const warmupKey = 'startup_preview_warmup_done';
    if (prefs.getBool(warmupKey) == true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ThemedProgressDialog(
        title: l10n.firstLaunchInitializing,
        message: l10n.firstLaunchWarmingUp,
        icon: Icons.auto_awesome_rounded,
      ),
    );

    try {
      await warmUpMilkdownWebAssets();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await prefs.setBool(warmupKey, true);
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showThemedSnackBar(
          context,
          message: l10n.firstLaunchComplete,
          icon: Icons.check_circle_outline_rounded,
          accentColor: Theme.of(context).colorScheme.primary,
        );
      }
    }
  }

  /// 启动时静默检查更新，有新版本时显示底部提示条
  Future<void> _checkUpdateOnStartup() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final updateInfo = await UpdateService.checkForUpdate(
        AppConstants.appVersion,
      );
      if (!mounted) return;
      if (updateInfo != null && updateInfo.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.newVersionFound(updateInfo.latestVersion)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: l10n.view,
              onPressed: () {
                // 切换到设置tab
                _switchTab(3);
              },
            ),
          ),
        );
      }
    } catch (_) {
      // 静默忽略网络错误
    }
  }

  void _switchTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);

    // 使用PageController平滑滑动到目标页面
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<FileProvider>(
      builder: (context, fileProvider, child) {
        if (!fileProvider.hasPermission) {
          return PermissionScreen(fileProvider: fileProvider);
        }

        // 桌面端使用自定义标题栏
        final useCustomTitleBar =
            Platform.isWindows || Platform.isLinux || Platform.isMacOS;

        return AppBackground(
          wrapWithSafeArea: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                // 自定义标题栏（仅桌面端）
                if (useCustomTitleBar)
                  const CustomTitleBar(isEditorMode: false),
                // 主内容
                Expanded(child: _buildBody(fileProvider)),
              ],
            ),
            bottomNavigationBar: _buildBottomNav(l10n),
            drawer: _buildDrawer(l10n),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: settings.tabBarOpacity),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home_rounded, l10n.homeTab),
                    _buildNavItem(
                      1,
                      Icons.folder_special_rounded,
                      l10n.myFiles,
                    ),
                    _buildNavItem(2, Icons.history_rounded, l10n.historyTab),
                    _buildNavItem(3, Icons.settings_rounded, l10n.settings),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;

    // 使用Expanded让每个tab均分底栏空间，增大点击区域
    // 只显示图标，不显示文字（无字Tab导航）
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 确保透明区域也可点击
        onTap: () => _switchTab(index),
        child: Container(
          height: 56, // 增大点击高度，符合Material Design触摸目标尺寸
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: isSelected ? 26 : 24, // 选中时图标稍大
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(FileProvider fileProvider) {
    // 使用PageView实现跟手滑动切换，支持边滑动边松手、滑到一半再滑回来等自然手势
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        // 当页面滑动完成时同步底栏状态
        // 当页面滑动完成时同步底栏状态
        if (index != _currentIndex) {
          setState(() => _currentIndex = index);
        }
      },
      children: [
        HomeTab(fileProvider: fileProvider),
        MyFilesTab(fileProvider: fileProvider),
        HistoryTab(fileProvider: fileProvider),
        const SettingsTab(),
      ],
    );
  }

  Widget _buildDrawer(AppLocalizations l10n) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            accountName: Text(l10n.appName),
            accountEmail: Text(AppConstants.appVersion),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Image(image: AssetImage('app.png')),
            ),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(l10n.settings),
            onTap: () {
              Navigator.pop(context);
              _switchTab(3); // Switch to Settings tab
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
