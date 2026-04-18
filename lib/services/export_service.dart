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
import '../utils/debug_log.dart';

/// 导出服务类
class ExportService {
  static final _headingRegex = RegExp(r'^(#{1,6})\s+(.+?)(?:\s+#+\s*)?$');
  static final _orderedListRegex = RegExp(r'^\s*(\d+)\.\s+(.+)$');
  static final _unorderedListRegex = RegExp(r'^\s*[-*+]\s+(.+)$');
  static final _blockquoteRegex = RegExp(r'^\s*>\s?(.*)$');
  // Accept both `| a | b |` and `a | b` table row styles.
  static final _tableRowRegex = RegExp(r'^\s*\|?.*\|.*\|?\s*$');
  static final _tableDividerRegex = RegExp(r'^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$');
  static final _hrRegex = RegExp(r'^\s*([-*_])\1{2,}\s*$');

  /// Share PNG bytes as an image file.
  static Future<bool> sharePngBytes(
    List<int> pngBytes,
    String fileName, {
    Duration cleanupDelay = const Duration(minutes: 5),
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName.png');
      await file.writeAsBytes(pngBytes, flush: true);
      await Share.shareXFiles([XFile(file.path)], subject: '$fileName.png');
      Future.delayed(cleanupDelay, () {
        try {
          file.deleteSync();
        } catch (e) { appDebugLog('删除失败: $e'); }
      });
      return true;
    } catch (e) {
      appDebugLog('图片分享失败: $e');
      return false;
    }
  }

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
        try { file.deleteSync(); } catch (e) {
          appDebugLog('清理临时图片文件失败: $e');
        }
      });
      
      return true;
    } catch (e) {
      appDebugLog('图片导出失败: $e');
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
      
      widgets.addAll(_parseMarkdownToPdfWidgets(content, font, boldFont));
      
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
        try { file.deleteSync(); } catch (e) {
          appDebugLog('清理临时PDF文件失败: $e');
        }
      });
      
      return true;
    } catch (e) {
      appDebugLog('PDF 导出失败: $e');
      return false;
    }
  }

  static List<pw.Widget> _parseMarkdownToPdfWidgets(
    String content,
    pw.Font font,
    pw.Font boldFont,
  ) {
    final lines = content.split('\n');
    final widgets = <pw.Widget>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final fence = trimmed.startsWith('~~~') ? '~~~' : '```';
        int end = i + 1;
        while (end < lines.length && !lines[end].trim().startsWith(fence)) {
          end++;
        }
        final safeEnd = end.clamp(0, lines.length).toInt();
        final code = lines.sublist(i + 1, safeEnd).join('\n');
        widgets.add(_buildCodeBlock(code, font));
        i = end < lines.length ? end + 1 : lines.length;
        continue;
      }

      if (_tableRowRegex.hasMatch(trimmed) && i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (_tableDividerRegex.hasMatch(next)) {
          int end = i + 2;
          while (end < lines.length && _tableRowRegex.hasMatch(lines[end].trim())) {
            end++;
          }
          widgets.add(_buildTable(lines.sublist(i, end), font, boldFont));
          widgets.add(pw.SizedBox(height: 8));
          i = end;
          continue;
        }
      }

      final headingMatch = _headingRegex.firstMatch(trimmed);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = _stripInlineMarkdown(headingMatch.group(2)!.trim());
        double size;
        if (level == 1) {
          size = 22.0;
        } else if (level == 2) {
          size = 20.0;
        } else if (level == 3) {
          size = 18.0;
        } else if (level == 4) {
          size = 16.0;
        } else {
          size = 14.0;
        }
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(text, style: pw.TextStyle(font: boldFont, fontSize: size)),
          ),
        );
        i++;
        continue;
      }

      if (_hrRegex.hasMatch(trimmed)) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Divider(color: PdfColors.grey500),
          ),
        );
        i++;
        continue;
      }

      if (_blockquoteRegex.hasMatch(trimmed)) {
        int end = i;
        while (end < lines.length && _blockquoteRegex.hasMatch(lines[end].trim())) {
          end++;
        }
        final quoteText = lines
            .sublist(i, end)
            .map((l) => _blockquoteRegex.firstMatch(l.trim())?.group(1) ?? '')
            .join('\n')
            .trim();
        widgets.add(_buildQuote(quoteText, font));
        i = end;
        continue;
      }

      final firstOrdered = _orderedListRegex.firstMatch(trimmed);
      final firstUnordered = _unorderedListRegex.firstMatch(trimmed);
      if (firstOrdered != null || firstUnordered != null) {
        int end = i;
        final items = <({int? number, String text})>[];
        while (end < lines.length) {
          final t = lines[end].trim();
          final om = _orderedListRegex.firstMatch(t);
          final um = _unorderedListRegex.firstMatch(t);
          if (om == null && um == null) break;
          items.add((
            number: om != null ? int.tryParse(om.group(1) ?? '') : null,
            text: (om?.group(2) ?? um?.group(1) ?? '').trim(),
          ));
          end++;
        }
        for (var idx = 0; idx < items.length; idx++) {
          final marker = firstOrdered != null
              ? '${items[idx].number ?? (idx + 1)}. '
              : '• ';
          widgets.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  marker,
                  style: pw.TextStyle(font: boldFont, fontSize: 12),
                ),
                pw.Expanded(
                  child: pw.Text(_stripInlineMarkdown(items[idx].text), style: pw.TextStyle(font: font, fontSize: 12, height: 1.5)),
                ),
              ],
            ),
          );
        }
        widgets.add(pw.SizedBox(height: 6));
        i = end;
        continue;
      }

      int end = i;
      final paragraphLines = <String>[];
      while (end < lines.length) {
        final t = lines[end].trim();
        if (t.isEmpty ||
            _headingRegex.hasMatch(t) ||
            _orderedListRegex.hasMatch(t) ||
            _unorderedListRegex.hasMatch(t) ||
            _blockquoteRegex.hasMatch(t) ||
            _hrRegex.hasMatch(t) ||
            t.startsWith('```') ||
            t.startsWith('~~~') ||
            _tableRowRegex.hasMatch(t)) {
          break;
        }
        paragraphLines.add(t);
        end++;
      }

      final paragraph = _stripInlineMarkdown(paragraphLines.join(' '));
      if (paragraph.isNotEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(paragraph, style: pw.TextStyle(font: font, fontSize: 12, height: 1.6)),
          ),
        );
      }
      i = end > i ? end : i + 1;
    }

    return widgets;
  }

  static pw.Widget _buildTable(List<String> lines, pw.Font font, pw.Font boldFont) {
    List<String> splitRow(String line) {
      var row = line.trim();
      if (row.startsWith('|')) row = row.substring(1);
      if (row.endsWith('|')) row = row.substring(0, row.length - 1);
      return row.split('|').map((e) => _stripInlineMarkdown(e.trim())).toList();
    }

    final header = splitRow(lines.first);
    final bodyRows = lines.length > 2 ? lines.sublist(2).map(splitRow).toList() : <List<String>>[];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: header
              .map((cell) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(cell, style: pw.TextStyle(font: boldFont, fontSize: 11)),
                  ))
              .toList(),
        ),
        ...bodyRows.map(
          (row) => pw.TableRow(
            children: List.generate(
              header.length,
              (idx) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(idx < row.length ? row[idx] : '', style: pw.TextStyle(font: font, fontSize: 10)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildQuote(String text, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: PdfColors.blue500, width: 3)),
        color: PdfColors.grey200,
      ),
      child: pw.Text(
        _stripInlineMarkdown(text),
        style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.black, height: 1.5),
      ),
    );
  }

  static String _stripInlineMarkdown(String text) {
    return text
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1) ?? '')
        .replaceAllMapped(
          RegExp(r'\*\*([^*]+)\*\*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'__([^_]+)__'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'\*([^*]+)\*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'_([^_]+)_'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'~~([^~]+)~~'),
          (match) => match.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'!\[[^\]]*\]\(([^\)]+)\)'),
          (match) => '[图片: ${match.group(1) ?? ''}]',
        )
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\(([^\)]+)\)'),
          (match) => '${match.group(1) ?? ''} (${match.group(2) ?? ''})',
        )
        .trim();
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
