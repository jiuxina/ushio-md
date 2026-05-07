// ============================================================================
// 字体服务
// 
// 管理应用字体的加载和安装：
// - 支持从本地文件安装自定义字体
// - 支持远程下载内置字体
// - 管理已安装的自定义字体列表
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/debug_log.dart';

/// 内置字体下载源配置
class BuiltinFontConfig {
  final String name;
  final String fontFamily;
  final String downloadUrl;
  final String fileName;
  final String description;

  const BuiltinFontConfig({
    required this.name,
    required this.fontFamily,
    required this.downloadUrl,
    required this.fileName,
    required this.description,
  });
}

/// 字体服务
class FontService {
  /// 自定义字体存储目录名
  static const String _customFontDir = 'custom_fonts';
  
  /// 已安装的自定义字体列表键
  static const String _customFontsKey = 'custom_fonts_list';
  
  /// 内置字体下载配置
  static const List<BuiltinFontConfig> builtinFonts = [
    BuiltinFontConfig(
      name: '思源黑体',
      fontFamily: 'Noto Sans SC',
      downloadUrl: 'https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf',
      fileName: 'NotoSansSC.ttf',
      description: 'Google 出品的中文字体，适合正文阅读',
    ),
    BuiltinFontConfig(
      name: 'JetBrains Mono',
      fontFamily: 'JetBrains Mono',
      downloadUrl: 'https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip',
      fileName: 'JetBrainsMono.ttf',
      description: 'JetBrains 出品的编程字体，适合代码块',
    ),
  ];
  
  /// 下载进度回调
  static void Function(double progress)? _onDownloadProgress;
  
  /// 设置下载进度回调
  static void setDownloadProgressCallback(void Function(double)? callback) {
    _onDownloadProgress = callback;
  }
  
