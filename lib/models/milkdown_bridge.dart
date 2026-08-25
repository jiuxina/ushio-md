import 'dart:math';

const _bridgeRequestSaltLimit = 1 << 20;
int _bridgeRequestCounter = 0;

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
  final double letterSpacing;
  final double paragraphSpacing;
  final double borderRadius;
  final double shadowOpacity;
  final String codeBlockTheme;

  const ThemePalettePayload({
    required this.mode,
    required this.colors,
    required this.bodyFont,
    required this.monoFont,
    required this.sizePx,
    required this.lineHeight,
    this.letterSpacing = 0.0,
    this.paragraphSpacing = 8.0,
    this.borderRadius = 12.0,
    this.shadowOpacity = 0.08,
    this.codeBlockTheme = 'auto',
  });

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'colors': colors,
    'font': {
      'body': bodyFont,
      'mono': monoFont,
      'sizePx': sizePx,
      'lineHeight': lineHeight,
      'letterSpacing': letterSpacing,
      'paragraphSpacing': paragraphSpacing,
    },
    'style': {'borderRadius': borderRadius, 'shadowOpacity': shadowOpacity},
    'codeBlockTheme': codeBlockTheme,
  };
}

class ExecCmdPayload {
  final String cmd;
  final Map<String, dynamic>? args;

  const ExecCmdPayload({required this.cmd, this.args});

  Map<String, dynamic> toJson() => {'cmd': cmd, if (args != null) 'args': args};
}

class OnImageErrorPayload {
  final String src;
  final String reason;

  const OnImageErrorPayload({required this.src, required this.reason});

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

  Map<String, dynamic> toJson() => {'src': src, 'reason': reason};
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
    final level = levelRaw is int
        ? levelRaw
        : int.tryParse(levelRaw?.toString() ?? '') ?? 1;
    return OutlineNodePayload(
      id: json['id']?.toString() ?? '',
      level: level,
      text: json['text']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'level': level, 'text': text};
}

class OnOutlineUpdatePayload {
  final List<OutlineNodePayload> outline;
  final String? docId;

  const OnOutlineUpdatePayload({required this.outline, this.docId});

  factory OnOutlineUpdatePayload.fromJson(Map<String, dynamic> json) {
    final raw = json['outline'];
    final list = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) => OutlineNodePayload.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
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

class OnImageClickPayload {
  final String src;
  final String? alt;

  const OnImageClickPayload({required this.src, this.alt});

  factory OnImageClickPayload.fromJson(Map<String, dynamic> json) {
    final src = json['src']?.toString();
    if (src == null || src.isEmpty) {
      throw const FormatException('OnImageClickPayload.src is required');
    }
    return OnImageClickPayload(src: src, alt: json['alt']?.toString());
  }

  Map<String, dynamic> toJson() => {'src': src, if (alt != null) 'alt': alt};
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

class UploadImageFilePayload {
  final String name;
  final String type;
  final int size;
  final String dataUrl;

  const UploadImageFilePayload({
    required this.name,
    required this.type,
    required this.size,
    required this.dataUrl,
  });

  factory UploadImageFilePayload.fromJson(Map<String, dynamic> json) {
    final dataUrl = json['dataUrl']?.toString();
    if (dataUrl == null || dataUrl.isEmpty) {
      throw const FormatException('UploadImageFilePayload.dataUrl is required');
    }
    final sizeRaw = json['size'];
    final size = sizeRaw is int
        ? sizeRaw
        : int.tryParse(sizeRaw?.toString() ?? '') ?? 0;
    return UploadImageFilePayload(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      size: size,
      dataUrl: dataUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'size': size,
    'dataUrl': dataUrl,
  };
}

class OnUploadImagesRequestPayload {
  final String requestId;
  final List<UploadImageFilePayload> files;

  const OnUploadImagesRequestPayload({
    required this.requestId,
    required this.files,
  });

