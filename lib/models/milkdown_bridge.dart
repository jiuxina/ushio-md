import 'dart:math';

const _bridgeRequestSaltLimit = 1 << 20;

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
  final String? baseDirectory;
  final bool? readOnly;

  const InitDocPayload({
    required this.markdown,
    this.docId,
    this.cursor,
    this.baseDirectory,
    this.readOnly,
  });

  Map<String, dynamic> toJson() => {
        'markdown': markdown,
        if (docId != null) 'docId': docId,
        if (cursor != null) 'cursor': cursor,
        if (baseDirectory != null) 'baseDirectory': baseDirectory,
        if (readOnly != null) 'readOnly': readOnly,
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

class OnImageErrorPayload {
  final String src;
  final String reason;

  const OnImageErrorPayload({
    required this.src,
    required this.reason,
  });

  factory OnImageErrorPayload.fromJson(Map<String, dynamic> json) {
    final src = json['src']?.toString();
    if (src == null || src.isEmpty) {
      throw const FormatException('OnImageErrorPayload.src is required');
    }
    return OnImageErrorPayload(
      src: src,
      reason: json['reason']?.toString() ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() => {
        'src': src,
        'reason': reason,
      };
}

class OutlineNodePayload {
  final String id;
  final int level;
  final String text;

  const OutlineNodePayload({
    required this.id,
    required this.level,
    required this.text,
  });

  factory OutlineNodePayload.fromJson(Map<String, dynamic> json) {
    final levelRaw = json['level'];
    final level = levelRaw is int ? levelRaw : int.tryParse(levelRaw?.toString() ?? '') ?? 1;
    return OutlineNodePayload(
      id: json['id']?.toString() ?? '',
      level: level,
      text: json['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level,
        'text': text,
      };
}

class OnOutlineUpdatePayload {
  final List<OutlineNodePayload> outline;
  final String? docId;

  const OnOutlineUpdatePayload({
    required this.outline,
    this.docId,
  });

  factory OnOutlineUpdatePayload.fromJson(Map<String, dynamic> json) {
    final raw = json['outline'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => OutlineNodePayload.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const <OutlineNodePayload>[];
    return OnOutlineUpdatePayload(
      outline: list,
      docId: json['docId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'outline': outline.map((e) => e.toJson()).toList(growable: false),
        if (docId != null) 'docId': docId,
      };
}

class OnLinkClickPayload {
  final String href;
  final String? text;
  final String? title;
  final bool isExternal;

  const OnLinkClickPayload({
    required this.href,
    this.text,
    this.title,
    required this.isExternal,
  });

  factory OnLinkClickPayload.fromJson(Map<String, dynamic> json) {
    final href = json['href']?.toString();
    if (href == null || href.isEmpty) {
      throw const FormatException('OnLinkClickPayload.href is required');
    }
    return OnLinkClickPayload(
      href: href,
      text: json['text']?.toString(),
      title: json['title']?.toString(),
      isExternal: json['isExternal'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'href': href,
        if (text != null) 'text': text,
        if (title != null) 'title': title,
        'isExternal': isExternal,
      };
}

String createBridgeRequestId() {
  final now = DateTime.now();
  final salt = Random.secure().nextInt(_bridgeRequestSaltLimit);
  return '${now.microsecondsSinceEpoch}-$salt';
}
