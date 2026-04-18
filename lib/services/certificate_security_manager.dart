// ============================================================================
// 证书安全管理器
//
// 处理自签名证书的安全连接：
// - 默认严格校验系统信任链
// - 检测自签名证书错误
// - 用户确认后允许特定主机的不安全连接
// - 本地安全存储信任的主机信息
//
// 安全策略：
// 1. 默认行为：严格依赖系统信任链
// 2. 自签名证书：弹窗警告，用户确认后放行
// 3. 域名限制：仅放行用户确认的特定主机
// 4. 本地存储：使用加密存储
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/debug_log.dart';

/// 证书验证结果
enum CertificateValidationResult {
  /// 证书有效（系统信任）
  valid,
  /// 证书无效（自签名或过期）
  invalid,
  /// 连接失败（网络错误）
  connectionFailed,
  /// 用户已信任此主机
  userTrusted,
}

/// 证书验证错误详情
class CertificateError {
  final String message;
  final String? host;
  final int? port;
  final Uint8List? certificateData;

  const CertificateError({
    required this.message,
    this.host,
    this.port,
    this.certificateData,
  });
}

/// 用户信任的主机信息
class TrustedHost {
  final String host;
  final int port;
  final DateTime trustedAt;
  final String? certificateFingerprint;

  const TrustedHost({
    required this.host,
    required this.port,
    required this.trustedAt,
    this.certificateFingerprint,
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'trustedAt': trustedAt.toIso8601String(),
    'certificateFingerprint': certificateFingerprint,
  };

  factory TrustedHost.fromJson(Map<String, dynamic> json) => TrustedHost(
    host: json['host'] as String,
    port: json['port'] as int,
    trustedAt: DateTime.parse(json['trustedAt'] as String),
    certificateFingerprint: json['certificateFingerprint'] as String?,
  );
}

/// 证书安全管理器
class CertificateSecurityManager {
  static const _storageKey = 'trusted_hosts';
  
  static final CertificateSecurityManager _instance = CertificateSecurityManager._internal();
  factory CertificateSecurityManager() => _instance;
  CertificateSecurityManager._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// 内存缓存：用户已信任的主机
  final Map<String, TrustedHost> _trustedHostsCache = {};

  /// 是否已初始化
  bool _initialized = false;

  /// 初始化：从安全存储加载信任的主机
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final data = await _storage.read(key: _storageKey);
      if (data != null) {
        final List<dynamic> hosts = jsonDecode(data);
        for (final hostJson in hosts) {
          final host = TrustedHost.fromJson(hostJson as Map<String, dynamic>);
          final key = '${host.host}:${host.port}';
          _trustedHostsCache[key] = host;
        }
      }
    } catch (e) {
      appDebugLog('加载信任主机失败: $e');
    }

    _initialized = true;
  }

  /// 检查主机是否已被用户信任
  Future<bool> isHostTrusted(String host, int port) async {
    await initialize();
    final key = '$host:$port';
    return _trustedHostsCache.containsKey(key);
  }

  /// 添加用户信任的主机
  Future<void> trustHost(String host, int port, {String? certificateFingerprint}) async {
    // 参数验证
    if (host.trim().isEmpty) {
      throw ArgumentError('主机名不能为空');
    }
    if (port < 1 || port > 65535) {
      throw ArgumentError('端口号必须在 1-65535 范围内: $port');
    }
    
    await initialize();
    
    final key = '$host:$port';
    final trustedHost = TrustedHost(
      host: host,
      port: port,
      trustedAt: DateTime.now(),
      certificateFingerprint: certificateFingerprint,
    );
    
    _trustedHostsCache[key] = trustedHost;
    await _saveTrustedHosts();
    
    appDebugLog('用户信任主机: $key');
  }

  /// 移除信任的主机
  Future<void> removeTrustedHost(String host, int port) async {
    // 参数验证
    if (host.trim().isEmpty) {
      throw ArgumentError('主机名不能为空');
    }
    
    await initialize();
    
    final key = '$host:$port';
    _trustedHostsCache.remove(key);
    await _saveTrustedHosts();
    
    appDebugLog('移除信任主机: $key');
  }

  /// 获取所有信任的主机
  Future<List<TrustedHost>> getTrustedHosts() async {
    await initialize();
    return _trustedHostsCache.values.toList();
  }

  /// 保存信任主机到安全存储
  Future<void> _saveTrustedHosts() async {
    final hosts = _trustedHostsCache.values.map((h) => h.toJson()).toList();
    await _storage.write(key: _storageKey, value: jsonEncode(hosts));
  }

  /// 测试连接（严格模式）
  /// 
  /// 返回证书验证结果和错误详情
  Future<CertificateValidationResult> testConnection(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: timeout,
      );
      await socket.close();
      return CertificateValidationResult.valid;
    } on HandshakeException catch (e) {
      // 证书验证失败（自签名或过期）
      appDebugLog('证书验证失败: $e');
      return CertificateValidationResult.invalid;
    } on SocketException catch (e) {
      appDebugLog('连接失败: $e');
      return CertificateValidationResult.connectionFailed;
    } catch (e) {
      appDebugLog('未知错误: $e');
      return CertificateValidationResult.connectionFailed;
    }
  }

  /// 测试连接（用户信任模式）
  /// 
  /// 如果主机已被用户信任，则跳过证书验证
  Future<CertificateValidationResult> testConnectionWithTrust(
    String host,
    int port,
  ) async {
    // 检查是否已信任
    if (await isHostTrusted(host, port)) {
      return CertificateValidationResult.userTrusted;
    }

    // 尝试严格连接
    return testConnection(host, port);
  }

  /// 创建不安全的 HttpClient（仅用于用户已信任的主机）
  /// 
  /// ⚠️ 警告：此方法创建的客户端跳过证书验证
  /// 仅在用户明确确认信任后使用
  HttpClient createUnsafeHttpClient({
    required String allowedHost,
    int? allowedPort,
  }) {
    // 参数验证
    if (allowedHost.isEmpty) {
      throw ArgumentError('allowedHost 不能为空');
    }
    
    final client = HttpClient();
    
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // 核心安全逻辑：仅放行用户确认的特定主机
      final isAllowed = host == allowedHost && (allowedPort == null || port == allowedPort);
      
      if (isAllowed) {
        appDebugLog('⚠️ 允许不安全连接: $host:$port (用户已信任)');
        return true;
      }
      
      // 其他主机拒绝
      appDebugLog('🚫 拒绝不安全连接: $host:$port (非信任主机)');
      return false;
    };
    
    return client;
  }

  /// 从 URL 解析主机和端口（带参数验证）
  (String host, int port) parseUrl(String url) {
    if (url.trim().isEmpty) {
      throw ArgumentError('URL 不能为空');
    }
    
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw ArgumentError('无效的 URL: $url');
    }
    
    if (uri.host.isEmpty) {
      throw ArgumentError('无法从 URL 解析主机名: $url');
    }
    
    final host = uri.host;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    
    if (port < 1 || port > 65535) {
      throw ArgumentError('端口号超出有效范围: $port');
    }
    
    return (host, port);
  }

  /// 检查 URL 是否使用自签名证书
  Future<CertificateValidationResult> checkUrlCertificate(String url) async {
    final (host, port) = parseUrl(url);
    return testConnectionWithTrust(host, port);
  }
}
