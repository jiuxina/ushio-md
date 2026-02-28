import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

/// 课堂考勤页面
///
/// 包含动态二维码签到、蓝牙雷达感应和学生考勤列表。
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  late final AnimationController _qrRotateController;
  late final AnimationController _radarController;
  Timer? _countdownTimer;

  int _qrCountdown = 30;

  // Mock student list
  final List<_StudentAttendance> _students = [
    _StudentAttendance(name: '张三', studentId: '2021001'),
    _StudentAttendance(name: '李四', studentId: '2021002'),
    _StudentAttendance(name: '王五', studentId: '2021003'),
    _StudentAttendance(name: '赵六', studentId: '2021004'),
    _StudentAttendance(name: '刘七', studentId: '2021005'),
    _StudentAttendance(name: '陈八', studentId: '2021006'),
    _StudentAttendance(name: '杨九', studentId: '2021007'),
    _StudentAttendance(name: '黄十', studentId: '2021008'),
  ];

  @override
  void initState() {
    super.initState();
    _qrRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_qrCountdown > 0) {
          _qrCountdown--;
        } else {
          _qrCountdown = 30;
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _qrRotateController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  int get _presentCount =>
      _students.where((s) => s.status == 'present').length;

  int get _absentCount =>
      _students.where((s) => s.status == 'absent').length;

  int get _lateCount => _students.where((s) => s.status == 'late').length;

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('考勤管理'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 16),
          _buildQrCodeSection(context),
          const SizedBox(height: 16),
          _buildBluetoothRadar(context),
          const SizedBox(height: 24),
          _buildSectionHeader(context, '学生名单'),
          const SizedBox(height: 12),
          _buildStudentList(context),
          const SizedBox(height: 16),
          _buildSummary(context),
          const SizedBox(height: 16),
          _buildSubmitButton(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==================== QR Code Section ====================

  Widget _buildQrCodeSection(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.3),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 120,
                  color: Color(0xFF1E293B),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: AnimatedBuilder(
                    animation: _qrRotateController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _qrRotateController.value * 2 * math.pi,
                        child: child,
                      );
                    },
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: AppConstants.primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined,
                  size: 16, color: AppConstants.primaryColor),
              const SizedBox(width: 4),
              Text(
                '动态刷新中...  ${_qrCountdown}s 后更新',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Bluetooth Radar ====================

  Widget _buildBluetoothRadar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _RadarPainter(
                    progress: _radarController.value,
                    color: AppConstants.accentColor,
                  ),
                  child: child,
                );
              },
              child: Center(
                child: Icon(
                  Icons.bluetooth_searching_rounded,
                  size: 32,
                  color: AppConstants.accentColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bluetooth_rounded,
                  size: 16, color: AppConstants.accentColor),
              const SizedBox(width: 4),
              Text(
                '蓝牙感应中...  已发现 ${_presentCount} 台设备',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppConstants.accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Student List ====================

  Widget _buildStudentList(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
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
        children: _students.asMap().entries.map((entry) {
          final index = entry.key;
          final student = entry.value;
          final isLast = index == _students.length - 1;

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppConstants.primaryColor.withValues(alpha: 0.15),
                      child: Text(
                        student.name[0],
                        style: const TextStyle(
                          color: AppConstants.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            student.studentId,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(context, student, 'present', '到课'),
                    const SizedBox(width: 4),
                    _buildStatusChip(context, student, 'late', '迟到'),
                    const SizedBox(width: 4),
                    _buildStatusChip(context, student, 'absent', '缺勤'),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    _StudentAttendance student,
    String status,
    String label,
  ) {
    final isSelected = student.status == status;
    Color chipColor;
    switch (status) {
      case 'present':
        chipColor = AppConstants.successColor;
        break;
      case 'late':
        chipColor = AppConstants.warningColor;
        break;
      case 'absent':
        chipColor = AppConstants.errorColor;
        break;
      default:
        chipColor = AppConstants.primaryColor;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          student.status = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? chipColor
                : Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? chipColor
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }

  // ==================== Summary ====================

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            '到课 $_presentCount',
            style: TextStyle(
              color: AppConstants.successColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            '迟到 $_lateCount',
            style: TextStyle(
              color: AppConstants.warningColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            '缺勤 $_absentCount',
            style: TextStyle(
              color: AppConstants.errorColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            '合计 ${_students.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Submit ====================

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('考勤已提交')),
          );
        },
        icon: const Icon(Icons.check_rounded),
        label: const Text('提交考勤'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
}

// ==================== Helper Classes ====================

class _StudentAttendance {
  final String name;
  final String studentId;
  String status; // present / absent / late

  _StudentAttendance({
    required this.name,
    required this.studentId,
    this.status = 'present',
  });
}

/// Radar sweep painter for the bluetooth section
class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw concentric circles
    for (int i = 1; i <= 3; i++) {
      final r = radius * i / 3;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, r, paint);
    }

    // Draw sweep arc
    final sweepAngle = math.pi / 3;
    final startAngle = progress * 2 * math.pi - math.pi / 2;

    final sweepPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      true,
      sweepPaint,
    );

    // Draw sweep edge line
    final edgePaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final edgeEndX = center.dx + radius * math.cos(startAngle + sweepAngle);
    final edgeEndY = center.dy + radius * math.sin(startAngle + sweepAngle);
    canvas.drawLine(center, Offset(edgeEndX, edgeEndY), edgePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
