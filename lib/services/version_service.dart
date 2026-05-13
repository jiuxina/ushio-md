// ============================================================================
// 版本存储服务
//
// 管理文档的版本历史，包括：
// - 创建版本快照（.versions/{文件名}/v{n}.md）
// - 版本元数据管理（.versions/{文件名}/metadata.json）
// - 版本内容读取与恢复
// - 版本备注更新
//
// 目录结构：
//   .versions/
//     {文件名不含扩展名}/
//       v1.md
//       v2.md
//       metadata.json
//
// 使用原子写入模式（先写临时文件，再重命名）。
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/document_version.dart';
import '../utils/debug_log.dart';

/// 版本存储服务
///
/// 管理文档版本的创建、读取、删除、恢复等操作。
/// 每个文件的版本存储在独立的子目录中。
class VersionService {
  /// 版本存储根目录名
  static const String _versionsDirName = '.versions';

  /// 元数据文件名
  static const String _metadataFileName = 'metadata.json';

  /// 按文件路径的写入锁，防止并发写入元数据
  final Map<String, Future<void>> _writeLocks = {};

  /// 获取文件的写入锁，确保同一文件的版本操作串行执行
  Future<void> _acquireLock(String filePath) async {
    final lock = _writeLocks[filePath];
    if (lock != null) {
      await lock;
    }
    final completer = Completer<void>();
    _writeLocks[filePath] = completer.future;
    // 返回时释放锁
    return completer.complete();
  }

  // ==================== 路径计算 ====================

  /// 获取文件对应的版本存储目录
  ///
  /// [filePath] 原始文件的绝对路径
  ///
  /// 返回 `.versions/{文件名不含扩展名}/` 的绝对路径
  String getVersionsDir(String filePath) {
    final file = File(filePath);
    final parentDir = file.parent.path;
    final baseName = _getBaseNameWithoutExtension(file.path);
    return '$parentDir${Platform.pathSeparator}$_versionsDirName${Platform.pathSeparator}$baseName';
  }

  /// 获取版本文件路径
  ///
  /// [filePath] 原始文件的绝对路径
  /// [versionNumber] 版本号
  String getVersionFilePath(String filePath, int versionNumber) {
    final dir = getVersionsDir(filePath);
    return '$dir${Platform.pathSeparator}v$versionNumber.md';
  }

  /// 获取元数据文件路径
  ///
  /// [filePath] 原始文件的绝对路径
  String getMetadataFilePath(String filePath) {
    final dir = getVersionsDir(filePath);
    return '$dir${Platform.pathSeparator}$_metadataFileName';
  }

