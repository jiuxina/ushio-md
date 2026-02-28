import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/course.dart';
import '../../../models/grade.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/campus_provider.dart';
import '../../../utils/constants.dart';

/// 学业与证明 — Tab 2
///
/// 包含 GPA 概览、课表快览、成绩列表、证明服务和毕业进度。
class AcademicTab extends StatefulWidget {
  const AcademicTab({super.key});

  @override
  State<AcademicTab> createState() => _AcademicTabState();
}

class _AcademicTabState extends State<AcademicTab> {
  bool _isMaintenance = false;
  String _selectedSemester = '2024-2025-2';

  final List<String> _semesters = [
    '2024-2025-2',
    '2024-2025-1',
    '2023-2024-2',
    '2023-2024-1',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final campus = context.read<CampusProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';

    try {
      await Future.wait([
        if (userId.isNotEmpty) campus.fetchCourses(userId),
      ]);
    } catch (e) {
      debugPrint('AcademicTab: failed to load data: $e');
    }

    if (mounted) {
      final hasMaintenanceError =
          campus.coursesError == '服务维护中，请稍后再试';
      if (hasMaintenanceError != _isMaintenance) {
        setState(() => _isMaintenance = hasMaintenanceError);
      }
    }
  }

  // ======================== helpers ========================

  String _periodToTime(int period) {
    const times = [
      '08:00', '08:55', '10:00', '10:55',
      '14:00', '14:55', '16:00', '16:55',
      '19:00', '19:55', '20:50',
    ];
    if (period >= 1 && period <= times.length) return times[period - 1];
    return '--:--';
  }

  Color _gpaColor(double gpa, double scale) {
    final ratio = gpa / scale;
    if (ratio >= 0.85) return AppConstants.successColor;
    if (ratio >= 0.7) return AppConstants.warningColor;
    return AppConstants.errorColor;
  }

