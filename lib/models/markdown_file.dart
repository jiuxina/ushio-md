/// Data model for a Markdown file
class MarkdownFile {
  final String path;
  final String name;
  String content;
  final DateTime lastModified;
  final int size;
  bool isModified;

  MarkdownFile({
    required this.path,
    required this.name,
    this.content = '',
    required this.lastModified,
    required this.size,
    this.isModified = false,
  });

  /// Get display name without extension
  String get displayName {
    if (name.endsWith('.md')) {
      return name.substring(0, name.length - 3);
    }
    return name;
  }

  /// Get formatted file size
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Get formatted last modified date
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(lastModified);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} 分钟前';
      }
      return '${diff.inHours} 小时前';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    } else {
      return '${lastModified.year}-${lastModified.month.toString().padLeft(2, '0')}-${lastModified.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownFile && other.path == path;
  }

  @override
  int get hashCode => path.hashCode;
}
