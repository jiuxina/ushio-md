// ============================================================================
// 本地 WebDAV 云同步集成测试
//
// 启动 tools/local_webdav_server.py，验证 WebDAVService 与 CloudSyncService
// 的连接、上传、下载、目录递归和 PROPFIND 解析。
// ============================================================================

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/cloud_sync_service.dart';
import 'package:mdreader/services/my_files_service.dart';
import 'package:mdreader/services/webdav_service.dart';
import 'package:path/path.dart' as p;

class _TestMyFilesService extends MyFilesService {
  _TestMyFilesService(this.workspacePath);

  final String workspacePath;

  @override
  Future<String> getWorkspacePath() async => workspacePath;
}

void main() {
  late Directory serverRoot;
  late Process server;
  late int port;

  setUpAll(() async {
    serverRoot = await Directory.systemTemp.createTemp('local_webdav_test_');
    port = 19000 + Random().nextInt(500);
    server = await Process.start('python', [
      p.join(Directory.current.path, 'tools', 'local_webdav_server.py'),
      '--port',
      '$port',
      '--dir',
      serverRoot.path,
      '--user',
      'test',
      '--password',
      'test',
    ]);
    server.stdout.listen((_) {});
    server.stderr.listen((_) {});

    var ready = false;
    for (var i = 0; i < 40; i++) {
      try {
        final socket = await Socket.connect(
          '127.0.0.1',
          port,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
        ready = true;
        break;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    expect(ready, isTrue, reason: 'local WebDAV server did not start');
  });

  tearDownAll(() {
    server.kill();
  });

  WebDAVService newService(String workspaceName) {
    final syncService = WebDAVService()
      ..setRemoteWorkspaceName(workspaceName)
      ..setRemotePathPrefix('');
    syncService.initialize(
      WebDAVConfig(
        url: 'http://127.0.0.1:$port',
        username: 'test',
        password: 'test',
      ),
    );
    return syncService;
  }

  test('WebDAVService 上传/列表/下载/删除', () async {
    final service = newService('Ushio-MD-T1');
    await service.ensureRemoteWorkspace();

    final localFile = File(p.join(serverRoot.path, 'note.md'));
    await localFile.writeAsString('# hello\n');
    expect(await service.uploadFile(localFile.path, 'note.md'), isTrue);

    final files = await service.listRemoteFiles();
    expect(files, isNotNull, reason: 'PROPFIND 响应必须能被客户端解析');
    expect(files!.map((f) => f.name), contains('note.md'));

    final remote = await service.getRemoteFileInfo('note.md');
    expect(remote, isNotNull);
    expect(remote!.name, 'note.md');

    final downloaded = File(p.join(serverRoot.path, 'downloaded.md'));
    expect(await service.downloadFile('note.md', downloaded.path), isTrue);
    expect(await downloaded.readAsString(), '# hello\n');

    expect(await service.deleteRemote('note.md'), isTrue);
    final afterDelete = await service.listRemoteFiles();
    expect(afterDelete!.map((f) => f.name), isNot(contains('note.md')));
  });

  test('CloudSyncService 全量同步上传（含嵌套目录）', () async {
    final service = newService('Ushio-MD-T2');
    final workspace = Directory(p.join(serverRoot.path, 'workspace_t2'));
    await workspace.create(recursive: true);
    await Directory(p.join(workspace.path, 'sub')).create(recursive: true);
    await File(
      p.join(workspace.path, 'local_a.md'),
    ).writeAsString('# local a\n');
    await File(
      p.join(workspace.path, 'sub', 'local_b.md'),
    ).writeAsString('# local b\n');

    final sync = CloudSyncService(
      syncService: service,
      myFilesService: _TestMyFilesService(workspace.path),
    );
    final result = await sync.syncAll();
    expect(result.success, isTrue, reason: result.errorMessage);
    expect(result.uploadedCount, 2);

    final remoteRoot = Directory(p.join(serverRoot.path, 'Ushio-MD-T2'));
    expect(File(p.join(remoteRoot.path, 'local_a.md')).existsSync(), isTrue);
    expect(
      File(p.join(remoteRoot.path, 'sub', 'local_b.md')).existsSync(),
      isTrue,
    );
  });

  test('CloudSyncService 全量同步下载远端新增文件', () async {
    final service = newService('Ushio-MD-T3');
    await service.ensureRemoteWorkspace();

    final remoteSeed = File(p.join(serverRoot.path, 'remote_seed.md'));
    await remoteSeed.writeAsString('# remote only\n');
    expect(await service.uploadFile(remoteSeed.path, 'remote_only.md'), isTrue);

    final workspace = Directory(p.join(serverRoot.path, 'workspace_t3'));
    await workspace.create(recursive: true);
    final sync = CloudSyncService(
      syncService: service,
      myFilesService: _TestMyFilesService(workspace.path),
    );

    final result = await sync.syncAll();
    expect(result.success, isTrue, reason: result.errorMessage);
    expect(result.downloadedCount, 1);
    expect(File(p.join(workspace.path, 'remote_only.md')).existsSync(), isTrue);
  });
}
