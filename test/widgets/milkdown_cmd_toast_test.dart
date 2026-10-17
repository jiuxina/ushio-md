import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/widgets/milkdown_webview_editor.dart';

void main() {
  group('isExpectedEditorCmdNoop', () {
    test('撤回/重做在无历史时是预期空操作', () {
      expect(isExpectedEditorCmdNoop('undo', 'not_applicable'), isTrue);
      expect(isExpectedEditorCmdNoop('redo', 'not_applicable'), isTrue);
    });

    test('遮挡数据在编辑器建好之前被拒是预期，值会补发', () {
      expect(
        isExpectedEditorCmdNoop('set_keyboard_metrics', 'editor_not_ready'),
        isTrue,
      );
    });

    test('其余失败仍然要提示用户', () {
      expect(isExpectedEditorCmdNoop('set_keyboard_metrics', 'readonly'), isFalse);
      expect(isExpectedEditorCmdNoop('insert_image', 'editor_not_ready'), isFalse);
      expect(isExpectedEditorCmdNoop('undo', 'invalid_args'), isFalse);
      expect(isExpectedEditorCmdNoop('toggle_bold', null), isFalse);
    });
  });
}
