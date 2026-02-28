import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/leave_request.dart';
import '../../../models/student_alert.dart';
import '../../../providers/teacher_provider.dart';
import '../../../utils/constants.dart';
import 'attendance_screen.dart';
import 'grade_entry_screen.dart';

/// 辅导员驾驶舱 — 教师/管理者主面板
class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  bool _isMaintenance = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<TeacherProvider>();

    try {
      await Future.wait([
        provider.fetchPendingApprovals(),
        provider.fetchStudentAlerts(),
      ]);
    } catch (e) {
      debugPrint('TeacherDashboard: failed to load data: $e');
    }

    if (mounted) {
      final hasMaintenanceError =
          provider.pendingApprovalsError == '服务维护中，请稍后再试' ||
              provider.studentAlertsError == '服务维护中，请稍后再试';
      if (hasMaintenanceError != _isMaintenance) {
        setState(() => _isMaintenance = hasMaintenanceError);
      }
    }
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeacherProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('辅导员驾驶舱'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            if (_isMaintenance) _buildMaintenanceBanner(context),
            const SizedBox(height: 16),
            _buildSummaryStats(context, provider),
            const SizedBox(height: 24),
            _buildSectionHeader(context, '学生预警雷达'),
            const SizedBox(height: 12),
            _buildAlertRadar(context, provider),
            const SizedBox(height: 24),
            _buildSectionHeader(context, '批量审批中心'),
            const SizedBox(height: 12),
            _buildBatchApproval(context, provider),
            const SizedBox(height: 24),
            _buildSectionHeader(context, '快捷操作'),
            const SizedBox(height: 12),
            _buildQuickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ==================== Maintenance Banner ====================

  Widget _buildMaintenanceBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.warningColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppConstants.warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.engineering_rounded,
              color: AppConstants.warningColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '服务维护中，当前数据为演示模式',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppConstants.warningColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Summary Stats ====================

  Widget _buildSummaryStats(BuildContext context, TeacherProvider provider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pendingCount = provider.pendingApprovals.length;
    final alertCount = provider.studentAlerts.length;

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
          _buildStatItem(context, '$pendingCount', '待审批',
              AppConstants.warningColor),
          _buildStatDivider(context),
          _buildStatItem(
              context, '$alertCount', '预警学生', AppConstants.errorColor),
          _buildStatDivider(context),
          _buildStatItem(
              context, '96.5%', '出勤率', AppConstants.successColor),
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

  // ==================== Alert Radar ====================

  Widget _buildAlertRadar(BuildContext context, TeacherProvider provider) {
    if (provider.studentAlertsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final alerts = provider.studentAlerts;
    if (alerts.isEmpty) {
      return _buildEmptyState(context, '暂无预警学生', Icons.check_circle_outline);
    }

    return Column(
      children: alerts.map((a) => _buildAlertCard(context, a)).toList(),
    );
  }

  Widget _buildAlertCard(BuildContext context, StudentAlert alert) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final alertColor = _alertLevelColor(alert.alertLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: alertColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: alertColor.withValues(alpha: 0.15),
                      child: Text(
                        alert.studentName.isNotEmpty
                            ? alert.studentName[0]
                            : '?',
                        style: TextStyle(
                          color: alertColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                alert.studentName,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildAlertBadge(context, alert.alertLevel),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert.reason,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBadge(BuildContext context, String level) {
    final color = _alertLevelColor(level);
    final label = _alertLevelLabel(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _alertLevelColor(String level) {
    switch (level) {
      case 'red':
        return AppConstants.errorColor;
      case 'yellow':
        return AppConstants.warningColor;
      case 'blue':
        return AppConstants.accentColor;
      default:
        return AppConstants.primaryColor;
    }
  }

  String _alertLevelLabel(String level) {
    switch (level) {
      case 'red':
        return '红色预警';
      case 'yellow':
        return '黄色预警';
      case 'blue':
        return '蓝色关注';
      default:
        return '未知';
    }
  }

  // ==================== Batch Approval ====================

  Widget _buildBatchApproval(BuildContext context, TeacherProvider provider) {
    if (provider.pendingApprovalsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final approvals = provider.pendingApprovals;
    if (approvals.isEmpty) {
      return _buildEmptyState(context, '暂无待审批请求', Icons.task_alt_rounded);
    }

    return Column(
      children:
          approvals.map((r) => _buildApprovalItem(context, r, provider)).toList(),
    );
  }

  Widget _buildApprovalItem(
    BuildContext context,
    LeaveRequest request,
    TeacherProvider provider,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dismissible(
      key: Key(request.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppConstants.successColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Row(
          children: [
            Icon(Icons.check_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('批准', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppConstants.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('驳回', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.close_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await provider.approveRequest(request.id);
          return true;
        } else {
          final comment = await _showRejectDialog(context);
          if (comment != null) {
            await provider.rejectRequest(request.id, comment);
            return true;
          }
          return false;
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        AppConstants.primaryColor.withValues(alpha: 0.15),
                    child: const Icon(Icons.person_rounded,
                        size: 18, color: AppConstants.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      request.userId,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          AppConstants.warningColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      request.type,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.warningColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatDate(request.startTime)} — ${_formatDate(request.endTime)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                request.reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '← 右滑批准  ·  左滑驳回 →',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.outline.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<String?> _showRejectDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('驳回原因'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入驳回原因（可选）',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(
              '确认驳回',
              style: TextStyle(color: AppConstants.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Quick Actions ====================

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            context,
            icon: Icons.person_search_rounded,
            label: '一键寻人',
            color: AppConstants.primaryColor,
            onTap: () {},
          ),
          _buildActionButton(
            context,
            icon: Icons.analytics_rounded,
            label: '学生画像',
            color: AppConstants.accentColor,
            onTap: () {},
          ),
          _buildActionButton(
            context,
            icon: Icons.fact_check_rounded,
            label: '考勤管理',
            color: AppConstants.successColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AttendanceScreen(),
                ),
              );
            },
          ),
          _buildActionButton(
            context,
            icon: Icons.grading_rounded,
            label: '成绩录入',
            color: AppConstants.warningColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GradeEntryScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Empty State ====================

  Widget _buildEmptyState(BuildContext context, String message, IconData icon) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: cs.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline),
          ),
        ],
      ),
    );
  }
}
