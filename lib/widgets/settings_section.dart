import 'package:flutter/material.dart';

import 'app_surface.dart';

/// 设置页区块卡片：图标 + 标题 + 内容，统一三种 UI 风格下的表现。
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  }) : childrenBuilder = null;

  const SettingsSection.builder({
    super.key,
    required this.title,
    required this.icon,
    required this.childrenBuilder,
  }) : children = const [];

  final String title;
  final IconData icon;
  final List<Widget> children;
  final List<Widget> Function(BuildContext)? childrenBuilder;

  @override
  Widget build(BuildContext context) {
    return AppSurface.builder(
      padding: const EdgeInsets.all(16),
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...?childrenBuilder?.call(context),
          if (childrenBuilder == null) ...children,
        ],
      ),
    );
  }
}
