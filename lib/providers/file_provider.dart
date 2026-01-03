import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/markdown_file.dart';
import '../services/file_service.dart';

/// Provider for managing file state
class FileProvider extends ChangeNotifier {
  final FileService _fileService = FileService();

  // State
  List<MarkdownFile> _files = [];
  List<String> _recentFiles = [];
  List<String> _pinnedFiles = [];
  List<String> _pinnedFolders = [];
  String? _currentDirectory;
  bool _isLoading = false;
  String? _error;
  bool _hasPermission = false;

  // Getters
  List<MarkdownFile> get files => _files;
  List<String> get recentFiles => _recentFiles;
  List<String> get pinnedFiles => _pinnedFiles;
  List<String> get pinnedFolders => _pinnedFolders;
  String? get currentDirectory => _currentDirectory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPermission => _hasPermission;
  FileService get fileService => _fileService;

  /// Initialize the provider
  Future<void> initialize() async {
    await _loadRecentFiles();
    await _loadPinnedItems();
    await checkPermissions();
  }

  /// Check storage permissions
  Future<bool> checkPermissions() async {
    _hasPermission = await _fileService.hasPermissions();
    notifyListeners();
    return _hasPermission;
  }

  /// Request storage permissions
  Future<bool> requestPermissions() async {
    _hasPermission = await _fileService.requestPermissions();
    notifyListeners();
    return _hasPermission;
  }

  /// Open app settings for permissions
  Future<void> openSettings() async {
    await _fileService.openSettings();
  }

  /// Set current directory and load files
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

  /// Refresh current directory
  Future<void> refresh() async {
    if (_currentDirectory != null) {
      await setDirectory(_currentDirectory!);
    }
  }

  /// Clear current directory (go back to home)
  void clearDirectory() {
    _currentDirectory = null;
    _files = [];
    _error = null;
    notifyListeners();
  }

  /// Pick a directory
  Future<void> pickDirectory() async {
    final path = await _fileService.pickDirectory();
    if (path != null) {
      await setDirectory(path);
    }
  }

  /// Pick and open a file
  Future<String?> pickAndOpenFile() async {
    final path = await _fileService.pickMarkdownFile();
    if (path != null) {
      await addToRecentFiles(path);
    }
    return path;
  }

  // ==================== RECENT FILES ====================
  
  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    _recentFiles = prefs.getStringList('recent_files') ?? [];
    notifyListeners();
  }

  Future<void> addToRecentFiles(String path) async {
    _recentFiles.remove(path);
    _recentFiles.insert(0, path);
    if (_recentFiles.length > 20) {
      _recentFiles = _recentFiles.sublist(0, 20);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_files', _recentFiles);
    notifyListeners();
  }

  Future<void> removeFromRecentFiles(String path) async {
    _recentFiles.remove(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_files', _recentFiles);
    notifyListeners();
  }

  Future<void> clearRecentFiles() async {
    _recentFiles.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_files');
    notifyListeners();
  }

  /// Reorder recent files
  void reorderRecentFiles(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _recentFiles.removeAt(oldIndex);
    _recentFiles.insert(newIndex, item);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_files', _recentFiles);
  }

  // ==================== PINNED ITEMS ====================

  Future<void> _loadPinnedItems() async {
    final prefs = await SharedPreferences.getInstance();
    _pinnedFiles = prefs.getStringList('pinned_files') ?? [];
    _pinnedFolders = prefs.getStringList('pinned_folders') ?? [];
  }

  bool isFilePinned(String path) => _pinnedFiles.contains(path);
  bool isFolderPinned(String path) => _pinnedFolders.contains(path);

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

  /// Reorder pinned files
  void reorderPinnedFiles(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _pinnedFiles.removeAt(oldIndex);
    _pinnedFiles.insert(newIndex, item);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_files', _pinnedFiles);
  }

  /// Reorder pinned folders
  void reorderPinnedFolders(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _pinnedFolders.removeAt(oldIndex);
    _pinnedFolders.insert(newIndex, item);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pinned_folders', _pinnedFolders);
  }

  // ==================== FILE OPERATIONS ====================

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

  Future<List<String>> getCommonPaths() async {
    return await _fileService.getCommonPaths();
  }
}
