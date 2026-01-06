// ============================================================================
// 我的文件服务
// 
// 管理 "我的文件" 工作区，包括：
// - 工作区初始化（创建 Ushio-MD 目录）
// - 文件导入（复制外部文件到工作区）
// - 路径检查（判断文件是否在工作区内）
// ============================================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// "我的文件" 工作区服务
class MyFilesService {
  /// 工作区根目录名称
  static const String workspaceName = 'Ushio-MD';
  
  /// 缓存的工作区路径
  String? _workspacePath;
  
  /// 获取工作区根路径
  /// 
  /// 工作区位于应用私有目录下：Android/data/com.ushiomd/files/Ushio-MD
  Future<String> getWorkspacePath() async {
    if (_workspacePath != null) {
      return _workspacePath!;
    }
    
    final externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('无法获取外部存储目录');
    }
    
    _workspacePath = '${externalDir.path}${Platform.pathSeparator}$workspaceName';
    return _workspacePath!;
  }
  
  /// 初始化工作区
  /// 
  /// 首次启动时调用，确保工作区目录存在
  Future<void> initWorkspace() async {
    final path = await getWorkspacePath();
    final dir = Directory(path);
    
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint('MyFilesService: 创建工作区目录 $path');
    }
  }
  
  /// 检查文件是否在工作区内
  /// 
  /// [filePath] 要检查的文件路径
  /// 返回 true 表示文件在工作区内
  Future<bool> isInWorkspace(String filePath) async {
    final workspacePath = await getWorkspacePath();
    return filePath.startsWith(workspacePath);
  }
  
  /// 复制文件到工作区
  /// 
  /// [sourcePath] 源文件路径
  /// [targetSubPath] 可选的目标子路径（相对于工作区根目录）
  /// 
  /// 返回复制后的文件路径
  Future<String> copyToWorkspace(String sourcePath, {String? targetSubPath}) async {
    final workspacePath = await getWorkspacePath();
    final sourceFile = File(sourcePath);
    
    if (!await sourceFile.exists()) {
      throw Exception('源文件不存在: $sourcePath');
    }
    
    // 确定目标路径
    final fileName = sourcePath.split(Platform.pathSeparator).last;
    String targetDir = workspacePath;
    
    if (targetSubPath != null && targetSubPath.isNotEmpty) {
      targetDir = '$workspacePath${Platform.pathSeparator}$targetSubPath';
      // 确保目标目录存在
      await Directory(targetDir).create(recursive: true);
    }
    
    final targetPath = '$targetDir${Platform.pathSeparator}$fileName';
    
    // 如果目标文件已存在，生成唯一文件名
    final targetFile = File(targetPath);
    String finalPath = targetPath;
    if (await targetFile.exists()) {
      finalPath = await _generateUniquePath(targetPath);
    }
    
    // 复制文件
    await sourceFile.copy(finalPath);
    debugPrint('MyFilesService: 复制文件 $sourcePath -> $finalPath');
    
    return finalPath;
  }
  
  /// 复制Markdown文件到工作区，同时处理引用的本地图片
  /// 
  /// [sourcePath] 源MD文件路径
  /// 
  /// 返回复制后的新文件路径
  Future<String> copyDocumentWithImages(String sourcePath) async {
    final workspacePath = await getWorkspacePath();
    final sourceFile = File(sourcePath);
    final sourceDir = sourceFile.parent.path;
    
    if (!await sourceFile.exists()) {
      throw Exception('源文件不存在: $sourcePath');
    }
    
    // 读取文件内容
    String content = await sourceFile.readAsString();
    
    // 解析图片引用（排除网络URL）
    final imageRegex = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
    final matches = imageRegex.allMatches(content);
    
    // 收集需要复制的本地图片
    final imagesToCopy = <String, String>{}; // originalPath -> newRelativePath
    
    for (final match in matches) {
      final imagePath = match.group(2) ?? '';
      
      // 跳过网络URL
      if (imagePath.startsWith('http://') || 
          imagePath.startsWith('https://') ||
          imagePath.startsWith('data:')) {
        continue;
      }
      
      // 解析为绝对路径
      String absolutePath;
      if (imagePath.startsWith('/') || imagePath.contains(':')) {
        absolutePath = imagePath;
      } else {
        // 相对路径，转为绝对路径
        absolutePath = '$sourceDir${Platform.pathSeparator}${imagePath.replaceAll('/', Platform.pathSeparator)}';
      }
      
      // 检查图片是否存在
      if (await File(absolutePath).exists()) {
        final imageName = absolutePath.split(Platform.pathSeparator).last;
        // 保持相对路径结构
        final relativePath = 'images/$imageName';
        imagesToCopy[absolutePath] = relativePath;
      }
    }
    
    // 确定目标文件路径
    final fileName = sourcePath.split(Platform.pathSeparator).last;
    String targetPath = '$workspacePath${Platform.pathSeparator}$fileName';
    
    if (await File(targetPath).exists()) {
      targetPath = await _generateUniquePath(targetPath);
    }
    
    final targetDir = File(targetPath).parent.path;
    
    // 复制图片并更新内容中的路径
    for (final entry in imagesToCopy.entries) {
      final originalPath = entry.key;
      final newRelativePath = entry.value;
      
      // 创建images目录
      final imagesDir = '$targetDir${Platform.pathSeparator}images';
      await Directory(imagesDir).create(recursive: true);
      
      // 复制图片
      final imageName = originalPath.split(Platform.pathSeparator).last;
      final newImagePath = '$imagesDir${Platform.pathSeparator}$imageName';
      await File(originalPath).copy(newImagePath);
      
      // 替换内容中的路径
      content = content.replaceAll(
        RegExp(r'!\[([^\]]*)\]\(' + RegExp.escape(originalPath.replaceAll(sourceDir + Platform.pathSeparator, '').replaceAll(Platform.pathSeparator, '/')) + r'\)'),
        '![\$1]($newRelativePath)',
      );
      
      // 也替换绝对路径引用
      content = content.replaceAll(
        RegExp(r'!\[([^\]]*)\]\(' + RegExp.escape(originalPath) + r'\)'),
        '![\$1]($newRelativePath)',
      );
    }
    
    // 写入新文件
    await File(targetPath).writeAsString(content);
    debugPrint('MyFilesService: 复制文档及图片 $sourcePath -> $targetPath (${imagesToCopy.length}张图片)');
    
    return targetPath;
  }
  
  /// 复制文件夹到工作区
  /// 
  /// [sourcePath] 源文件夹路径
  /// 
  /// 返回复制后的文件夹路径
  Future<String> copyFolderToWorkspace(String sourcePath) async {
    final workspacePath = await getWorkspacePath();
    final sourceDir = Directory(sourcePath);
    
    if (!await sourceDir.exists()) {
      throw Exception('源文件夹不存在: $sourcePath');
    }
    
    final folderName = sourcePath.split(Platform.pathSeparator).last;
    String targetPath = '$workspacePath${Platform.pathSeparator}$folderName';
    
    // 如果目标目录已存在，生成唯一名称
    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      targetPath = await _generateUniqueFolderPath(targetPath);
    }
    
    // 递归复制目录
    await _copyDirectory(sourceDir, Directory(targetPath));
    debugPrint('MyFilesService: 复制文件夹 $sourcePath -> $targetPath');
    
    return targetPath;
  }
  
  /// 复制图片到文档的 images 子目录
  /// 
  /// [imagePath] 图片源路径
  /// [documentPath] Markdown 文档路径
  /// 
  /// 返回相对路径（如 images/photo.jpg）
  Future<String> copyImageToDocument(String imagePath, String documentPath) async {
    final docDir = File(documentPath).parent.path;
    final imagesDir = '$docDir${Platform.pathSeparator}images';
    
    // 确保 images 目录存在
    await Directory(imagesDir).create(recursive: true);
    
    final imageFile = File(imagePath);
    final imageName = imagePath.split(Platform.pathSeparator).last;
    String targetPath = '$imagesDir${Platform.pathSeparator}$imageName';
    
    // 如果目标文件已存在，生成唯一文件名
    if (await File(targetPath).exists()) {
      targetPath = await _generateUniquePath(targetPath);
    }
    
    // 复制图片
    await imageFile.copy(targetPath);
    
    // 返回相对路径
    final relativePath = 'images${Platform.pathSeparator}$imageName';
    return relativePath.replaceAll(Platform.pathSeparator, '/');
  }
  
  /// 列出工作区中的所有文件和文件夹
  Future<List<FileSystemEntity>> listWorkspaceContents({String? subPath}) async {
    final workspacePath = await getWorkspacePath();
    String targetPath = workspacePath;
    
    if (subPath != null && subPath.isNotEmpty) {
      targetPath = '$workspacePath${Platform.pathSeparator}$subPath';
    }
    
    final dir = Directory(targetPath);
    if (!await dir.exists()) {
      return [];
    }
    
    final entities = <FileSystemEntity>[];
    await for (final entity in dir.list()) {
      entities.add(entity);
    }
    
    // 排序：文件夹在前，文件在后，按名称排序
    entities.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
    
    return entities;
  }
  
  /// 在工作区创建新文件
  Future<String> createFile(String fileName, {String? subPath}) async {
    final workspacePath = await getWorkspacePath();
    String targetDir = workspacePath;
    
    if (subPath != null && subPath.isNotEmpty) {
      targetDir = '$workspacePath${Platform.pathSeparator}$subPath';
      await Directory(targetDir).create(recursive: true);
    }
    
    // 确保有 .md 扩展名
    if (!fileName.endsWith('.md')) {
      fileName = '$fileName.md';
    }
    
    String targetPath = '$targetDir${Platform.pathSeparator}$fileName';
    
    // 如果文件已存在，生成唯一名称
    if (await File(targetPath).exists()) {
      targetPath = await _generateUniquePath(targetPath);
    }
    
    // 创建文件并写入默认内容
    final file = File(targetPath);
    final name = fileName.replaceAll('.md', '');
    await file.writeAsString('# $name\n\n');
    
    return targetPath;
  }
  
  /// 在工作区创建新文件夹
  Future<String> createFolder(String folderName, {String? subPath}) async {
    final workspacePath = await getWorkspacePath();
    String targetDir = workspacePath;
    
    if (subPath != null && subPath.isNotEmpty) {
      targetDir = '$workspacePath${Platform.pathSeparator}$subPath';
    }
    
    String targetPath = '$targetDir${Platform.pathSeparator}$folderName';
    
    // 如果目录已存在，生成唯一名称
    if (await Directory(targetPath).exists()) {
      targetPath = await _generateUniqueFolderPath(targetPath);
    }
    
    await Directory(targetPath).create(recursive: true);
    return targetPath;
  }
  
  /// 删除工作区中的文件或文件夹
  Future<void> delete(String path) async {
    final entity = FileSystemEntity.typeSync(path);
    
    if (entity == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (entity == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    }
  }
  
  /// 重命名文件或文件夹
  Future<String> rename(String path, String newName) async {
    final entity = FileSystemEntity.typeSync(path);
    final parentDir = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
    final newPath = '$parentDir${Platform.pathSeparator}$newName';
    
    if (entity == FileSystemEntityType.file) {
      await File(path).rename(newPath);
    } else if (entity == FileSystemEntityType.directory) {
      await Directory(path).rename(newPath);
    }
    
    return newPath;
  }
  
  // ==================== 私有方法 ====================
  
  /// 生成唯一文件路径
  Future<String> _generateUniquePath(String originalPath) async {
    final lastDot = originalPath.lastIndexOf('.');
    final basePath = lastDot > 0 ? originalPath.substring(0, lastDot) : originalPath;
    final extension = lastDot > 0 ? originalPath.substring(lastDot) : '';
    
    int counter = 1;
    String newPath = '${basePath}_$counter$extension';
    
    while (await File(newPath).exists()) {
      counter++;
      newPath = '${basePath}_$counter$extension';
    }
    
    return newPath;
  }
  
  /// 生成唯一文件夹路径
  Future<String> _generateUniqueFolderPath(String originalPath) async {
    int counter = 1;
    String newPath = '${originalPath}_$counter';
    
    while (await Directory(newPath).exists()) {
      counter++;
      newPath = '${originalPath}_$counter';
    }
    
    return newPath;
  }
  
  /// 递归复制目录
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    
    await for (final entity in source.list()) {
      final newPath = '${destination.path}${Platform.pathSeparator}${entity.path.split(Platform.pathSeparator).last}';
      
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }
}
