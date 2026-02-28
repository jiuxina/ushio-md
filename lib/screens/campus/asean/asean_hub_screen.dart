import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

/// 民大东盟与民族特色专区 — Module 11
///
/// 包含三个子标签页：多语种服务、留学生服务、民族文化。
class AseanHubScreen extends StatefulWidget {
  const AseanHubScreen({super.key});

  @override
  State<AseanHubScreen> createState() => _AseanHubScreenState();
}

class _AseanHubScreenState extends State<AseanHubScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('民大东盟与民族特色专区'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadius),
              ),
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: '多语种服务'),
                Tab(text: '留学生服务'),
                Tab(text: '民族文化'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MultilingualServicesTab(),
          _InternationalStudentTab(),
          _EthnicCultureTab(),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 1: 多语种服务 (Multilingual Services)
// =============================================================================

class _MultilingualServicesTab extends StatefulWidget {
  const _MultilingualServicesTab();

  @override
  State<_MultilingualServicesTab> createState() =>
      _MultilingualServicesTabState();
}

class _MultilingualServicesTabState extends State<_MultilingualServicesTab> {
  int _selectedLanguageIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  static const _languages = [
    {'flag': '🇨🇳', 'label': '中文'},
    {'flag': '🇹🇭', 'label': 'ไทย'},
    {'flag': '🇻🇳', 'label': 'Tiếng Việt'},
    {'flag': '🇱🇦', 'label': 'ລາວ'},
    {'flag': '🇰🇭', 'label': 'ខ្មែរ'},
    {'flag': '🇬🇧', 'label': 'English'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Language selector grid
        Text('选择语言', style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemCount: _languages.length,
          itemBuilder: (context, index) {
            final lang = _languages[index];
            final selected = _selectedLanguageIndex == index;
            return GestureDetector(
              onTap: () => setState(() => _selectedLanguageIndex = index),
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? AppConstants.primaryColor.withValues(alpha: 0.15)
                      : cs.surface.withValues(alpha: 0.7),
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius),
                  border: Border.all(
                    color: selected
                        ? AppConstants.primaryColor
                        : theme.dividerColor.withValues(alpha: 0.5),
                    width: selected ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      lang['label']!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? AppConstants.primaryColor
                            : cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Translation dictionary
        Text('翻译词典', style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '输入关键词搜索...',
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.borderRadius),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Sample word card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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
              Text('你好', style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              )),
              const Divider(),
              _buildTranslationRow('🇹🇭', 'สวัสดี', theme),
              _buildTranslationRow('🇻🇳', 'Xin chào', theme),
              _buildTranslationRow('🇱🇦', 'ສະບາຍດີ', theme),
              _buildTranslationRow('🇰🇭', 'សួស្តី', theme),
              _buildTranslationRow('🇬🇧', 'Hello', theme),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Floating translation placeholder
        Text('悬浮翻译', style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConstants.accentColor.withValues(alpha: 0.15),
                AppConstants.primaryColor.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(
              color: AppConstants.accentColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.translate_rounded,
                  size: 32, color: AppConstants.accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('悬浮翻译窗口',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      '开启后可在任意页面悬浮显示实时翻译结果，方便跨语言交流',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTranslationRow(String flag, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 2: 留学生服务 (International Student Services)
// =============================================================================

class _InternationalStudentTab extends StatefulWidget {
  const _InternationalStudentTab();

  @override
  State<_InternationalStudentTab> createState() =>
      _InternationalStudentTabState();
}

class _InternationalStudentTabState extends State<_InternationalStudentTab> {
  int _currentPartnerIndex = 0;

  // Demo partner data
  static const _demoPartners = [
    {
      'name': 'Nguyen Van A',
      'native': '🇻🇳 Tiếng Việt',
      'learning': '🇨🇳 中文',
      'college': '国际教育学院',
      'bio': '来自河内，喜欢中国文化和美食，希望找到语伴一起练习中文。',
    },
    {
      'name': 'Somchai T.',
      'native': '🇹🇭 ไทย',
      'learning': '🇨🇳 中文',
      'college': '东南亚语言文化学院',
      'bio': '曼谷留学生，正在学习HSK5，喜欢旅行和摄影。',
    },
    {
      'name': '李明',
      'native': '🇨🇳 中文',
      'learning': '🇹🇭 ไทย',
      'college': '外国语学院',
      'bio': '大三学生，辅修泰语，希望找泰国朋友练习口语。',
    },
  ];

  static const _bilingualGuides = [
    {'zh': '签证延期', 'en': 'Visa Extension', 'icon': Icons.badge_outlined},
    {
      'zh': '住宿登记',
      'en': 'Housing Registration',
      'icon': Icons.hotel_outlined,
    },
    {
      'zh': '奖学金申请',
      'en': 'Scholarship Application',
      'icon': Icons.school_outlined,
    },
    {
      'zh': '保险办理',
      'en': 'Insurance Processing',
      'icon': Icons.health_and_safety_outlined,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Visa countdown card
        _buildVisaCountdownCard(theme, cs),
        const SizedBox(height: 24),

        // Bilingual guide
        Text('双语服务指南', style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        ..._bilingualGuides.map((item) => _buildBilingualItem(
              item['zh'] as String,
              item['en'] as String,
              item['icon'] as IconData,
              theme,
              cs,
            )),
        const SizedBox(height: 24),

        // Language partner cards
        Text('语伴匹配', style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 4),
        Text(
          '找到志同道合的语言学习伙伴',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
        ),
        const SizedBox(height: 12),
        _buildPartnerCard(theme, cs),
        const SizedBox(height: 12),
        _buildPartnerButtons(theme),
      ],
    );
  }

  Widget _buildVisaCountdownCard(ThemeData theme, ColorScheme cs) {
    // Demo: 23 days remaining → warning state
    const daysRemaining = 23;
    final isWarning = daysRemaining < 30;
    final accentColor =
        isWarning ? AppConstants.errorColor : AppConstants.successColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(color: accentColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: accentColor),
              const SizedBox(width: 8),
              Text('签证到期倒计时',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
              const Spacer(),
              if (isWarning)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.errorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('⚠️ 即将到期',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppConstants.errorColor,
                        fontWeight: FontWeight.w600,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$daysRemaining',
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          Text('天', style: theme.textTheme.titleMedium?.copyWith(
            color: accentColor,
          )),
          const SizedBox(height: 8),
          Text(
            '请尽快办理签证延期手续',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildBilingualItem(
    String zh,
    String en,
    IconData icon,
    ThemeData theme,
    ColorScheme cs,
  ) {
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppConstants.primaryColor.withValues(alpha: 0.2),
                      AppConstants.primaryColor.withValues(alpha: 0.1),
                    ]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppConstants.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zh,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      Text(en,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.outline,
                          )),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerCard(ThemeData theme, ColorScheme cs) {
    if (_currentPartnerIndex >= _demoPartners.length) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('暂无更多语伴推荐',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.outline,
                )),
          ],
        ),
      );
    }

    final partner = _demoPartners[_currentPartnerIndex];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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
          CircleAvatar(
            radius: 36,
            backgroundColor:
                AppConstants.primaryColor.withValues(alpha: 0.15),
            child: Text(
              partner['name']![0],
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppConstants.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(partner['name']!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),
          Text(partner['college']!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.outline,
              )),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLangChip(partner['native']!, theme, cs),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 16, color: cs.outline),
              const SizedBox(width: 8),
              _buildLangChip(partner['learning']!, theme, cs),
            ],
          ),
          const SizedBox(height: 12),
          Text(partner['bio']!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.8),
              )),
        ],
      ),
    );
  }

  Widget _buildLangChip(String label, ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppConstants.primaryColor,
          )),
    );
  }

  Widget _buildPartnerButtons(ThemeData theme) {
    final exhausted = _currentPartnerIndex >= _demoPartners.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircleButton(
          icon: Icons.close_rounded,
          color: AppConstants.errorColor,
          label: '跳过 ⏭',
          onTap: exhausted
              ? null
              : () => setState(() => _currentPartnerIndex++),
          theme: theme,
        ),
        const SizedBox(width: 32),
        _buildCircleButton(
          icon: Icons.favorite_rounded,
          color: AppConstants.successColor,
          label: '匹配 ❤️',
          onTap: exhausted
              ? null
              : () => setState(() => _currentPartnerIndex++),
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback? onTap,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: onTap != null
                  ? color.withValues(alpha: 0.15)
                  : theme.disabledColor.withValues(alpha: 0.1),
              border: Border.all(
                color: onTap != null
                    ? color.withValues(alpha: 0.5)
                    : theme.disabledColor.withValues(alpha: 0.3),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon,
                color: onTap != null ? color : theme.disabledColor,
                size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onTap != null
                  ? color
                  : theme.disabledColor,
            )),
      ],
    );
  }
}

