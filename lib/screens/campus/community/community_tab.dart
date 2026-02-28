import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/community_post.dart';
import '../../../models/venue.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/campus_provider.dart';
import '../../../utils/constants.dart';

/// 社区与场馆 — Tab 4
///
/// 包含三个子标签页：校园圈、场馆预约、心理健康。
class CommunityTab extends StatefulWidget {
  const CommunityTab({super.key});

  @override
  State<CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<CommunityTab>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  bool _isMaintenance = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final campus = context.read<CampusProvider>();
    try {
      await Future.wait([
        campus.fetchCommunityPosts(),
        campus.fetchVenues(),
      ]);
    } catch (e) {
      debugPrint('CommunityTab: failed to load data: $e');
    }

    if (mounted) {
      final hasMaintenanceError =
          campus.communityPostsError == '服务维护中，请稍后再试' ||
              campus.venuesError == '服务维护中，请稍后再试';
      if (hasMaintenanceError != _isMaintenance) {
        setState(() => _isMaintenance = hasMaintenanceError);
      }
    }
  }

  // ======================== helpers ========================

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  // ======================== build ========================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        if (_isMaintenance) _buildMaintenanceBanner(theme),
        // Sub-tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: cs.onSurface,
            unselectedLabelColor: cs.outline,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: AppConstants.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: '校园圈'),
              Tab(text: '场馆预约'),
              Tab(text: '心理健康'),
            ],
          ),
        ),
        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _CampusFeedView(
                onRefresh: _loadData,
                relativeTime: _relativeTime,
              ),
              _VenueBookingView(onRefresh: _loadData),
              const _MentalHealthView(),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== maintenance banner ====================

  Widget _buildMaintenanceBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
}

// =============================================================================
// Sub-tab 1: 校园圈 (Campus Feed)
// =============================================================================