  factory OnUploadImagesRequestPayload.fromJson(Map<String, dynamic> json) {
    final requestId = json['requestId']?.toString();
    if (requestId == null || requestId.isEmpty) {
      throw const FormatException(
        'OnUploadImagesRequestPayload.requestId is required',
      );
    }
    final rawFiles = json['files'];
    final files = rawFiles is List
        ? rawFiles
              .whereType<Map>()
              .map(
                (item) => UploadImageFilePayload.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <UploadImageFilePayload>[];
    return OnUploadImagesRequestPayload(requestId: requestId, files: files);
  }

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'files': files.map((e) => e.toJson()).toList(growable: false),
  };
}

class OnInsertImageRequestPayload {
  final String requestId;

  const OnInsertImageRequestPayload({required this.requestId});

  factory OnInsertImageRequestPayload.fromJson(Map<String, dynamic> json) {
    final requestId = json['requestId']?.toString();
    if (requestId == null || requestId.isEmpty) {
      throw const FormatException(
        'OnInsertImageRequestPayload.requestId is required',
      );
    }
    return OnInsertImageRequestPayload(requestId: requestId);
  }

  Map<String, dynamic> toJson() => {'requestId': requestId};
}

class OnCmdMetricPayload {
  final String cmd;
  final bool ok;
  final String? reason;
  final int? durationMs;

  const OnCmdMetricPayload({
    required this.cmd,
    required this.ok,
    this.reason,
    this.durationMs,
  });

  factory OnCmdMetricPayload.fromJson(Map<String, dynamic> json) {
    final cmd = json['cmd']?.toString() ?? '';
    final durationRaw = json['durationMs'];
    final durationMs = durationRaw is int
        ? durationRaw
        : int.tryParse(durationRaw?.toString() ?? '');
    return OnCmdMetricPayload(
      cmd: cmd,
      ok: json['ok'] == true,
      reason: json['reason']?.toString(),
      durationMs: durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'cmd': cmd,
    'ok': ok,
    if (reason != null) 'reason': reason,
    if (durationMs != null) 'durationMs': durationMs,
  };
}

class OnCmdFailureAggregatePayload {
  final String cmd;
  final String reason;
  final int count;

  const OnCmdFailureAggregatePayload({
    required this.cmd,
    required this.reason,
    required this.count,
  });

  factory OnCmdFailureAggregatePayload.fromJson(Map<String, dynamic> json) {
    final cmd = json['cmd']?.toString() ?? '';
    final reason = json['reason']?.toString() ?? 'unknown';
    final countRaw = json['count'];
    final count = countRaw is int
        ? countRaw
        : int.tryParse(countRaw?.toString() ?? '') ?? 0;
    return OnCmdFailureAggregatePayload(cmd: cmd, reason: reason, count: count);
  }

  Map<String, dynamic> toJson() => {
    'cmd': cmd,
    'reason': reason,
    'count': count,
  };
}

class OnHistoryStatePayload {
  final bool canUndo;
  final bool canRedo;

  const OnHistoryStatePayload({required this.canUndo, required this.canRedo});

  factory OnHistoryStatePayload.fromJson(Map<String, dynamic> json) {
    return OnHistoryStatePayload(
      canUndo: json['canUndo'] == true,
      canRedo: json['canRedo'] == true,
    );
  }

