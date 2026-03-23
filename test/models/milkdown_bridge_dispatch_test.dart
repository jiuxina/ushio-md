import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/models/milkdown_bridge.dart';

void main() {
  group('dispatchMilkdownBridgeMessage', () {
    test('dispatches on_content_change markdown', () {
      String? markdown;

      dispatchMilkdownBridgeMessage(
        {
          'type': 'on_content_change',
          'payload': {'mode': 'full', 'markdown': '# hello'},
        },
        onContentChange: (value) => markdown = value,
      );

      expect(markdown, '# hello');
    });

    test('dispatches on_link_click payload', () {
      OnLinkClickPayload? payload;

      dispatchMilkdownBridgeMessage(
        {
          'type': 'on_link_click',
          'payload': {
            'href': 'https://example.com',
            'text': 'Example',
            'title': 'Go',
            'isExternal': true,
          },
        },
        onLinkClick: (value) => payload = value,
      );

      expect(payload, isNotNull);
      expect(payload!.href, 'https://example.com');
      expect(payload!.text, 'Example');
      expect(payload!.title, 'Go');
      expect(payload!.isExternal, isTrue);
    });

    test('dispatches on_checkbox_toggle payload', () {
      int? index;
      bool? checked;

      dispatchMilkdownBridgeMessage(
        {
          'type': 'on_checkbox_toggle',
          'payload': {'index': 3, 'checked': false},
        },
        onCheckboxToggle: (i, v) {
          index = i;
          checked = v;
        },
      );

      expect(index, 3);
      expect(checked, isFalse);
    });

    test('dispatches on_render_complete without payload', () {
      var called = false;

      dispatchMilkdownBridgeMessage(
        {'type': 'on_render_complete'},
        onRenderComplete: () => called = true,
      );

      expect(called, isTrue);
    });

    test('ignores malformed payload safely', () {
      var called = false;

      dispatchMilkdownBridgeMessage(
        {
          'type': 'on_link_click',
          'payload': {'text': 'missing href'},
        },
        onLinkClick: (_) => called = true,
      );

      expect(called, isFalse);
    });

    test('dispatches on_upload_images_request payload', () {
      OnUploadImagesRequestPayload? payload;

      dispatchMilkdownBridgeMessage(
        {
          'type': 'on_upload_images_request',
          'payload': {
            'requestId': 'upload-1',
            'files': [
              {
                'name': 'a.png',
                'type': 'image/png',
                'size': 10,
                'dataUrl': 'data:image/png;base64,AA==',
              },
            ],
          },
        },
        onUploadImagesRequest: (value) => payload = value,
      );

      expect(payload, isNotNull);
      expect(payload!.requestId, 'upload-1');
      expect(payload!.files.length, 1);
      expect(payload!.files.first.name, 'a.png');
    });
  });
}
