import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/leave_request.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/campus_provider.dart';
import '../../../utils/constants.dart';

/// 智慧办事 — Tab 3
///
/// 快捷办事入口、请假表单、我的申请列表、报修等。
class OfficeTab extends StatefulWidget {
  const OfficeTab({super.key});

  @override
  State<OfficeTab> createState() => _OfficeTabState();
}

class _OfficeTabState extends State<OfficeTab> {
  bool _isMaintenance = false;
  int _filterIndex = 0; // 0=全部 1=处理中 2=已办结
  bool _showLeaveForm = false;
  bool _showRepairForm = false;

  // Leave form state
  String _leaveType = '事假';
  DateTime? _leaveStart;
  DateTime? _leaveEnd;
  final _destinationController = TextEditingController();
  final _leaveReasonController = TextEditingController();
  final List<String> _photoPlaceholders = [];
  bool _submittingLeave = false;
  bool _showCancelRules = false;

  // Repair form state
  final Set<String> _faultTypes = {};
  final _buildingController = TextEditingController();
  final _roomController = TextEditingController();
  String _preferredTimeSlot = '上午';
  final _repairDescController = TextEditingController();
  bool _submittingRepair = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _leaveReasonController.dispose();
    _buildingController.dispose();
    _roomController.dispose();
    _repairDescController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final campus = context.read<CampusProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';

    try {
      await Future.wait([
        if (userId.isNotEmpty) campus.fetchLeaveRequests(userId),
      ]);
    } catch (e) {
      debugPrint('OfficeTab: failed to load data: $e');
    }

