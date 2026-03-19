import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/models/milkdown_bridge.dart';

void main() {
  group('milkdown bridge model', () {
    test('InitDocPayload serializes expected fields', () {
      const payload = InitDocPayload(
        markdown: '# title',
        docId: 'doc-1',
        cursor: {'from': 1, 'to': 2},
      );

      expect(payload.toJson(), {
        'markdown': '# title',
        'docId': 'doc-1',
        'cursor': {'from': 1, 'to': 2},
      });
    });

    test('BridgeEnvelope wraps payload with protocol fields', () {
      const envelope = BridgeEnvelope<ExecCmdPayload>(
        v: 1,
        source: 'flutter',
        target: 'web',
        type: 'exec_cmd',
        requestId: 'r1',
        ts: 12345,
        payload: ExecCmdPayload(cmd: 'focus_editor'),
      );

      expect(
        envelope.toJson((payload) => payload.toJson()),
        {
          'v': 1,
          'source': 'flutter',
          'target': 'web',
          'type': 'exec_cmd',
          'requestId': 'r1',
          'ts': 12345,
          'payload': {'cmd': 'focus_editor'},
        },
      );
    });

    test('ThemePalettePayload serializes color and font fields', () {
      const payload = ThemePalettePayload(
        mode: 'dark',
        colors: {
          'primary': '#ffffff',
          'shadow': 'rgba(0, 0, 0, 0.120)',
        },
        bodyFont: 'Noto Sans SC',
        monoFont: 'JetBrains Mono',
        sizePx: 18,
        lineHeight: 1.6,
      );

      expect(payload.toJson(), {
        'mode': 'dark',
        'colors': {
          'primary': '#ffffff',
          'shadow': 'rgba(0, 0, 0, 0.120)',
        },
        'font': {
          'body': 'Noto Sans SC',
          'mono': 'JetBrains Mono',
          'sizePx': 18.0,
          'lineHeight': 1.6,
        },
      });
    });

    test('ExecCmdPayload serializes optional args', () {
      const payload = ExecCmdPayload(
        cmd: 'insert_image',
        args: {'src': 'http://localhost/a.png', 'alt': 'a'},
      );

      expect(payload.toJson(), {
        'cmd': 'insert_image',
        'args': {'src': 'http://localhost/a.png', 'alt': 'a'},
      });
    });

    test('createBridgeRequestId creates non-empty IDs', () {
      final id = createBridgeRequestId();
      expect(id, isNotEmpty);
      expect(id.contains('-'), isTrue);
    });

    test('createBridgeRequestId generates unique IDs across calls', () {
      final ids = List.generate(1000, (_) => createBridgeRequestId()).toSet();
      expect(ids.length, 1000);
    });
  });
}
