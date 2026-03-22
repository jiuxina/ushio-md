import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/models/milkdown_bridge.dart';

void main() {
  group('milkdown bridge model', () {
    test('InitDocPayload serializes expected fields', () {
      const payload = InitDocPayload(
        markdown: '# title',
        docId: 'doc-1',
        cursor: {'from': 1, 'to': 2},
        baseDirectory: '/tmp/demo',
        readOnly: true,
      );

      expect(payload.toJson(), {
        'markdown': '# title',
        'docId': 'doc-1',
        'cursor': {'from': 1, 'to': 2},
        'baseDirectory': '/tmp/demo',
        'readOnly': true,
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

    test('OnImageErrorPayload serializes and deserializes', () {
      const payload = OnImageErrorPayload(
        src: 'file:///bad/path.png',
        reason: 'load_failed',
      );

      expect(payload.toJson(), {
        'src': 'file:///bad/path.png',
        'reason': 'load_failed',
      });

      expect(
        OnImageErrorPayload.fromJson(payload.toJson()).toJson(),
        payload.toJson(),
      );
    });

    test('OnImageErrorPayload.fromJson throws when src missing', () {
      expect(
        () => OnImageErrorPayload.fromJson({'reason': 'load_failed'}),
        throwsFormatException,
      );
    });

    test('OnLinkClickPayload serializes and deserializes', () {
      const payload = OnLinkClickPayload(
        href: 'https://example.com',
        text: 'example',
        title: 'go',
        isExternal: true,
      );
      expect(payload.toJson(), {
        'href': 'https://example.com',
        'text': 'example',
        'title': 'go',
        'isExternal': true,
      });
      expect(OnLinkClickPayload.fromJson(payload.toJson()).toJson(), payload.toJson());
    });

    test('OnOutlineUpdatePayload serializes and deserializes', () {
      const payload = OnOutlineUpdatePayload(
        outline: [
          OutlineNodePayload(id: 'line-0', level: 1, text: 'Title'),
          OutlineNodePayload(id: 'line-2', level: 2, text: 'Section'),
        ],
        docId: 'doc-1',
      );
      expect(payload.toJson(), {
        'outline': [
          {'id': 'line-0', 'level': 1, 'text': 'Title'},
          {'id': 'line-2', 'level': 2, 'text': 'Section'},
        ],
        'docId': 'doc-1',
      });
      expect(
        OnOutlineUpdatePayload.fromJson(payload.toJson()).toJson(),
        payload.toJson(),
      );
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
