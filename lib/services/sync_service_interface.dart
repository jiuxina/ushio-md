// ============================================================================
// 同步服务接口
//
// 定义云同步服务的通用接口，支持多种协议（WebDAV、FTP 等）
// ============================================================================

/// 远程文件信息
class RemoteFileInfo {
  final String name;
  final String path;
  final bool isDirectory;
  final DateTime? modifiedTime;

  RemoteFileInfo({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.modifiedTime,
  });
}

/// 同步服务接口
abstract class SyncServiceInterface {
  /// 云端工作区目录名称
  String get remoteWorkspaceName;

  /// 云端路径前缀
  String get remotePathPrefix;

  /// 设置工作区名称
  void setRemoteWorkspaceName(String name);

  /// 设置远程路径前缀
  void setRemotePathPrefix(String prefix);

  /// 获取完整的远程工作区路径
  String getFullRemotePath();

  /// 测试连接
  Future<bool> testConnection();

  /// 确保远程工作区目录存在
  Future<void> ensureRemoteWorkspace();

  /// 列出远程目录内容
  ///
  /// [remotePath] 远程路径（相对于工作区根目录）
  Future<List<RemoteFileInfo>?> listRemoteFiles({String remotePath});

  /// 上传文件
  ///
  /// [localPath] 本地文件路径
  /// [remotePath] 远程文件路径（相对于工作区）
  Future<bool> uploadFile(String localPath, String remotePath);

  /// 下载文件
  ///
  /// [remotePath] 远程文件路径（相对于工作区）
  /// [localPath] 本地保存路径
  Future<bool> downloadFile(String remotePath, String localPath);

  /// 删除远程文件或目录
  Future<bool> deleteRemote(String remotePath);

  /// 获取远程文件信息
  Future<RemoteFileInfo?> getRemoteFileInfo(String remotePath);
}
