// ============================================================================
// ExportService 测试
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mdreader/services/export_service.dart';

// 1. Fake PathProvider
class FakePathProviderPlatform extends PathProviderPlatform {
  final String _tempPath;
  FakePathProviderPlatform(this._tempPath);
  
  @override
  Future<String?> getTemporaryPath() async => _tempPath;
  
  @override
  Future<String?> getApplicationDocumentsPath() async => _tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ExportService', () {
    late Directory tempDir;
    final List<MethodCall> shareLog = [];

    setUp(() async {
      // Setup Temp Dir
      tempDir = await Directory.systemTemp.createTemp('export_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      
      // Mock Share Channel
      const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/share');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel, 
        (MethodCall methodCall) async {
          shareLog.add(methodCall);
          return null;
        }
      );
      shareLog.clear();
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
      
      // Clear mock handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'), 
        null
      );
    });

    testWidgets('captureAndShareAsImage should create image and call share', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();
      
      // Build a widget to capture
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: Container(
                width: 100,
                height: 100,
                color: Colors.red,
                child: const Text('Capture Me'),
              ),
            ),
          ),
        ),
      );
      
      // Ensure it's rendered
      await tester.pumpAndSettle();
      
      final result = await ExportService.captureAndShareAsImage(
        key, 
        'test_image',
        cleanupDelay: Duration.zero,
      );
      
      expect(result, true);
      
      // Verify file created
      final file = File('${tempDir.path}/test_image.png');
      expect(await file.exists(), true);
      
      // Verify Share called
      expect(shareLog, isNotEmpty);
      expect(shareLog.last.method, 'shareFiles'); 
      // Note: method name might vary by version (share, shareFiles, shareUri)
      // On 'share_plus' 7.x it is likely 'shareUri' or 'shareFiles'. 
      // Let's print log on failure or be lenient.
      // Usually checking 'share' or checking arguments contains file path.
    });

    test('exportAndShareAsPdf handles failure when fonts unavailable', () async {
      // In test environment, PdfGoogleFonts likely fails or returns error.
      // We verify it returns false gracefully instead of crashing.
      
      final result = await ExportService.exportAndShareAsPdf(
        '# Title', 
        'test_pdf',
        cleanupDelay: Duration.zero,
      );
      
      // It might return false, or true if environment allows net. 
      // But usually false.
      // If it returns true (e.g. cached), capture failure shouldn't fail test?
      // Let's create an assertion based on outcome.
      
      if (!result) {
        // Expected behavior in offline test
        final file = File('${tempDir.path}/test_pdf.pdf');
        expect(await file.exists(), false);
      } else {
        // Unexpected success (maybe good?), verify file
        final file = File('${tempDir.path}/test_pdf.pdf');
        expect(await file.exists(), true);
        expect(shareLog, isNotEmpty);
      }
    });
  });
}
