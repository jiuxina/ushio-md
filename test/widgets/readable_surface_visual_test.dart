import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:mdreader/widgets/app_modal.dart';
import 'package:mdreader/widgets/glass_card.dart';
import 'package:mdreader/widgets/settings_section.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('readable surfaces render over checkerboard, dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final colors = ColorScheme.fromSeed(
        seedColor: const Color(0xFF625285),
        brightness: dark ? Brightness.dark : Brightness.light,
      );
      final theme = ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        extensions: [
          AppStyleTheme.resolve(
            brightness: colors.brightness,
            colorScheme: colors,
            backgroundColor: colors.surface,
            textSecondary: colors.onSurfaceVariant,
            buttonStyleMode: AppButtonStyleMode.softShadow,
            cardOpacity: 0.4,
            customCardColor: dark ? Colors.white : const Color(0xFF101319),
          ),
        ],
      );
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              body: CustomPaint(
                painter: const _Checkerboard(),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 20),
                    GlassCard(
                      icon: Icons.description_outlined,
                      title: 'Readable document 示例文档',
                      subtitle: '2.4 KB · 2026/11/20 · Generated fixture',
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                    SettingsSection.builder(
                      title: 'Surface readability 设置区块',
                      icon: Icons.tune,
                      childrenBuilder: (context) => [
                        const Text(
                          'Primary text stays clear across custom colors.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '辅助说明：低透明度与复杂背景下仍保持清晰。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        const TextField(
                          decoration: InputDecoration(
                            labelText: 'Generated name',
                            helperText: 'This is synthetic test content.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => showAppDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              scrollable: true,
                              title: const Text('Confirm generated operation'),
                              content: const Text('文字衬底与背景分离，辅助说明和操作保持清晰。'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ),
                          child: const Text('Open dialog'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final metadata = tester.widget<Text>(
        find.text('2.4 KB · 2026/11/20 · Generated fixture'),
      );
      expect(metadata.style!.fontSize, greaterThanOrEqualTo(13));
      if (const bool.fromEnvironment('READABILITY_CAPTURE')) {
        await _capture(tester, captureKey, dark ? 'light-card' : 'dark-card');
      }
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('READABILITY_CAPTURE')) {
        await _capture(
          tester,
          captureKey,
          dark ? 'light-dialog' : 'dark-dialog',
        );
      }
    });
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await Directory(
        'build/readability/captures',
      ).create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

class _Checkerboard extends CustomPainter {
  const _Checkerboard();

  @override
  void paint(Canvas canvas, Size size) {
    for (var y = 0.0; y < size.height; y += 24) {
      for (var x = 0.0; x < size.width; x += 24) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, 24, 24),
          Paint()
            ..color = ((x + y) / 24).round().isEven
                ? Colors.black
                : Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Checkerboard oldDelegate) => false;
}
