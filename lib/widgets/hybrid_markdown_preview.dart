import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'milkdown_webview_editor.dart';
import 'webview_markdown_preview.dart';

class HybridMarkdownPreviewController {
  final MarkdownWebViewController _legacy = MarkdownWebViewController();
  final MilkdownWebViewController _milkdown = MilkdownWebViewController();
  bool _usingMilkdown = true;

  void _setUsingMilkdown(bool value) {
    _usingMilkdown = value;
  }

  void suppressNextReload() {
    if (_usingMilkdown) {
      _milkdown.suppressNextReload();
    } else {
      _legacy.suppressNextReload();
    }
  }

  Future<void> scrollToHeading(int headingIndex, {double topOffset = 32.0}) {
    if (_usingMilkdown) {
      return _milkdown.scrollToHeading(headingIndex, topOffset: topOffset);
    }
    return _legacy.scrollToHeading(headingIndex, topOffset: topOffset);
  }

  Future<Uint8List?> captureScreenshot() {
    if (_usingMilkdown) return _milkdown.captureScreenshot();
    return _legacy.captureScreenshot();
  }

  Future<Uint8List?> captureFullPageScreenshot({
    int maxShots = 30,
    Duration settleDelay = const Duration(milliseconds: 80),
  }) {
    if (_usingMilkdown) {
      return _milkdown.captureFullPageScreenshot(
        maxShots: maxShots,
        settleDelay: settleDelay,
      );
    }
    return _legacy.captureFullPageScreenshot(
      maxShots: maxShots,
      settleDelay: settleDelay,
    );
  }
}

class HybridMarkdownPreview extends StatefulWidget {
  final String data;
  final bool isDark;
  final double fontSize;
  final String? fontFamily;
  final Color? bgColor;
  final Color? fgColor;
  final String? codeFont;
  final String? baseDirectory;
  final void Function(String text, String? href, String title)? onTapLink;
  final Function(int index, bool value) onCheckboxChanged;
  final String? Function(String type, int p1, int p2, int p3, String extra)? onGetMarkdown;
  final void Function(String key, String newText)? onInPlaceEdit;
  final VoidCallback? onLoadFinished;
  final HybridMarkdownPreviewController? controller;
  final bool hidePageScrollbar;
  final double bottomPadding;
  final bool readOnly;
  final ValueChanged<String>? onMilkdownContentChange;
  final Duration milkdownBootstrapTimeout;

  const HybridMarkdownPreview({
    super.key,
    required this.data,
    required this.isDark,
    required this.fontSize,
    this.fontFamily,
    this.bgColor,
    this.fgColor,
    this.codeFont,
    this.baseDirectory,
    this.onTapLink,
    required this.onCheckboxChanged,
    this.onGetMarkdown,
    this.onInPlaceEdit,
    this.onLoadFinished,
    this.controller,
    this.hidePageScrollbar = false,
    this.bottomPadding = 0,
    this.readOnly = true,
    this.onMilkdownContentChange,
    this.milkdownBootstrapTimeout = const Duration(seconds: 3),
  });

  @override
  State<HybridMarkdownPreview> createState() => _HybridMarkdownPreviewState();
}

class _HybridMarkdownPreviewState extends State<HybridMarkdownPreview> {
  bool _useLegacyFallback = false;
  Timer? _bootstrapTimer;

  MarkdownWebViewController get _legacyController =>
      widget.controller?._legacy ?? MarkdownWebViewController();
  MilkdownWebViewController get _milkdownController =>
      widget.controller?._milkdown ?? MilkdownWebViewController();

  @override
  void initState() {
    super.initState();
    widget.controller?._setUsingMilkdown(true);
    _armBootstrapTimeout();
  }

  @override
  void didUpdateWidget(covariant HybridMarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_useLegacyFallback && oldWidget.data != widget.data) {
      _armBootstrapTimeout();
    }
  }

  void _armBootstrapTimeout() {
    _bootstrapTimer?.cancel();
    _bootstrapTimer = Timer(widget.milkdownBootstrapTimeout, () {
      if (!mounted || _useLegacyFallback) return;
      setState(() {
        _useLegacyFallback = true;
        widget.controller?._setUsingMilkdown(false);
      });
    });
  }

  void _handleMilkdownLoadFinished() {
    _bootstrapTimer?.cancel();
    widget.controller?._setUsingMilkdown(true);
    widget.onLoadFinished?.call();
  }

  void _handleMilkdownImageError(OnImageErrorPayload payload) {
    if (payload.src == 'milkdown_bootstrap' && !_useLegacyFallback && mounted) {
      setState(() {
        _useLegacyFallback = true;
        widget.controller?._setUsingMilkdown(false);
      });
    }
  }

  @override
  void dispose() {
    _bootstrapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useLegacyFallback) {
      return WebViewMarkdownPreview(
        data: widget.data,
        isDark: widget.isDark,
        fontSize: widget.fontSize,
        fontFamily: widget.fontFamily,
        bgColor: widget.bgColor,
        fgColor: widget.fgColor,
        codeFont: widget.codeFont,
        baseDirectory: widget.baseDirectory,
        onTapLink: widget.onTapLink,
        onCheckboxChanged: widget.onCheckboxChanged,
        onGetMarkdown: widget.onGetMarkdown,
        onInPlaceEdit: widget.onInPlaceEdit,
        onLoadFinished: widget.onLoadFinished,
        controller: _legacyController,
        hidePageScrollbar: widget.hidePageScrollbar,
        bottomPadding: widget.bottomPadding,
      );
    }

    return MilkdownWebViewEditor(
      initialMarkdown: widget.data,
      readOnly: widget.readOnly,
      bodyFont: widget.fontFamily,
      monoFont: widget.codeFont,
      fontSize: widget.fontSize,
      baseDirectory: widget.baseDirectory,
      onContentChange: widget.onMilkdownContentChange,
      onLinkClick: (payload) =>
          widget.onTapLink?.call(payload.text ?? '', payload.href, payload.title ?? ''),
      onCheckboxToggle: widget.onCheckboxChanged,
      onImageError: _handleMilkdownImageError,
      onLoadFinished: _handleMilkdownLoadFinished,
      controller: _milkdownController,
    );
  }
}
