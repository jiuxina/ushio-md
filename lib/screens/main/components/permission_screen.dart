import 'package:flutter/material.dart';
import '../../../providers/file_provider.dart';

class PermissionScreen extends StatelessWidget {
  final FileProvider fileProvider;

  const PermissionScreen({super.key, required this.fileProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  '需要存储权限',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '请授予存储权限以浏览和编辑 Markdown 文件',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () async {
                    final granted = await fileProvider.requestPermissions();
                    if (!granted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('请在设置中授予存储权限'),
                          action: SnackBarAction(
                            label: '打开设置',
                            onPressed: () => fileProvider.openSettings(),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.security),
                  label: const Text('授予权限'),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => fileProvider.openSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('打开系统设置'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