// =============================================================================
// Tab 3: 民族文化 (Ethnic Culture Space)
// =============================================================================

class _EthnicCultureTab extends StatelessWidget {
  const _EthnicCultureTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Festival map section
        Text('民族节日地图', style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        _buildFestivalMap(theme, cs),
        const SizedBox(height: 24),

        // Sutuo credits section
        Text('素拓分明细', style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        _buildSutuoCredits(theme, cs),
        const SizedBox(height: 24),

        // AR costume try-on
        Text('民族服饰体验', style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        _buildArCostume(theme, cs),
      ],
    );
  }

  Widget _buildFestivalMap(ThemeData theme, ColorScheme cs) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.successColor.withValues(alpha: 0.15),
            AppConstants.accentColor.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: AppConstants.successColor.withValues(alpha: 0.3),
        ),
      ),
      child: Stack(
        children: [
          // Map grid lines for visual effect
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter(cs.outline)),
          ),
          // Festival markers
          Positioned(
            left: 40,
            top: 50,
            child: _buildFestivalMarker('🎋', '三月三', theme),
          ),
          Positioned(
            right: 60,
            bottom: 50,
            child: _buildFestivalMarker('🎵', '歌圩节', theme),
          ),
          // Map label
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('广西民族节日分布',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.outline,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFestivalMarker(
      String emoji, String label, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppConstants.warningColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppConstants.warningColor.withValues(alpha: 0.6),
            ),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  Widget _buildSutuoCredits(ThemeData theme, ColorScheme cs) {
    const totalCredits = 12.5;
    const activities = [
      {'name': '三月三文化节志愿者', 'credits': 3.0},
      {'name': '东盟文化交流周', 'credits': 2.5},
      {'name': '壮族歌舞表演', 'credits': 2.0},
      {'name': '国际美食文化节', 'credits': 2.5},
      {'name': '民族手工艺工坊', 'credits': 2.5},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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
              Icon(Icons.stars_rounded, color: AppConstants.warningColor),
              const SizedBox(width: 8),
              Text('累计素拓分',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
              const Spacer(),
              Text('$totalCredits',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.warningColor,
                  )),
            ],
          ),
          const Divider(height: 24),
          ...activities.map((a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 18,
                        color: AppConstants.successColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a['name'] as String,
                          style: theme.textTheme.bodyMedium),
                    ),
                    Text('+${a['credits']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppConstants.successColor,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildArCostume(ThemeData theme, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppConstants.primaryColor.withValues(alpha: 0.10),
            AppConstants.accentColor.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: AppConstants.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.camera_alt_rounded,
                size: 36, color: AppConstants.primaryColor),
          ),
          const SizedBox(height: 16),
          Text('民族服饰 AR 试穿',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text(
            '体验壮族、苗族、瑶族等民族传统服饰',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('开始体验'),
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text('需要摄像头权限',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.outline,
              )),
        ],
      ),
    );
  }
}

// =============================================================================
// Custom painter for the festival map grid
// =============================================================================

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      color != oldDelegate.color;
}