  /// 获取自定义字体存储目录
  static Future<Directory> _getCustomFontDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${appDir.path}/$_customFontDir');
    if (!await fontDir.exists()) {
      await fontDir.create(recursive: true);
    }
    return fontDir;
  }
  
  /// 检查内置字体是否已下载
  static Future<bool> isBuiltinFontDownloaded(String fontFamily) async {
    try {
      final fontDir = await _getCustomFontDirectory();
      final config = builtinFonts.firstWhere(
        (f) => f.fontFamily == fontFamily,
        orElse: () => throw Exception('Font not found: $fontFamily'),
      );
      final fontFile = File('${fontDir.path}/${config.fileName}');
      return await fontFile.exists();
    } catch (e) {
      return false;
    }
  }
  
  /// 下载内置字体
  /// 
  /// 返回下载成功后的字体路径，失败返回 null
  static Future<String?> downloadBuiltinFont(
    String fontFamily, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final config = builtinFonts.firstWhere(
        (f) => f.fontFamily == fontFamily,
        orElse: () => throw Exception('Font not found: $fontFamily'),
      );
      
      final fontDir = await _getCustomFontDirectory();
      final fontPath = '${fontDir.path}/${config.fileName}';
      
      appDebugLog('开始下载字体: ${config.name} from ${config.downloadUrl}');
      
      // 下载字体文件
      final response = await http.get(Uri.parse(config.downloadUrl));
      
      if (response.statusCode != 200) {
        appDebugLog('下载字体失败: HTTP ${response.statusCode}');
        return null;
      }
      
      // 保存字体文件
      final fontFile = File(fontPath);
      await fontFile.writeAsBytes(response.bodyBytes);
      
      // 加载字体
      await _loadCustomFont(config.fontFamily, fontPath);
      
      // 保存到已安装列表
      await _saveCustomFontInfo(config.fontFamily, fontPath);
      
      appDebugLog('字体下载成功: ${config.name}');
      return fontPath;
    } catch (e, stackTrace) {
      appDebugLog('下载字体失败: $e\n$stackTrace');
      return null;
    }
  }
  
  /// 从文件管理器选择并安装字体
  /// 
  /// 返回安装的字体名称，或 null 表示取消/失败
  static Future<String?> installFontFromFile(BuildContext context) async {
    try {
      // 选择字体文件（支持 TTF 和 OTF）
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
        dialogTitle: '选择字体文件',
      );
      
      if (result == null || result.files.isEmpty) {
        return null;
      }
      
      final file = result.files.first;
      if (file.path == null) {
        return null;
      }
      
      final sourceFile = File(file.path!);
      final fontName = file.name.replaceAll(RegExp(r'\.(ttf|otf)$', caseSensitive: false), '');
      
      // 复制到应用目录
      final fontDir = await _getCustomFontDirectory();
      final destinationPath = '${fontDir.path}/${file.name}';
      await sourceFile.copy(destinationPath);
      
      // 加载字体
      await _loadCustomFont(fontName, destinationPath);
      
      // 保存到已安装列表
      await _saveCustomFontInfo(fontName, destinationPath);
      
      return fontName;
    } on PlatformException catch (e) {
      appDebugLog('安装字体失败 (平台错误): ${e.code} - ${e.message}');
      return null;
    } on FileSystemException catch (e) {
      appDebugLog('安装字体失败 (文件系统错误): ${e.path} - ${e.message}');
      return null;
    } catch (e, stackTrace) {
      appDebugLog('安装字体失败: $e\n$stackTrace');
      return null;
    }
  }
  
  /// 加载自定义字体
  static Future<void> _loadCustomFont(String fontName, String fontPath) async {
    try {
      final fontFile = File(fontPath);
      if (await fontFile.exists()) {
        final fontData = await fontFile.readAsBytes();
        final fontLoader = FontLoader(fontName);
        fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
        await fontLoader.load();
      } else {
        appDebugLog('加载字体失败: 字体文件不存在 $fontPath');
      }
    } on FileSystemException catch (e) {
      appDebugLog('加载字体失败 (文件系统错误): ${e.path} - ${e.message}');
    } catch (e, stackTrace) {
      appDebugLog('加载字体失败: $fontName - $e\n$stackTrace');
    }
  }
  
  /// 保存自定义字体信息
  static Future<void> _saveCustomFontInfo(String fontName, String fontPath) async {
    final prefs = await SharedPreferences.getInstance();
    final fonts = prefs.getStringList(_customFontsKey) ?? [];
    final fontInfo = '$fontName|$fontPath';
    if (!fonts.contains(fontInfo)) {
      fonts.add(fontInfo);
      await prefs.setStringList(_customFontsKey, fonts);
    }
  }
  
  /// 获取已安装的自定义字体列表
  static Future<List<CustomFontInfo>> getInstalledCustomFonts() async {
    final prefs = await SharedPreferences.getInstance();
    final fonts = prefs.getStringList(_customFontsKey) ?? [];
    return fonts.map((info) {
      final parts = info.split('|');
      return CustomFontInfo(
        name: parts[0],
        path: parts.length > 1 ? parts[1] : '',
      );
    }).toList();
  }
  
  /// 加载所有已安装的自定义字体
  static Future<void> loadAllCustomFonts() async {
    final fonts = await getInstalledCustomFonts();
    for (final font in fonts) {
      await _loadCustomFont(font.name, font.path);
    }
  }
  
  /// 删除自定义字体
  static Future<bool> removeCustomFont(String fontName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fonts = prefs.getStringList(_customFontsKey) ?? [];
      
      String? fontPath;
      fonts.removeWhere((info) {
        if (info.startsWith('$fontName|')) {
          fontPath = info.split('|')[1];
          return true;
        }
        return false;
      });
      
      await prefs.setStringList(_customFontsKey, fonts);
      
      // 删除字体文件
      if (fontPath != null) {
        final file = File(fontPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      return true;
    } on PlatformException catch (e) {
      appDebugLog('删除字体失败 (平台错误): ${e.code} - ${e.message}');
      return false;
    } on FileSystemException catch (e) {
      appDebugLog('删除字体失败 (文件系统错误): ${e.path} - ${e.message}');
      return false;
    } catch (e, stackTrace) {
      appDebugLog('删除字体失败: $fontName - $e\n$stackTrace');
      return false;
    }
  }
}

/// 自定义字体信息
class CustomFontInfo {
  final String name;
  final String path;
  
  CustomFontInfo({required this.name, required this.path});
}
