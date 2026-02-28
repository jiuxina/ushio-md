import 'package:flutter/material.dart';

import '../../../models/language_partner.dart';
import '../../../utils/constants.dart';

/// 语伴匹配全屏页面
///
/// 使用手动实现的可滑动卡片堆栈（Stack + AnimatedPositioned）。
class LanguagePartnerScreen extends StatefulWidget {
  const LanguagePartnerScreen({super.key});

  @override
  State<LanguagePartnerScreen> createState() => _LanguagePartnerScreenState();
}

class _LanguagePartnerScreenState extends State<LanguagePartnerScreen>
    with SingleTickerProviderStateMixin {
  // Demo data
  final List<LanguagePartner> _partners = [
    LanguagePartner(
      id: '1',
      userId: 'u1',
      userName: 'Nguyen Van A',
      nativeLanguage: '🇻🇳 Tiếng Việt',
      learningLanguage: '🇨🇳 中文',
      college: '国际教育学院',
      bio: '来自河内，喜欢中国文化和美食，希望找到语伴一起练习中文。',
      interests: ['美食', '旅行', '电影'],
      createdAt: DateTime.now(),
    ),
    LanguagePartner(
      id: '2',
      userId: 'u2',
      userName: 'Somchai T.',
      nativeLanguage: '🇹🇭 ไทย',
      learningLanguage: '🇨🇳 中文',
      college: '东南亚语言文化学院',
      bio: '曼谷留学生，正在学习HSK5，喜欢旅行和摄影。',
      interests: ['摄影', 'HSK', '音乐'],
      createdAt: DateTime.now(),
    ),
    LanguagePartner(
      id: '3',
      userId: 'u3',
      userName: '李明',
      nativeLanguage: '🇨🇳 中文',
      learningLanguage: '🇹🇭 ไทย',
      college: '外国语学院',
      bio: '大三学生，辅修泰语，希望找泰国朋友练习口语。',
      interests: ['语言学习', '篮球', '动漫'],
      createdAt: DateTime.now(),
    ),
    LanguagePartner(
      id: '4',
      userId: 'u4',
      userName: 'Chanthou S.',
      nativeLanguage: '🇰🇭 ខ្មែរ',
      learningLanguage: '🇬🇧 English',
      college: '文学院',
      bio: '来自金边，热爱文学与写作，希望提升英语写作能力。',
      interests: ['写作', '阅读', '绘画'],
      createdAt: DateTime.now(),
    ),
  ];

  int _currentIndex = 0;
  double _dragOffset = 0;

  void _onSkip() {
    if (_currentIndex < _partners.length) {
      setState(() => _currentIndex++);
    }
  }

  void _onMatch() {
    if (_currentIndex < _partners.length) {
      setState(() => _currentIndex++);
    }
  }

  void _onSuperLike() {
    if (_currentIndex < _partners.length) {
      setState(() => _currentIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('语伴匹配')),
      body: Column(
        children: [
          Expanded(
            child: _currentIndex >= _partners.length
                ? _buildEmptyState(theme, cs)
                : _buildCardStack(theme, cs),
          ),
          if (_currentIndex < _partners.length)
            _buildActionButtons(theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text('暂无更多语伴推荐',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.outline,
              )),
          const SizedBox(height: 8),
          Text('稍后再来看看吧',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.outline,
              )),
        ],
      ),
    );
  }

  Widget _buildCardStack(ThemeData theme, ColorScheme cs) {
    final remaining = _partners.length - _currentIndex;
    final visibleCount = remaining.clamp(0, 3);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset.abs() > 100) {
          if (_dragOffset > 0) {
            _onMatch();
          } else {
            _onSkip();
          }
        }
        setState(() => _dragOffset = 0);
      },
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.center,
          children: List.generate(visibleCount, (stackIndex) {
            final reverseIndex = visibleCount - 1 - stackIndex;
            final partnerIndex = _currentIndex + reverseIndex;
            final isTop = reverseIndex == 0;

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: reverseIndex * 8.0,
              left: isTop ? _dragOffset : 0,
              right: isTop ? -_dragOffset : 0,
              child: Transform.scale(
                scale: 1 - reverseIndex * 0.04,
                child: Opacity(
                  opacity: 1 - reverseIndex * 0.2,
                  child: _buildPartnerCard(
                    _partners[partnerIndex],
                    theme,
                    cs,
                    showOverlay: isTop && _dragOffset.abs() > 40,
                    isRight: _dragOffset > 0,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPartnerCard(
    LanguagePartner partner,
    ThemeData theme,
    ColorScheme cs, {
    bool showOverlay = false,
    bool isRight = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: showOverlay
              ? (isRight
                  ? AppConstants.successColor.withValues(alpha: 0.6)
                  : AppConstants.errorColor.withValues(alpha: 0.6))
              : theme.dividerColor.withValues(alpha: 0.5),
          width: showOverlay ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar placeholder
          CircleAvatar(
            radius: 44,
            backgroundColor:
                AppConstants.primaryColor.withValues(alpha: 0.15),
            child: partner.userAvatar != null
                ? ClipOval(
                    child: Image.network(partner.userAvatar!,
                        width: 88, height: 88, fit: BoxFit.cover),
                  )
                : Text(
                    (partner.userName ?? '?')[0],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Name
          Text(partner.userName ?? '未知用户',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 4),

          // College
          if (partner.college != null)
            Text(partner.college!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                )),
          const SizedBox(height: 16),

          // Language flags
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _langChip(partner.nativeLanguage, theme),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded,
                  size: 16, color: cs.outline),
              const SizedBox(width: 8),
              _langChip(partner.learningLanguage, theme),
            ],
          ),
          const SizedBox(height: 16),

          // Bio
          if (partner.bio != null)
            Text(partner.bio!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.8),
                )),
          const SizedBox(height: 16),

          // Interests
          if (partner.interests.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: partner.interests.map((interest) {
                return Chip(
                  label: Text(interest),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: AppConstants.primaryColor,
                  ),
                  backgroundColor:
                      AppConstants.primaryColor.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),

          // Swipe overlay indicator
          if (showOverlay)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                isRight ? '❤️ 匹配' : '⏭ 跳过',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isRight
                      ? AppConstants.successColor
                      : AppConstants.errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _langChip(String label, ThemeData theme) {
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

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Skip
          _actionButton(
            icon: Icons.close_rounded,
            color: AppConstants.errorColor,
            size: 52,
            onTap: _onSkip,
          ),
          // Super like
          _actionButton(
            icon: Icons.star_rounded,
            color: AppConstants.warningColor,
            size: 44,
            onTap: _onSuperLike,
          ),
          // Match
          _actionButton(
            icon: Icons.favorite_rounded,
            color: AppConstants.successColor,
            size: 52,
            onTap: _onMatch,
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
