// ============================================================================
// 导出服务
//
// 将 Markdown 内容导出为其他格式：
// - 图片（WYSIWYG 长图，包含粒子效果和背景样式）
// - PDF 文档
// ============================================================================

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/debug_log.dart';
import 'pdf_math_parser.dart';
import 'pdf_math_render_session.dart';

/// 导出服务类
class ExportService {
  static final _headingRegex = RegExp(r'^(#{1,6})\s+(.+?)(?:\s+#+\s*)?$');
  static final _orderedListRegex = RegExp(r'^\s*(\d+)\.\s+(.+)$');
  static final _unorderedListRegex = RegExp(r'^\s*[-*+]\s+(.+)$');
  static final _blockquoteRegex = RegExp(r'^\s*>\s?(.*)$');
  // Accept both `| a | b |` and `a | b` table row styles.
  static final _tableRowRegex = RegExp(r'^\s*\|?.*\|.*\|?\s*$');
  static final _tableDividerRegex = RegExp(
    r'^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$',
  );
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
        } catch (e) {
          appDebugLog('删除失败: $e');
        }
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
      final boundary =
          globalKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
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
        try {
          file.deleteSync();
        } catch (e) {
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
      final bytes = await createPdfBytes(content, title: title);

      // 保存到临时目录
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName.pdf');
      await file.writeAsBytes(bytes);

      // 分享
      await Share.shareXFiles([XFile(file.path)], subject: '$fileName.pdf');

      // 延迟清理
      Future.delayed(cleanupDelay, () {
        try {
          file.deleteSync();
        } catch (e) {
          appDebugLog('清理临时PDF文件失败: $e');
        }
      });

      return true;
    } catch (e) {
      appDebugLog('PDF 导出失败: $e');
      return false;
    }
  }

  /// Builds a PDF without sharing it. Injected fonts and renderer keep parser
  /// tests independent of network fonts and platform WebView channels.
  static Future<Uint8List> createPdfBytes(
    String content, {
    String? title,
    pw.Font? font,
    pw.Font? boldFont,
    Future<PdfMathRenderSession> Function()? mathSessionFactory,
  }) async {
    final regular = font ?? await PdfGoogleFonts.notoSansSCRegular();
    final bold = boldFont ?? await PdfGoogleFonts.notoSansSCBold();
    final document = PdfMathDocument.parse(content);
    final math = _PdfMathLayout(
      document,
      mathSessionFactory ?? PdfMathRenderSession.open,
    );
    try {
      final widgets = <pw.Widget>[];
      if (title != null && title.isNotEmpty) {
        widgets.add(
          pw.Header(
            level: 0,
            child: pw.Text(
              title,
              style: pw.TextStyle(font: bold, fontSize: 24),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 20));
      }
      widgets.addAll(
        await _parseMarkdownToPdfWidgets(
          document.markdown,
          regular,
          bold,
          math,
        ),
      );
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (_) => widgets,
        ),
      );
      return await pdf.save();
    } finally {
      await math.dispose();
    }
  }

  static Future<List<pw.Widget>> _parseMarkdownToPdfWidgets(
    String content,
    pw.Font font,
    pw.Font boldFont,
    _PdfMathLayout math,
  ) async {
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

      final expression = math.document.expressions[trimmed];
      if (expression != null && expression.displayMode) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: await math.block(expression, font),
          ),
        );
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
          while (end < lines.length &&
              _tableRowRegex.hasMatch(lines[end].trim())) {
            end++;
          }
          widgets.add(
            await _buildTable(lines.sublist(i, end), font, boldFont, math),
          );
          widgets.add(pw.SizedBox(height: 8));
          i = end;
          continue;
        }
      }

      final headingMatch = _headingRegex.firstMatch(trimmed);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!.trim();
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
            child: await math.inline(
              text,
              pw.TextStyle(font: boldFont, fontSize: size),
            ),
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
        while (end < lines.length &&
            _blockquoteRegex.hasMatch(lines[end].trim())) {
          end++;
        }
        final quoteText = lines
            .sublist(i, end)
            .map((l) => _blockquoteRegex.firstMatch(l.trim())?.group(1) ?? '')
            .join('\n')
            .trim();
        widgets.add(await _buildQuote(quoteText, font, math));
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
                  child: await math.inline(
                    items[idx].text,
                    pw.TextStyle(font: font, fontSize: 12, height: 1.5),
                    maxWidth: _PdfMathLayout.pageWidth - 28,
                  ),
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

      final paragraph = paragraphLines.join(' ');
      if (paragraph.isNotEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: await math.inline(
              paragraph,
              pw.TextStyle(font: font, fontSize: 12, height: 1.6),
            ),
          ),
        );
      }
      i = end > i ? end : i + 1;
    }

    return widgets;
  }

  static Future<pw.Widget> _buildTable(
    List<String> lines,
    pw.Font font,
    pw.Font boldFont,
    _PdfMathLayout math,
  ) async {
    List<String> splitRow(String line) {
      var row = line.trim();
      if (row.startsWith('|')) row = row.substring(1);
      if (row.endsWith('|')) row = row.substring(0, row.length - 1);
      return row.split('|').map((e) => e.trim()).toList();
    }

    final header = splitRow(lines.first);
    final bodyRows = lines.length > 2
        ? lines.sublist(2).map(splitRow).toList()
        : <List<String>>[];

    final cellWidth = _PdfMathLayout.pageWidth / header.length - 12;
    final headerWidgets = <pw.Widget>[];
    for (final cell in header) {
      headerWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: await math.inline(
            cell,
            pw.TextStyle(font: boldFont, fontSize: 11),
            maxWidth: cellWidth,
          ),
        ),
      );
    }
    final bodyWidgets = <pw.TableRow>[];
    for (final row in bodyRows) {
      final cells = <pw.Widget>[];
      for (var idx = 0; idx < header.length; idx++) {
        cells.add(
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: await math.inline(
              idx < row.length ? row[idx] : '',
              pw.TextStyle(font: font, fontSize: 10),
              maxWidth: cellWidth,
            ),
          ),
        );
      }
      bodyWidgets.add(pw.TableRow(children: cells));
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headerWidgets,
        ),
        ...bodyWidgets,
      ],
    );
  }

  static Future<pw.Widget> _buildQuote(
    String text,
    pw.Font font,
    _PdfMathLayout math,
  ) async {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.blue500, width: 3),
        ),
        color: PdfColors.grey200,
      ),
      child: await math.inline(
        text,
        pw.TextStyle(
          font: font,
          fontSize: 11,
          color: PdfColors.black,
          height: 1.5,
        ),
        maxWidth: _PdfMathLayout.pageWidth - 18,
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
        .replaceAllMapped(RegExp(r'_([^_]+)_'), (match) => match.group(1) ?? '')
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
      child: pw.Text(code, style: pw.TextStyle(font: font, fontSize: 10)),
    );
  }
}

