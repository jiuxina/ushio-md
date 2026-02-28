import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../utils/constants.dart';
import '../../../widgets/glass_card.dart';
import '../../settings/appearance_settings_screen.dart';

/// 我的数字身份 - Tab 5
///
/// 用户个人中心，包含身份信息、服务入口和系统设置。
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _notificationsEnabled = true;

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isLoggedIn) {
      return _buildLoginPrompt(context);
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 16),
          _buildProfileCard(context, authProvider),
          const SizedBox(height: 16),
          _buildStatisticsRow(context),
          const SizedBox(height: 24),
          _buildSectionHeader(context, '常用服务'),
          const SizedBox(height: 12),
          _buildServicesSection(context),
          const SizedBox(height: 24),
          _buildSectionHeader(context, '系统设置'),
          const SizedBox(height: 12),
          _buildSettingsSection(context),
          const SizedBox(height: 24),
          _buildLogoutButton(context, authProvider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==================== Login Prompt ====================

  Widget _buildLoginPrompt(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 64,
                color: cs.outline,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '尚未登录',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '登录后即可使用数字身份功能',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.outline,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/login');
              },
              icon: const Icon(Icons.login_rounded),
              label: const Text('去登录'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Profile Card ====================

  Widget _buildProfileCard(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = authProvider.currentUser!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 36,
                backgroundColor:
                    AppConstants.primaryColor.withValues(alpha: 0.15),
                backgroundImage: user.avatar != null
                    ? NetworkImage(user.avatar!)
                    : null,
                child: user.avatar == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 36,
                        color: AppConstants.primaryColor,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRoleBadge(context, user.role),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${user.college} · ${user.major}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '学号 ${user.studentId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Digital campus code button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showCampusCode(context, user.name),
              icon: const Icon(Icons.qr_code_rounded, size: 20),
              label: const Text('电子校园码'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: AppConstants.primaryColor.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context, String role) {
    Color badgeColor;
    switch (role) {
      case '教师':
        badgeColor = AppConstants.warningColor;
        break;
      case '研究生':
        badgeColor = AppConstants.accentColor;
        break;
      default:
        badgeColor = AppConstants.primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.isEmpty ? '本科生' : role,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  // ==================== Statistics Row ====================

  Widget _buildStatisticsRow(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
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
          _buildStatItem(context, '100', '信用分',
              AppConstants.successColor),
          _buildStatDivider(context),
          _buildStatItem(context, '3', '待办事项',
              AppConstants.warningColor),
          _buildStatDivider(context),
          _buildStatItem(context, '2', '我的预约',
              AppConstants.primaryColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
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

  // ==================== Services Section ====================

  Widget _buildServicesSection(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          icon: Icons.payment_rounded,
          iconColor: AppConstants.warningColor,
          title: '缴费与发票',
          subtitle: '查看缴费记录与电子发票',
          onTap: () {},
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
        GlassCard(
          icon: Icons.description_rounded,
          iconColor: AppConstants.primaryColor,
          title: '我的申请',
          subtitle: '审批进度查询',
          onTap: () {},
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
        GlassCard(
          icon: Icons.notifications_rounded,
          iconColor: AppConstants.accentColor,
          title: '消息通知',
          subtitle: '校园消息与系统通知',
          onTap: () {},
          trailing: _buildBadge(context, '5'),
        ),
        GlassCard(
          icon: Icons.star_rounded,
          iconColor: const Color(0xFFF472B6),
          title: '我的收藏',
          subtitle: '收藏的内容与服务',
          onTap: () {},
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppConstants.errorColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ==================== Settings Section ====================

  Widget _buildSettingsSection(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          icon: Icons.palette_rounded,
          iconColor: AppConstants.primaryColor,
          title: '外观设置',
          subtitle: '主题、字体与配色方案',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AppearanceSettingsScreen(),
              ),
            );
          },
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
        GlassCard(
          icon: Icons.notifications_active_rounded,
          iconColor: AppConstants.accentColor,
          title: '通知设置',
          subtitle: _notificationsEnabled ? '已开启' : '已关闭',
          onTap: () {
            setState(() {
              _notificationsEnabled = !_notificationsEnabled;
            });
          },
          trailing: Switch.adaptive(
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
            activeColor: AppConstants.primaryColor,
          ),
        ),
        GlassCard(
          icon: Icons.shield_rounded,
          iconColor: AppConstants.successColor,
          title: '隐私与安全',
          subtitle: '账号安全与隐私管理',
          onTap: () {},
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
        GlassCard(
          icon: Icons.cleaning_services_rounded,
          iconColor: AppConstants.warningColor,
          title: '清理缓存',
          subtitle: '当前缓存 12.3 MB',
          onTap: () => _showClearCacheDialog(context),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
        GlassCard(
          icon: Icons.info_outline_rounded,
          iconColor: AppConstants.primaryColor,
          title: '关于相思同行',
          subtitle: '版本 ${AppConstants.appVersion}',
          onTap: () {},
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
      ],
    );
  }

  // ==================== Logout Button ====================

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLogoutDialog(context, authProvider),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                '退出登录',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppConstants.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== Dialogs ====================

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await authProvider.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
            child: Text(
              '退出',
              style: TextStyle(color: AppConstants.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('确定要清理所有缓存数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清理')),
              );
            },
            child: const Text('清理'),
          ),
        ],
      ),
    );
  }

  void _showCampusCode(BuildContext context, String userName) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '电子校园码',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // QR code placeholder
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 160,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              userName,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '请将此码出示给扫码设备',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.outline,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