  String _weekdayLabel(int day) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    if (day >= 1 && day <= 7) return labels[day - 1];
    return '';
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
          _buildGpaOverview(theme, cs),
          const SizedBox(height: 24),
          _buildCourseScheduleQuickView(theme, cs),
          const SizedBox(height: 24),
          _buildGradeList(theme, cs),
          const SizedBox(height: 24),
          _buildCertificateServices(theme, cs),
          const SizedBox(height: 24),
          _buildGraduationProgress(theme, cs),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            '学业中心',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSemester,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: cs.outline),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              items: _semesters.map((s) {
                return DropdownMenuItem(value: s, child: Text(s));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSemester = val);
                  _loadData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // ==================== GPA overview ====================

  Widget _buildGpaOverview(ThemeData theme, ColorScheme cs) {
    // Placeholder values – replace with real data when backend provides grades
    const double currentGpa = 3.5;
    const double maxGpa = 4.0;
    const int earnedCredits = 86;
    const int requiredCredits = 160;
    const String ranking = '12/156';

    final gpaColor = _gpaColor(currentGpa, maxGpa);

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
              // Circular GPA indicator
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _GpaCirclePainter(
                    progress: currentGpa / maxGpa,
                    color: gpaColor,
                    trackColor: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentGpa.toStringAsFixed(1),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: gpaColor,
                          ),
                        ),
                        Text(
                          '/ ${maxGpa.toStringAsFixed(1)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GpaInfoRow(
                      label: '已修学分',
                      value: '$earnedCredits / $requiredCredits',
                      icon: Icons.school_rounded,
                      color: AppConstants.primaryColor,
                    ),
                    const SizedBox(height: 12),
                    _GpaInfoRow(
                      label: '专业排名',
                      value: ranking,
                      icon: Icons.leaderboard_rounded,
                      color: AppConstants.accentColor,
                    ),
                    const SizedBox(height: 12),
                    _GpaInfoRow(
                      label: '本学期',
                      value: _selectedSemester,
                      icon: Icons.calendar_month_rounded,
                      color: AppConstants.warningColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== course schedule quick view ====================

  Widget _buildCourseScheduleQuickView(ThemeData theme, ColorScheme cs) {
    final campus = context.watch<CampusProvider>();
    final today = DateTime.now().weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '课表快览',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '查看完整课表',
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Mini week header
        Container(
          padding: const EdgeInsets.all(12),
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
              // Weekday row
              Row(
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final isToday = day == today;
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppConstants.primaryColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _weekdayLabel(day),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday
                                ? AppConstants.primaryColor
                                : cs.outline,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              // Today's courses
              if (campus.coursesLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else ...[
                ..._buildTodayCourseBlocks(campus.courses, today, theme, cs),
                if (campus.courses
                    .where((c) => c.dayOfWeek == today)
                    .isEmpty)
                  _emptyState('今日无课程安排'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTodayCourseBlocks(
      List<Course> courses, int today, ThemeData theme, ColorScheme cs) {
    final todayCourses = courses
        .where((c) => c.dayOfWeek == today)
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

    return todayCourses.map((c) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.primaryColor.withValues(alpha: 0.1),
              AppConstants.primaryColor.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          border: Border.all(
            color: AppConstants.primaryColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: AppConstants.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '第${c.startPeriod}-${c.endPeriod}节 · ${_periodToTime(c.startPeriod)}-${_periodToTime(c.endPeriod)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                c.location,
                style: TextStyle(
                  fontSize: 11,
                  color: AppConstants.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ==================== grade list ====================

  Widget _buildGradeList(ThemeData theme, ColorScheme cs) {
    // Placeholder grades – replace with provider data when available
    final grades = <Grade>[
      const Grade(
        id: '1', courseId: 'c1', courseName: '高等数学A',
        score: 92, credit: 5, gradePoint: 4.0, semester: '2024-2025-2',
      ),
      const Grade(
        id: '2', courseId: 'c2', courseName: '大学英语III',
        score: 85, credit: 3, gradePoint: 3.5, semester: '2024-2025-2',
      ),
      const Grade(
        id: '3', courseId: 'c3', courseName: '数据结构',
        score: 78, credit: 4, gradePoint: 3.0, semester: '2024-2025-2',
      ),
      const Grade(
        id: '4', courseId: 'c4', courseName: '线性代数',
        score: 95, credit: 3, gradePoint: 4.0, semester: '2024-2025-2',
      ),
    ];

    final filtered =
        grades.where((g) => g.semester == _selectedSemester).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '成绩列表',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: _emptyState('暂无成绩数据'),
                )
              : Column(
                  children: filtered.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final g = entry.value;
                    return _GradeExpansionTile(
                      grade: g,
                      isFirst: idx == 0,
                      isLast: idx == filtered.length - 1,
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // ==================== certificate services ====================

  Widget _buildCertificateServices(ThemeData theme, ColorScheme cs) {
    final items = <_CertificateItem>[
      _CertificateItem(
        Icons.verified_rounded,
        '在读证明',
        AppConstants.primaryColor,
      ),
      _CertificateItem(
        Icons.description_rounded,
        '成绩单',
        AppConstants.successColor,
      ),
      _CertificateItem(
        Icons.translate_rounded,
        '英语等级',
        AppConstants.warningColor,
      ),
      _CertificateItem(
        Icons.more_horiz_rounded,
        '更多证明',
        AppConstants.accentColor,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '证明服务',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: items.map((item) {
            return GestureDetector(
              onTap: () {},
              child: Container(
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            item.color.withValues(alpha: 0.2),
                            item.color.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppConstants.borderRadius),
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==================== graduation progress ====================

  Widget _buildGraduationProgress(ThemeData theme, ColorScheme cs) {
    final categories = <_GraduationCategory>[
      _GraduationCategory('必修', 62, 90, AppConstants.primaryColor),
      _GraduationCategory('选修', 18, 30, AppConstants.successColor),
      _GraduationCategory('实践', 6, 20, AppConstants.warningColor),
    ];

    final totalEarned =
        categories.fold<int>(0, (sum, c) => sum + c.earned);
    final totalRequired =
        categories.fold<int>(0, (sum, c) => sum + c.requiredCredits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '毕业进度',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
          child: Column(
            children: [
              // Overall progress
              Row(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: AppConstants.warningColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '总学分进度',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$totalEarned / $totalRequired',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalRequired > 0 ? totalEarned / totalRequired : 0,
                  minHeight: 8,
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppConstants.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Category breakdowns
              ...categories.map((cat) {
                final progress =
                    cat.requiredCredits > 0 ? cat.earned / cat.requiredCredits : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          cat.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor:
                                theme.dividerColor.withValues(alpha: 0.3),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(cat.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${cat.earned}/${cat.requiredCredits}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== shared empty state ====================

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded,
              size: 18,
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

// ========================================================================
// Private helper widgets & data classes
// ========================================================================

/// Circular GPA progress painter.
class _GpaCirclePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _GpaCirclePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 6;
    const strokeWidth = 8.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GpaCirclePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Row showing a GPA-related metric.
class _GpaInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _GpaInfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Expandable grade item tile.
class _GradeExpansionTile extends StatelessWidget {
  final Grade grade;
  final bool isFirst;
  final bool isLast;

  const _GradeExpansionTile({
    required this.grade,
    required this.isFirst,
    required this.isLast,
  });

  Color _scoreColor(double score) {
    if (score >= 90) return AppConstants.successColor;
    if (score >= 75) return AppConstants.primaryColor;
    if (score >= 60) return AppConstants.warningColor;
    return AppConstants.errorColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _scoreColor(grade.score);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                grade.score.toInt().toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          title: Text(
            grade.courseName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${grade.credit}学分 · 绩点 ${grade.gradePoint.toStringAsFixed(1)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.outline,
            ),
          ),
          children: [
            Row(
              children: [
                _detailChip('成绩', grade.score.toStringAsFixed(1), color, theme),
                const SizedBox(width: 8),
                _detailChip('学分', grade.credit.toStringAsFixed(1),
                    AppConstants.primaryColor, theme),
                const SizedBox(width: 8),
                _detailChip('绩点', grade.gradePoint.toStringAsFixed(1),
                    AppConstants.accentColor, theme),
                if (grade.rank != null) ...[
                  const SizedBox(width: 8),
                  _detailChip('排名', grade.rank!,
                      AppConstants.warningColor, theme),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(
      String label, String value, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateItem {
  final IconData icon;
  final String label;
  final Color color;
  const _CertificateItem(this.icon, this.label, this.color);
}

class _GraduationCategory {
  final String label;
  final int earned;
  final int requiredCredits;
  final Color color;
  const _GraduationCategory(
      this.label, this.earned, this.requiredCredits, this.color);
}
