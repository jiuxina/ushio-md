# 本地 WebDAV 云同步测试

本文档记录如何在本地自建 WebDAV 服务器，并在安卓模拟器（MuMu V2324HA / vivo X100s Pro）里完整测试汐（Ushio-MD）的云同步功能。

## 1. 启动本地 WebDAV 服务器

服务端脚本：`tools/local_webdav_server.py`，只依赖 Python 标准库。

```powershell
python tools/local_webdav_server.py `
  --host 0.0.0.0 --port 18080 `
  --dir F:\tmp\webdev `
  --user test --password test
```

### 存储池隔离

- 服务端只把 `--dir` 指定的专用目录作为存储池，本次测试使用 `F:\tmp\webdev`。
- 服务启动时会拒绝把宿主机的盘符根目录、用户主目录、Documents/Desktop/Downloads 等个人目录作为存储池。
- 请求路径经过规范化校验：`..`、URL 编码的 `..`、符号链接/目录联接逃逸一律返回 `403`，不会写到存储池之外。
- 支持 Basic 认证（默认 `test/test`），未认证请求返回 `401`。

支持的 WebDAV 方法（对应 `lib/services/webdav_service.dart` 的使用范围）：

- `OPTIONS`：连接测试
- `PROPFIND`：递归列目录（depth 0/1）
- `MKCOL`：创建目录
- `PUT` / `GET`：上传 / 下载
- `DELETE`：删除

## 2. 模拟器与 App 配置

本次测试目标设备是 MuMu 实例 `MuMuPlayer-12.0-2`，adb 连接地址 `127.0.0.1:16448`，型号 V2324HA。

```powershell
# 安装 debug APK
adb -s 127.0.0.1:16448 install -r build\app\outputs\flutter-apk\app-debug.apk

# 端口反向映射：模拟器内 127.0.0.1:18080 -> 宿主机 18080
adb -s 127.0.0.1:16448 reverse tcp:18080 tcp:18080
```

App 内「设置 -> 云同步」配置：

| 配置项 | 值 |
| --- | --- |
| 服务器地址 | `http://127.0.0.1:18080` |
| 用户名 | `test` |
| 密码 | `test` |
| 云端文件夹名称 | `Ushio-MD` |
| 云端路径前缀 | `/storage/emulated/0/` |

Android 12 需要授予「所有文件访问」权限，否则 App 看不到公共 Documents 下的工作区文件，同步会显示“上传 0 个文件”。可通过：

```powershell
adb -s 127.0.0.1:16448 shell cmd appops set com.ushiomd MANAGE_EXTERNAL_STORAGE allow
```

## 3. 实测结果（2026-08-10）

工作区使用自定义基础路径 `/storage/emulated/0/Documents/Ushio-md-clean`，实际工作区为 `.../Ushio-md-clean/Ushio-md`。

1. 「测试连接」：显示“连接成功！”。
2. 首次「立即同步」：预览“将上传 2 个文件”，确认后两个文件均写入
   `F:\tmp\webdev\storage\emulated\0\Ushio-MD\`，包括嵌套目录下的中文文件名
   `nested_folder\中文笔记.md`。
3. 在服务器端新增 `remote_note.md` 后再次同步：预览“将下载 1 个文件”，确认后文件出现在本地工作区。
4. 两端均存在修改时：预览显示“2 个文件存在冲突”，可在弹窗中选择「保留本地 / 保留云端 / 跳过」；本次选择「保留云端」后本地文件被覆盖为云端版本。

### 过程中发现并修复的问题

自建服务器最初的 PROPFIND 响应中，`<d:propstat>` 缺少 `<d:status>HTTP/1.1 200 OK</d:status>`，导致 `webdav_client` 解析远端文件列表时报错，App 每次同步都会把所有本地文件当“新增”重新上传、且无法发现远端新增文件。已在 `tools/local_webdav_server.py` 修复。

## 4. 自动化回归测试

`test/services/local_webdav_sync_test.dart` 会临时启动 `tools/local_webdav_server.py`，覆盖：

- WebDAV 连接、上传、PROPFIND 列表解析、下载、删除
- `CloudSyncService` 全量同步上传（含嵌套目录）
- `CloudSyncService` 下载远端新增文件

运行：

```powershell
flutter test test\services\local_webdav_sync_test.dart
```