class _CampusFeedView extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final String Function(DateTime) relativeTime;

  const _CampusFeedView({
    required this.onRefresh,
    required this.relativeTime,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final campus = context.watch<CampusProvider>();

    return Stack(
      children: [
        // Feed content
        RefreshIndicator(
          onRefresh: onRefresh,
          color: AppConstants.primaryColor,
          child: _buildContent(context, theme, cs, campus),
        ),
        // FAB for new post
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'community_fab',
            onPressed: () => _showCreatePostSheet(context, theme, cs),
            backgroundColor: AppConstants.primaryColor,
            child: const Icon(Icons.edit_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    CampusProvider campus,
  ) {
    if (campus.communityPostsLoading && campus.communityPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (campus.communityPostsError != null && campus.communityPosts.isEmpty) {
      return _buildErrorState(context, theme, cs, campus.communityPostsError!);
    }

    if (campus.communityPosts.isEmpty) {
      return _buildEmptyState(theme, cs);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: campus.communityPosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildPostCard(context, theme, cs, campus.communityPosts[index]),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            '还没有动态，快来发第一条吧！',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    String error,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
          const SizedBox(height: 12),
          Text(error,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // ==================== post card ====================

  Widget _buildPostCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    CommunityPost post,
  ) {
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
          // Header: avatar, name, time
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    AppConstants.primaryColor.withValues(alpha: 0.15),
                backgroundImage: post.userAvatar != null
                    ? NetworkImage(post.userAvatar!)
                    : null,
                child: post.userAvatar == null
                    ? Text(
                        (post.userName ?? '?')[0],
                        style: const TextStyle(
                          color: AppConstants.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.userName ?? '匿名用户',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      relativeTime(post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.topic != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppConstants.accentColor.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadiusSmall),
                  ),
                  child: Text(
                    '#${post.topic}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppConstants.accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Content
          Text(post.content, style: theme.textTheme.bodyMedium),
          // Images grid
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildImagesGrid(cs, post.images),
          ],
          const SizedBox(height: 12),
          // Footer: like + comment counts
          Row(
            children: [
              Icon(Icons.favorite_border_rounded, size: 18, color: cs.outline),
              const SizedBox(width: 4),
              Text(
                '${post.likeCount}',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
              const SizedBox(width: 20),
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 18, color: cs.outline),
              const SizedBox(width: 4),
              Text(
                '${post.commentCount}',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagesGrid(ColorScheme cs, List<String> images) {
    final count = images.length.clamp(0, 9);
    final crossAxisCount = count == 1
        ? 1
        : count <= 4
            ? 2
            : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: count,
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
        child: Container(
          color: cs.surfaceContainerHighest,
          child: Image.network(
            images[i],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(Icons.image_outlined, color: cs.outline, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== create post bottom sheet ====================

  void _showCreatePostSheet(
      BuildContext context, ThemeData theme, ColorScheme cs) {
    final contentController = TextEditingController();
    String? selectedTopic;
    const topics = ['学习', '生活', '吐槽', '求助', '活动', '二手'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
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
                  const SizedBox(height: 16),
                  Text(
                    '发布动态',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Text area
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: '分享你的校园生活…',
                      hintStyle:
                          TextStyle(color: cs.outline.withValues(alpha: 0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusSmall),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusSmall),
                        borderSide: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Image add row
                  Row(
                    children: [
                      _GlassActionChip(
                        icon: Icons.image_outlined,
                        label: '图片',
                        onTap: () {
                          // TODO: pick images
                        },
                      ),
                      const SizedBox(width: 8),
                      _GlassActionChip(
                        icon: Icons.camera_alt_outlined,
                        label: '拍照',
                        onTap: () {
                          // TODO: open camera
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Topic selector chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: topics.map((t) {
                      final isSelected = selectedTopic == t;
                      return ChoiceChip(
                        label: Text(t),
                        selected: isSelected,
                        selectedColor:
                            AppConstants.primaryColor.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppConstants.primaryColor
                              : cs.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppConstants.primaryColor
                                  .withValues(alpha: 0.4)
                              : theme.dividerColor.withValues(alpha: 0.5),
                        ),
                        onSelected: (v) {
                          setSheetState(
                              () => selectedTopic = v ? t : null);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final text = contentController.text.trim();
                        if (text.isEmpty) return;
                        final auth = context.read<AuthProvider>();
                        final campus = context.read<CampusProvider>();
                        campus.createCommunityPost({
                          'user_id': auth.currentUser?.id ?? '',
                          'user_name': auth.currentUser?.name ?? '匿名用户',
                          'content': text,
                          'topic': selectedTopic,
                          'images': <String>[],
                        });
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.borderRadius),
                        ),
                      ),
                      child: const Text('发布',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// Sub-tab 2: 场馆预约 (Venue Booking)
// =============================================================================

class _VenueBookingView extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _VenueBookingView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final campus = context.watch<CampusProvider>();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppConstants.primaryColor,
      child: _buildContent(context, theme, cs, campus),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    CampusProvider campus,
  ) {
    if (campus.venuesLoading && campus.venues.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (campus.venuesError != null && campus.venues.isEmpty) {
      return _buildErrorState(theme, cs, campus.venuesError!);
    }

    if (campus.venues.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stadium_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              '暂无可用场馆',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: campus.venues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildVenueCard(context, theme, cs, campus.venues[index]),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme cs, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
          const SizedBox(height: 12),
          Text(error,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // ==================== venue card ====================

  Widget _buildVenueCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Venue venue,
  ) {
    final venueIconMap = <String, IconData>{
      '羽毛球': Icons.sports_tennis_rounded,
      '篮球': Icons.sports_basketball_rounded,
      '自习室': Icons.menu_book_rounded,
      '会议室': Icons.meeting_room_rounded,
      '游泳': Icons.pool_rounded,
      '健身': Icons.fitness_center_rounded,
    };
    final venueColorMap = <String, Color>{
      '羽毛球': const Color(0xFF22C55E),
      '篮球': const Color(0xFFF97316),
      '自习室': const Color(0xFF6366F1),
      '会议室': const Color(0xFF3B82F6),
      '游泳': const Color(0xFF06B6D4),
      '健身': const Color(0xFFEF4444),
    };
    final icon = venueIconMap[venue.type] ?? Icons.place_rounded;
    final color = venueColorMap[venue.type] ?? AppConstants.primaryColor;

    return GestureDetector(
      onTap: venue.isAvailable
          ? () => _showBookingSheet(context, theme, cs, venue)
          : null,
      child: Container(
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
          children: [
            // Image placeholder
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.25),
                    color.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          venue.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: venue.isAvailable
                              ? AppConstants.successColor
                                  .withValues(alpha: 0.12)
                              : AppConstants.errorColor
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                              AppConstants.borderRadiusSmall),
                        ),
                        child: Text(
                          venue.isAvailable ? '可预约' : '不可用',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: venue.isAvailable
                                ? AppConstants.successColor
                                : AppConstants.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          venue.type,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.location_on_outlined,
                          size: 14, color: cs.outline),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          venue.location,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 14, color: cs.outline),
                      const SizedBox(width: 4),
                      Text(
                        '容纳 ${venue.capacity} 人',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== booking bottom sheet ====================

  void _showBookingSheet(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Venue venue,
  ) {
    DateTime selectedDate = DateTime.now();
    String? selectedSlot;
    const timeSlots = [
      '08:00-10:00',
      '10:00-12:00',
      '14:00-16:00',
      '16:00-18:00',
      '19:00-21:00',
    ];
    const slotLabels = ['上午 1', '上午 2', '下午 1', '下午 2', '晚间'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
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
                  const SizedBox(height: 16),
                  Text(
                    '预约 ${venue.name}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date picker
                  Text('选择日期',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 14)),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(
                            AppConstants.borderRadiusSmall),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            '${selectedDate.year}年${selectedDate.month}月${selectedDate.day}日',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: cs.outline),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Time slot grid
                  Text('选择时段',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(timeSlots.length, (i) {
                      final isSelected = selectedSlot == timeSlots[i];
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() => selectedSlot = timeSlots[i]);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppConstants.primaryColor
                                    .withValues(alpha: 0.15)
                                : cs.surface.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(
                                AppConstants.borderRadiusSmall),
                            border: Border.all(
                              color: isSelected
                                  ? AppConstants.primaryColor
                                      .withValues(alpha: 0.5)
                                  : theme.dividerColor
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                slotLabels[i],
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isSelected
                                      ? AppConstants.primaryColor
                                      : cs.outline,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                timeSlots[i],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isSelected
                                      ? AppConstants.primaryColor
                                      : cs.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  // Violation record notice
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          AppConstants.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                          AppConstants.borderRadiusSmall),
                      border: Border.all(
                        color: AppConstants.warningColor
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: AppConstants.warningColor),
                        const SizedBox(width: 8),
                        Text(
                          '违约次数: 0，信用分: 100',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppConstants.warningColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedSlot == null
                          ? null
                          : () {
                              final auth = context.read<AuthProvider>();
                              final campus =
                                  context.read<CampusProvider>();
                              campus.bookVenue({
                                'user_id': auth.currentUser?.id ?? '',
                                'venue_id': venue.id,
                                'date':
                                    selectedDate.toIso8601String(),
                                'time_slot': selectedSlot,
                                'status': 'pending',
                              });
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('预约提交成功'),
                                  backgroundColor:
                                      AppConstants.successColor,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            cs.outline.withValues(alpha: 0.2),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppConstants.borderRadius),
                        ),
                      ),
                      child: const Text('确认预约',
                          style:
                              TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// Sub-tab 3: 心理健康 (Mental Health)
// =============================================================================

class _MentalHealthView extends StatefulWidget {
  const _MentalHealthView();

  @override
  State<_MentalHealthView> createState() => _MentalHealthViewState();
}

class _MentalHealthViewState extends State<_MentalHealthView> {
  int? _selectedMoodIndex;
  bool _checkedIn = false;

  static const _moods = [
    ('😊', '开心'),
    ('😐', '平静'),
    ('😔', '低落'),
    ('😰', '焦虑'),
    ('😢', '难过'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        _buildMoodCheckIn(theme, cs),
        const SizedBox(height: 16),
        _buildMoodWaveChart(theme, cs),
        const SizedBox(height: 16),
        _buildResourcesSection(theme, cs),
      ],
    );
  }

  // ==================== mood check-in ====================

  Widget _buildMoodCheckIn(ThemeData theme, ColorScheme cs) {
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
                      AppConstants.primaryColor.withValues(alpha: 0.2),
                      AppConstants.primaryColor.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_emotions_outlined,
                    color: AppConstants.primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '今日心情',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_checkedIn)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        AppConstants.successColor.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadiusSmall),
                  ),
                  child: Text(
                    '今日已打卡',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppConstants.successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_moods.length, (i) {
              final isSelected = _selectedMoodIndex == i;
              return GestureDetector(
                onTap: _checkedIn
                    ? null
                    : () {
                        setState(() {
                          _selectedMoodIndex = i;
                          _checkedIn = true;
                        });
                      },
                child: AnimatedContainer(
                  duration: AppConstants.animationDuration,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppConstants.primaryColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: AppConstants.primaryColor
                                .withValues(alpha: 0.4),
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(_moods[i].$1, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(
                        _moods[i].$2,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? AppConstants.primaryColor
                              : cs.outline,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ==================== mood wave chart placeholder ====================

  Widget _buildMoodWaveChart(ThemeData theme, ColorScheme cs) {
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
                      AppConstants.accentColor.withValues(alpha: 0.2),
                      AppConstants.accentColor.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.waves_rounded,
                    color: AppConstants.accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '情绪波浪图',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
              painter: _WavePainter(
                color: AppConstants.accentColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '最近7天情绪趋势',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== resources section ====================

  Widget _buildResourcesSection(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            '心理资源',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 心理咨询预约
        _buildResourceCard(
          theme: theme,
          cs: cs,
          icon: Icons.phone_in_talk_rounded,
          iconColor: AppConstants.primaryColor,
          title: '心理咨询预约',
          subtitle: '预约专业心理咨询师',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        // 24小时心理热线 (prominent)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppConstants.primaryColor.withValues(alpha: 0.15),
                AppConstants.accentColor.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppConstants.primaryColor.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppConstants.primaryColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryColor.withValues(alpha: 0.25),
                      AppConstants.primaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.call_rounded,
                    color: AppConstants.primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '24小时心理热线',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '400-161-9995',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppConstants.primaryColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '全国心理援助热线，随时倾听',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // AI助手入口
        _buildResourceCard(
          theme: theme,
          cs: cs,
          icon: Icons.smart_toy_outlined,
          iconColor: AppConstants.accentColor,
          title: 'AI 心理助手',
          subtitle: '智能对话，倾诉烦恼',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildResourceCard({
    required ThemeData theme,
    required ColorScheme cs,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    iconColor.withValues(alpha: 0.2),
                    iconColor.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: cs.outline),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shared widgets
// =============================================================================

/// Small glass action chip for the create-post sheet.
class _GlassActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GlassActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: cs.outline),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative wave line painter for the mood chart placeholder.
class _WavePainter extends CustomPainter {
  final Color color;

  _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final w = size.width;
    final h = size.height;
    final mid = h * 0.5;

    path.moveTo(0, mid);
    fillPath.moveTo(0, h);
    fillPath.lineTo(0, mid);

    // Draw a smooth wave across the width
    const segments = 7;
    final segW = w / segments;
    for (int i = 0; i < segments; i++) {
      final x1 = segW * i + segW * 0.5;
      final y1 = mid + (i.isEven ? -1 : 1) * (15 + (i * 3 % 12));
      final x2 = segW * (i + 1);
      final y2 = mid + ((i + 1) % 3 == 0 ? -8 : 8);
      path.quadraticBezierTo(x1, y1, x2, y2);
      fillPath.quadraticBezierTo(x1, y1, x2, y2);
    }

    fillPath.lineTo(w, h);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.color != color;
}
