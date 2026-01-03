/// ============================================================================
/// Markdown 文件数据模型
/// ============================================================================
/// 
/// 表示一个 Markdown 文件的数据结构。
/// 包含文件的基本信息和格式化显示的辅助方法。
/// ============================================================================

/// Markdown 文件模型
class MarkdownFile {
  // ==================== 属性 ====================
  
  /// 文件的绝对路径
  final String path;
  
  /// 文件名（包含扩展名）
  final String name;
  
  /// 文件内容
  String content;
  
  /// 最后修改时间
  final DateTime lastModified;
  
  /// 文件大小（字节）
  final int size;
  
  /// 是否已修改（用于编辑器的保存状态追踪）
  bool isModified;

  // ==================== 构造函数 ====================

  MarkdownFile({
    required this.path,
    required this.name,
    this.content = '',
    required this.lastModified,
    required this.size,
    this.isModified = false,
  });

  // ==================== 计算属性 ====================

  /// 获取不含扩展名的显示名称
  /// 
  /// 例如: "笔记.md" -> "笔记"
  String get displayName {
    if (name.endsWith('.md')) {
      return name.substring(0, name.length - 3);
    }
    return name;
  }

  /// 获取格式化的文件大小
  /// 
  /// 自动转换单位：
  /// - 小于 1KB: 显示为 "xxx B"
  /// - 小于 1MB: 显示为 "x.x KB"
  /// - 其他: 显示为 "x.x MB"
  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 获取格式化的修改时间
  /// 
  /// 智能显示：
  /// - 1小时内: "x 分钟前"
  /// - 24小时内: "x 小时前"
  /// - 昨天: "昨天"
  /// - 一周内: "x 天前"
  /// - 更早: "yyyy-MM-dd"
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
      // 格式化为 yyyy-MM-dd
      return '${lastModified.year}-${lastModified.month.toString().padLeft(2, '0')}-${lastModified.day.toString().padLeft(2, '0')}';
    }
  }

  // ==================== 对象比较 ====================

  /// 两个文件相等的条件是路径相同
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkdownFile && other.path == path;
  }

  /// 使用路径作为 hashCode
  @override
  int get hashCode => path.hashCode;
}
