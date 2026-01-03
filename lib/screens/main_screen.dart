import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/file_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import 'editor_screen.dart';
import 'folder_browser_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  
  // Animation controller for tab transitions
  late AnimationController _tabAnimationController;
  late Animation<double> _tabAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initialize();
  }

  void _setupAnimations() {
    _tabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tabAnimation = CurvedAnimation(
      parent: _tabAnimationController,
      curve: Curves.easeOutCubic,
    );
    _tabAnimationController.forward();
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
    _previousIndex = _currentIndex;
    setState(() => _currentIndex = index);
    _tabAnimationController.reset();
    _tabAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FileProvider>(
      builder: (context, fileProvider, child) {
        if (!fileProvider.hasPermission) {
          return _buildPermissionScreen(fileProvider);
        }

        return Scaffold(
          body: _buildBody(fileProvider),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              _buildNavItem(1, Icons.history_rounded, '最近文件'),
              _buildNavItem(2, Icons.folder_rounded, '最近文件夹'),
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

    return GestureDetector(
      onTap: () => _switchTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FileProvider fileProvider) {
    Widget content;
    switch (_currentIndex) {
      case 0:
        content = _buildHomeTab(fileProvider);
        break;
      case 1:
        content = _buildRecentFilesTab(fileProvider);
        break;
      case 2:
        content = _buildRecentFoldersTab(fileProvider);
        break;
      case 3:
        content = _buildSettingsTab();
        break;
      default:
        content = _buildHomeTab(fileProvider);
    }
    
    // Direction-aware slide animation
    // Slide from right when moving to higher index, from left when moving to lower index
    final isMovingRight = _currentIndex > _previousIndex;
    final beginOffset = isMovingRight 
        ? const Offset(0.15, 0)   // Slide from right
        : const Offset(-0.15, 0); // Slide from left
    
    return AnimatedBuilder(
      animation: _tabAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(_tabAnimation),
          child: FadeTransition(
            opacity: _tabAnimation,
            child: child,
          ),
        );
      },
      child: content,
    );
  }

  Widget _buildGradientContainer({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    
    Widget content = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                  const Color(0xFF0f0f23),
                ]
              : [
                  const Color(0xFFf8f9ff),
                  const Color(0xFFf0f4ff),
                  const Color(0xFFe8eeff),
                ],
        ),
      ),
      child: SafeArea(child: child),
    );
    
    // Apply background image if set
    if (settings.backgroundImagePath != null) {
      final bgFile = File(settings.backgroundImagePath!);
      if (bgFile.existsSync()) {
        Widget bgImage = Image.file(
          bgFile,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
        
        // Apply blur effect
        if (settings.backgroundEffect == 'blur') {
          bgImage = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: settings.backgroundBlur,
              sigmaY: settings.backgroundBlur,
            ),
            child: bgImage,
          );
        }
        
        content = Stack(
          fit: StackFit.expand,
          children: [
            bgImage,
            // Apply overlay effect
            if (settings.backgroundEffect == 'overlay')
              Container(
                color: isDark 
                    ? Colors.black.withOpacity(settings.backgroundOverlayOpacity)
                    : Colors.white.withOpacity(settings.backgroundOverlayOpacity),
              ),
            SafeArea(child: child),
          ],
        );
      }
    }
    
    return content;
  }

  // ==================== HOME TAB ====================
  Widget _buildHomeTab(FileProvider fileProvider) {
    return _buildGradientContainer(
      child: Column(
        children: [
          _buildHomeHeader(fileProvider),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => fileProvider.refresh(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildQuickActions(fileProvider),
                  
                  // Pinned files section
                  if (fileProvider.pinnedFiles.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('置顶文件', Icons.push_pin),
                    const SizedBox(height: 12),
                    _buildPinnedFilesList(fileProvider),
                  ],
                  
                  // Pinned folders section
                  if (fileProvider.pinnedFolders.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('置顶文件夹', Icons.folder_special),
                    const SizedBox(height: 12),
                    _buildPinnedFoldersList(fileProvider),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeHeader(FileProvider fileProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: _buildAppTitle(),
    );
  }

  Widget _buildAppTitle() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              AppConstants.appDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(FileProvider fileProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.15),
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '快速操作',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // First row
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.add_circle,
                  label: '新建文件',
                  color: Colors.green,
                  onTap: () => _showCreateFileDialog(fileProvider),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.create_new_folder,
                  label: '新建文件夹',
                  color: Colors.orange,
                  onTap: () => _showCreateFolderDialog(fileProvider),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.file_open,
                  label: '打开文件',
                  color: Colors.blue,
                  onTap: () async {
                    final path = await fileProvider.pickAndOpenFile();
                    if (path != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditorScreen(filePath: path),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.folder_open,
                  label: '打开文件夹',
                  color: Colors.amber,
                  onTap: () async {
                    final path = await fileProvider.pickDirectory();
                    if (path != null && mounted) {
                      await fileProvider.addToRecentFolders(path);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FolderBrowserScreen(folderPath: path),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
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
    );
  }

  Widget _buildPinnedFilesList(FileProvider fileProvider) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fileProvider.pinnedFiles.length,
      onReorder: fileProvider.reorderPinnedFiles,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scale = 1.0 + (animation.value * 0.05);
            return Transform.scale(scale: scale, child: child);
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final path = fileProvider.pinnedFiles[index];
        return _buildDraggableFileTile(
          key: ValueKey(path),
          path: path,
          fileProvider: fileProvider,
          isPinned: true,
        );
      },
    );
  }

  Widget _buildPinnedFoldersList(FileProvider fileProvider) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fileProvider.pinnedFolders.length,
      onReorder: fileProvider.reorderPinnedFolders,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scale = 1.0 + (animation.value * 0.05);
            return Transform.scale(scale: scale, child: child);
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final path = fileProvider.pinnedFolders[index];
        return _buildDraggableFolderTile(
          key: ValueKey(path),
          path: path,
          fileProvider: fileProvider,
          isPinned: true,
        );
      },
    );
  }

  Widget _buildDraggableFileTile({
    required Key key,
    required String path,
    required FileProvider fileProvider,
    bool isPinned = false,
  }) {
    final fileName = path.split(Platform.pathSeparator).last;
    final file = File(path);
    final exists = file.existsSync();

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPinned 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: exists
              ? () {
                  fileProvider.addToRecentFiles(path);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditorScreen(filePath: path),
                    ),
                  );
                }
              : null,
          onLongPress: () => _showFileContextMenu(path, fileProvider, isPinned: isPinned),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (exists ? Theme.of(context).colorScheme.primary : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.description,
                    color: exists ? Theme.of(context).colorScheme.primary : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName.replaceAll('.md', '').replaceAll('.markdown', ''),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        exists ? path : '文件不存在',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: fileProvider.pinnedFiles.indexOf(path),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableFolderTile({
    required Key key,
    required String path,
    required FileProvider fileProvider,
    bool isPinned = false,
  }) {
    final folderName = path.split(Platform.pathSeparator).last;

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPinned 
              ? Colors.amber.withOpacity(0.3)
              : Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            fileProvider.addToRecentFolders(path);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FolderBrowserScreen(folderPath: path),
              ),
            );
          },
          onLongPress: () => _showFolderContextMenu(path, fileProvider, isPinned: isPinned),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folderName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        path,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: fileProvider.pinnedFolders.indexOf(path),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentDirectoryContent(FileProvider fileProvider) {
    if (fileProvider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (fileProvider.error != null) {
      return _buildErrorState(fileProvider.error!);
    }

    if (fileProvider.files.isEmpty) {
      return _buildEmptyState('没有找到 Markdown 文件');
    }

    return Column(
      children: fileProvider.files
          .map((file) => _buildFileTile(file, fileProvider))
          .toList(),
    );
  }

  // ==================== RECENT FILES TAB ====================
  Widget _buildRecentFilesTab(FileProvider fileProvider) {
    return _buildGradientContainer(
      child: Column(
        children: [
          _buildTabHeader('最近文件', Icons.history),
          Expanded(
            child: fileProvider.recentFiles.isEmpty
                ? _buildEmptyState('没有最近打开的文件')
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: fileProvider.recentFiles.length,
                    itemBuilder: (context, index) {
                      return _buildRecentFileTile(
                        fileProvider.recentFiles[index],
                        fileProvider,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== RECENT FOLDERS TAB ====================
  Widget _buildRecentFoldersTab(FileProvider fileProvider) {
    return _buildGradientContainer(
      child: Column(
        children: [
          _buildTabHeader('最近文件夹', Icons.folder),
          Expanded(
            child: fileProvider.recentFolders.isEmpty
                ? _buildEmptyState('没有最近文件夹')
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: fileProvider.recentFolders.length,
                    itemBuilder: (context, index) {
                      return _buildFolderTile(
                        fileProvider.recentFolders[index],
                        fileProvider,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  // ==================== SHARED WIDGETS ====================
  Widget _buildGlassCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor.withOpacity(0.2),
                        iconColor.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                trailing ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFileTile(String path, FileProvider fileProvider) {
    final fileName = path.split(Platform.pathSeparator).last;
    final file = File(path);
    final exists = file.existsSync();
    String dateStr = '';
    if (exists) {
      try {
        final modified = file.lastModifiedSync();
        dateStr = '${modified.month}/${modified.day} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return _buildGlassCard(
      icon: Icons.description,
      iconColor: exists
          ? Theme.of(context).colorScheme.primary
          : Colors.grey,
      title: fileName.replaceAll('.md', '').replaceAll('.markdown', ''),
      subtitle: exists ? (dateStr.isNotEmpty ? '$dateStr · $path' : path) : '文件不存在',
      onTap: exists
          ? () {
              fileProvider.addToRecentFiles(path);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditorScreen(filePath: path),
                ),
              );
            }
          : () {},
      onLongPress: () => _showFileContextMenu(path, fileProvider, isRecent: true),
    );
  }

  Widget _buildFolderTile(String path, FileProvider fileProvider) {
    final folderName = path.split(Platform.pathSeparator).last;
    final dir = Directory(path);
    String dateStr = '';
    try {
      if (dir.existsSync()) {
        final stat = dir.statSync();
        final modified = stat.modified;
        dateStr = '${modified.month}/${modified.day} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    return _buildGlassCard(
      icon: Icons.folder,
      iconColor: Colors.amber,
      title: folderName,
      subtitle: dateStr.isNotEmpty ? '$dateStr · $path' : path,
      onTap: () {
        fileProvider.addToRecentFolders(path);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FolderBrowserScreen(folderPath: path),
          ),
        );
      },
      onLongPress: () => _showFolderContextMenu(path, fileProvider),
    );
  }

  Widget _buildFileTile(dynamic file, FileProvider fileProvider) {
    return _buildGlassCard(
      icon: Icons.description,
      iconColor: Theme.of(context).colorScheme.primary,
      title: file.displayName,
      subtitle: '${file.formattedSize} · ${file.formattedDate}',
      onTap: () {
        fileProvider.addToRecentFiles(file.path);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(filePath: file.path),
          ),
        );
      },
      onLongPress: () => _showFileContextMenu(file.path, fileProvider),
    );
  }

  List<PopupMenuEntry<String>> _buildFileMenuItems() {
    return [
      const PopupMenuItem(
        value: 'rename',
        child: Row(
          children: [
            Icon(Icons.edit),
            SizedBox(width: 8),
            Text('重命名'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('删除'),
          ],
        ),
      ),
    ];
  }

  void _showFileContextMenu(String path, FileProvider fileProvider, {bool isRecent = false, bool isPinned = false}) {
    final fileName = path.split(Platform.pathSeparator).last;
    final isCurrentlyPinned = fileProvider.isFilePinned(path);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              fileName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _buildContextMenuItem(
              icon: Icons.open_in_new,
              label: '打开',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditorScreen(filePath: path),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildContextMenuItem(
              icon: isCurrentlyPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: isCurrentlyPinned ? '取消置顶' : '置顶到首页',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                fileProvider.togglePinFile(path);
              },
            ),
            if (!isRecent && !isPinned) ...[
              const SizedBox(height: 8),
              _buildContextMenuItem(
                icon: Icons.edit,
                label: '重命名',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(path, fileProvider);
                },
              ),
            ],
            const SizedBox(height: 8),
            _buildContextMenuItem(
              icon: Icons.delete,
              label: isRecent ? '从列表中移除' : (isPinned ? '取消置顶' : '删除文件'),
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                if (isRecent) {
                  fileProvider.removeFromRecentFiles(path);
                } else if (isPinned) {
                  fileProvider.togglePinFile(path);
                } else {
                  _confirmDelete(path, fileProvider);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFolderContextMenu(String path, FileProvider fileProvider, {bool isPinned = false}) {
    final folderName = path.split(Platform.pathSeparator).last;
    final isCurrentlyPinned = fileProvider.isFolderPinned(path);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              folderName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _buildContextMenuItem(
              icon: Icons.folder_open,
              label: '打开文件夹',
              color: Colors.amber,
              onTap: () {
                Navigator.pop(context);
                fileProvider.addToRecentFolders(path);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FolderBrowserScreen(folderPath: path),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildContextMenuItem(
              icon: isCurrentlyPinned ? Icons.push_pin_outlined : Icons.push_pin,
              label: isCurrentlyPinned ? '取消置顶' : '置顶到首页',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                fileProvider.togglePinFolder(path);
              },
            ),
            const SizedBox(height: 8),
            _buildContextMenuItem(
              icon: Icons.add_circle,
              label: '在此新建文件',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _showCreateFileInFolderDialog(path, fileProvider);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFileAction(String action, String path, FileProvider fileProvider) async {
    switch (action) {
      case 'rename':
        _showRenameDialog(path, fileProvider);
        break;
      case 'delete':
        _confirmDelete(path, fileProvider);
        break;
    }
  }

  Future<void> _showRenameDialog(String path, FileProvider fileProvider) async {
    final fileName = path.split(Platform.pathSeparator).last;
    final nameWithoutExt = fileName.replaceAll('.md', '').replaceAll('.markdown', '');
    final controller = TextEditingController(text: nameWithoutExt);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('重命名文件'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '新文件名',
            suffixText: '.md',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != nameWithoutExt) {
      try {
        final dir = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
        final newPath = '$dir${Platform.pathSeparator}$result.md';
        final file = File(path);
        await file.rename(newPath);
        fileProvider.refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('重命名失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(String path, FileProvider fileProvider) async {
    final fileName = path.split(Platform.pathSeparator).last;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除文件'),
        content: Text('确定要删除 "$fileName" 吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await fileProvider.deleteFile(path);
    }
  }

  Future<void> _showCreateFileDialog(FileProvider fileProvider) async {
    final nameController = TextEditingController();
    String? selectedPath = fileProvider.currentDirectory;
    
    if (selectedPath == null && fileProvider.recentFolders.isNotEmpty) {
      selectedPath = fileProvider.recentFolders.first;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text('新建 Markdown'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '文件名',
                    hintText: '例如: 我的笔记',
                    suffixText: '.md',
                    prefixIcon: const Icon(Icons.edit),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '保存位置',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final path = await fileProvider.fileService.pickDirectory();
                    if (path != null) {
                      setDialogState(() => selectedPath = path);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedPath ?? '点击选择文件夹',
                            style: TextStyle(
                              color: selectedPath != null
                                  ? null
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: selectedPath == null || nameController.text.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'name': nameController.text,
                        'path': selectedPath!,
                      });
                    },
              icon: const Icon(Icons.check),
              label: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final file = await fileProvider.createFile(
        result['path']!,
        result['name']!,
      );
      if (file != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(filePath: file.path),
          ),
        );
      }
    }
  }

  Future<void> _showCreateFileInFolderDialog(String folderPath, FileProvider fileProvider) async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('新建文件'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '文件名',
            suffixText: '.md',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final file = await fileProvider.createFile(folderPath, result);
      if (file != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditorScreen(filePath: file.path),
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionScreen(FileProvider fileProvider) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '需要存储权限',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '请授予存储权限以浏览和编辑 Markdown 文件',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () async {
                    final granted = await fileProvider.requestPermissions();
                    if (!granted && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('请在设置中授予存储权限'),
                          action: SnackBarAction(
                            label: '打开设置',
                            onPressed: () => fileProvider.openSettings(),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.security),
                  label: const Text('授予权限'),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => fileProvider.openSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('打开系统设置'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== CREATE FOLDER DIALOG ====================
  Future<void> _showCreateFolderDialog(FileProvider fileProvider) async {
    final nameController = TextEditingController();
    String? selectedPath = fileProvider.currentDirectory;
    
    if (selectedPath == null && fileProvider.recentFolders.isNotEmpty) {
      selectedPath = fileProvider.recentFolders.first;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.create_new_folder, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Text('新建文件夹'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '文件夹名称',
                    hintText: '例如: 我的笔记',
                    prefixIcon: const Icon(Icons.folder),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '创建位置',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final path = await fileProvider.fileService.pickDirectory();
                    if (path != null) {
                      setDialogState(() => selectedPath = path);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder, color: Colors.amber),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedPath ?? '点击选择位置',
                            style: TextStyle(
                              color: selectedPath != null
                                  ? null
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: selectedPath == null || nameController.text.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'name': nameController.text,
                        'path': selectedPath!,
                      });
                    },
              icon: const Icon(Icons.check),
              label: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final newFolderPath = '${result['path']}${Platform.pathSeparator}${result['name']}';
        await Directory(newFolderPath).create(recursive: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件夹 "${result['name']}" 创建成功')),
          );
          // Navigate to the new folder
          await fileProvider.addToRecentFolders(newFolderPath);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FolderBrowserScreen(folderPath: newFolderPath),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败: $e')),
          );
        }
      }
    }
  }

  // ==================== SETTINGS TAB ====================
  Widget _buildSettingsTab() {
    return _buildGradientContainer(
      child: Consumer2<SettingsProvider, FileProvider>(
        builder: (context, settings, fileProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSettingsHeader(),
              const SizedBox(height: 20),
              
              // Theme section
              _buildSettingsSection('外观', Icons.palette, [
                _buildThemeModeSelector(settings),
                const SizedBox(height: 16),
                _buildThemeColorSelector(settings),
                const SizedBox(height: 16),
                _buildBackgroundSettings(settings),
              ]),
              
              const SizedBox(height: 16),
              
              // Editor section
              _buildSettingsSection('编辑器', Icons.edit, [
                _buildFontSizeSlider(settings),
                const SizedBox(height: 16),
                _buildAutoSaveToggle(settings),
                if (settings.autoSave) ...[
                  const SizedBox(height: 12),
                  _buildAutoSaveIntervalSelector(settings),
                ],
              ]),
              
              const SizedBox(height: 16),
              
              // Storage section
              _buildSettingsSection('存储', Icons.folder, [
                _buildClearRecentFilesButton(fileProvider),
                const SizedBox(height: 12),
                _buildClearRecentFoldersButton(fileProvider),
              ]),
              
              const SizedBox(height: 16),
              
              // About section
              _buildAboutSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('app.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设置',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              AppConstants.appDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoSaveIntervalSelector(SettingsProvider settings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('保存间隔', style: Theme.of(context).textTheme.bodyMedium),
        DropdownButton<int>(
          value: settings.autoSaveInterval,
          items: const [
            DropdownMenuItem(value: 10, child: Text('10 秒')),
            DropdownMenuItem(value: 30, child: Text('30 秒')),
            DropdownMenuItem(value: 60, child: Text('1 分钟')),
            DropdownMenuItem(value: 300, child: Text('5 分钟')),
          ],
          onChanged: (v) => settings.setAutoSaveInterval(v ?? 30),
        ),
      ],
    );
  }

  Widget _buildClearRecentFilesButton(FileProvider fileProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('清除最近文件', style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '${fileProvider.recentFiles.length} 个文件',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        TextButton(
          onPressed: fileProvider.recentFiles.isEmpty
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
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    fileProvider.clearRecentFiles();
                  }
                },
          child: const Text('清除'),
        ),
      ],
    );
  }

  Widget _buildClearRecentFoldersButton(FileProvider fileProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('清除最近文件夹', style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '${fileProvider.recentFolders.length} 个文件夹',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        TextButton(
          onPressed: fileProvider.recentFolders.isEmpty
              ? null
              : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text('清除最近文件夹'),
                      content: const Text('确定要清除所有最近文件夹记录吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('清除'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    fileProvider.clearRecentFolders();
                  }
                },
          child: const Text('清除'),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
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
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildThemeModeSelector(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('主题模式', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildThemeModeChip(settings, ThemeMode.system, '跟随系统'),
            const SizedBox(width: 8),
            _buildThemeModeChip(settings, ThemeMode.light, '浅色'),
            const SizedBox(width: 8),
            _buildThemeModeChip(settings, ThemeMode.dark, '深色'),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeModeChip(SettingsProvider settings, ThemeMode mode, String label) {
    final isSelected = settings.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => settings.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeColorSelector(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('主题色', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(SettingsProvider.themeColors.length, (index) {
            final color = SettingsProvider.themeColors[index];
            final isSelected = settings.primaryColorIndex == index;
            return GestureDetector(
              onTap: () => settings.setPrimaryColorIndex(index),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                      : null,
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBackgroundSettings(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('背景图片', style: Theme.of(context).textTheme.bodyMedium),
            TextButton.icon(
              onPressed: () => _pickBackgroundImage(settings),
              icon: const Icon(Icons.image, size: 18),
              label: const Text('选择'),
            ),
          ],
        ),
        if (settings.backgroundImagePath != null) ...[
          const SizedBox(height: 8),
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(File(settings.backgroundImagePath!)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('覆盖效果', style: Theme.of(context).textTheme.bodyMedium),
              IconButton(
                onPressed: () => settings.setBackgroundImage(null),
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                tooltip: '移除背景图片',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildBackgroundEffectChip(settings, 'none', '无'),
              const SizedBox(width: 8),
              _buildBackgroundEffectChip(settings, 'blur', '模糊'),
            ],
          ),
          if (settings.backgroundEffect == 'blur') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('模糊度'),
                Expanded(
                  child: Slider(
                    value: settings.backgroundBlur,
                    min: 0,
                    max: 30,
                    onChanged: (v) => settings.setBackgroundBlur(v),
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBackgroundEffectChip(SettingsProvider settings, String value, String label) {
    final isSelected = settings.backgroundEffect == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => settings.setBackgroundEffect(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickBackgroundImage(SettingsProvider settings) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        settings.setBackgroundImage(result.files.first.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Widget _buildFontSizeSlider(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('字体大小', style: Theme.of(context).textTheme.bodyMedium),
            Text('${settings.fontSize.toInt()}', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        Slider(
          value: settings.fontSize,
          min: 12,
          max: 24,
          divisions: 12,
          onChanged: (v) => settings.setFontSize(v),
        ),
      ],
    );
  }

  Widget _buildAutoSaveToggle(SettingsProvider settings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('自动保存', style: Theme.of(context).textTheme.bodyMedium),
        Switch(
          value: settings.autoSave,
          onChanged: (v) => settings.setAutoSave(v),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '关于',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('app.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '版本 ${AppConstants.appVersion}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppConstants.appDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            '作者: ${AppConstants.appAuthor}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 24),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _launchGitHub(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.open_in_new, color: Colors.purple, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GitHub 开源仓库',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '查看源代码和提交反馈',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchGitHub() async {
    final url = Uri.parse(AppConstants.githubUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
