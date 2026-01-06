// ============================================================================
// 插件安全服务
// 
// 提供去中心化的安全验证机制：
// - 危险权限检测和警告
// - 可选的作者签名验证
// - 社区声誉系统接口预留
// ============================================================================

import 'package:flutter/material.dart';
import 'plugin_manifest.dart';

/// 插件安全服务
/// 
/// 采用去中心化信任模型，用户自主决定是否信任插件
class PluginSecurity {
  /// 检查插件是否需要危险权限确认
  /// 
  /// 返回需要用户确认的危险权限列表
  static List<String> checkDangerousPermissions(PluginManifest manifest) {
    return manifest.dangerousPermissions;
  }

  /// 验证作者签名（可选）
  /// 
  /// 签名验证是可选的，用于确认插件来源
  /// 未签名的插件仍然可以安装，但会显示提示
  static Future<SignatureVerifyResult> verifySignature(PluginManifest manifest) async {
    if (manifest.signature == null || manifest.signature!.isEmpty) {
      return SignatureVerifyResult(
        isValid: false,
        status: SignatureStatus.unsigned,
        message: '此插件未签名',
      );
    }

    // TODO: 实现实际的签名验证逻辑
    // 当前版本返回未验证状态
    return SignatureVerifyResult(
      isValid: false,
      status: SignatureStatus.unverified,
      message: '签名验证功能开发中',
    );
  }

  /// 显示危险权限警告对话框
  /// 
  /// 返回 true 表示用户确认继续，false 表示用户取消
  static Future<bool> showDangerousPermissionWarning(
    BuildContext context,
    PluginManifest manifest,
  ) async {
    final dangerousPerms = manifest.dangerousPermissions;
    if (dangerousPerms.isEmpty) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('安全警告'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '插件 "${manifest.name}" 请求以下危险权限：',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            ...dangerousPerms.map((perm) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _getPermissionIcon(perm),
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      PluginPermission.getDescription(perm),
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                '这些权限可能会访问您的云服务账户、网络或文件系统。'
                '请确保您信任此插件的来源。',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            child: const Text('我了解风险，继续'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// 显示首次联网提醒对话框
  /// 
  /// 当用户首次访问在线市场时显示
  static Future<bool> showNetworkAccessWarning(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('联网提醒'),
          ],
        ),
        content: const Text(
          '访问在线插件市场需要连接互联网。\n\n'
          '应用将从 GitHub 获取官方插件列表。\n'
          '是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('允许'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// 获取权限对应的图标
  static IconData _getPermissionIcon(String permission) {
    switch (permission) {
      case PluginPermission.cloudService:
        return Icons.cloud;
      case PluginPermission.network:
        return Icons.wifi;
      case PluginPermission.fileSystem:
        return Icons.folder;
      case PluginPermission.fileActions:
        return Icons.file_copy;
      default:
        return Icons.security;
    }
  }
}

/// 签名验证状态
enum SignatureStatus {
  /// 有效签名
  valid,
  /// 无效签名
  invalid,
  /// 未签名
  unsigned,
  /// 未验证（签名存在但无法验证）
  unverified,
}

/// 签名验证结果
class SignatureVerifyResult {
  final bool isValid;
  final SignatureStatus status;
  final String message;
  final String? signerInfo;

  SignatureVerifyResult({
    required this.isValid,
    required this.status,
    required this.message,
    this.signerInfo,
  });
}
