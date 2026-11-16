import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/file_path_changes.dart';
import 'file_service.dart';
import 'version_service.dart';

enum BatchFileFailure { destinationConflict, invalidDestination, missing, io }

class BatchFileItemResult {
  const BatchFileItemResult({
    required this.sourcePath,
    this.destinationPath,
    this.failure,
    this.details,
  });

  final String sourcePath;
  final String? destinationPath;
  final BatchFileFailure? failure;
  final String? details;
  bool get isSuccess => failure == null;
}

class BatchFileResult {
  BatchFileResult(Iterable<BatchFileItemResult> items)
    : items = List.unmodifiable(items);

  final List<BatchFileItemResult> items;
  List<BatchFileItemResult> get succeeded =>
      items.where((item) => item.isSuccess).toList();
  List<BatchFileItemResult> get failed =>
      items.where((item) => !item.isSuccess).toList();
  Map<String, String?> get pathChanges => {
    for (final item in succeeded) item.sourcePath: item.destinationPath,
  };
}

/// Runs each selected top-level item independently without overwriting targets.
///
/// Move failures roll the current item back before processing the next item.
/// Renames intentionally do not fall back to copy/delete across file systems.
class BatchFileService {
  BatchFileService({FileService? fileService, VersionService? versionService})
    : _fileService = fileService ?? FileService(),
      _versionService = versionService ?? VersionService();

  final FileService _fileService;
  final VersionService _versionService;

  Future<List<String>> _topLevelPaths(Iterable<String> paths) async {
    final unique = paths.map(normalizedFilePath).toSet().toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    final selected = <String>[];
    for (final path in unique) {
      if (selected.any((parent) => isPathWithin(path, parent))) continue;
      selected.add(path);
    }
    return selected;
  }

  Future<BatchFileResult> move(
    Iterable<String> paths,
    String destinationDirectory,
  ) async {
    final destination = normalizedFilePath(destinationDirectory);
    final results = <BatchFileItemResult>[];
    for (final source in await _topLevelPaths(paths)) {
      final target = p.join(destination, p.basename(source));
      try {
        final type = await FileSystemEntity.type(source, followLinks: false);
        if (type == FileSystemEntityType.notFound) {
          results.add(_failure(source, BatchFileFailure.missing));
          continue;
        }
        if (type != FileSystemEntityType.file &&
            type != FileSystemEntityType.directory) {
          results.add(_failure(source, BatchFileFailure.invalidDestination));
          continue;
        }
        if (!await Directory(destination).exists() ||
            p.equals(source, target) ||
            (type == FileSystemEntityType.directory &&
                isPathWithin(destination, source))) {
          results.add(_failure(source, BatchFileFailure.invalidDestination));
          continue;
        }
        if (await FileSystemEntity.type(target, followLinks: false) !=
            FileSystemEntityType.notFound) {
          results.add(_failure(source, BatchFileFailure.destinationConflict));
          continue;
        }
        final oldHistory = _versionService.getVersionsDir(source);
        final newHistory = _versionService.getVersionsDir(target);
        final isVersionedDocument =
            type == FileSystemEntityType.file && _isVersionedDocument(source);
        final moveHistory =
            isVersionedDocument && await _ownsHistory(source, oldHistory);
        if (isVersionedDocument &&
            await FileSystemEntity.type(newHistory, followLinks: false) !=
                FileSystemEntityType.notFound) {
          results.add(_failure(source, BatchFileFailure.destinationConflict));
          continue;
        }

        // Parse and prepare all metadata before touching either source.
        final metadata = await _prepareMetadata(
          source: source,
          target: target,
          isDirectory: type == FileSystemEntityType.directory,
          oldHistory: moveHistory ? oldHistory : null,
          newHistory: moveHistory ? newHistory : null,
        );
        var sourceMoved = false;
        var historyMoved = false;
        try {
          await _rename(source, target, type);
          sourceMoved = true;
          if (moveHistory) {
            await Directory(p.dirname(newHistory)).create(recursive: true);
            await Directory(oldHistory).rename(newHistory);
            historyMoved = true;
          }
          for (final rewrite in metadata) {
            await File(
              rewrite.newPath,
            ).writeAsString(rewrite.updated, encoding: utf8, flush: true);
          }
        } catch (error) {
          // Always try to return both filesystem entries, even if one metadata
          // restore fails. Report all rollback errors instead of hiding a move.
          final rollbackErrors = <Object>[];
          for (final rewrite in metadata) {
            try {
              final current = File(rewrite.newPath);
              if (await current.exists()) {
                await current.writeAsString(
                  rewrite.original,
                  encoding: utf8,
                  flush: true,
                );
              }
            } catch (rollbackError) {
              rollbackErrors.add(rollbackError);
            }
          }
          if (historyMoved) {
            try {
              await Directory(newHistory).rename(oldHistory);
            } catch (rollbackError) {
              rollbackErrors.add(rollbackError);
            }
          }
          if (sourceMoved) {
            try {
              await _rename(target, source, type);
            } catch (rollbackError) {
              rollbackErrors.add(rollbackError);
            }
          }
          if (rollbackErrors.isNotEmpty) {
            throw FileSystemException(
              '$error; rollback failed: ${rollbackErrors.join('; ')}',
              source,
            );
          }
          rethrow;
        }
        _fileService.invalidatePathCache(source);
        _fileService.invalidatePathCache(target);
        results.add(
          BatchFileItemResult(sourcePath: source, destinationPath: target),
        );
      } catch (error) {
        results.add(_failure(source, BatchFileFailure.io, error.toString()));
      }
    }
    return BatchFileResult(results);
  }

