import 'package:flutter/material.dart';

import '../../../utils/constants.dart';
import '../../../widgets/glass_card.dart';
import 'account_deletion_screen.dart';

/// 隐私合规中心
///
/// 展示个人信息收集清单、第三方共享清单及数据导出功能。
class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  // 权限开关状态（必要权限始终开启）
  final Map<String, bool> _permissions = {
    '学号': true,
    '手机号': true,
    '定位信息': true,
    '相机': false,
    '生物特征': false,
  };

  // 必要权限列表（不可关闭）
  static const _requiredPermissions = {'学号', '手机号', '定位信息'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私合规中心')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader(context, '个人信息收集清单'),
          const SizedBox(height: 12),
          _buildDataCollectionHeader(context),
          const SizedBox(height: 8),
          _buildDataCollectionList(context),
          const SizedBox(height: 24),
          _buildSectionHeader(context, '第三方共享清单'),
          const SizedBox(height: 12),
          _buildThirdPartyList(context),
          const SizedBox(height: 24),
          _buildSectionHeader(context, '数据导出'),
          const SizedBox(height: 12),
          _buildDataExportSection(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==================== Section Header ====================

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  // ==================== Data Collection ====================

  Widget _buildDataCollectionHeader(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppConstants.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '我们依据《个人信息保护法》收集以下信息，仅用于提供校园服务。',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCollectionList(BuildContext context) {
    final items = <_DataItem>[
      _DataItem(Icons.badge_rounded, '学号', '身份认证', '合同履行'),
      _DataItem(Icons.phone_android_rounded, '手机号', '验证码登录', '合同履行'),
      _DataItem(Icons.location_on_rounded, '定位信息', '校车与导航', '合同履行'),
      _DataItem(Icons.camera_alt_rounded, '相机', '证明材料上传', '用户同意'),
      _DataItem(Icons.fingerprint_rounded, '生物特征', '快捷登录', '用户同意'),
    ];

    return Column(
      children: items.map((item) => _buildDataCollectionItem(context, item)).toList(),
    );
  }

  Widget _buildDataCollectionItem(BuildContext context, _DataItem item) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isRequired = _requiredPermissions.contains(item.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppConstants.primaryColor.withValues(alpha: 0.2),
                  AppConstants.primaryColor.withValues(alpha: 0.1),
                ]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: AppConstants.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.name,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (isRequired) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: '必要权限',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppConstants.warningColor
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('必要',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppConstants.warningColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '用途: ${item.purpose}  ·  法律依据: ${item.legalBasis}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _permissions[item.name] ?? false,
              onChanged: isRequired
                  ? null
                  : (v) => setState(() => _permissions[item.name] = v),
              activeColor: AppConstants.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Third-party Sharing ====================

  Widget _buildThirdPartyList(BuildContext context) {
    final items = <_ThirdParty>[
      _ThirdParty('支付宝', '缴费', '订单与金额信息'),
      _ThirdParty('高德地图', '导航', '位置坐标'),
      _ThirdParty('阿里云OSS', '文件存储', '上传的文件内容'),
      _ThirdParty('极光推送', '消息通知', '设备标识'),
    ];

    return Column(
      children: items.map((item) {
        return GlassCard(
          icon: Icons.business_rounded,
          iconColor: AppConstants.accentColor,
          title: item.name,
          subtitle: '用途: ${item.purpose}  ·  共享数据: ${item.dataShared}',
          onTap: () => _showThirdPartyDetail(context, item),
          trailing: Text('查看详情',
              style: TextStyle(
                  fontSize: 12, color: AppConstants.primaryColor)),
        );
      }).toList(),
    );
  }

  void _showThirdPartyDetail(BuildContext context, _ThirdParty item) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(item.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailRow(theme, '服务用途', item.purpose),
            const SizedBox(height: 8),
            _buildDetailRow(theme, '共享数据', item.dataShared),
            const SizedBox(height: 8),
            _buildDetailRow(theme, '数据处理方式', '加密传输，用后即删'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ),
        Expanded(
          child: Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  // ==================== Data Export ====================

  Widget _buildDataExportSection(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          icon: Icons.download_rounded,
          iconColor: AppConstants.successColor,
          title: '导出我的数据',
          subtitle: '下载您在平台上的所有个人数据',
          onTap: () => _showExportDialog(context),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
        GlassCard(
          icon: Icons.person_off_rounded,
          iconColor: AppConstants.errorColor,
          title: '账号注销',
          subtitle: '永久删除您的账号和所有数据',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AccountDeletionScreen(),
              ),
            );
          },
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
      ],
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出我的数据'),
        content: const Text('我们将打包您的个人数据并发送到您的注册邮箱，预计需要1-3个工作日。确认导出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据导出请求已提交，请留意邮箱')),
              );
            },
            child: const Text('确认导出'),
          ),
        ],
      ),
    );
  }
}

// ==================== Data Models ====================

class _DataItem {
  final IconData icon;
  final String name;
  final String purpose;
  final String legalBasis;

  const _DataItem(this.icon, this.name, this.purpose, this.legalBasis);
}

class _ThirdParty {
  final String name;
  final String purpose;
  final String dataShared;

  const _ThirdParty(this.name, this.purpose, this.dataShared);
}
