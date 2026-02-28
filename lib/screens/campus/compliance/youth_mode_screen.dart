import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../utils/constants.dart';

/// 青少年模式（防沉迷）
///
/// 提供使用时间限制、夜间锁定、内容过滤和家长密码功能。
class YouthModeScreen extends StatefulWidget {
  const YouthModeScreen({super.key});

  @override
  State<YouthModeScreen> createState() => _YouthModeScreenState();
}

class _YouthModeScreenState extends State<YouthModeScreen> {
  bool _youthModeEnabled = false;

  // 设置项
  double _dailyLimitMinutes = 120; // 默认 2 小时
  bool _nightLockEnabled = true;
  int _contentFilterLevel = 1; // 0=宽松, 1=标准, 2=严格
  String _parentPin = '';

  // 模拟用量
  final double _todayUsageMinutes = 75;

  // 关闭模式时验证 PIN
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('青少年模式')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          const SizedBox(height: 16),
          _buildToggleCard(context),
          if (_youthModeEnabled) ...[
            const SizedBox(height: 16),
            _buildUsageStatsCard(context),
            const SizedBox(height: 24),
            _buildSectionHeader(context, '使用限制'),
            const SizedBox(height: 12),
            _buildDailyLimitCard(context),
            const SizedBox(height: 8),
            _buildNightLockCard(context),
            const SizedBox(height: 24),
            _buildSectionHeader(context, '内容过滤'),
            const SizedBox(height: 12),
            _buildContentFilterCard(context),
            const SizedBox(height: 24),
            _buildSectionHeader(context, '家长密码'),
            const SizedBox(height: 12),
            _buildParentPinCard(context),
          ],
          const SizedBox(height: 32),
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

  // ==================== Toggle Card ====================

  Widget _buildToggleCard(BuildContext context) {
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppConstants.warningColor.withValues(alpha: 0.2),
                AppConstants.warningColor.withValues(alpha: 0.1),
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.child_care_rounded,
                color: AppConstants.warningColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('青少年模式',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  _youthModeEnabled ? '已开启' : '未开启',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _youthModeEnabled,
            onChanged: (v) {
              if (!v && _parentPin.isNotEmpty) {
                _showPinVerifyDialog(context);
              } else {
                setState(() => _youthModeEnabled = v);
              }
            },
            activeColor: AppConstants.primaryColor,
          ),
        ],
      ),
    );
  }

  // ==================== Usage Stats ====================

  Widget _buildUsageStatsCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = (_todayUsageMinutes / _dailyLimitMinutes).clamp(0.0, 1.0);
    final hours = (_todayUsageMinutes ~/ 60);
    final minutes = (_todayUsageMinutes % 60).toInt();

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
      child: Column(
        children: [
          Text('今日使用时长',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          const SizedBox(height: 16),
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: progress,
                backgroundColor: cs.outline.withValues(alpha: 0.15),
                progressColor: progress > 0.8
                    ? AppConstants.errorColor
                    : AppConstants.primaryColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '/ ${(_dailyLimitMinutes ~/ 60)}h',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Daily Limit ====================

  Widget _buildDailyLimitCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hours = _dailyLimitMinutes ~/ 60;
    final mins = (_dailyLimitMinutes % 60).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_rounded, size: 20, color: cs.outline),
              const SizedBox(width: 8),
              Text('每日使用时限',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                hours > 0
                    ? '${hours}小时${mins > 0 ? ' ${mins}分钟' : ''}'
                    : '${mins}分钟',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppConstants.primaryColor,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: _dailyLimitMinutes,
            min: 30,
            max: 240,
            divisions: 7,
            activeColor: AppConstants.primaryColor,
            onChanged: (v) => setState(() => _dailyLimitMinutes = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30分钟',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
              Text('4小时',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Night Lock ====================

  Widget _buildNightLockCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.nightlight_round, size: 20, color: cs.outline),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('夜间锁定',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text('22:00 - 06:00 自动锁定',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.outline)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _nightLockEnabled,
            onChanged: (v) => setState(() => _nightLockEnabled = v),
            activeColor: AppConstants.primaryColor,
          ),
        ],
      ),
    );
  }

  // ==================== Content Filter ====================

  Widget _buildContentFilterCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final levels = ['宽松', '标准', '严格'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_rounded, size: 20, color: cs.outline),
              const SizedBox(width: 8),
              Text('内容过滤等级',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(levels.length, (i) {
            return RadioListTile<int>(
              value: i,
              groupValue: _contentFilterLevel,
              onChanged: (v) =>
                  setState(() => _contentFilterLevel = v ?? 1),
              title: Text(levels[i], style: theme.textTheme.bodyMedium),
              activeColor: AppConstants.primaryColor,
              contentPadding: EdgeInsets.zero,
              dense: true,
            );
          }),
        ],
      ),
    );
  }

  // ==================== Parent PIN ====================

  Widget _buildParentPinCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pin_rounded, size: 20, color: cs.outline),
              const SizedBox(width: 8),
              Text('家长密码',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                _parentPin.isEmpty ? '未设置' : '已设置',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: _parentPin.isEmpty
                        ? AppConstants.warningColor
                        : AppConstants.successColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('设置 6 位数字密码，关闭青少年模式时需要验证。',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline)),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: InputDecoration(
              labelText: '6 位数字密码',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _pinController.text.length == 6
                  ? () {
                      setState(() => _parentPin = _pinController.text);
                      _pinController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('家长密码已设置')),
                      );
                    }
                  : null,
              child: Text(_parentPin.isEmpty ? '设置密码' : '修改密码'),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PIN Verify Dialog ====================

  void _showPinVerifyDialog(BuildContext context) {
    final verifyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('验证家长密码'),
        content: TextField(
          controller: verifyController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: InputDecoration(
            labelText: '请输入家长密码',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (verifyController.text == _parentPin) {
                Navigator.of(ctx).pop();
                setState(() => _youthModeEnabled = false);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('密码错误')),
                );
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    ).then((_) => verifyController.dispose());
  }
}

// ==================== Circular Progress Painter ====================

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  _CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor;
}