  Future<BatchFileResult> delete(Iterable<String> paths) async {
    final results = <BatchFileItemResult>[];
    for (final source in await _topLevelPaths(paths)) {
      try {
        final type = await FileSystemEntity.type(source, followLinks: false);
        if (type == FileSystemEntityType.notFound) {
          results.add(_failure(source, BatchFileFailure.missing));
          continue;
        }
        if (type == FileSystemEntityType.directory) {
          await Directory(source).delete(recursive: true);
        } else if (type == FileSystemEntityType.file) {
          await _fileService.deleteFile(source);
        } else {
          results.add(_failure(source, BatchFileFailure.invalidDestination));
          continue;
        }
        _fileService.invalidatePathCache(source);
        results.add(BatchFileItemResult(sourcePath: source));
      } catch (error) {
        results.add(_failure(source, BatchFileFailure.io, error.toString()));
      }
    }
    return BatchFileResult(results);
  }

  BatchFileItemResult _failure(
    String source,
    BatchFileFailure failure, [
    String? details,
  ]) => BatchFileItemResult(
    sourcePath: source,
    failure: failure,
    details: details,
  );

  Future<void> _rename(
    String source,
    String target,
    FileSystemEntityType type,
  ) async {
    if (type == FileSystemEntityType.directory) {
      await Directory(source).rename(target);
    } else {
      await File(source).rename(target);
    }
  }

  /// Match the document types accepted by the file browser. Images can share a
  /// stem with a document, but must never claim its stem-based history folder.
  bool _isVersionedDocument(String path) {
    final extension = p.extension(path).toLowerCase();
    return extension.isEmpty ||
        extension == '.md' ||
        extension == '.markdown' ||
        extension == '.txt';
  }

  Future<bool> _ownsHistory(String source, String historyPath) async {
    final type = await FileSystemEntity.type(historyPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Invalid version history directory',
        historyPath,
      );
    }
    final metadata = File(p.join(historyPath, 'metadata.json'));
    if (!await metadata.exists()) {
      throw FileSystemException(
        'Cannot determine version history ownership',
        historyPath,
      );
    }
    final values =
        jsonDecode(await metadata.readAsString(encoding: utf8))
            as List<dynamic>;
    if (values.isEmpty) {
      throw FileSystemException(
        'Cannot determine version history ownership',
        historyPath,
      );
    }
    var hasOwned = false;
    var hasForeign = false;
    for (final value in values) {
      final owner = (value as Map<String, dynamic>)['filePath'] as String;
      if (p.equals(normalizedFilePath(owner), source)) {
        hasOwned = true;
      } else {
        hasForeign = true;
      }
    }
    if (hasOwned && hasForeign) {
      throw FileSystemException(
        'Version history is shared by different documents',
        historyPath,
      );
    }
    return hasOwned;
  }

  Future<List<_MetadataRewrite>> _prepareMetadata({
    required String source,
    required String target,
    required bool isDirectory,
    String? oldHistory,
    String? newHistory,
  }) async {
    final metadataFiles = <File>[];
    if (isDirectory) {
      await for (final entity in Directory(
        source,
      ).list(recursive: true, followLinks: false)) {
        if (entity is File &&
            p.basename(entity.path) == 'metadata.json' &&
            p
                .split(p.relative(entity.path, from: source))
                .contains('.versions')) {
          metadataFiles.add(entity);
        }
      }
    } else if (oldHistory != null) {
      final metadata = File(p.join(oldHistory, 'metadata.json'));
      if (await metadata.exists()) metadataFiles.add(metadata);
    }
    final changes = <String, String?>{
      source: target,
      if (oldHistory != null) oldHistory: newHistory,
    };
    final rewrites = <_MetadataRewrite>[];
    for (final file in metadataFiles) {
      final original = await file.readAsString(encoding: utf8);
      final list = jsonDecode(original) as List<dynamic>;
      final updated = [
        for (final value in list)
          {
            ...value as Map<String, dynamic>,
            'filePath': applyFilePathChanges(
              value['filePath'] as String,
              changes,
            ),
            'versionPath': applyFilePathChanges(
              value['versionPath'] as String,
              changes,
            ),
          },
      ];
      rewrites.add(
        _MetadataRewrite(
          applyFilePathChanges(file.path, changes)!,
          original,
          jsonEncode(updated),
        ),
      );
    }
    return rewrites;
  }
}

class _MetadataRewrite {
  const _MetadataRewrite(this.newPath, this.original, this.updated);
  final String newPath;
  final String original;
  final String updated;
}
