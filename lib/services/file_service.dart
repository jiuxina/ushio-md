import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/markdown_file.dart';

/// Service for file system operations
class FileService {
  /// Request storage permissions
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 11+, we need MANAGE_EXTERNAL_STORAGE
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // Request basic storage permission first
      var status = await Permission.storage.request();
      if (status.isGranted) {
        return true;
      }

      // For Android 11+, request MANAGE_EXTERNAL_STORAGE
      status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    }
    return true;
  }

  /// Check if we have storage permissions
  Future<bool> hasPermissions() async {
    if (Platform.isAndroid) {
      return await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted;
    }
    return true;
  }

  /// Open permission settings
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Pick a directory
  Future<String?> pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    return result;
  }

  /// Pick a markdown file
  Future<String?> pickMarkdownFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    return result?.files.single.path;
  }

  /// List markdown files in a directory
  Future<List<MarkdownFile>> listMarkdownFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return [];
    }

    final files = <MarkdownFile>[];
    try {
      await for (final entity in directory.list()) {
        if (entity is File) {
          final path = entity.path.toLowerCase();
          if (path.endsWith('.md') || path.endsWith('.markdown')) {
            final stat = await entity.stat();
            files.add(MarkdownFile(
              path: entity.path,
              name: entity.path.split(Platform.pathSeparator).last,
              lastModified: stat.modified,
              size: stat.size,
            ));
          }
        }
      }
    } catch (e) {
      // Handle permission errors gracefully
      debugPrint('Error listing files: $e');
    }

    // Sort by last modified, newest first
    files.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return files;
  }

  /// List subdirectories in a directory
  Future<List<Directory>> listSubdirectories(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return [];
    }

    final dirs = <Directory>[];
    try {
      await for (final entity in directory.list()) {
        if (entity is Directory) {
          dirs.add(entity);
        }
      }
    } catch (e) {
      debugPrint('Error listing directories: $e');
    }

    // Sort alphabetically
    dirs.sort((a, b) => a.path.compareTo(b.path));
    return dirs;
  }

  /// Read file content
  Future<String> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }
    return await file.readAsString();
  }

  /// Save file content
  Future<void> saveFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  /// Create a new markdown file
  Future<MarkdownFile> createFile(String directoryPath, String fileName) async {
    if (!fileName.endsWith('.md')) {
      fileName = '$fileName.md';
    }

    final path = '$directoryPath${Platform.pathSeparator}$fileName';
    final file = File(path);

    if (await file.exists()) {
      throw Exception('File already exists: $fileName');
    }

    await file.writeAsString('# $fileName\n\n');

    final stat = await file.stat();
    return MarkdownFile(
      path: path,
      name: fileName,
      content: '# $fileName\n\n',
      lastModified: stat.modified,
      size: stat.size,
    );
  }

  /// Delete a file
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Rename a file
  Future<String> renameFile(String oldPath, String newName) async {
    if (!newName.endsWith('.md')) {
      newName = '$newName.md';
    }

    final file = File(oldPath);
    final directory = file.parent.path;
    final newPath = '$directory${Platform.pathSeparator}$newName';

    if (await File(newPath).exists()) {
      throw Exception('File already exists: $newName');
    }

    await file.rename(newPath);
    return newPath;
  }

  /// Get common storage paths
  Future<List<String>> getCommonPaths() async {
    final paths = <String>[];

    if (Platform.isAndroid) {
      // Common Android paths
      final commonDirs = [
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Notes',
        '/storage/emulated/0',
      ];

      for (final dir in commonDirs) {
        if (await Directory(dir).exists()) {
          paths.add(dir);
        }
      }
    }

    return paths;
  }
}
