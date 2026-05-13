// ============================================================================
// 文档版本数据模型
//
// 表示一个文档版本快照的基本信息。
// 版本内容存储在独立的版本文件中，此模型仅记录元数据。
// ============================================================================

/// 文档版本模型
class DocumentVersion {
  // ==================== 属性 ====================

  /// 版本唯一标识符
  final String versionId;

  /// 版本号（从 1 开始递增）
  final int versionNumber;

  /// 创建时间
  final DateTime timestamp;

  /// 用户备注（可选）
  final String note;

  /// 原始文档的绝对路径
  final String filePath;

  /// 版本文件的绝对路径
  final String versionPath;

  /// 版本文件大小（字节）
  final int fileSize;

  // ==================== 构造函数 ====================

  const DocumentVersion({
    required this.versionId,
    required this.versionNumber,
    required this.timestamp,
    this.note = '',
    required this.filePath,
    required this.versionPath,
    required this.fileSize,
  });

  // ==================== 计算属性 ====================

  /// 获取格式化的创建时间
  ///
  /// 格式：yyyy-MM-dd HH:mm
  String get formattedTimestamp {
    final year = timestamp.year;
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  /// 获取显示名称
  ///
  /// 优先返回用户备注，无备注时返回格式化的时间戳。
  String get displayName => note.isNotEmpty ? note : formattedTimestamp;

  // ==================== 序列化 ====================

  /// 从 JSON 创建实例
  factory DocumentVersion.fromJson(Map<String, dynamic> json) {
    return DocumentVersion(
      versionId: json['versionId'] as String,
      versionNumber: json['versionNumber'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      note: json['note'] as String? ?? '',
      filePath: json['filePath'] as String,
      versionPath: json['versionPath'] as String,
      fileSize: json['fileSize'] as int,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'versionId': versionId,
      'versionNumber': versionNumber,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
      'filePath': filePath,
      'versionPath': versionPath,
      'fileSize': fileSize,
    };
  }

  // ==================== 副本 ====================

  /// 创建副本，可选择性替换部分字段
  DocumentVersion copyWith({
    String? versionId,
    int? versionNumber,
    DateTime? timestamp,
    String? note,
    String? filePath,
    String? versionPath,
    int? fileSize,
  }) {
    return DocumentVersion(
      versionId: versionId ?? this.versionId,
      versionNumber: versionNumber ?? this.versionNumber,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
      filePath: filePath ?? this.filePath,
      versionPath: versionPath ?? this.versionPath,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  // ==================== 对象比较 ====================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentVersion && other.versionId == versionId;
  }

  @override
  int get hashCode => versionId.hashCode;

  @override
  String toString() {
    return 'DocumentVersion(v$versionNumber, $formattedTimestamp, '
        'note: ${note.isEmpty ? "(empty)" : note})';
  }
}
