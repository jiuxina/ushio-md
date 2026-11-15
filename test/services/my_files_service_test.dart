import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/providers/settings_provider.dart';
import 'package:mdreader/services/my_files_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _WorkspacePaths extends PathProviderPlatform {
  _WorkspacePaths(this.documents);

  Future<String?> Function(int call) documents;
  int calls = 0;

  @override
  Future<String?> getApplicationDocumentsPath() => documents(++calls);
}

class _WorkspaceSettings extends SettingsProvider {
  _WorkspaceSettings(this.basePath, {this.name = 'workspace'});

  final String? basePath;
  final String name;

  @override
  String? get customWorkspaceBasePath => basePath;

  @override
  String get workspaceName => name;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalPaths = PathProviderPlatform.instance;
  final originalDebugPrint = debugPrint;
  late Directory fixture;
  late _WorkspacePaths paths;

  setUp(() async {
    final fixtures = await Directory(
      p.join(Directory.current.path, '.sisyphus', 'workspace-tests'),
    ).create(recursive: true);
    fixture = await fixtures.createTemp('resolver-');
    paths = _WorkspacePaths((_) async => p.join(fixture.path, 'documents'));
    PathProviderPlatform.instance = paths;
    debugPrint = (String? message, {int? wrapWidth}) {};
  });

  tearDown(() {
    PathProviderPlatform.instance = originalPaths;
    debugPrint = originalDebugPrint;
  });

  MyFilesService serviceFor(String? base, {String name = 'workspace'}) {
    final settings = _WorkspaceSettings(base, name: name);
    addTearDown(settings.dispose);
    return MyFilesService()..setSettingsProvider(settings);
  }

  Future<String> blockedBase(String name) async {
    final file = File(p.join(fixture.path, name));
    await file.writeAsString(
      'This is a file, not a writable parent directory.',
    );
    return file.path;
  }

  group('workspace resolution', () {
    test(
      'uses a writable custom workspace without querying system paths',
      () async {
        final custom = p.join(fixture.path, 'custom');
        paths.documents = (_) async =>
            throw PlatformException(code: 'documents_unavailable');

        final workspace = await serviceFor(custom).getWorkspacePath();

        expect(workspace, p.join(custom, 'workspace'));
        expect(await Directory(workspace).exists(), isTrue);
        expect(paths.calls, 0);
      },
    );

    test(
      'preserves files belonging to other callers during write probes',
      () async {
        final custom = p.join(fixture.path, 'custom');
        final workspace = await Directory(
          p.join(custom, 'workspace'),
        ).create(recursive: true);
        final existingProbe = File(
          p.join(workspace.path, '.ushio_write_probe'),
        );
        await existingProbe.writeAsString('keep this existing file');

        expect(await serviceFor(custom).getWorkspacePath(), workspace.path);

        expect(await existingProbe.exists(), isTrue);
        expect(await existingProbe.readAsString(), 'keep this existing file');
        expect(
          await workspace
              .list()
              .map((entry) => p.basename(entry.path))
              .toList(),
          ['.ushio_write_probe'],
          reason:
              'A successful probe must clean up only its own temporary data.',
        );
      },
    );

    test(
      'concurrent services agree on the writable custom workspace',
      () async {
        final custom = p.join(fixture.path, 'custom');
        final expected = p.join(custom, 'workspace');
        await Directory(expected).create(recursive: true);
        await Directory(
          p.join(fixture.path, 'documents', 'workspace'),
        ).create(recursive: true);
        final services = List.generate(32, (_) => serviceFor(custom));

        final resolved = await Future.wait(
          services.map((service) => service.getWorkspacePath()),
        );

        expect(resolved, everyElement(expected));
        expect(await Directory(expected).list().toList(), isEmpty);
      },
    );

    test(
      'falls back when the custom parent cannot contain a directory',
      () async {
        final custom = await blockedBase('blocked-custom');
        final expected = p.join(fixture.path, 'documents', 'workspace');

        expect(await serviceFor(custom).getWorkspacePath(), expected);
        expect(await Directory(expected).exists(), isTrue);
      },
    );

    test(
      'isolates a default path error and tries the private directory',
      () async {
        final privateBase = p.join(fixture.path, 'private');
        paths.documents = (call) async {
          if (call == 1) {
            throw PlatformException(code: 'default_unavailable');
          }
          return privateBase;
        };

        final workspace = await serviceFor(null).getWorkspacePath();

        expect(workspace, p.join(privateBase, 'workspace'));
        expect(await Directory(workspace).exists(), isTrue);
        expect(paths.calls, 2);
      },
    );

    test('reports failure when every candidate is unwritable', () async {
      final custom = await blockedBase('blocked-custom');
      final documents = await blockedBase('blocked-documents');
      paths.documents = (_) async => documents;

      await expectLater(
        serviceFor(custom).getWorkspacePath(),
        throwsA(isA<FileSystemException>()),
      );
    });

    test(
      'initialization propagates a failure so the UI can offer retry',
      () async {
        final documents = await blockedBase('blocked-documents');
        paths.documents = (_) async => documents;

        await expectLater(
          serviceFor(null).initWorkspace(),
          throwsA(isA<FileSystemException>()),
        );
      },
    );

    test('does not cache a failed choice and can recover on retry', () async {
      final documents = await blockedBase('blocked-documents');
      paths.documents = (_) async => documents;
      final service = serviceFor(null);
      await expectLater(
        service.getWorkspacePath(),
        throwsA(isA<FileSystemException>()),
      );
      final recoveredBase = p.join(fixture.path, 'recovered');
      paths.documents = (_) async => recoveredBase;

      expect(
        await service.getWorkspacePath(),
        p.join(recoveredBase, 'workspace'),
      );
    });

    test('reports failure when platform directories are unavailable', () async {
      paths.documents = (_) async => null;

      await expectLater(
        serviceFor(null).getWorkspacePath(),
        throwsA(isA<FileSystemException>()),
      );
    });

    test(
      'caches successful choices without querying directories again',
      () async {
        final service = serviceFor(null);
        final workspace = await service.getWorkspacePath();
        final calls = paths.calls;
        paths.documents = (_) async =>
            throw PlatformException(code: 'documents_unavailable');

        expect(await service.getWorkspacePath(), workspace);
        expect(paths.calls, calls);
      },
    );

    test('new settings invalidate the cached workspace', () async {
      final service = serviceFor(null);
      await service.getWorkspacePath();
      final newBase = p.join(fixture.path, 'new-custom');
      final settings = _WorkspaceSettings(newBase, name: 'new-workspace');
      addTearDown(settings.dispose);
      service.setSettingsProvider(settings);

      expect(
        await service.getWorkspacePath(),
        p.join(newBase, 'new-workspace'),
      );
    });

    test(
      'initializes the default workspace when no settings are supplied',
      () async {
        final service = MyFilesService();

        await service.initWorkspace();
        final workspace = await service.getWorkspacePath();

        expect(workspace, p.join(fixture.path, 'documents', 'Ushio-md'));
        expect(await Directory(workspace).exists(), isTrue);
      },
    );
  });
}