  Map<String, dynamic> toJson() => {'canUndo': canUndo, 'canRedo': canRedo};
}

String createBridgeRequestId() {
  final now = DateTime.now();
  final salt = Random.secure().nextInt(_bridgeRequestSaltLimit);
  _bridgeRequestCounter = (_bridgeRequestCounter + 1) & 0x7fffffff;
  return '${now.microsecondsSinceEpoch}-$salt-$_bridgeRequestCounter';
}

/// Dispatch a bridge message from Web -> Flutter to typed callback handlers.
///
/// The dispatcher is intentionally tolerant to malformed payloads: invalid
/// payload structures are ignored instead of throwing, so bridge noise does not
/// break host-side event handling.
void dispatchMilkdownBridgeMessage(
  Map<String, dynamic> map, {
  void Function(String markdown)? onContentChange,
  void Function(OnOutlineUpdatePayload payload)? onOutlineUpdate,
  void Function(OnLinkClickPayload payload)? onLinkClick,
  void Function(OnImageErrorPayload payload)? onImageError,
  void Function(OnImageClickPayload payload)? onImageClick,
  void Function(OnUploadImagesRequestPayload payload)? onUploadImagesRequest,
  void Function(OnInsertImageRequestPayload payload)? onInsertImageRequest,
  void Function(OnCmdMetricPayload payload)? onCmdMetric,
  void Function(OnCmdFailureAggregatePayload payload)? onCmdFailureAggregate,
  void Function(OnHistoryStatePayload payload)? onHistoryState,
  void Function(int index, bool checked)? onCheckboxToggle,
  void Function(String cmd, bool ok, String? reason)? onCmdResult,
  void Function()? onRenderComplete,
}) {
  final type = map['type'] as String?;
  if (type == null || type.isEmpty) return;

  if (type == 'on_render_complete') {
    onRenderComplete?.call();
    return;
  }

  final payload = map['payload'];
  if (payload is! Map) return;
  final payloadMap = Map<String, dynamic>.from(payload);

  if (type == 'on_content_change') {
    final markdown = payloadMap['markdown'];
    if (markdown is String) {
      onContentChange?.call(markdown);
    }
    return;
  }

  if (type == 'on_outline_update') {
    try {
      onOutlineUpdate?.call(OnOutlineUpdatePayload.fromJson(payloadMap));
    } on FormatException {
      // Ignore malformed payload.
    }
    return;
  }

  if (type == 'on_link_click') {
    try {
      onLinkClick?.call(OnLinkClickPayload.fromJson(payloadMap));
    } on FormatException {
      // Ignore malformed payload.
    }
    return;
  }

  if (type == 'on_image_error') {
    try {
      onImageError?.call(OnImageErrorPayload.fromJson(payloadMap));
    } on FormatException {
      // Ignore malformed payload.
    }
    return;
  }

  if (type == 'on_image_click') {
    try {
      onImageClick?.call(OnImageClickPayload.fromJson(payloadMap));
    } on FormatException {
      // Ignore malformed payload.
    }
    return;
  }

  if (type == 'on_upload_images_request') {
    try {
      onUploadImagesRequest?.call(
        OnUploadImagesRequestPayload.fromJson(payloadMap),
      );
    } on FormatException {
      // Ignore malformed payload.
    }
    return;
  }

  if (type == 'on_insert_image_request') {
    try {
      onInsertImageRequest?.call(
        OnInsertImageRequestPayload.fromJson(payloadMap),
      );
    } on FormatException {
      // Ignore malformed payload.
    }
    return;
  }

  if (type == 'on_cmd_metric') {
    onCmdMetric?.call(OnCmdMetricPayload.fromJson(payloadMap));
    return;
  }

  if (type == 'on_cmd_failure_aggregate') {
    onCmdFailureAggregate?.call(
      OnCmdFailureAggregatePayload.fromJson(payloadMap),
    );
    return;
  }

  if (type == 'on_history_state') {
    try {
      onHistoryState?.call(OnHistoryStatePayload.fromJson(payloadMap));
    } on FormatException {
      // Ignore malformed payload.
    }
    return;
  }

  if (type == 'on_checkbox_toggle') {
    final index = payloadMap['index'];
    final checked = payloadMap['checked'];
    final parsedIndex = index is int
        ? index
        : int.tryParse(index?.toString() ?? '');
    if (parsedIndex != null && checked is bool) {
      onCheckboxToggle?.call(parsedIndex, checked);
    }
    return;
  }

  if (type == 'on_cmd_result') {
    final cmd = payloadMap['cmd']?.toString() ?? '';
    final ok = payloadMap['ok'] == true;
    final reason = payloadMap['reason']?.toString();
    onCmdResult?.call(cmd, ok, reason);
  }
}
