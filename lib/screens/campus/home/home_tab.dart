import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/announcement.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/campus_provider.dart';
import '../../../utils/constants.dart';

/// 首页看板 — Tab 1
///
/// 包含问候栏、动态业务卡片、快捷服务、今日摘要和公告列表。
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _isMaintenance = false;

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
        campus.fetchAnnouncements(),
        if (userId.isNotEmpty) campus.fetchCourses(userId),
      ]);
    } catch (e) {
      debugPrint('HomeTab: failed to load data: $e');
    }

    // Detect maintenance state from error messages
    if (mounted) {
      final hasMaintenanceError =
          campus.announcementsError == '服务维护中，请稍后再试' ||
              campus.coursesError == '服务维护中，请稍后再试';
      if (hasMaintenanceError != _isMaintenance) {
        setState(() => _isMaintenance = hasMaintenanceError);
      }
    }
  }

  // ======================== helpers ========================

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '早上好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  /// Period → time-of-day string (based on common 45-min periods).
  String _periodToTime(int period) {
    const times = [
      '08:00',
      '08:55',
      '10:00',
      '10:55',
      '14:00',
      '14:55',
      '16:00',
      '16:55',
      '19:00',
      '19:55',
      '20:50',
    ];
    if (period >= 1 && period <= times.length) return times[period - 1];
    return '--:--';
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
          _buildTopBar(theme, cs),
          const SizedBox(height: 20),
          _buildSearchBar(theme, cs),
          const SizedBox(height: 20),
          _buildBusinessCards(theme, cs),
          const SizedBox(height: 24),
          _buildQuickServices(theme, cs),
          const SizedBox(height: 24),
          _buildTodaySummary(theme, cs),
          const SizedBox(height: 24),
          _buildAnnouncementsSection(theme, cs),
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

  // ==================== top bar ====================

  Widget _buildTopBar(ThemeData theme, ColorScheme cs) {
    final auth = context.watch<AuthProvider>();
    final name = auth.currentUser?.name ?? '同学';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}，$name',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '相思同行 · 今天也要加油哦',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                ),
              ),
            ],
          ),
        ),
        // Notification bell
        _GlassIconButton(
          icon: Icons.notifications_outlined,
          badgeCount: 3,
          onTap: () {},
        ),
      ],
    );
  }

  // ==================== search bar ====================

  Widget _buildSearchBar(ThemeData theme, ColorScheme cs) {
    return GestureDetector(
      onTap: () {
        // TODO: open search overlay
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: cs.outline, size: 20),
            const SizedBox(width: 10),
            Text(
              '搜索课程、服务、公告…',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== business cards ====================

  Widget _buildBusinessCards(ThemeData theme, ColorScheme cs) {
    final campus = context.watch<CampusProvider>();

    // Find next course for today
    final today = DateTime.now().weekday; // 1-7
    final todayCourses = campus.courses
        .where((c) => c.dayOfWeek == today)
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

    return SizedBox(
      height: 156,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        children: [
          // 校车实况
          _BusinessCard(
            width: 180,
            icon: Icons.directions_bus_rounded,
            iconColor: AppConstants.errorColor,
            gradientColors: [
              AppConstants.errorColor.withValues(alpha: 0.12),
              AppConstants.errorColor.withValues(alpha: 0.04),
            ],
            label: '校车实况',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '相思湖 ↔ 武鸣',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '12',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.errorColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'min',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppConstants.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () {},
          ),
          const SizedBox(width: 12),

          // 下一节课
          _BusinessCard(
            width: 180,
            icon: Icons.menu_book_rounded,
            iconColor: AppConstants.primaryColor,
            gradientColors: [
              AppConstants.primaryColor.withValues(alpha: 0.12),
              AppConstants.primaryColor.withValues(alpha: 0.04),
            ],
            label: '下一节课',
            child: todayCourses.isNotEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todayCourses.first.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_periodToTime(todayCourses.first.startPeriod)}  ${todayCourses.first.location}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.outline,
                        ),
                      ),
                    ],
                  )
                : Text(
                    '今日无课 🎉',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.outline,
                    ),
                  ),
            onTap: () {},
          ),
          const SizedBox(width: 12),

          // 校园卡余额
          _BusinessCard(
            width: 180,
            icon: Icons.credit_card_rounded,
            iconColor: AppConstants.successColor,
            gradientColors: [
              AppConstants.successColor.withValues(alpha: 0.12),
              AppConstants.successColor.withValues(alpha: 0.04),
            ],
            label: '校园卡余额',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '¥',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppConstants.successColor,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '128.50',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.successColor,
                  ),
                ),
              ],
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ==================== quick services ====================

  Widget _buildQuickServices(ThemeData theme, ColorScheme cs) {
    final items = <_QuickServiceItem>[
      _QuickServiceItem(Icons.event_note_rounded, '请假',
          AppConstants.primaryColor),
      _QuickServiceItem(Icons.build_rounded, '报修',
          AppConstants.warningColor),
      _QuickServiceItem(Icons.payment_rounded, '缴费',
          AppConstants.successColor),
      _QuickServiceItem(Icons.stadium_rounded, '场馆',
          AppConstants.accentColor),
      _QuickServiceItem(Icons.calendar_today_rounded, '课表',
          AppConstants.primaryColor),
      _QuickServiceItem(Icons.assessment_rounded, '成绩',
          const Color(0xFFEC4899)),
      _QuickServiceItem(Icons.local_library_rounded, '图书馆',
          const Color(0xFF8B5CF6)),
      _QuickServiceItem(Icons.more_horiz_rounded, '更多',
          AppConstants.lightTextSecondary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快捷服务',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 0,
            childAspectRatio: 1.1,
            children: items.map((item) {
              return GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            item.color.withValues(alpha: 0.18),
                            item.color.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                            AppConstants.borderRadius),
                      ),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==================== today summary ====================

  Widget _buildTodaySummary(ThemeData theme, ColorScheme cs) {
    final campus = context.watch<CampusProvider>();
    final today = DateTime.now().weekday;
    final todayCourses = campus.courses
        .where((c) => c.dayOfWeek == today)
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日概览',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // 今日课程
        _SummaryCard(
          icon: Icons.school_rounded,
          iconColor: AppConstants.primaryColor,
          title: '今日课程',
          trailing: todayCourses.isNotEmpty
              ? '${todayCourses.length} 节'
              : null,
          child: todayCourses.isNotEmpty
              ? Column(
                  children: todayCourses.map((c) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 28,
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${_periodToTime(c.startPeriod)}-${_periodToTime(c.endPeriod)}  ${c.location}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : _emptyState('暂无课程安排'),
        ),
        const SizedBox(height: 10),
        // 考试倒计时
        _SummaryCard(
          icon: Icons.timer_rounded,
          iconColor: AppConstants.warningColor,
          title: '考试倒计时',
          child: _emptyState('暂无数据'),
        ),
      ],
    );
  }

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.inbox_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6)),
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

  // ==================== announcements ====================

  Widget _buildAnnouncementsSection(ThemeData theme, ColorScheme cs) {
    final campus = context.watch<CampusProvider>();
    final items = campus.announcements.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '最新公告',
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
                '查看更多',
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (campus.announcementsLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (items.isEmpty)
          Center(child: _emptyState('暂无公告'))
        else
          ...items.map((a) => _buildAnnouncementItem(a, theme, cs)),
      ],
    );
  }

  Widget _buildAnnouncementItem(
      Announcement a, ThemeData theme, ColorScheme cs) {
    final categoryColor = switch (a.category) {
      '教务' => AppConstants.primaryColor,
      '活动' => AppConstants.successColor,
      '安全' => AppConstants.errorColor,
      _ => AppConstants.warningColor,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (a.isImportant)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.push_pin_rounded,
                        size: 16, color: AppConstants.errorColor),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              a.department,
                              style: TextStyle(
                                fontSize: 10,
                                color: categoryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _relativeTime(a.publishedAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========================================================================
// Private helper widgets
// ========================================================================

/// Glass-style icon button with optional badge dot.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 22, color: cs.onSurface),
            if (badgeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppConstants.errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal-scroll business card with glassmorphism style.
class _BusinessCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final String label;
  final Widget child;
  final VoidCallback onTap;

  const _BusinessCard({
    required this.width,
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.label,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surface.withValues(alpha: 0.85),
              ...gradientColors,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor.withValues(alpha: 0.25),
                        iconColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            child,
          ],
        ),
      ),
    );
  }
}

/// Summary card used in the "今日概览" section.
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailing;
  final Widget child;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.2),
                      iconColor.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                Text(
                  trailing!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _QuickServiceItem {
  final IconData icon;
  final String label;
  final Color color;
  const _QuickServiceItem(this.icon, this.label, this.color);
}
