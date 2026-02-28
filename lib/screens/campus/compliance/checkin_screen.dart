import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../utils/constants.dart';

/// 每日签到与积分奖励
///
/// 包含月历签到视图、签到按钮动画、连续签到计数和奖励列表。
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with TickerProviderStateMixin {
  // 模拟签到数据
  final Set<int> _checkedDays = {1, 2, 3, 5, 6, 7, 8, 12, 13, 14};
  bool _todayChecked = false;
  int _streak = 3;
  int _totalCoins = 86;

  // 金币掉落动画
  late AnimationController _coinAnimController;
  bool _showCoinAnimation = false;

  @override
  void initState() {
    super.initState();
    _coinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _coinAnimController.dispose();
    super.dispose();
  }

  void _doCheckin() {
    if (_todayChecked) return;
    setState(() {
      _todayChecked = true;
      _checkedDays.add(DateTime.now().day);
      _streak++;
      _totalCoins += 2;
      _showCoinAnimation = true;
    });
    _coinAnimController.forward(from: 0).then((_) {
      if (mounted) setState(() => _showCoinAnimation = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('每日签到')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: [
              const SizedBox(height: 16),
              _buildStreakCard(context),
              const SizedBox(height: 16),
              _buildCalendar(context),
              const SizedBox(height: 24),
              _buildCheckinButton(context),
              const SizedBox(height: 24),
              _buildSectionHeader(context, '积分奖励'),
              const SizedBox(height: 12),
              _buildPiggyBank(context),
              const SizedBox(height: 12),
              _buildRewardsList(context),
              const SizedBox(height: 32),
            ],
          ),
          if (_showCoinAnimation) _buildCoinDropAnimation(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  // ==================== Streak Card ====================

  Widget _buildStreakCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Text(
            '连续签到 $_streak 天',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppConstants.warningColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Calendar ====================

  Widget _buildCalendar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun

    const weekLabels = ['日', '一', '二', '三', '四', '五', '六'];

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Text(
            '${now.year}年${now.month}月',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Week headers
          Row(
            children: weekLabels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(l,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.outline)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final day = index - startWeekday + 1;
              final isToday = day == now.day;
              final isChecked = _checkedDays.contains(day);

              return Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? AppConstants.primaryColor.withValues(alpha: 0.15)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(
                          color:
                              AppConstants.primaryColor.withValues(alpha: 0.5))
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isToday ? FontWeight.bold : null,
                        color: isToday
                            ? AppConstants.primaryColor
                            : cs.onSurface,
                      ),
                    ),
                    if (isChecked)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: const BoxDecoration(
                          color: AppConstants.warningColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== Checkin Button ====================

  Widget _buildCheckinButton(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: GestureDetector(
        onTap: _doCheckin,
        child: AnimatedContainer(
          duration: AppConstants.animationDuration,
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _todayChecked
                  ? [Colors.grey.shade400, Colors.grey.shade500]
                  : [AppConstants.primaryColor, AppConstants.primaryDark],
            ),
            boxShadow: [
              if (!_todayChecked)
                BoxShadow(
                  color: AppConstants.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Center(
            child: Text(
              _todayChecked ? '已签到' : '签到',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== Coin Drop Animation ====================

  Widget _buildCoinDropAnimation(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final random = math.Random(42);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _coinAnimController,
        builder: (context, _) {
          return Stack(
            children: List.generate(8, (i) {
              final x = random.nextDouble() * size.width;
              final startY = -40.0;
              final endY = size.height * 0.6;
              final y = startY +
                  (endY - startY) * _coinAnimController.value;
              final rotation =
                  _coinAnimController.value * math.pi * (2 + i * 0.5);
              final opacity =
                  (1.0 - _coinAnimController.value).clamp(0.0, 1.0);

              return Positioned(
                left: x,
                top: y + i * 30,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: rotation,
                    child: const Icon(
                      Icons.monetization_on_rounded,
                      color: AppConstants.warningColor,
                      size: 28,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // ==================== Piggy Bank ====================

  Widget _buildPiggyBank(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings_rounded,
              size: 48, color: AppConstants.warningColor),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('累计积分',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
              Text(
                '$_totalCoins',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppConstants.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Rewards List ====================

  Widget _buildRewardsList(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final rewards = <MapEntry<String, String>>[
      const MapEntry('7天连签', '10 积分'),
      const MapEntry('30天连签', '50 积分'),
      const MapEntry('100天连签', '200 积分'),
      const MapEntry('365天连签', '1000 积分'),
    ];

    return Container(
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
      child: Column(
        children: [
          ...rewards.map((r) => ListTile(
                leading:
                    Icon(Icons.card_giftcard_rounded, color: cs.outline),
                title: Text(r.key, style: theme.textTheme.bodyMedium),
                trailing: Text(r.value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppConstants.warningColor,
                      fontWeight: FontWeight.w600,
                    )),
              )),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.storefront_rounded,
                color: AppConstants.primaryColor),
            title: Text('积分商城',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
