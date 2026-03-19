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

    test('createBridgeRequestId creates non-empty IDs', () {
      final id = createBridgeRequestId();
      expect(id, isNotEmpty);
      expect(id.contains('-'), isTrue);
    });
  });
}