class _PdfMathLayout {
  _PdfMathLayout(this.document, this._sessionFactory);

  static final pageWidth = PdfPageFormat.a4.width - 80;
  static final _pageHeight = PdfPageFormat.a4.height - 80;
  final PdfMathDocument document;
  final Future<PdfMathRenderSession> Function() _sessionFactory;
  final _cache = <String, PdfMathImage?>{};
  PdfMathRenderSession? _session;

  Future<PdfMathImage?> _render(
    PdfMathExpression expression,
    double fontSize,
    double maxWidth,
  ) async {
    final key =
        '${expression.tex}\u0000${expression.displayMode}\u0000$fontSize\u0000$maxWidth';
    if (_cache.containsKey(key)) return _cache[key];
    final session = _session ??= await _sessionFactory();
    final image = await session.render(
      tex: expression.tex,
      displayMode: expression.displayMode,
      fontSizePt: fontSize,
      maxWidthPt: maxWidth,
    );
    _cache[key] = image;
    return image;
  }

  Future<pw.Widget> inline(
    String source,
    pw.TextStyle style, {
    double? maxWidth,
  }) async {
    final text = ExportService._stripInlineMarkdown(source);
    final spans = <pw.InlineSpan>[];
    var offset = 0;
    for (final match in PdfMathDocument.markerPattern.allMatches(text)) {
      spans.add(pw.TextSpan(text: text.substring(offset, match.start)));
      final expression = document.expressions[match.group(0)];
      if (expression == null) {
        spans.add(pw.TextSpan(text: match.group(0)));
      } else {
        final image = await _render(
          expression,
          style.fontSize ?? 12,
          maxWidth ?? pageWidth,
        );
        if (image == null) {
          spans.add(pw.TextSpan(text: expression.source));
        } else {
          final scale = _imageScale(image, maxWidth ?? pageWidth);
          spans.add(
            pw.WidgetSpan(
              baseline: -(image.heightPt - image.baselinePt) * scale,
              child: pw.Image(
                pw.MemoryImage(image.png),
                width: image.widthPt * scale,
                height: image.heightPt * scale,
              ),
            ),
          );
        }
      }
      offset = match.end;
    }
    spans.add(pw.TextSpan(text: text.substring(offset)));
    return pw.RichText(
      text: pw.TextSpan(style: style, children: spans),
    );
  }

  Future<pw.Widget> block(PdfMathExpression expression, pw.Font font) async {
    final image = await _render(expression, 14, pageWidth);
    if (image == null) {
      return pw.Text(
        expression.source,
        style: pw.TextStyle(font: font, fontSize: 12),
      );
    }
    final scale = _imageScale(image, pageWidth);
    return pw.Center(
      child: pw.Image(
        pw.MemoryImage(image.png),
        width: image.widthPt * scale,
        height: image.heightPt * scale,
      ),
    );
  }

  double _imageScale(PdfMathImage image, double maxWidth) {
    final widthScale = image.widthPt > maxWidth
        ? maxWidth / image.widthPt
        : 1.0;
    final heightScale = image.heightPt > _pageHeight - 32
        ? (_pageHeight - 32) / image.heightPt
        : 1.0;
    return widthScale < heightScale ? widthScale : heightScale;
  }

  Future<void> dispose() async => _session?.dispose();
}
