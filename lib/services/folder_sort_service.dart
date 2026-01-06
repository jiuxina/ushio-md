import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FolderSortService {
  static final FolderSortService _instance = FolderSortService._internal();
  factory FolderSortService() => _instance;
  FolderSortService._internal();

  static const String _fileName = 'folder_sort_orders.json';
  
  // Key: Folder Path, Value: List of Filenames in order
  Map<String, List<String>> _folderOrders = {};
  
  // Key: Folder Path, Value: Sort Option Index
  Map<String, int> _folderSortOptions = {};
  
  bool _initialized = false;

  /// Initialize and load saved orders
  Future<void> init() async {
    if (_initialized) return;
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        
        if (json.containsKey('orders')) {
          // New format
          final orders = json['orders'] as Map<String, dynamic>;
          _folderOrders = orders.map((key, value) => MapEntry(key, List<String>.from(value)));
          
          if (json.containsKey('options')) {
            final options = json['options'] as Map<String, dynamic>;
            _folderSortOptions = options.map((key, value) => MapEntry(key, value as int));
          }
        } else {
          // Legacy format (just orders)
          _folderOrders = json.map((key, value) => MapEntry(key, List<String>.from(value)));
        }
      }
    } catch (e) {
      debugPrint('Error loading folder sort orders: $e');
    }
    _initialized = true;
  }

  /// Get settings file
  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Save orders and options to disk
  Future<void> _save() async {
    try {
      final file = await _getFile();
      final data = {
        'orders': _folderOrders,
        'options': _folderSortOptions,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving folder sort orders: $e');
    }
  }

  /// Get custom order for a folder
  List<String> getOrder(String folderPath) {
    return _folderOrders[folderPath] ?? [];
  }

  /// Save custom order for a folder
  Future<void> saveOrder(String folderPath, List<String> filenames) async {
    _folderOrders[folderPath] = filenames;
    // When saving a custom order, we imply the user wants to use Custom sort,
    // but the UI typically handles switching the mode.
    // However, to be safe, let's just save the order here.
    await _save();
  }

  /// Get sort option for a folder
  int getSortOptionIndex(String folderPath) {
    return _folderSortOptions[folderPath] ?? 0; // Default to 0 (nameAsc)
  }

  /// Save sort option for a folder
  Future<void> saveSortOption(String folderPath, int optionIndex) async {
    _folderSortOptions[folderPath] = optionIndex;
    await _save();
  }
  
  /// Sorts a list of entities based on saved order and falls back to default logic
  List<FileSystemEntity> sortEntities(String folderPath, List<FileSystemEntity> entities) {
    final savedOrder = getOrder(folderPath);
    if (savedOrder.isEmpty) return entities;

    // Separate directories and files
    final dirs = <FileSystemEntity>[];
    final files = <FileSystemEntity>[];
    
    for (var entity in entities) {
      if (entity is Directory) {
        dirs.add(entity);
      } else {
        files.add(entity);
      }
    }

    // Sort helper
    int compare(FileSystemEntity a, FileSystemEntity b) {
       final nameA = a.path.split(Platform.pathSeparator).last;
       final nameB = b.path.split(Platform.pathSeparator).last;
       
       final indexA = savedOrder.indexOf(nameA);
       final indexB = savedOrder.indexOf(nameB);
       
       // If both items are in the saved order, sort by index
       if (indexA != -1 && indexB != -1) {
         return indexA.compareTo(indexB);
       }
       
       // If only A is in order, put A first
       if (indexA != -1) return -1;
       
       // If only B is in order, put B first
       if (indexB != -1) return 1;
       
       // If neither is in order, sort by name
       return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    }

    // Sort both lists
    dirs.sort(compare);
    files.sort(compare);

    // Combine (Folders first, then files)
    return [...dirs, ...files];
  }

  @visibleForTesting
  void reset() {
    _initialized = false;
    _folderOrders.clear();
    _folderSortOptions.clear();
  }
}