  /// 从文件路径提取不含扩展名的文件名
  String _getBaseNameWithoutExtension(String filePath) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final lastDot = fileName.lastIndexOf('.');
    return lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
  }

  // ==================== 版本创建 ====================

  /// 创建新版本
  ///
  /// [filePath] 原始文件的绝对路径
  /// [content] 版本内容
  /// [note] 用户备注（可选）
  ///
  /// 返回创建的版本信息。
  /// 自动创建 `.versions` 目录和文件独立子目录（如不存在）。
  Future<DocumentVersion> createVersion(
    String filePath,
    String content, {
    String note = '',
  }) async {
    // 获取写入锁，防止并发写入
    await _acquireLock(filePath);

    final versionsDir = getVersionsDir(filePath);

    // 确保版本目录存在
    await Directory(versionsDir).create(recursive: true);

    // 读取现有元数据列表
    final metadataList = await _readMetadataList(filePath);

    // 计算下一个版本号
    final nextVersionNumber = metadataList.isEmpty
        ? 1
        : metadataList
              .map((v) => v.versionNumber)
              .reduce((a, b) => a > b ? a : b) + 1;

    // 写入版本文件（原子写入）
    final versionPath = getVersionFilePath(filePath, nextVersionNumber);
    await _atomicWrite(versionPath, content);

    // 构建版本记录
    final version = DocumentVersion(
      versionId: 'v_${DateTime.now().millisecondsSinceEpoch}_$nextVersionNumber',
      versionNumber: nextVersionNumber,
      timestamp: DateTime.now(),
      note: note,
      filePath: filePath,
      versionPath: versionPath,
      fileSize: utf8.encode(content).length,
    );

    // 更新元数据
    metadataList.add(version);
    await _writeMetadataList(filePath, metadataList);

    appDebugLog('VersionService: 创建版本 v$nextVersionNumber for $filePath');
    return version;
  }

  // ==================== 版本查询 ====================

  /// 获取版本历史列表
  ///
  /// [filePath] 原始文件的绝对路径
  ///
  /// 返回按版本号降序排列的版本列表（最新版本在前）。
  /// 如果 `.versions` 目录或元数据文件不存在，返回空列表。
  Future<List<DocumentVersion>> getVersionHistory(String filePath) async {
    final metadataList = await _readMetadataList(filePath);

    // 按版本号降序排列
    metadataList.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return metadataList;
  }

  /// 获取版本内容
  ///
  /// [filePath] 原始文件的绝对路径
  /// [versionNumber] 版本号
  ///
  /// 返回版本的 Markdown 内容。
  /// 如果版本文件不存在或损坏，抛出异常。
  Future<String> getVersionContent(String filePath, int versionNumber) async {
    final versionPath = getVersionFilePath(filePath, versionNumber);
    final file = File(versionPath);

    if (!await file.exists()) {
      throw Exception('版本文件不存在: v$versionNumber');
    }

    try {
      return await file.readAsString();
    } catch (e) {
      appDebugLog('VersionService: 读取版本文件失败: $e');
      throw Exception('版本文件损坏: v$versionNumber');
    }
  }

  // ==================== 版本删除 ====================

  /// 删除指定版本
  ///
  /// [filePath] 原始文件的绝对路径
  /// [versionNumber] 版本号
  ///
  /// 删除版本文件和对应的元数据记录。
  /// 如果版本不存在，静默处理。
  Future<void> deleteVersion(String filePath, int versionNumber) async {
    // 删除版本文件
    final versionPath = getVersionFilePath(filePath, versionNumber);
    final versionFile = File(versionPath);
    if (await versionFile.exists()) {
      await versionFile.delete();
    }

    // 更新元数据
    final metadataList = await _readMetadataList(filePath);
    metadataList.removeWhere((v) => v.versionNumber == versionNumber);
    await _writeMetadataList(filePath, metadataList);

    appDebugLog('VersionService: 删除版本 v$versionNumber for $filePath');
  }

  // ==================== 版本备注 ====================

  /// 更新版本备注
  ///
  /// [filePath] 原始文件的绝对路径
  /// [versionNumber] 版本号
  /// [note] 新备注内容
  ///
  /// 如果版本不存在，抛出异常。
  Future<void> updateVersionNote(
    String filePath,
    int versionNumber,
    String note,
  ) async {
    final metadataList = await _readMetadataList(filePath);
    final index = metadataList.indexWhere(
      (v) => v.versionNumber == versionNumber,
    );

    if (index == -1) {
      throw Exception('版本不存在: v$versionNumber');
    }

    metadataList[index] = metadataList[index].copyWith(note: note);
    await _writeMetadataList(filePath, metadataList);

    appDebugLog('VersionService: 更新版本 v$versionNumber 备注');
  }

  // ==================== 版本恢复 ====================

  /// 恢复到指定版本
  ///
  /// [filePath] 原始文件的绝对路径
  /// [versionNumber] 要恢复的版本号
  ///
  /// 操作步骤：
  /// 1. 读取当前文件内容，创建备份版本
  /// 2. 读取目标版本内容
  /// 3. 将目标版本内容写入原始文件
  ///
  /// 返回恢复后的新版本信息（包含备份）。
  /// 如果目标版本不存在，抛出异常。
  Future<DocumentVersion> restoreVersion(
    String filePath,
    int versionNumber,
  ) async {
    // 读取目标版本内容
    final targetContent = await getVersionContent(filePath, versionNumber);

    // 读取当前文件内容并创建备份
    final currentFile = File(filePath);
    if (await currentFile.exists()) {
      final currentContent = await currentFile.readAsString();
      await createVersion(
        filePath,
        currentContent,
        note: '恢复前自动备份',
      );
    }

    // 将目标版本内容写入原始文件（原子写入）
    await _atomicWrite(filePath, targetContent);

    // 创建恢复版本记录
    final restoredVersion = await createVersion(
      filePath,
      targetContent,
      note: '从 v$versionNumber 恢复',
    );

    appDebugLog('VersionService: 恢复到版本 v$versionNumber for $filePath');
    return restoredVersion;
  }

  // ==================== 从版本创建新文件 ====================

  /// 从版本创建新文档
  ///
  /// [filePath] 原始文件的绝对路径
  /// [versionNumber] 版本号
  ///
  /// 在原始文件同目录下创建新文件，文件名带时间戳后缀。
  /// 例如：`笔记.md` → `笔记_20260513_143022.md`
  ///
  /// 返回新文件的绝对路径。
  /// 如果版本不存在，抛出异常。
  Future<String> createNewDocFromVersion(
    String filePath,
    int versionNumber,
  ) async {
    // 读取版本内容
    final content = await getVersionContent(filePath, versionNumber);

    // 构建新文件名
    final file = File(filePath);
    final parentDir = file.parent.path;
    final baseName = _getBaseNameWithoutExtension(filePath);
    final now = DateTime.now();
    final timestamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final newFileName = '${baseName}_$timestamp.md';
    final newFilePath = '$parentDir${Platform.pathSeparator}$newFileName';

    // 写入新文件（原子写入）
    await _atomicWrite(newFilePath, content);

    appDebugLog('VersionService: 从版本 v$versionNumber 创建新文件 $newFileName');
    return newFilePath;
  }

  // ==================== 内部方法 ====================

  /// 读取元数据列表
  ///
  /// 如果元数据文件不存在或损坏，返回空列表。
  Future<List<DocumentVersion>> _readMetadataList(String filePath) async {
    final metadataPath = getMetadataFilePath(filePath);
    final file = File(metadataPath);

    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
      return jsonList
          .map((json) => DocumentVersion.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      appDebugLog('VersionService: 读取元数据失败，返回空列表: $e');
      return [];
    }
  }

  /// 写入元数据列表（原子写入）
  Future<void> _writeMetadataList(
    String filePath,
    List<DocumentVersion> metadataList,
  ) async {
    final metadataPath = getMetadataFilePath(filePath);
    final jsonList = metadataList.map((v) => v.toJson()).toList();
    final content = const JsonEncoder.withIndent('  ').convert(jsonList);
    await _atomicWrite(metadataPath, content);
  }

  /// 原子写入
  ///
  /// 先写入临时文件，再重命名，确保写入过程的原子性。
  /// Windows 上需先删除目标文件再重命名。
  Future<void> _atomicWrite(String path, String content) async {
    final file = File(path);
    final tempFile = File('$path.tmp');

    try {
      await tempFile.writeAsString(content, flush: true);
      if (Platform.isWindows && await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(path);
    } catch (e) {
      // 清理临时文件
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }
}
