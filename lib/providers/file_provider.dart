/// ============================================================================
/// 文件状态管理器
/// ============================================================================
/// 
/// 管理应用的文件相关状态，包括：
/// - 文件列表和当前目录
/// - 最近访问的文件/文件夹
/// - 置顶的文件/文件夹
/// - 存储权限管理
/// 
/// 使用 SharedPreferences 持久化存储用户数据。
/// ============================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/markdown_file.dart';
import '../services/file_service.dart';

/// 文件状态提供者
/// 
/// 通过 ChangeNotifier 实现响应式状态管理，
/// 当状态变化时自动通知 UI 更新。
class FileProvider extends ChangeNotifier {
  // ==================== 依赖 ====================
  
  /// 文件服务（处理实际的文件系统操作）
  final FileService _fileService = FileService();

  // ==================== 状态 ====================
  
  /// 当前目录下的 Markdown 文件列表
  List<MarkdownFile> _files = [];
  
  /// 最近打开的文件路径列表（最多保存 20 个）
  List<String> _recentFiles = [];
  
  /// 最近访问的文件夹路径列表（最多保存 20 个）
  List<String> _recentFolders = [];
  
  /// 置顶的文件路径列表
  List<String> _pinnedFiles = [];
  
  /// 置顶的文件夹路径列表
  List<String> _pinnedFolders = [];
  
  /// 当前浏览的目录路径（null 表示在首页）
  String? _currentDirectory;
  
  /// 是否正在加载
  bool _isLoading = false;
  
  /// 错误信息
  String? _error;
  
  /// 是否已获取存储权限
  bool _hasPermission = false;

  // ==================== Getters ====================
  
  List<MarkdownFile> get files => _files;
  List<String> get recentFiles => _recentFiles;
  List<String> get recentFolders => _recentFolders;
  List<String> get pinnedFiles => _pinnedFiles;
  List<String> get pinnedFolders => _pinnedFolders;
  String? get currentDirectory => _currentDirectory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPermission => _hasPermission;
  FileService get fileService => _fileService;

  // ==================== 初始化 ====================

  /// 初始化提供者
  /// 
  /// 从本地存储加载：
  /// - 最近文件列表
  /// - 最近文件夹列表
  /// - 置顶项目列表
  /// 
  /// 并检查存储权限状态
  Future<void> initialize() async {
    await _loadRecentFiles();
    await _loadRecentFolders();
    await _loadPinnedItems();
    await checkPermissions();
  }

  // ==================== 权限管理 ====================

  /// 检查存储权限
  /// 
  /// 返回 true 表示已获取权限
  Future<bool> checkPermissions() async {
    _hasPermission = await _fileService.hasPermissions();
    notifyListeners();
    return _hasPermission;
  }

  /// 请求存储权限
  /// 
  /// 弹出系统权限请求对话框
  /// 返回 true 表示用户授权
  Future<bool> requestPermissions() async {
    _hasPermission = await _fileService.requestPermissions();
    notifyListeners();
    return _hasPermission;
  }

  /// 打开系统设置页面
  /// 
  /// 用户可在设置中手动开启权限
  Future<void> openSettings() async {
    await _fileService.openSettings();
  }

  // ==================== 目录操作 ====================

