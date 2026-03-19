import 'dart:math';

class BridgeEnvelope<T> {
  final int v;
  final String source;
  final String target;
  final String type;
  final String requestId;
  final int ts;
  final T payload;

  const BridgeEnvelope({
    required this.v,
    required this.source,
    required this.target,
    required this.type,
    required this.requestId,
    required this.ts,
    required this.payload,
  });

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T payload) encode) {
    return {
      'v': v,
      'source': source,
      'target': target,
      'type': type,
      'requestId': requestId,
      'ts': ts,
      'payload': encode(payload),
    };
  }
}

class InitDocPayload {
  final String markdown;
  final String? docId;
  final Map<String, int>? cursor;

  const InitDocPayload({
    required this.markdown,
    this.docId,
    this.cursor,
  });

  Map<String, dynamic> toJson() => {
        'markdown': markdown,
        if (docId != null) 'docId': docId,
        if (cursor != null) 'cursor': cursor,
      };
}

class ThemePalettePayload {
  final String mode;
  final Map<String, String> colors;
  final String bodyFont;
  final String monoFont;
  final double sizePx;
  final double lineHeight;

  const ThemePalettePayload({
    required this.mode,
    required this.colors,
    required this.bodyFont,
    required this.monoFont,
    required this.sizePx,
    required this.lineHeight,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'colors': colors,
        'font': {
          'body': bodyFont,
          'mono': monoFont,
          'sizePx': sizePx,
          'lineHeight': lineHeight,
        },
      };
}

class ExecCmdPayload {
  final String cmd;
  final Map<String, dynamic>? args;

  const ExecCmdPayload({
    required this.cmd,
    this.args,
  });

  Map<String, dynamic> toJson() => {
        'cmd': cmd,
        if (args != null) 'args': args,
      };
}

String createBridgeRequestId() {
  final now = DateTime.now();
  final salt = Random().nextInt(1 << 20);
  return '${now.microsecondsSinceEpoch}-$salt';
}
