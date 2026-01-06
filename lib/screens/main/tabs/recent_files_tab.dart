import 'dart:io';
import 'package:flutter/material.dart';
import '../../../providers/file_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/tab_header.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/glass_card.dart';
import '../../../utils/file_actions.dart';
import '../../editor_screen.dart';

class RecentFilesTab extends StatelessWidget {
  final FileProvider fileProvider;

  const RecentFilesTab({super.key, required this.fileProvider});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          const TabHeader(title: '最近文件', icon: Icons.history),
          Expanded(
            child: fileProvider.recentFiles.isEmpty
                ? const EmptyState(message: '没有最近打开的文件')
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: fileProvider.recentFiles.length,
                    itemBuilder: (context, index) {
                      return _buildRecentFileTile(
                        context,
                        fileProvider.recentFiles[index],
                        fileProvider,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFileTile(BuildContext context, String path, FileProvider fileProvider) {
    final fileName = path.split(Platform.pathSeparator).last;
    final file = File(path);
    final exists = file.existsSync();
    String dateStr = '';
    if (exists) {
      try {
        final modified = file.lastModifiedSync();
        dateStr = '${modified.month}/${modified.day} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return GlassCard(
      icon: Icons.description,
      iconColor: exists
          ? Theme.of(context).colorScheme.primary
          : Colors.grey,
      title: fileName.replaceAll('.md', '').replaceAll('.markdown', ''),
      subtitle: exists ? (dateStr.isNotEmpty ? '$dateStr · $path' : path) : '文件不存在',
      onTap: exists
          ? () {
              fileProvider.addToRecentFiles(path);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditorScreen(filePath: path),
                ),
              );
            }
          : () {},
      onLongPress: () => FileActions.showFileContextMenu(context, path, fileProvider, isRecent: true),
    );
  }
}
