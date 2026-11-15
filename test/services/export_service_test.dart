import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/export_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalPaths = PathProviderPlatform.instance;

  group('ExportService', () {
    late Directory tempDir;
    final shareLog = <MethodCall>[];
    final sharedBytes = <List<int>>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('export_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      shareLog.clear();
      sharedBytes.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            (call) async {
              shareLog.add(call);
              final arguments = call.arguments as Map<dynamic, dynamic>;
              final paths = arguments['paths'] as List<dynamic>;
              sharedBytes.add(await File(paths.single as String).readAsBytes());
              return 'dev.fluttercommunity.plus/share/unavailable';
            },
          );
    });

    tearDown(() {
      PathProviderPlatform.instance = originalPaths;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
    });

    testWidgets('captures a rendered widget and shares a valid PNG', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: const SizedBox(
                width: 100,
                height: 100,
                child: ColoredBox(color: Colors.red, child: Text('Capture Me')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = await tester.runAsync(
        () => ExportService.captureAndShareAsImage(
          key,
          'test_image',
          cleanupDelay: Duration.zero,
        ),
      );

      expect(result, isTrue);
      expect(shareLog.single.method, 'shareFiles');
      expect(
        sharedBytes.single.take(8),
        [137, 80, 78, 71, 13, 10, 26, 10],
        reason:
            'The share callback must receive a complete PNG before cleanup.',
      );
      final paths = (shareLog.single.arguments as Map)['paths'] as List;
      expect(paths.single, '${tempDir.path}/test_image.png');
    });

    test('exports and shares a valid PDF', () async {
      final result = await ExportService.exportAndShareAsPdf(
        '# Title\n\nBody',
        'test_pdf',
        cleanupDelay: Duration.zero,
      );

      expect(result, isTrue);
      expect(shareLog.single.method, 'shareFiles');
      expect(sharedBytes.single.take(5), [
        37,
        80,
        68,
        70,
        45,
      ], reason: 'The share callback must receive a valid PDF before cleanup.');
      final paths = (shareLog.single.arguments as Map)['paths'] as List;
      expect(paths.single, '${tempDir.path}/test_pdf.pdf');
    });
  });
}