  /// 设置当前目录并加载文件
  /// 
  /// [path] 目录的绝对路径
  /// 
  /// 加载该目录下的所有 Markdown 文件
  Future<void> setDirectory(String path) async {
    _isLoading = true;
    _error = null;
    _currentDirectory = path;
    notifyListeners();

    try {
      _files = await _fileService.listMarkdownFiles(path);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _files = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 刷新当前目录
  /// 
  /// 重新加载当前目录下的文件列表
  Future<void> refresh() async {
    if (_currentDirectory != null) {
      await setDirectory(_currentDirectory!);
    }
  }

  /// 清除当前目录（返回首页）
  void clearDirectory() {
    _currentDirectory = null;
    _files = [];
    _error = null;
    notifyListeners();
  }

  /// 选择目录
  /// 
  /// 打开系统文件选择器，让用户选择一个目录
  Future<void> pickDirectory() async {
    final path = await _fileService.pickDirectory();
    if (path != null) {
      await setDirectory(path);
    }
  }

  /// 选择并打开文件
  /// 
  /// 打开系统文件选择器，选择一个 Markdown 文件
  /// 并将其添加到最近文件列表
  /// 
  /// 返回选中的文件路径（用户取消则返回 null）
  Future<String?> pickAndOpenFile() async {
    final path = await _fileService.pickMarkdownFile();
    if (path != null) {
      await addToRecentFiles(path);
    }
    return path;
  }

  // ==================== 最近文件管理 ====================
  
  /// 从本地存储加载最近文件列表
  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    _recentFiles = prefs.getStringList('recent_files') ?? [];
    notifyListeners();
  }

  /// 添加文件到最近列表
  /// 
  /// [path] 文件的绝对路径
  /// 
  /// 如果文件已存在，会移动到列表首位
  /// 列表最多保存 20 个文件
  Future<void> addToRecentFiles(String path) async {
    _recentFiles.remove(path);  // 移除已存在的（确保不重复）
    _recentFiles.insert(0, path);  // 添加到首位
    
    // 限制最大数量
    if (_recentFiles.length > 20) {
      _recentFiles = _recentFiles.sublist(0, 20);
    }

    // 持久化存储
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_files', _recentFiles);
    notifyListeners();
  }

  /// 从最近列表移除文件
  Future<void> removeFromRecentFiles(String path) async {
    _recentFiles.remove(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_files', _recentFiles);
    notifyListeners();
  }

  /// 清空最近文件列表
  Future<void> clearRecentFiles() async {
    _recentFiles.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_files');
    notifyListeners();
  }

  /// 重新排序最近文件（拖拽排序）
  void reorderRecentFiles(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _recentFiles.removeAt(oldIndex);
    _recentFiles.insert(newIndex, item);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_files', _recentFiles);
  }

  // ==================== 最近文件夹管理 ====================
  
  /// 从本地存储加载最近文件夹列表
  Future<void> _loadRecentFolders() async {
    final prefs = await SharedPreferences.getInstance();
    _recentFolders = prefs.getStringList('recent_folders') ?? [];
    notifyListeners();
  }

  /// 添加文件夹到最近列表
  Future<void> addToRecentFolders(String path) async {
    _recentFolders.remove(path);
    _recentFolders.insert(0, path);
    if (_recentFolders.length > 20) {
      _recentFolders = _recentFolders.sublist(0, 20);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_folders', _recentFolders);
    notifyListeners();
  }

  /// 从最近列表移除文件夹
  Future<void> removeFromRecentFolders(String path) async {
    _recentFolders.remove(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_folders', _recentFolders);
    notifyListeners();
  }

  /// 清空最近文件夹列表
  Future<void> clearRecentFolders() async {
    _recentFolders.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_folders');
    notifyListeners();
  }

  // ==================== 置顶项目管理 ====================

  /// 从本地存储加载置顶项目
  Future<void> _loadPinnedItems() async {
    final prefs = await SharedPreferences.getInstance();
    _pinnedFiles = prefs.getStringList('pinned_files') ?? [];
    _pinnedFolders = prefs.getStringList('pinned_folders') ?? [];
  }

  /// 检查文件是否已置顶
  bool isFilePinned(String path) => _pinnedFiles.contains(path);
  
  /// 检查文件夹是否已置顶
  bool isFolderPinned(String path) => _pinnedFolders.contains(path);

  /// 切换文件置顶状态
  /// 
  /// 已置顶则取消，未置顶则添加
  Future<void> togglePinFile(String path) async {
    if (_pinnedFiles.contains(path)) {
      _pinnedFiles.remove(path);
    } else {
      _pinnedFiles.insert(0, path);
    }
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_files', _pinnedFiles);
  }

  /// 切换文件夹置顶状态
  Future<void> togglePinFolder(String path) async {
    if (_pinnedFolders.contains(path)) {
      _pinnedFolders.remove(path);
    } else {
      _pinnedFolders.insert(0, path);
    }
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_folders', _pinnedFolders);
  }

  /// 重新排序置顶文件（拖拽排序）
  void reorderPinnedFiles(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _pinnedFiles.removeAt(oldIndex);
    _pinnedFiles.insert(newIndex, item);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_files', _pinnedFiles);
  }

  /// 重新排序置顶文件夹（拖拽排序）
  void reorderPinnedFolders(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _pinnedFolders.removeAt(oldIndex);
    _pinnedFolders.insert(newIndex, item);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_folders', _pinnedFolders);
  }

  // ==================== 文件操作 ====================

  /// 创建新文件
  /// 
  /// [directory] 目标目录路径
  /// [name] 文件名（不含扩展名）
  /// 
  /// 返回创建的文件对象，失败返回 null
  Future<MarkdownFile?> createFile(String directory, String name) async {
    try {
      final file = await _fileService.createFile(directory, name);
      await refresh();
      await addToRecentFiles(file.path);
      return file;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 删除文件
  /// 
  /// [path] 文件的绝对路径
  /// 
  /// 同时从最近列表和置顶列表中移除
  /// 返回 true 表示删除成功
  Future<bool> deleteFile(String path) async {
    try {
      await _fileService.deleteFile(path);
      await removeFromRecentFiles(path);
      _pinnedFiles.remove(path);
      await refresh();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 获取常用路径列表
  /// 
  /// 返回设备上的常用目录（如 Download、Documents 等）
  Future<List<String>> getCommonPaths() async {
    return await _fileService.getCommonPaths();
  }
}
