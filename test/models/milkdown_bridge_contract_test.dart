import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/models/milkdown_bridge.dart';

/// 路线 A（编辑路径增量化）的跨端契约锁。
/// 这些用例锁的是**当前实现的事实**，改造 JS 侧时不得单方面破坏；
/// 若某条必须破坏，先改这里的断言并说明原因。
void main() {
  group('路线 A 跨端契约', () {
    // Phase 5 要把 on_content_change 的 mode 改成 'incremental'。
    // 分发器今天只读 markdown、忽略 mode —— 这条自由度的依据就是它。
    test('on_content_change 的 mode 取值不影响 markdown 透传', () {
      for (final mode in ['full', 'code_sanitized', 'incremental', null]) {
        String? seen;
        dispatchMilkdownBridgeMessage(
          {
            'type': 'on_content_change',
            'payload': {'mode': mode, 'markdown': '# 正文 $mode'},
          },
          onContentChange: (value) => seen = value,
        );
        expect(seen, '# 正文 $mode', reason: 'mode=$mode 应当被忽略');
      }
    });

    // heading id 是 JS↔Dart 的跨端标识：TOC 用它索引文本行。
    test('on_outline_update 保留 line-N 形式的节点 id', () {
      OnOutlineUpdatePayload? payload;
      dispatchMilkdownBridgeMessage(
        {
          'type': 'on_outline_update',
          'payload': {
            'outline': [
              {'id': 'line-3', 'level': 1, 'text': '一级'},
              {'id': 'line-17', 'level': 2, 'text': '二级'},
            ],
          },
        },
        onOutlineUpdate: (value) => payload = value,
      );

      expect(payload, isNotNull);
      expect(payload!.outline.length, 2);
      expect(payload!.outline.first.id, 'line-3');
      expect(payload!.outline.last.id, 'line-17');
      expect(payload!.outline.first.level, 1);
      expect(payload!.outline.last.text, '二级');
    });

    // 加载遮罩只靠这一条消息清除（每次开档至少一次）；Phase 5 取消「每停顿都发」。
    test('on_render_complete 无 payload 也要触发，且只触发一次', () {
      var calls = 0;
      dispatchMilkdownBridgeMessage(
        {'type': 'on_render_complete'},
        onRenderComplete: () => calls++,
      );
      dispatchMilkdownBridgeMessage(
        {
          'type': 'on_render_complete',
          'payload': <String, dynamic>{},
        },
        onRenderComplete: () => calls++,
      );
      expect(calls, 2);
    });

    // 渐进渲染的进度条；Phase 5 之后仍需在开档期间到达。
    test('on_render_progress 透传 0..1 进度', () {
      final seen = <double>[];
      dispatchMilkdownBridgeMessage(
        {
          'type': 'on_render_progress',
          'payload': {'progress': 0.42},
        },
        onRenderProgress: seen.add,
      );
      dispatchMilkdownBridgeMessage(
        {'type': 'on_render_progress', 'payload': {'progress': 'bad'}},
        onRenderProgress: seen.add,
      );
      expect(seen, [0.42]);
    });

    // 诊断通道今天未接线，Phase 0 的插桩上报复用它们，不能改成抛错。
    test('未接线的诊断消息缺 payload 时静默忽略', () {
      var threw = false;
      try {
        dispatchMilkdownBridgeMessage(
          {'type': 'on_cmd_metric'},
          onCmdMetric: (_) => threw = true,
        );
        dispatchMilkdownBridgeMessage(
          {'type': 'on_cmd_failure_aggregate'},
          onCmdFailureAggregate: (_) => threw = true,
        );
        dispatchMilkdownBridgeMessage(
          {'type': 'on_image_error'},
          onImageError: (_) => threw = true,
        );
      } catch (_) {
        threw = true;
      }
      expect(threw, isFalse);
    });
  });
}
