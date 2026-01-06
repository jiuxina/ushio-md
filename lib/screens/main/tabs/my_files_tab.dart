import 'package:flutter/material.dart';
import '../../../providers/file_provider.dart';
import '../../../services/my_files_service.dart';
import '../../folder_browser_screen.dart';

class MyFilesTab extends StatefulWidget {
  final FileProvider fileProvider;

  const MyFilesTab({super.key, required this.fileProvider});

  @override
  State<MyFilesTab> createState() => _MyFilesTabState();
}

class _MyFilesTabState extends State<MyFilesTab> {
  final MyFilesService _myFilesService = MyFilesService();
  String? _rootPath;

  @override
  void initState() {
    super.initState();
    _initWorkspace();
  }

  Future<void> _initWorkspace() async {
    await _myFilesService.initWorkspace();
    final path = await _myFilesService.getWorkspacePath();
    if (mounted) setState(() => _rootPath = path);
  }

  @override
  Widget build(BuildContext context) {
    if (_rootPath == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return FolderBrowserScreen(
      folderPath: _rootPath!,
      showBackButton: false,
    );
  }
}