    if (mounted) {
      final hasMaintenanceError =
          campus.leaveRequestsError == '服务维护中，请稍后再试';
      if (hasMaintenanceError != _isMaintenance) {
        setState(() => _isMaintenance = hasMaintenanceError);
      }
    }
  }

  // ======================== helpers ========================

  String _formatDate(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _durationText(Duration d) {
    if (d.inDays > 0) return '${d.inDays}天${d.inHours % 24}小时';
    if (d.inHours > 0) return '${d.inHours}小时${d.inMinutes % 60}分钟';
    return '${d.inMinutes}分钟';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppConstants.warningColor;
      case 'approved':
        return AppConstants.successColor;
      case 'rejected':
        return AppConstants.errorColor;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待审批';
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已拒绝';
      case 'cancelled':
        return '已撤回';
      default:
        return status;
    }
  }

  List<LeaveRequest> _filteredRequests(List<LeaveRequest> all) {
    switch (_filterIndex) {
      case 1:
        return all.where((r) => r.status == 'pending').toList();
      case 2:
        return all
            .where((r) =>
                r.status == 'approved' ||
                r.status == 'rejected' ||
                r.status == 'cancelled')
            .toList();
      default:
        return all;
    }
  }

  // ======================== actions ========================

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _leaveStart = dt;
      } else {
        _leaveEnd = dt;
      }
    });
  }

  Future<void> _submitLeave() async {
    if (_leaveStart == null || _leaveEnd == null) {
      _showSnackBar('请选择起止时间');
      return;
    }
    if (_leaveEnd!.isBefore(_leaveStart!)) {
      _showSnackBar('结束时间不能早于开始时间');
      return;
    }
    if (_leaveReasonController.text.trim().isEmpty) {
      _showSnackBar('请填写请假事由');
      return;
    }

    setState(() => _submittingLeave = true);

    final auth = context.read<AuthProvider>();
    final campus = context.read<CampusProvider>();
    final userId = auth.currentUser?.id ?? '';

    await campus.createLeaveRequest({
      'user_id': userId,
      'type': _leaveType,
      'start_time': _leaveStart!.toIso8601String(),
      'end_time': _leaveEnd!.toIso8601String(),
      'reason': _leaveReasonController.text.trim(),
      'destination': _destinationController.text.trim(),
      'attachments': _photoPlaceholders,
      'status': 'pending',
    });

    if (mounted) {
      setState(() {
        _submittingLeave = false;
        if (campus.leaveRequestsError == null) {
          _showLeaveForm = false;
          _leaveType = '事假';
          _leaveStart = null;
          _leaveEnd = null;
          _destinationController.clear();
          _leaveReasonController.clear();
          _photoPlaceholders.clear();
        }
      });
      if (campus.leaveRequestsError != null) {
        _showSnackBar(campus.leaveRequestsError!);
      } else {
        _showSnackBar('提交成功');
      }
    }
  }

  Future<void> _submitRepair() async {
    if (_faultTypes.isEmpty) {
      _showSnackBar('请选择故障类型');
      return;
    }
    if (_buildingController.text.trim().isEmpty ||
        _roomController.text.trim().isEmpty) {
      _showSnackBar('请填写楼栋和房间号');
      return;
    }
    if (_repairDescController.text.trim().isEmpty) {
      _showSnackBar('请填写故障描述');
      return;
    }

    setState(() => _submittingRepair = true);

    // Simulate submission
    await Future<void>.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        _submittingRepair = false;
        _showRepairForm = false;
        _faultTypes.clear();
        _buildingController.clear();
        _roomController.clear();
        _repairDescController.clear();
      });
      _showSnackBar('报修提交成功');
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  void _showApprovalTimeline(LeaveRequest req) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ApprovalTimelineSheet(request: req),
    );
  }

  // ======================== build ========================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppConstants.primaryColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 8),
          if (_isMaintenance) _buildMaintenanceBanner(theme),
          _buildHeader(theme, cs),
          const SizedBox(height: 20),
          _buildQuickActions(theme, cs),
          const SizedBox(height: 24),
          if (_showLeaveForm) ...[
            _buildLeaveForm(theme, cs),
            const SizedBox(height: 24),
          ],
          if (_showRepairForm) ...[
            _buildRepairForm(theme, cs),
            const SizedBox(height: 24),
          ],
          _buildMyApplications(theme, cs),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==================== maintenance banner ====================

  Widget _buildMaintenanceBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppConstants.warningColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: AppConstants.warningColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.construction_rounded,
              size: 20, color: AppConstants.warningColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '服务维护中，部分功能暂不可用',
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

  // ==================== header ====================

  Widget _buildHeader(ThemeData theme, ColorScheme cs) {
    final filters = ['全部', '处理中', '已办结'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '智慧办事',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(filters.length, (i) {
              final selected = _filterIndex == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filters[i]),
                  selected: selected,
                  onSelected: (_) => setState(() => _filterIndex = i),
                  selectedColor:
                      AppConstants.primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppConstants.primaryColor : cs.outline,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppConstants.primaryColor.withValues(alpha: 0.4)
                        : theme.dividerColor.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadiusSmall),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ==================== quick actions ====================

  Widget _buildQuickActions(ThemeData theme, ColorScheme cs) {
    final actions = [
      _QuickAction(
        Icons.event_note_rounded,
        '学生请假',
        AppConstants.warningColor,
        () => setState(() {
          _showLeaveForm = !_showLeaveForm;
          _showRepairForm = false;
        }),
      ),
      _QuickAction(
        Icons.build_rounded,
        '公寓报修',
        AppConstants.primaryColor,
        () => setState(() {
          _showRepairForm = !_showRepairForm;
          _showLeaveForm = false;
        }),
      ),
      _QuickAction(
        Icons.stadium_rounded,
        '场馆预约',
        AppConstants.successColor,
        () => _showSnackBar('场馆预约功能即将上线'),
      ),
      _QuickAction(
        Icons.description_rounded,
        '证明申请',
        const Color(0xFF8B5CF6),
        () => _showSnackBar('证明申请功能即将上线'),
      ),
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final a = actions[i];
          final isActive =
              (i == 0 && _showLeaveForm) || (i == 1 && _showRepairForm);
          return _QuickActionCard(
            icon: a.icon,
            label: a.label,
            color: a.color,
            isActive: isActive,
            onTap: a.onTap,
          );
        },
      ),
    );
  }

  // ==================== leave form ====================

  Widget _buildLeaveForm(ThemeData theme, ColorScheme cs) {
    final types = ['事假', '病假', '公假', '其他'];

    Duration? calcDuration;
    if (_leaveStart != null && _leaveEnd != null) {
      final diff = _leaveEnd!.difference(_leaveStart!);
      if (!diff.isNegative) calcDuration = diff;
    }

    return _GlassSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.event_note_rounded,
                  color: AppConstants.warningColor, size: 20),
              const SizedBox(width: 8),
              Text('学生请假申请',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _showLeaveForm = false),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Type selector
          Text('请假类型', style: theme.textTheme.bodySmall?.copyWith(
            color: cs.outline, fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: types.map((t) {
              final selected = _leaveType == t;
              return ChoiceChip(
                label: Text(t),
                selected: selected,
                onSelected: (_) => setState(() => _leaveType = t),
                selectedColor:
                    AppConstants.primaryColor.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color:
                      selected ? AppConstants.primaryColor : cs.onSurface,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected
                      ? AppConstants.primaryColor.withValues(alpha: 0.4)
                      : theme.dividerColor.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusSmall),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Start / End time
          Row(
            children: [
              Expanded(
                child: _TimePickerField(
                  label: '开始时间',
                  value:
                      _leaveStart != null ? _formatDate(_leaveStart!) : null,
                  onTap: () => _pickDateTime(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePickerField(
                  label: '结束时间',
                  value: _leaveEnd != null ? _formatDate(_leaveEnd!) : null,
                  onTap: () => _pickDateTime(isStart: false),
                ),
              ),
            ],
          ),

          // Duration display
          if (calcDuration != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    AppConstants.accentColor.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 14, color: AppConstants.accentColor),
                  const SizedBox(width: 4),
                  Text(
                    '时长：${_durationText(calcDuration)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppConstants.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Destination
          TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              labelText: '离校去向',
              hintText: '请填写目的地',
              prefixIcon: const Icon(Icons.place_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Reason
          TextField(
            controller: _leaveReasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '请假事由',
              hintText: '请详细说明请假原因',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Photo upload area (9-grid)
          Text('证明材料', style: theme.textTheme.bodySmall?.copyWith(
            color: cs.outline, fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 8),
          _buildPhotoGrid(theme, cs),
          const SizedBox(height: 16),

          // Cancel rules collapsible
          _buildCancelRules(theme, cs),
          const SizedBox(height: 16),

          // Submit
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submittingLeave ? null : _submitLeave,
              icon: _submittingLeave
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_submittingLeave ? '提交中…' : '提交申请'),
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(ThemeData theme, ColorScheme cs) {
    const maxPhotos = 9;
    final count = _photoPlaceholders.length;
    final showAdd = count < maxPhotos;
    final total = count + (showAdd ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: total,
      itemBuilder: (_, i) {
        if (i == count && showAdd) {
          // Add button
          return GestureDetector(
            onTap: () {
              setState(() => _photoPlaceholders.add('photo_${count + 1}'));
            },
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.7),
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
                border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      color: cs.outline, size: 28),
                  const SizedBox(height: 4),
                  Text('上传',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.outline)),
                ],
              ),
            ),
          );
        }
        // Placeholder thumbnail
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
              child: Center(
                child: Icon(Icons.image_outlined,
                    color: cs.outline, size: 32),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () =>
                    setState(() => _photoPlaceholders.removeAt(i)),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCancelRules(ThemeData theme, ColorScheme cs) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          onTap: () => setState(() => _showCancelRules = !_showCancelRules),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: cs.outline),
                const SizedBox(width: 6),
                Text('销假规则',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline)),
                const Spacer(),
                Icon(
                  _showCancelRules
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: cs.outline,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: AppConstants.animationDuration,
          crossFadeState: _showCancelRules
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadiusSmall),
            ),
            child: Text(
              '1. 请假结束后须在24小时内完成销假\n'
              '2. 超过3天未销假将自动标记异常\n'
              '3. 病假需上传医院证明材料\n'
              '4. 公假需上传相关活动通知',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.outline,
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== my applications ====================

  Widget _buildMyApplications(ThemeData theme, ColorScheme cs) {
    final campus = context.watch<CampusProvider>();
    final requests = _filteredRequests(campus.leaveRequests);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('我的申请',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),

        // Loading
        if (campus.leaveRequestsLoading && requests.isEmpty)
          _buildLoadingState(theme, cs),

        // Error
        if (campus.leaveRequestsError != null &&
            !_isMaintenance &&
            requests.isEmpty)
          _buildErrorState(theme, cs, campus.leaveRequestsError!),

        // Empty
        if (!campus.leaveRequestsLoading &&
            campus.leaveRequestsError == null &&
            requests.isEmpty)
          _buildEmptyState(theme, cs),

        // List
        if (requests.isNotEmpty)
          ...requests.map((r) => _buildApplicationItem(theme, cs, r)),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme, ColorScheme cs) {
    return _GlassSection(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppConstants.primaryColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              Text('加载中…',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.outline)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme cs, String error) {
    return _GlassSection(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppConstants.errorColor, size: 32),
              const SizedBox(height: 8),
              Text(error,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppConstants.errorColor)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadData,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs) {
    return _GlassSection(
      child: SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, color: cs.outline, size: 32),
              const SizedBox(height: 8),
              Text('暂无申请记录',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.outline)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationItem(
      ThemeData theme, ColorScheme cs, LeaveRequest r) {
    final statusColor = _statusColor(r.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showApprovalTimeline(r),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.5)),
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
                // Type tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    r.type,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatDate(r.startTime)} — ${_formatDate(r.endTime)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _statusLabel(r.status),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== repair form ====================

  Widget _buildRepairForm(ThemeData theme, ColorScheme cs) {
    final faultOptions = ['水电', '网络', '家具', '门锁', '其他'];
    final timeSlots = ['上午', '下午', '晚上', '随时'];

    return _GlassSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_rounded,
                  color: AppConstants.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text('公寓报修',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _showRepairForm = false),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fault type multi-select
          Text('故障类型（可多选）', style: theme.textTheme.bodySmall?.copyWith(
            color: cs.outline, fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: faultOptions.map((f) {
              final selected = _faultTypes.contains(f);
              return FilterChip(
                label: Text(f),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _faultTypes.add(f);
                    } else {
                      _faultTypes.remove(f);
                    }
                  });
                },
                selectedColor:
                    AppConstants.primaryColor.withValues(alpha: 0.15),
                checkmarkColor: AppConstants.primaryColor,
                labelStyle: TextStyle(
                  color: selected ? AppConstants.primaryColor : cs.onSurface,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected
                      ? AppConstants.primaryColor.withValues(alpha: 0.4)
                      : theme.dividerColor.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadiusSmall),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Location
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buildingController,
                  decoration: InputDecoration(
                    labelText: '楼栋',
                    hintText: '如：6号楼',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _roomController,
                  decoration: InputDecoration(
                    labelText: '房间号',
                    hintText: '如：301',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preferred time slot
          Text('期望上门时间', style: theme.textTheme.bodySmall?.copyWith(
            color: cs.outline, fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: timeSlots.map((t) {
              final selected = _preferredTimeSlot == t;
              return ChoiceChip(
                label: Text(t),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _preferredTimeSlot = t),
                selectedColor:
                    AppConstants.primaryColor.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color:
                      selected ? AppConstants.primaryColor : cs.onSurface,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected
                      ? AppConstants.primaryColor.withValues(alpha: 0.4)
                      : theme.dividerColor.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusSmall),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Description
          TextField(
            controller: _repairDescController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '故障描述',
              hintText: '请详细描述故障情况',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusSmall),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Submit
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submittingRepair ? null : _submitRepair,
              icon: _submittingRepair
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_submittingRepair ? '提交中…' : '提交报修'),
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Private helper classes
// ============================================================================

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);
}

/// Glassmorphism section wrapper matching the codebase style.
class _GlassSection extends StatelessWidget {
  final Widget child;
  const _GlassSection({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
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
      child: child,
    );
  }
}

/// Quick action card with glassmorphism styling.
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animationDuration,
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.12)
              : theme.colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.4)
                : theme.dividerColor.withValues(alpha: 0.5),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.2),
                    color.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Date / time picker field.
class _TimePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
          borderRadius:
              BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: cs.outline),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value ?? label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: value != null ? cs.onSurface : cs.outline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Approval timeline bottom sheet.
class _ApprovalTimelineSheet extends StatelessWidget {
  final LeaveRequest request;
  const _ApprovalTimelineSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Build timeline nodes
    final nodes = <_TimelineNode>[
      _TimelineNode(
        title: '提交申请',
        time: _fmt(request.createdAt),
        status: _NodeStatus.completed,
        detail: '${request.type} · ${request.reason}',
      ),
      _TimelineNode(
        title: '辅导员审批',
        time: request.reviewedAt != null ? _fmt(request.reviewedAt!) : null,
        status: _nodeStatus(request.status, 1),
        detail: request.reviewerComment,
      ),
      _TimelineNode(
        title: '院系审批',
        time: request.reviewedAt != null &&
                (request.status == 'approved' || request.status == 'rejected')
            ? _fmt(request.reviewedAt!)
            : null,
        status: _nodeStatus(request.status, 2),
        detail: null,
      ),
    ];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('审批进度',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ...List.generate(nodes.length, (i) {
                  final node = nodes[i];
                  final isLast = i == nodes.length - 1;
                  return _buildTimelineNode(theme, cs, node, isLast);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(
      ThemeData theme, ColorScheme cs, _TimelineNode node, bool isLast) {
    final color = _nodeColor(node.status);
    final icon = _nodeIcon(node.status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical line + dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 12, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.dividerColor.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (node.time != null)
                    Text(node.time!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline)),
                  if (node.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(node.detail!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  _NodeStatus _nodeStatus(String reqStatus, int step) {
    if (reqStatus == 'approved') return _NodeStatus.completed;
    if (reqStatus == 'rejected') {
      return step <= 1 ? _NodeStatus.completed : _NodeStatus.rejected;
    }
    if (reqStatus == 'cancelled') return _NodeStatus.cancelled;
    // pending
    if (step == 1) return _NodeStatus.current;
    return _NodeStatus.pending;
  }

  Color _nodeColor(_NodeStatus s) {
    switch (s) {
      case _NodeStatus.completed:
        return AppConstants.successColor;
      case _NodeStatus.current:
        return AppConstants.primaryColor;
      case _NodeStatus.rejected:
        return AppConstants.errorColor;
      case _NodeStatus.cancelled:
        return Colors.grey;
      case _NodeStatus.pending:
        return Colors.grey;
    }
  }

  IconData _nodeIcon(_NodeStatus s) {
    switch (s) {
      case _NodeStatus.completed:
        return Icons.check;
      case _NodeStatus.current:
        return Icons.more_horiz;
      case _NodeStatus.rejected:
        return Icons.close;
      case _NodeStatus.cancelled:
        return Icons.remove;
      case _NodeStatus.pending:
        return Icons.circle_outlined;
    }
  }
}

enum _NodeStatus { completed, current, pending, rejected, cancelled }

class _TimelineNode {
  final String title;
  final String? time;
  final _NodeStatus status;
  final String? detail;
  const _TimelineNode({
    required this.title,
    this.time,
    required this.status,
    this.detail,
  });
}
