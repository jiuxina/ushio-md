import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_provider.dart';
import '../utils/constants.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<String> _commonPaths = [];
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _loadCommonPaths();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimationController.forward();
  }

  Future<void> _loadCommonPaths() async {
    final provider = context.read<FileProvider>();
    _commonPaths = await provider.getCommonPaths();
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
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
          body: _buildGradientBody(fileProvider),
          floatingActionButton: _buildExpandableFAB(fileProvider),
        );
      },
    );
  }

  Widget _buildGradientBody(FileProvider fileProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
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
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(fileProvider),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => fileProvider.refresh(),
                child: _buildBody(fileProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(FileProvider fileProvider) {
    if (_isSearching) {
      return _buildSearchHeader();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (fileProvider.currentDirectory != null)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    final parent = Directory(fileProvider.currentDirectory!).parent;
                    if (parent.path.length > 1) {
                      fileProvider.setDirectory(parent.path);
                    } else {
                      // Go back to home
                      fileProvider.setDirectory(parent.path);
                    }
                  },
                ),
              Expanded(
                child: fileProvider.currentDirectory == null
                    ? _buildAppTitle()
                    : Text(
                        fileProvider.currentDirectory!.split(Platform.pathSeparator).last,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
              ),
              _buildHeaderActions(fileProvider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppTitle() {
    return Row(
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
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.edit_document,
            color: Colors.white,
            size: 24,
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
              'Markdown 编辑器',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderActions(FileProvider fileProvider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          icon: Icons.search,
          onPressed: () => setState(() => _isSearching = true),
        ),
        const SizedBox(width: 4),
        _buildIconButton(
          icon: Icons.settings,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          _buildIconButton(
            icon: Icons.arrow_back,
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchController.clear();
              });
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索文件...',
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
        ],
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
                _buildGradientButton(
                  label: '授予权限',
                  icon: Icons.security,
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

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(FileProvider fileProvider) {
    final searchQuery = _searchController.text.toLowerCase();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Quick actions on home
        if (fileProvider.currentDirectory == null) ...[
          _buildQuickActions(fileProvider),
          const SizedBox(height: 24),
        ],

        // Recent files section
        if (fileProvider.currentDirectory == null &&
            fileProvider.recentFiles.isNotEmpty) ...[
          _buildSectionHeader('最近文件', Icons.history),
          const SizedBox(height: 12),
          ...fileProvider.recentFiles
              .where((path) =>
                  searchQuery.isEmpty ||
                  path.toLowerCase().contains(searchQuery))
              .take(5)
              .map((path) => _buildRecentFileTile(path, fileProvider)),
          const SizedBox(height: 24),
        ],

        // Common folders section
        if (fileProvider.currentDirectory == null && _commonPaths.isNotEmpty) ...[
          _buildSectionHeader('常用文件夹', Icons.folder),
          const SizedBox(height: 12),
          ..._commonPaths.map((path) => _buildFolderTile(path, fileProvider)),
          const SizedBox(height: 24),
        ],

        // Browse section on home
        if (fileProvider.currentDirectory == null) ...[
          _buildSectionHeader('浏览文件', Icons.explore),
          const SizedBox(height: 12),
          _buildBrowseOptions(fileProvider),
        ],

        // Current directory files
        if (fileProvider.currentDirectory != null) ...[
          if (fileProvider.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            )
          else if (fileProvider.error != null)
            _buildErrorState(fileProvider.error!)
          else if (fileProvider.files.isEmpty)
            _buildEmptyState()
          else
            ...fileProvider.files
                .where((file) =>
                    searchQuery.isEmpty ||
                    file.name.toLowerCase().contains(searchQuery))
                .map((file) => _buildFileTile(file, fileProvider)),
        ],

        // Bottom padding for FAB
        const SizedBox(height: 80),
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
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.add_circle,
                  label: '新建文件',
                  color: Colors.green,
                  onTap: () => _showGlobalCreateFileDialog(fileProvider),
                ),
              ),
              const SizedBox(width: 12),
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
                    await fileProvider.pickDirectory();
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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

  Widget _buildBrowseOptions(FileProvider fileProvider) {
    return Column(
      children: [
        _buildGlassCard(
          icon: Icons.folder_open,
          iconColor: Theme.of(context).colorScheme.primary,
          title: '选择文件夹',
          subtitle: '浏览手机存储中的文件夹',
          onTap: () => fileProvider.pickDirectory(),
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
                      ),
                    ],
                  ),
                ),
                trailing ?? Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
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

    return _buildGlassCard(
      icon: Icons.description,
      iconColor: exists
          ? Theme.of(context).colorScheme.primary
          : Colors.grey,
      title: fileName.replaceAll('.md', '').replaceAll('.markdown', ''),
      subtitle: exists ? '点击打开' : '文件不存在',
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
      trailing: IconButton(
        icon: Icon(
          Icons.close,
          size: 18,
          color: Theme.of(context).colorScheme.outline,
        ),
        onPressed: () => fileProvider.removeFromRecentFiles(path),
      ),
    );
  }

  Widget _buildFolderTile(String path, FileProvider fileProvider) {
    final folderName = path.split(Platform.pathSeparator).last;

    return _buildGlassCard(
      icon: Icons.folder,
      iconColor: Colors.amber,
      title: folderName,
      subtitle: path,
      onTap: () => fileProvider.setDirectory(path),
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
      trailing: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          color: Theme.of(context).colorScheme.outline,
        ),
        onSelected: (value) async {
          if (value == 'delete') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('删除文件'),
                content: Text('确定要删除 "${file.name}" 吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await fileProvider.deleteFile(file.path);
            }
          }
        },
        itemBuilder: (context) => [
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.article_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '没有找到 Markdown 文件',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮创建新文件',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
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

  Widget _buildExpandableFAB(FileProvider fileProvider) {
    return ScaleTransition(
      scale: _fabAnimationController,
      child: FloatingActionButton.extended(
        onPressed: () => _showQuickActionsSheet(fileProvider),
        icon: const Icon(Icons.add),
        label: const Text('新建'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showQuickActionsSheet(FileProvider fileProvider) {
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
            const SizedBox(height: 24),
            Text(
              '新建 Markdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            _buildBottomSheetOption(
              icon: Icons.edit_note,
              title: '创建空白文件',
              subtitle: '从空白开始编写',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showGlobalCreateFileDialog(fileProvider);
              },
            ),
            const SizedBox(height: 12),
            _buildBottomSheetOption(
              icon: Icons.note_add,
              title: '使用模板创建',
              subtitle: '选择预设模板快速开始',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                _showTemplateSelector(fileProvider);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
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
                    Text(
                      subtitle,
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
    );
  }

  Future<void> _showGlobalCreateFileDialog(FileProvider fileProvider) async {
    final nameController = TextEditingController();
    String? selectedPath = fileProvider.currentDirectory;

    // If no directory selected, use first common path or let user pick
    if (selectedPath == null && _commonPaths.isNotEmpty) {
      selectedPath = _commonPaths.first;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                      setDialogState(() {
                        selectedPath = path;
                      });
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
                        Icon(
                          Icons.folder,
                          color: Colors.amber,
                        ),
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

  void _showTemplateSelector(FileProvider fileProvider) {
    final templates = [
      {
        'name': '空白笔记',
        'icon': Icons.article,
        'color': Colors.blue,
        'content': '# 标题\n\n在这里开始编写...\n',
      },
      {
        'name': '待办清单',
        'icon': Icons.checklist,
        'color': Colors.green,
        'content': '# 待办事项\n\n## 今日任务\n\n- [ ] 任务 1\n- [ ] 任务 2\n- [ ] 任务 3\n\n## 已完成\n\n- [x] 示例任务\n',
      },
      {
        'name': '会议记录',
        'icon': Icons.groups,
        'color': Colors.orange,
        'content': '# 会议记录\n\n**日期**: ${DateTime.now().toString().split(' ')[0]}\n**参会人**: \n\n## 议题\n\n1. \n\n## 决议\n\n- \n\n## 待办事项\n\n- [ ] \n',
      },
      {
        'name': '日记模板',
        'icon': Icons.book,
        'color': Colors.purple,
        'content': '# ${DateTime.now().toString().split(' ')[0]} 日记\n\n## 今日心情\n\n😊 开心\n\n## 今日要事\n\n- \n\n## 今日感悟\n\n',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '选择模板',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildBottomSheetOption(
                      icon: template['icon'] as IconData,
                      title: template['name'] as String,
                      subtitle: '使用此模板创建新文件',
                      color: template['color'] as Color,
                      onTap: () {
                        Navigator.pop(context);
                        _createFileFromTemplate(
                          fileProvider,
                          template['name'] as String,
                          template['content'] as String,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFileFromTemplate(
    FileProvider fileProvider,
    String templateName,
    String content,
  ) async {
    final nameController = TextEditingController(text: templateName);
    String? selectedPath = fileProvider.currentDirectory ?? (_commonPaths.isNotEmpty ? _commonPaths.first : null);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('保存文件'),
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
                    suffixText: '.md',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                            selectedPath ?? '选择保存位置',
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
            FilledButton(
              onPressed: selectedPath == null ? null : () {
                Navigator.pop(context, {
                  'name': nameController.text,
                  'path': selectedPath!,
                  'content': content,
                });
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final fileName = result['name']!.endsWith('.md') 
            ? result['name']! 
            : '${result['name']!}.md';
        final filePath = '${result['path']}${Platform.pathSeparator}$fileName';
        
        await fileProvider.fileService.saveFile(filePath, result['content']!);
        await fileProvider.addToRecentFiles(filePath);
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditorScreen(filePath: filePath),
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
}
