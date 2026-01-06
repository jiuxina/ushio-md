// ============================================================================
// UpdateService 测试
// ============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mdreader/services/update_service.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

// Mocks
class MockHttpClient extends Mock implements http.Client {}
class MockHttpRequest extends Mock implements http.Request {}
class MockHttpResponse extends Mock implements http.StreamedResponse {}
class MockAppInstaller extends Mock implements AppInstaller {}

// Fake PathProvider
class FakePathProviderPlatform extends PathProviderPlatform {
  final String _tempPath;
  FakePathProviderPlatform(this._tempPath);
  
  @override
  Future<String?> getTemporaryPath() async => _tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('UpdateService', () {
    late Directory tempDir;
    late MockHttpClient mockClient;
    late MockAppInstaller mockInstaller;

    setUp(() async {
      // Setup Temp Dir
      tempDir = await Directory.systemTemp.createTemp('update_test');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      
      // Setup Mock Client & Installer
      mockClient = MockHttpClient();
      mockInstaller = MockAppInstaller();
      
      // Default success install
      when(() => mockInstaller.install(any())).thenAnswer(
        (_) async => true
      );
      
      registerFallbackValue(http.Request('GET', Uri.parse('http://example.com')));
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('downloadAndInstallUpdate should use proxy first and invoke install', () async {
      final originalUrl = 'https://github.com/app.apk';
      final fileName = 'update.apk';
      
      // Simulate Successful Response for Proxy URL
      final proxyUrl = 'https://gh-proxy.org/$originalUrl';
      
      final mockResponse = MockHttpResponse();
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockResponse.contentLength).thenReturn(10);
      when(() => mockResponse.stream).thenAnswer((_) => http.ByteStream.fromBytes([1, 2, 3]));
      
      when(() => mockClient.send(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments.first as http.Request;
        if (request.url.toString() == proxyUrl) {
           return mockResponse;
        }
        throw Exception('Unexpected URL: ${request.url}');
      });
      
      final success = await UpdateService.downloadAndInstallUpdate(
        originalUrl, 
        fileName, 
        client: mockClient,
        installer: mockInstaller,
      );
      
      expect(success, true);
      
      // Verify Proxy URL was used
      verify(() => mockClient.send(
        any(that: predicate<http.Request>((req) => req.url.toString() == proxyUrl))
      )).called(1);
      
      // Verify Install Logic invoked
      verify(() => mockInstaller.install(any(that: contains(fileName)))).called(1);
    });

    test('downloadAndInstallUpdate should fallback to original URL on proxy failure', () async {
      final originalUrl = 'https://github.com/app.apk';
      final fileName = 'update_fallback.apk';
      final proxyUrl = 'https://gh-proxy.org/$originalUrl';
      
      final mockSuccessResponse = MockHttpResponse();
      when(() => mockSuccessResponse.statusCode).thenReturn(200);
      when(() => mockSuccessResponse.contentLength).thenReturn(10);
      when(() => mockSuccessResponse.stream).thenAnswer((_) => http.ByteStream.fromBytes([1, 2, 3]));
      
      // Mock Proxy Fail
      when(() => mockClient.send(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments.first as http.Request;
        if (request.url.toString() == proxyUrl) {
           throw Exception('Proxy Timeout'); // Simulate network error
        }
        if (request.url.toString() == originalUrl) {
           return mockSuccessResponse;
        }
        throw Exception('Unexpected URL: ${request.url}');
      });
      
      final success = await UpdateService.downloadAndInstallUpdate(
        originalUrl, 
        fileName, 
        client: mockClient,
        installer: mockInstaller,
      );
      
      expect(success, true);
      
      // Verify Fallback URL was used
      verify(() => mockClient.send(
        any(that: predicate<http.Request>((req) => req.url.toString() == originalUrl))
      )).called(1);
      
       // Verify Install Logic invoked
      verify(() => mockInstaller.install(any(that: contains(fileName)))).called(1);
    });
  });
}
