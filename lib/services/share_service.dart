// ============================================================================
// 分享服务
// 
// 封装原生分享功能，支持分享：
// - Markdown 文件
// - 文本内容
// - 文件夹（压缩后分享）
// ============================================================================

import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

/// 分享服务类
class ShareService {
  /// 分享文件
  /// 
  /// [filePath] 要分享的文件路径
  /// [subject] 可选的主题/标题
  Future<void> shareFile(String filePath, {String? subject}) async {
    final xFile = XFile(filePath);
    await Share.shareXFiles(
      [xFile],
      subject: subject,
    );
  }
  
  /// 分享多个文件
  /// 
  /// [filePaths] 要分享的文件路径列表
  /// [subject] 可选的主题/标题
  Future<void> shareFiles(List<String> filePaths, {String? subject}) async {
    final xFiles = filePaths.map((path) => XFile(path)).toList();
    await Share.shareXFiles(
      xFiles,
      subject: subject,
    );
  }
  
  /// 分享文本内容
  /// 
  /// [text] 要分享的文本
  /// [subject] 可选的主题/标题
  Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
  
  /// 分享文件夹（压缩后分享）
  /// 
  /// [folderPath] 要分享的文件夹路径
  /// 返回 true 表示成功，false 表示失败
  Future<bool> shareFolder(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        return false;
      }
      
      final folderName = folderPath.split(Platform.pathSeparator).last;
      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/$folderName.zip';
      
      // 创建 ZIP 归档
      final encoder = ZipEncoder();
      final archive = Archive();
      
      await _addDirectoryToArchive(archive, dir, folderName);
      
      final zipData = encoder.encode(archive);
      
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);
      
      // 分享 ZIP 文件
      await shareFile(zipPath, subject: '$folderName.zip');
      
      // 清理临时文件（延迟删除，确保分享完成）
      Future.delayed(const Duration(minutes: 5), () {
        try {
          zipFile.deleteSync();
        } catch (_) {}
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 递归添加目录内容到归档
  Future<void> _addDirectoryToArchive(Archive archive, Directory dir, String basePath) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = entity.path.replaceFirst('${dir.path}/', '');
        final fileName = '$basePath/$relativePath';
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
      }
    }
  }
}

