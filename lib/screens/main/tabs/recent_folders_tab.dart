import 'dart:io';
import 'package:flutter/material.dart';
import '../../../providers/file_provider.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/tab_header.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/glass_card.dart';
import '../../../utils/file_actions.dart';
import '../../folder_browser_screen.dart';

class RecentFoldersTab extends StatelessWidget {
  final FileProvider fileProvider;

  const RecentFoldersTab({super.key, required this.fileProvider});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          const TabHeader(title: '最近文件夹', icon: Icons.folder),
          Expanded(
            child: fileProvider.recentFolders.isEmpty
                ? const EmptyState(message: '没有最近文件夹', icon: Icons.folder_open)
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: fileProvider.recentFolders.length,
                    itemBuilder: (context, index) {
                      return _buildFolderTile(
                        context,
                        fileProvider.recentFolders[index],
                        fileProvider,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderTile(BuildContext context, String path, FileProvider fileProvider) {
    final folderName = path.split(Platform.pathSeparator).last;
    final dir = Directory(path);
    String dateStr = '';
    try {
      if (dir.existsSync()) {
        final stat = dir.statSync();
        final modified = stat.modified;
        dateStr = '${modified.month}/${modified.day} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    return GlassCard(
      icon: Icons.folder,
      iconColor: Colors.amber,
      title: folderName,
      subtitle: dateStr.isNotEmpty ? '$dateStr · $path' : path,
      onTap: () {
        fileProvider.addToRecentFolders(path);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FolderBrowserScreen(folderPath: path),
          ),
        );
      },
      onLongPress: () => FileActions.showFolderContextMenu(context, path, fileProvider),
    );
  }
}
