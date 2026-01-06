import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import 'main/tabs/home_tab.dart';
import 'main/tabs/my_files_tab.dart';
import 'main/tabs/history_tab.dart';
import 'main/tabs/settings_tab.dart';
import 'main/components/permission_screen.dart';
import 'editor_screen.dart';
import '../providers/plugin_provider.dart';
import '../plugins/extensions/navigation_extension.dart';

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
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      _handleSharedFiles(value);
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // 获取启动时的分享意图 (冷启动)
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      _handleSharedFiles(value);
    });
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    
    final file = files.first;
    final path = file.path;
    
    if (path.isEmpty) return;
    
    debugPrint("Received shared file: $path");
    
    // 确保文件存在
    if (File(path).existsSync()) {
      // 添加到最近文件并打开编辑器
      // 需要在下一帧执行，确保上下文准备好
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        final fileProvider = context.read<FileProvider>();
        fileProvider.addToRecentFiles(path);
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(filePath: path),
          ),
        );
      });
    }
  }

  Future<void> _initialize() async {
    final fileProvider = context.read<FileProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    
    await fileProvider.initialize();
    await settingsProvider.initialize();
    if (mounted) setState(() {});
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
    return Consumer<FileProvider>(
      builder: (context, fileProvider, child) {
        if (!fileProvider.hasPermission) {
          return PermissionScreen(fileProvider: fileProvider);
        }

        return Scaffold(
          body: _buildBody(fileProvider),
          bottomNavigationBar: _buildBottomNav(),
          drawer: _buildDrawer(),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, '首页'),
              _buildNavItem(1, Icons.folder_special_rounded, '我的文件'),
              _buildNavItem(2, Icons.history_rounded, '历史'),
              _buildNavItem(3, Icons.settings_rounded, '设置'),
            ],
          ),
        ),
      ),
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

  Widget _buildDrawer() {
    return Consumer<PluginProvider>(
      builder: (context, pluginProvider, child) {
        final navExtensions = pluginProvider.getNavigationExtensions()
            .where((ext) => ext.position == NavigationPosition.drawer)
            .toList();

        // Sort by priority
        navExtensions.sort((a, b) => a.priority.compareTo(b.priority));

        return Drawer(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                accountName: const Text('汐 Markdown'),
                accountEmail: Text(AppConstants.appVersion),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Image(image: AssetImage('app.png')),
                ),
              ),
              if (navExtensions.isEmpty)
                const ListTile(
                  title: Text('暂无插件导航项'),
                  leading: Icon(Icons.extension_off),
                ),
              ...navExtensions.map((ext) {
                return ListTile(
                  leading: Icon(ext.iconData),
                  title: Text(ext.title),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('插件页面: ${ext.title} (暂未实现加载)')),
                    );
                    // TODO: Implement plugin page loading (WebView or Custom Widget)
                  },
                );
              }),
              const Spacer(),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('设置'),
                onTap: () {
                  Navigator.pop(context);
                  _switchTab(3); // Switch to Settings tab
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
