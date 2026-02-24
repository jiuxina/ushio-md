import 'package:flutter/material.dart';

class TocItem {
  final int level;
  final String title;
  final int lineNumber;
  final GlobalKey? anchorKey;

  TocItem({
    required this.level,
    required this.title,
    required this.lineNumber,
    this.anchorKey,
  });
}
