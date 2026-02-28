import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../utils/constants.dart';

/// 账号注销流程
///
/// 使用 Stepper 组件引导用户完成四步注销流程：
/// 安全验证 → 资产清算 → 注销申请 → 倒计时确认
class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  int _currentStep = 0;

  // Step 1
  final _passwordController = TextEditingController();
  bool _passwordVerified = false;
  bool _obscurePassword = true;

  // Step 2
  bool _confirmedCardBalance = false;
  bool _confirmedCredits = false;
  bool _confirmedSubscriptions = false;

  // Step 3
  bool _acknowledged = false;

  // Step 4 – 模拟 15 天倒计时
  final DateTime _deletionDate =
      DateTime.now().add(const Duration(days: 15));

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号注销')),
      body: Stepper(
        currentStep: _currentStep,
        physics: const BouncingScrollPhysics(),
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        onStepTapped: null,
        steps: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
          _buildStep4(),
        ],
      ),
    );
  }

  // ==================== Step 1: 安全验证 ====================

  Step _buildStep1() {
    return Step(
      title: const Text('安全验证'),
      subtitle: const Text('请输入密码确认身份'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: '请输入登录密码',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _passwordController.text.isEmpty
                ? null
                : () {
                    setState(() {
                      _passwordVerified = true;
                      _currentStep = 1;
                    });
                  },
            child: const Text('确认身份'),
          ),
        ],
      ),
    );
  }

  // ==================== Step 2: 资产清算确认 ====================

  Step _buildStep2() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Step(
      title: const Text('资产清算确认'),
      subtitle: const Text('请确认以下资产信息'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAssetRow(theme, '校园卡余额', '¥ 128.50'),
          _buildAssetRow(theme, '积分余额', '360 积分'),
          _buildAssetRow(theme, '未完成订阅', '1 项'),
          const Divider(height: 24),
          CheckboxListTile(
            value: _confirmedCardBalance,
            onChanged: (v) =>
                setState(() => _confirmedCardBalance = v ?? false),
            title: Text('我已知晓校园卡余额将清零',
                style: theme.textTheme.bodyMedium),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _confirmedCredits,
            onChanged: (v) =>
                setState(() => _confirmedCredits = v ?? false),
            title: Text('我已知晓积分将作废',
                style: theme.textTheme.bodyMedium),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _confirmedSubscriptions,
            onChanged: (v) =>
                setState(() => _confirmedSubscriptions = v ?? false),
            title: Text('我已知晓未完成订阅将终止',
                style: theme.textTheme.bodyMedium),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                (_confirmedCardBalance && _confirmedCredits && _confirmedSubscriptions)
                    ? () => setState(() => _currentStep = 2)
                    : null,
            child: const Text('下一步'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppConstants.warningColor)),
        ],
      ),
    );
  }

  // ==================== Step 3: 注销申请 ====================

  Step _buildStep3() {
    final theme = Theme.of(context);

    return Step(
      title: const Text('注销申请'),
      subtitle: const Text('请仔细阅读以下信息'),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.errorColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppConstants.errorColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppConstants.errorColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '注销后有 15天犹豫期，期间可撤回申请。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppConstants.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('以下数据将被永久删除：',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildDeletionItem(theme, '所有聊天消息'),
          _buildDeletionItem(theme, '上传的文件与附件'),
          _buildDeletionItem(theme, '请假、报修等业务记录'),
          _buildDeletionItem(theme, '积分与签到记录'),
          _buildDeletionItem(theme, '个人资料与偏好设置'),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _acknowledged,
            onChanged: (v) => setState(() => _acknowledged = v ?? false),
            title: Text('我已了解以上信息',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _acknowledged
                ? () => setState(() => _currentStep = 3)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
            ),
            child: const Text('申请注销'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletionItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.remove_circle_outline_rounded,
              size: 16, color: AppConstants.errorColor),
          const SizedBox(width: 8),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  // ==================== Step 4: 倒计时确认 ====================

  Step _buildStep4() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final remaining = _deletionDate.difference(DateTime.now());
    final days = remaining.inDays;

    return Step(
      title: const Text('倒计时确认'),
      subtitle: Text('剩余 $days 天'),
      isActive: _currentStep >= 3,
      state: StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(Icons.timer_outlined,
                    size: 48, color: AppConstants.warningColor),
                const SizedBox(height: 12),
                Text('$days 天后账号将被永久删除',
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '预计删除日期：${_deletionDate.year}-${_deletionDate.month.toString().padLeft(2, '0')}-${_deletionDate.day.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _showWithdrawDialog(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppConstants.successColor),
            ),
            child: Text('撤回注销',
                style: TextStyle(color: AppConstants.successColor)),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤回注销申请'),
        content: const Text('确定要撤回账号注销申请吗？您的账号将恢复正常使用。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('注销申请已撤回')),
              );
              Navigator.of(context).pop();
            },
            child: Text('确认撤回',
                style: TextStyle(color: AppConstants.successColor)),
          ),
        ],
      ),
    );
  }
}
