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

  test(
    'moves a document with its history and preserves cached content',
    () async {
      final root = await fixture();
      final source = await Directory(p.join(root.path, 'source')).create();
      final destination = await Directory(
        p.join(root.path, 'destination'),
      ).create();
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
      expect(
        history.single.versionPath,
        versions.getVersionFilePath(movedPath, 1),
      );
      expect(await versions.getVersionContent(movedPath, 1), '# previous');
    },
  );

  test('skips collisions and reports independent successes', () async {
    final root = await fixture();
    final source = await Directory(p.join(root.path, 'source')).create();
    final destination = await Directory(
      p.join(root.path, 'destination'),
    ).create();
    final first = File(p.join(source.path, 'first.md'));
    final second = File(p.join(source.path, 'second.md'));
    await first.writeAsString('source first');
    await second.writeAsString('source second');
    await Directory(p.join(destination.path, 'first.md')).create();

    final result = await BatchFileService().move([
      first.path,
      second.path,
    ], destination.path);

    expect(result.succeeded.single.sourcePath, second.path);
    expect(result.failed.single.failure, BatchFileFailure.destinationConflict);
    expect(await first.readAsString(), 'source first');
    expect(
      await Directory(p.join(destination.path, 'first.md')).exists(),
      isTrue,
    );
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

    final destination = await Directory(
      p.join(root.path, 'destination'),
    ).create();
    final result = await BatchFileService().move([
      file.path,
      folder.path,
      p.join(folder.path, '.', 'document.md'),
    ], destination.path);
    expect(result.succeeded, hasLength(1));
    expect(
      await File(p.join(destination.path, 'folder', 'document.md')).exists(),
      isTrue,
    );
  });

  test('moving a folder rewrites nested version metadata', () async {
    final root = await fixture();
    final folder = await Directory(p.join(root.path, 'folder')).create();
    final destination = await Directory(
      p.join(root.path, 'destination'),
    ).create();
    final file = File(p.join(folder.path, 'nested.md'));
    await file.writeAsString('current');
    final versions = VersionService();
    await versions.createVersion(file.path, 'historic');

    final result = await BatchFileService().move([
      folder.path,
    ], destination.path);
    expect(result.failed, isEmpty);
    final moved = p.join(destination.path, 'folder', 'nested.md');
    final history = await versions.getVersionHistory(moved);
    expect(history.single.filePath, moved);
    expect(history.single.versionPath, versions.getVersionFilePath(moved, 1));
    expect(await versions.getVersionContent(moved, 1), 'historic');
  });

  test(
    'history collisions preserve both source file and its history',
    () async {
      final root = await fixture();
      final source = await Directory(p.join(root.path, 'source')).create();
      final destination = await Directory(
        p.join(root.path, 'destination'),
      ).create();
      final file = File(p.join(source.path, 'note.md'));
      await file.writeAsString('current');
      final versions = VersionService();
      await versions.createVersion(file.path, 'source history');
      final targetHistory = versions.getVersionsDir(
        p.join(destination.path, 'note.md'),
      );
      await Directory(targetHistory).create(recursive: true);
      await File(p.join(targetHistory, 'keep.md')).writeAsString('destination');

      final result = await BatchFileService().move([
        file.path,
      ], destination.path);
      expect(
        result.failed.single.failure,
        BatchFileFailure.destinationConflict,
      );
      expect(await file.readAsString(), 'current');
      expect(await versions.getVersionContent(file.path, 1), 'source history');
      expect(
        await File(p.join(targetHistory, 'keep.md')).readAsString(),
        'destination',
      );
    },
  );

  test(
    'batch delete reports missing paths without stopping other items',
    () async {
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
    },
  );

  test(
    'orphan destination history never attaches to a different document',
    () async {
      final root = await fixture();
      final source = await Directory(p.join(root.path, 'source')).create();
      final destination = await Directory(
        p.join(root.path, 'destination'),
      ).create();
      final file = File(p.join(source.path, 'note.md'));
      await file.writeAsString('new document without history');
      final versions = VersionService();
      await versions.createVersion(
        p.join(destination.path, 'note.md'),
        'unrelated previous document',
      );

      final result = await BatchFileService().move([
        file.path,
      ], destination.path);

      expect(
        result.failed.single.failure,
        BatchFileFailure.destinationConflict,
      );
      expect(await file.exists(), isTrue);
      expect(
        await versions.getVersionContent(
          p.join(destination.path, 'note.md'),
          1,
        ),
        'unrelated previous document',
      );
    },
  );

  test(
    'history destination failure rolls the document back to its source',
    () async {
      final root = await fixture();
      final source = await Directory(p.join(root.path, 'source')).create();
      final destination = await Directory(
        p.join(root.path, 'destination'),
      ).create();
      final file = File(p.join(source.path, 'note.md'));
      await file.writeAsString('retain current');
      final versions = VersionService();
      await versions.createVersion(file.path, 'retain history');
      await File(
        p.join(destination.path, '.versions'),
      ).writeAsString('blocker');

      final result = await BatchFileService().move([
        file.path,
      ], destination.path);

      expect(result.failed.single.failure, BatchFileFailure.io);
      expect(await file.readAsString(), 'retain current');
      expect(await File(p.join(destination.path, 'note.md')).exists(), isFalse);
      expect(await versions.getVersionContent(file.path, 1), 'retain history');
    },
  );

  test(
    'malformed version metadata leaves all source files untouched',
    () async {
      final root = await fixture();
      final folder = await Directory(p.join(root.path, 'folder')).create();
      final destination = await Directory(
        p.join(root.path, 'destination'),
      ).create();
      final file = File(p.join(folder.path, 'note.md'));
      await file.writeAsString('retain document');
      final versions = VersionService();
      final history = await Directory(
        versions.getVersionsDir(file.path),
      ).create(recursive: true);
      await File(
        p.join(history.path, 'metadata.json'),
      ).writeAsString('invalid metadata');

      final result = await BatchFileService().move([
        folder.path,
      ], destination.path);

      expect(result.failed.single.failure, BatchFileFailure.io);
      expect(await file.readAsString(), 'retain document');
      expect(
        await Directory(p.join(destination.path, 'folder')).exists(),
        isFalse,
      );
    },
  );

  test('moving an image does not steal a same-stem document history', () async {
    final root = await fixture();
    final source = await Directory(p.join(root.path, 'source')).create();
    final destination = await Directory(
      p.join(root.path, 'destination'),
    ).create();
    final document = File(p.join(source.path, 'note.md'));
    final image = File(p.join(source.path, 'note.png'));
    await document.writeAsString('document remains');
    await image.writeAsBytes([137, 80, 78, 71]);
    final versions = VersionService();
    await versions.createVersion(document.path, 'document history remains');

    final result = await BatchFileService().move([image.path], destination.path);

    expect(result.failed, isEmpty);
    expect(await document.readAsString(), 'document remains');
    expect(
      await versions.getVersionContent(document.path, 1),
      'document history remains',
    );
    expect(
      await Directory(
        versions.getVersionsDir(p.join(destination.path, 'note.png')),
      ).exists(),
      isFalse,
    );
  });

  test('moving an image ignores unrelated destination document history',
      () async {
    final root = await fixture();
    final source = await Directory(p.join(root.path, 'source')).create();
    final destination = await Directory(
      p.join(root.path, 'destination'),
    ).create();
    final image = File(p.join(source.path, 'note.png'));
    await image.writeAsBytes([137, 80, 78, 71]);
    final versions = VersionService();
    final document = p.join(destination.path, 'note.md');
    await versions.createVersion(document, 'unrelated destination history');

    final result = await BatchFileService().move([image.path], destination.path);

    expect(result.failed, isEmpty);
    expect(await File(p.join(destination.path, 'note.png')).exists(), isTrue);
    expect(
      await versions.getVersionContent(document, 1),
      'unrelated destination history',
    );
  });

  test('moving a document leaves foreign same-stem history in place', () async {
    final root = await fixture();
    final source = await Directory(p.join(root.path, 'source')).create();
    final destination = await Directory(
      p.join(root.path, 'destination'),
    ).create();
    final first = File(p.join(source.path, 'note.md'));
    final second = File(p.join(source.path, 'note.markdown'));
    await first.writeAsString('first document');
    await second.writeAsString('second document');
    final versions = VersionService();
    await versions.createVersion(first.path, 'first history');

    final result = await BatchFileService().move([second.path], destination.path);

    expect(result.failed, isEmpty);
    expect(await first.readAsString(), 'first document');
    expect(await versions.getVersionContent(first.path, 1), 'first history');
    expect(
      await Directory(
        versions.getVersionsDir(p.join(destination.path, 'note.markdown')),
      ).exists(),
      isFalse,
    );
  });
}
