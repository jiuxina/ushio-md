/// ============================================================================
/// 字体服务
/// ============================================================================
/// 
/// 管理应用字体的加载和安装：
/// - 支持从本地文件安装自定义字体
/// - 管理已安装的自定义字体列表
/// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 字体服务
class FontService {
  /// 自定义字体存储目录名
  static const String _customFontDir = 'custom_fonts';
  
  /// 已安装的自定义字体列表键
  static const String _customFontsKey = 'custom_fonts_list';
  
  /// 获取自定义字体存储目录
  static Future<Directory> _getCustomFontDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${appDir.path}/$_customFontDir');
    if (!await fontDir.exists()) {
      await fontDir.create(recursive: true);
    }
    return fontDir;
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
    } catch (e) {
      debugPrint('安装字体失败: $e');
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
      }
    } catch (e) {
      debugPrint('加载字体失败: $e');
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
    } catch (e) {
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
