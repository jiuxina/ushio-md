import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

/// 邀请海报生成器
///
/// 生成包含用户信息和二维码的分享海报，支持保存和分享。
class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  // 模拟数据
  static const _referralCode = 'XSTX2024';
  static const _invitedCount = 5;
  static const _earnedPoints = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('邀请好友')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 16),
          _buildPosterPreview(context),
          const SizedBox(height: 24),
          _buildActionButtons(context),
          const SizedBox(height: 24),
          _buildStatsCard(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==================== Poster Preview ====================

  Widget _buildPosterPreview(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.primaryColor,
            AppConstants.primaryDark,
            Color(0xFF7C3AED),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            // App logo & name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_rounded,
                    color: AppConstants.primaryColor, size: 28),
                const SizedBox(width: 8),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // User avatar
            CircleAvatar(
              radius: 36,
              backgroundColor:
                  AppConstants.primaryColor.withValues(alpha: 0.15),
              child: const Icon(Icons.person_rounded,
                  size: 36, color: AppConstants.primaryColor),
            ),
            const SizedBox(height: 12),
            // Referral code
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '邀请码: $_referralCode',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppConstants.primaryColor,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // QR code placeholder
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3)),
              ),
              child: const Center(
                child: Icon(Icons.qr_code_2,
                    size: 120, color: Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(height: 20),
            // Tagline
            Text(
              '一起加入相思同行，智慧校园等你来！',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Action Buttons ====================

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('海报已生成')),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('生成海报'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已保存到相册')),
                  );
                },
                icon: const Icon(Icons.save_alt_rounded, size: 20),
                label: const Text('保存到相册'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                      color:
                          AppConstants.primaryColor.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分享功能即将上线')),
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text('分享给好友'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                      color:
                          AppConstants.primaryColor.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== Stats Card ====================

  Widget _buildStatsCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('$_invitedCount',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    )),
                const SizedBox(height: 4),
                Text('已邀请',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline)),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
          Expanded(
            child: Column(
              children: [
                Text('$_earnedPoints',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.warningColor,
                    )),
                const SizedBox(height: 4),
                Text('获得积分',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
