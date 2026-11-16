import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/services/export_service.dart';
import 'package:mdreader/services/pdf_math_render_session.dart';
import 'package:pdf/widgets.dart' as pw;

class FakeMathSession implements PdfMathRenderSession {
  final requests = <String>[];
  bool disposed = false;
  bool fail = false;
  bool invalid = false;

  @override
  Future<PdfMathImage?> render({
    required String tex,
    required bool displayMode,
    required double fontSizePt,
    required double maxWidthPt,
  }) async {
    requests.add('$tex/$displayMode/$fontSizePt/$maxWidthPt');
    if (fail) throw StateError('screenshot failed');
    if (invalid) return null;
    return PdfMathImage(
      png: _testPng(),
      widthPt: 24,
      heightPt: 12,
      baselinePt: 9,
    );
  }

  @override
  Future<void> dispose() async => disposed = true;
}

Uint8List _testPng() {
  List<int> chunk(String type, List<int> data) {
    final content = [...ascii.encode(type), ...data];
    var crc = 0xffffffff;
    for (final byte in content) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = crc & 1 == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    final length = ByteData(4)..setUint32(0, data.length);
    final checksum = ByteData(4)..setUint32(0, crc ^ 0xffffffff);
    return [
      ...length.buffer.asUint8List(),
      ...content,
      ...checksum.buffer.asUint8List(),
    ];
  }
  return Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10,
    ...chunk('IHDR', [0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0]),
    ...chunk('IDAT', ZLibEncoder().convert([0, 255, 255, 255, 255])),
    ...chunk('IEND', []),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> build(
    String markdown, {
    required Future<PdfMathRenderSession> Function() sessionFactory,
  }) {
    return ExportService.createPdfBytes(
      markdown,
      font: pw.Font.helvetica(),
      boldFont: pw.Font.helveticaBold(),
      mathSessionFactory: sessionFactory,
    );
  }

  test('embeds inline and block formula images and reuses a session', () async {
    final session = FakeMathSession();
    var opened = 0;
    final bytes = await build(
      '# Heading \$x_i^2\$\n\n'
      '1. First \$x_i^2\$ and \$\\sin(-30^\\circ)=\$.\n\n'
      '| Formula | Value |\n| --- | --- |\n| \$a_b\$ | 2 |\n\n'
      '\$\$\n\\frac{1}{2}\n\$\$',
      sessionFactory: () async {
        opened++;
        return session;
      },
    );

    expect(opened, 1);
    expect(session.disposed, isTrue);
    expect(session.requests.any((request) => request.startsWith('x_i^2/')), isTrue);
    expect(
      session.requests.any(
        (request) => request.startsWith(r'\sin(-30^\circ)=/false/'),
      ),
      isTrue,
    );
    expect(
      session.requests.any(
        (request) => request.startsWith(r'\frac{1}{2}/true/'),
      ),
      isTrue,
    );
    expect(
      RegExp(r'/Subtype\s*/Image').hasMatch(latin1.decode(bytes)),
      isTrue,
      reason: 'A valid PDF header alone does not prove formulas were rendered.',
    );
  });

  test('does not open a WebView for documents without real formulas', () async {
    var opened = 0;
    final bytes = await build(
      '# Plain\n\nCode `\$x\$` and escaped \\\$5.\n\n```\n\$y\$\n```',
      sessionFactory: () async {
        opened++;
        return FakeMathSession();
      },
    );

    expect(opened, 0);
    expect(latin1.decode(bytes).startsWith('%PDF-'), isTrue);
  });

  test('caches repeated formulas with the same rendering constraints', () async {
    final session = FakeMathSession();
    await build(
      r'First $x_i$ and again $x_i$.',
      sessionFactory: () async => session,
    );

    expect(session.requests, hasLength(1));
  });

  test('preserves invalid formula source and disposes the session', () async {
    final session = FakeMathSession()..invalid = true;
    final bytes = await build(
      r'Formula $\notACommand{x_i}$.',
      sessionFactory: () async => session,
    );

    expect(latin1.decode(bytes).startsWith('%PDF-'), isTrue);
    expect(session.disposed, isTrue);
    expect(RegExp(r'/Subtype\s*/Image').hasMatch(latin1.decode(bytes)), isFalse);
  });

  test('reports screenshot errors and still releases the session', () async {
    final session = FakeMathSession()..fail = true;
    await expectLater(
      build(r'Formula $x$.', sessionFactory: () async => session),
      throwsStateError,
    );

    expect(session.disposed, isTrue);
  });
}
