// ============================================================================
// 导出服务
// 
// 将 Markdown 内容导出为其他格式：
// - 图片（WYSIWYG 长图，包含粒子效果和背景样式）
// - PDF 文档
// ============================================================================

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// 导出服务类
class ExportService {
  /// 将 Widget 捕获为图片并分享
  /// 
  /// [globalKey] 要捕获的 Widget 的 GlobalKey
  /// [fileName] 输出文件名（不含扩展名）
  /// [pixelRatio] 图片分辨率倍数（默认 3.0 高清）
  static Future<bool> captureAndShareAsImage(
    GlobalKey globalKey, 
    String fileName, {
    double pixelRatio = 3.0,
    Duration cleanupDelay = const Duration(minutes: 5),
  }) async {
    try {
      final boundary = globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return false;
      
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      
      final pngBytes = byteData.buffer.asUint8List();
      
      // 保存到临时目录
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName.png');
      await file.writeAsBytes(pngBytes);
      
      // 分享
      await Share.shareXFiles([XFile(file.path)], subject: '$fileName.png');
      
      // 延迟清理
      Future.delayed(cleanupDelay, () {
        try { file.deleteSync(); } catch (_) {}
      });
      
      return true;
    } catch (e) {
      debugPrint('图片导出失败: $e');
      return false;
    }
  }
  
  /// 将 Markdown 文本导出为 PDF 并分享
  /// 
  /// [content] Markdown 文本内容
  /// [fileName] 输出文件名（不含扩展名）
  /// [title] PDF 标题
  static Future<bool> exportAndShareAsPdf(
    String content,
    String fileName, {
    String? title,
    Duration cleanupDelay = const Duration(minutes: 5),
  }) async {
    try {
      final pdf = pw.Document();
      
      // 加载中文字体（使用正确的方法名）
      final font = await PdfGoogleFonts.notoSansSCRegular();
      final boldFont = await PdfGoogleFonts.notoSansSCBold();
      
      // 解析 Markdown 并生成 PDF 内容
      final lines = content.split('\n');
      final widgets = <pw.Widget>[];
      
      // 如果有标题
      if (title != null && title.isNotEmpty) {
        widgets.add(
          pw.Header(
            level: 0,
            child: pw.Text(
              title,
              style: pw.TextStyle(font: boldFont, fontSize: 24),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 20));
      }
      
      // 简单的 Markdown 解析
      bool inCodeBlock = false;
      final codeBlockLines = <String>[];
      
      for (final line in lines) {
        // 代码块处理
        if (line.trim().startsWith('```')) {
          if (inCodeBlock) {
            // 结束代码块
            widgets.add(_buildCodeBlock(codeBlockLines.join('\n'), font));
            codeBlockLines.clear();
          }
          inCodeBlock = !inCodeBlock;
          continue;
        }
        
        if (inCodeBlock) {
          codeBlockLines.add(line);
          continue;
        }
        
        // 标题
        if (line.startsWith('# ')) {
          widgets.add(pw.Header(level: 0, child: pw.Text(line.substring(2), style: pw.TextStyle(font: boldFont, fontSize: 20))));
        } else if (line.startsWith('## ')) {
          widgets.add(pw.Header(level: 1, child: pw.Text(line.substring(3), style: pw.TextStyle(font: boldFont, fontSize: 18))));
        } else if (line.startsWith('### ')) {
          widgets.add(pw.Header(level: 2, child: pw.Text(line.substring(4), style: pw.TextStyle(font: boldFont, fontSize: 16))));
        } else if (line.startsWith('- ') || line.startsWith('* ')) {
          // 列表项
          widgets.add(pw.Bullet(text: line.substring(2), style: pw.TextStyle(font: font)));
        } else if (line.trim().isEmpty) {
          widgets.add(pw.SizedBox(height: 8));
        } else {
          // 普通段落
          widgets.add(pw.Paragraph(text: line, style: pw.TextStyle(font: font)));
        }
      }
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => widgets,
        ),
      );
      
      // 保存到临时目录
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // 分享
      await Share.shareXFiles([XFile(file.path)], subject: '$fileName.pdf');
      
      // 延迟清理
      Future.delayed(cleanupDelay, () {
        try { file.deleteSync(); } catch (_) {}
      });
      
      return true;
    } catch (e) {
      debugPrint('PDF 导出失败: $e');
      return false;
    }
  }
  
  /// 构建代码块
  static pw.Widget _buildCodeBlock(String code, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        code,
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
    );
  }
}
