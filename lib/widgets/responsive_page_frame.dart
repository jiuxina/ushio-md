import 'package:flutter/material.dart';

import '../utils/responsive_layout.dart';

class ResponsivePageFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;
  final Alignment alignment;

  const ResponsivePageFrame({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? ResponsiveLayout.pagePadding(context);
    final effectiveMaxWidth =
        maxWidth ?? ResponsiveLayout.pageMaxWidth(context);

    if (!ResponsiveLayout.isDesktopWidth(context)) {
      return Padding(padding: effectivePadding, child: child);
    }

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(padding: effectivePadding, child: child),
      ),
    );
  }
}
