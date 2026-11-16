import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/batch_file_service.dart';
import 'package:mdreader/services/file_service.dart';
import 'package:mdreader/services/version_service.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Directory> fixture() async {
    final root = await Directory(
      p.join(Directory.current.path, 'build', 'batch-file-tests'),
    ).create(recursive: true);
    return root.createTemp('case-');
  }

  test('moves a document with its history and preserves cached content', () async {
    final root = await fixture();
    final source = await Directory(p.join(root.path, 'source')).create();
    final destination = await Directory(p.join(root.path, 'destination')).create();
    final file = File(p.join(source.path, 'formula.md'));
    await file.writeAsString('# original');
    final files = FileService();
    final versions = VersionService();
    await files.readFile(file.path);
    await versions.createVersion(file.path, '# previous');

    final result = await BatchFileService(
      fileService: files,
      versionService: versions,
    ).move([file.path], destination.path);

    final movedPath = p.join(destination.path, 'formula.md');
    expect(result.succeeded, hasLength(1));
    expect(result.failed, isEmpty);
    expect(await file.exists(), isFalse);
    expect(await File(movedPath).readAsString(), '# original');
    expect(await files.readFile(movedPath), '# original');
    final history = await versions.getVersionHistory(movedPath);
    expect(history, hasLength(1));
    expect(history.single.filePath, movedPath);
    expect(history.single.versionPath, versions.getVersionFilePath(movedPath, 1));
    expect(await versions.getVersionContent(movedPath, 1), '# previous');
  });

  test('skips collisions and reports independent successes', () async {
    final root = await fixture();
    final source = await Directory(p.join(root.path, 'source')).create();
    final destination = await Directory(p.join(root.path, 'destination')).create();
    final first = File(p.join(source.path, 'first.md'));
    final second = File(p.join(source.path, 'second.md'));
    await first.writeAsString('source first');
    await second.writeAsString('source second');
    await Directory(p.join(destination.path, 'first.md')).create();

    final result = await BatchFileService().move(
      [first.path, second.path],
      destination.path,
    );

    expect(result.succeeded.single.sourcePath, second.path);
    expect(result.failed.single.failure, BatchFileFailure.destinationConflict);
    expect(await first.readAsString(), 'source first');
    expect(await Directory(p.join(destination.path, 'first.md')).exists(), isTrue);
    expect(await File(p.join(destination.path, 'second.md')).exists(), isTrue);
  });

  test('rejects folder descendants and collapses nested selections', () async {
    final root = await fixture();
    final folder = await Directory(p.join(root.path, 'folder')).create();
    final child = await Directory(p.join(folder.path, 'child')).create();
    final file = File(p.join(folder.path, 'document.md'));
    await file.writeAsString('retained');

    final invalid = await BatchFileService().move([folder.path], child.path);
    expect(invalid.failed.single.failure, BatchFileFailure.invalidDestination);
    expect(await file.exists(), isTrue);

    final destination = await Directory(p.join(root.path, 'destination')).create();
    final result = await BatchFileService().move(
      [file.path, folder.path, p.join(folder.path, '.', 'document.md')],
      destination.path,
    );
    expect(result.succeeded, hasLength(1));
    expect(await File(p.join(destination.path, 'folder', 'document.md')).exists(),
        isTrue);
  });

  test('moving a folder rewrites nested version metadata', () async {
    final root = await fixture();
    final folder = await Directory(p.join(root.path, 'folder')).create();
    final destination = await Directory(p.join(root.path, 'destination')).create();
    final file = File(p.join(folder.path, 'nested.md'));
    await file.writeAsString('current');
    final versions = VersionService();
    await versions.createVersion(file.path, 'historic');

    final result = await BatchFileService().move([folder.path], destination.path);
    expect(result.failed, isEmpty);
    final moved = p.join(destination.path, 'folder', 'nested.md');
    final history = await versions.getVersionHistory(moved);
    expect(history.single.filePath, moved);
    expect(history.single.versionPath, versions.getVersionFilePath(moved, 1));
    expect(await versions.getVersionContent(moved, 1), 'historic');
  });

  test('history collisions preserve both source file and its history', () async {
    final root = await fixture();
    final source = await Directory(p.join(root.path, 'source')).create();
    final destination = await Directory(p.join(root.path, 'destination')).create();
    final file = File(p.join(source.path, 'note.md'));
    await file.writeAsString('current');
    final versions = VersionService();
    await versions.createVersion(file.path, 'source history');
    final targetHistory = versions.getVersionsDir(
      p.join(destination.path, 'note.md'),
    );
    await Directory(targetHistory).create(recursive: true);
    await File(p.join(targetHistory, 'keep.md')).writeAsString('destination');

    final result = await BatchFileService().move([file.path], destination.path);
    expect(result.failed.single.failure, BatchFileFailure.destinationConflict);
    expect(await file.readAsString(), 'current');
    expect(await versions.getVersionContent(file.path, 1), 'source history');
    expect(await File(p.join(targetHistory, 'keep.md')).readAsString(),
        'destination');
  });

  test('batch delete reports missing paths without stopping other items', () async {
    final root = await fixture();
    final file = File(p.join(root.path, 'delete.md'));
    await file.writeAsString('synthetic deletion fixture');
    final result = await BatchFileService().delete([
      p.join(root.path, 'missing.md'),
      file.path,
    ]);
    expect(result.succeeded.single.sourcePath, file.path);
    expect(result.failed.single.failure, BatchFileFailure.missing);
    expect(await file.exists(), isFalse);
  });
}
