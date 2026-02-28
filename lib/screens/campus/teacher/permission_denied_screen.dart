import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

/// 403 权限不足页面
class PermissionDeniedScreen extends StatelessWidget {
  const PermissionDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppConstants.primaryColor.withValues(alpha: 0.08),
              cs.surface,
              AppConstants.accentColor.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: 72,
                  color: AppConstants.errorColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.lock_rounded,
                size: 28,
                color: AppConstants.errorColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 24),
              Text(
                '无权限访问',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '您当前的身份没有权限访问该功能',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.outline,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.home_rounded),
                label: const Text('返回首页'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
