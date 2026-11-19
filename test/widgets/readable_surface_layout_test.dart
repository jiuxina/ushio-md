import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:mdreader/utils/constants.dart';
import 'package:mdreader/utils/theme_tones.dart';
import 'package:mdreader/widgets/app_modal.dart';
import 'package:mdreader/widgets/app_surface.dart';
import 'package:mdreader/widgets/glass_card.dart';
import 'package:mdreader/widgets/readable_surface_scope.dart';
import 'package:mdreader/widgets/settings_section.dart';

const _longTitle = '设置区块标题在窄屏和大字号下应完整换行 Readable section title';
const _subtitle = '2.4 KB · 2026/11/20 12:00 · 完全生成的测试信息';

ThemeData _theme({
  required AppButtonStyleMode style,
  Brightness brightness = Brightness.light,
}) {
  final dark = brightness == Brightness.dark;
  final paper = dark
      ? AppConstants.darkThemeSchemes.first
      : AppConstants.lightThemeSchemes.first;
  final scheme = ThemeTones.scheme(
    brightness: brightness,
    primary: const Color(0xFF625285),
    themeScheme: paper,
    error: AppConstants.errorColor,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: ThemeData(
      brightness: brightness,
    ).textTheme.apply(bodyColor: paper.text, displayColor: paper.text),
    extensions: [
      AppStyleTheme.resolve(
        brightness: brightness,
        colorScheme: scheme,
        backgroundColor: paper.background,
        textSecondary: paper.textSecondary,
        buttonStyleMode: style,
        cardOpacity: 0.1,
        // Deliberately oppose the page brightness to expose inherited colors.
        customCardColor: dark ? Colors.white : const Color(0xFF101319),
      ),
    ],
  );
}

void _viewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _expectReadable(Color foreground, Color surface) {
  for (final backdrop in [Colors.black, Colors.white]) {
    final background = Color.alphaBlend(surface, backdrop);
    expect(
      ReadableSurfacePalette.contrastRatio(foreground, background),
      greaterThanOrEqualTo(4.5),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required ThemeData theme,
  required double scale,
  required Widget child,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);

void main() {
  for (final width in [320.0, 600.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final style in [
        AppButtonStyleMode.classic,
        AppButtonStyleMode.softShadow,
      ]) {
        for (final brightness in Brightness.values) {
          testWidgets(
            'cards fit $width at ${scale}x, ${style.name}, ${brightness.name}',
            (tester) async {
              _viewport(tester, width);
              ReadableSurfacePalette? palette;
              await _pump(
                tester,
                theme: _theme(style: style, brightness: brightness),
                scale: scale,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GlassCard(
                      icon: Icons.description_outlined,
                      title: '示例文档 — Readability sample',
                      subtitle: _subtitle,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {},
                    ),
                    SettingsSection(
                      title: _longTitle,
                      icon: Icons.tune,
                      children: [
                        Builder(
                          builder: (context) {
                            palette = ReadableSurfaceScope.maybeOf(context);
                            return const Text('说明文字应在不同卡片颜色上保持可读。');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              expect(palette, isNotNull);
              final title = find.text(_longTitle);
              expect(tester.getTopLeft(title).dx, greaterThanOrEqualTo(16));
              expect(
                tester.getBottomRight(title).dx,
                lessThanOrEqualTo(width - 16),
              );
              final metadata = tester.widget<Text>(find.text(_subtitle));
              expect(metadata.style?.color, isNotNull);
              _expectReadable(metadata.style!.color!, palette!.surface);
            },
          );
        }
      }
    }
  }

  testWidgets(
    'surface builder resolves explicit colors inside its own backing',
    (tester) async {
      final source = _theme(style: AppButtonStyleMode.classic);
      ThemeData? resolved;
      await _pump(
        tester,
        theme: source,
        scale: 1,
        child: AppSurface.builder(
          color: Colors.white,
          builder: (context) {
            resolved = Theme.of(context);
            return Text('显式局部颜色', style: resolved!.textTheme.bodySmall);
          },
        ),
      );
      expect(
        resolved!.colorScheme.surface.computeLuminance(),
        greaterThan(0.8),
      );
      _expectReadable(
        tester.widget<Text>(find.text('显式局部颜色')).style!.color!,
        resolved!.colorScheme.surface,
      );
    },
  );

  for (final width in [320.0, 600.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'dialog and sheet fit $width at ${scale}x with local colors',
        (tester) async {
          _viewport(tester, width);
          ThemeData? dialogTheme;
          ThemeData? sheetTheme;
          await _pump(
            tester,
            theme: _theme(style: AppButtonStyleMode.classic),
            scale: scale,
            child: Builder(
              builder: (context) => Wrap(
                children: [
                  TextButton(
                    onPressed: () => showAppDialog<void>(
                      context: context,
                      builder: (context) {
                        dialogTheme = Theme.of(context);
                        return AlertDialog(
                          scrollable: true,
                          title: const Text('确认示例操作 Confirm fixture'),
                          content: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('这是自动生成的长说明，验证窄屏和大字号下能够阅读。'),
                              SizedBox(height: 16),
                              TextField(
                                decoration: InputDecoration(
                                  labelText: '示例输入',
                                  helperText: '完整的辅助说明应允许换行并保持清晰。',
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消 Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('确认 Confirm'),
                            ),
                          ],
                        );
                      },
                    ),
                    child: const Text('打开对话框'),
                  ),
                  TextButton(
                    onPressed: () => showAppModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) {
                        sheetTheme = Theme.of(context);
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('生成的面板说明 Bottom sheet fixture'),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('关闭面板'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    child: const Text('打开面板'),
                  ),
                ],
              ),
            ),
          );

          await tester.tap(find.text('打开对话框'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final localDialogTheme = dialogTheme!;
          _expectReadable(
            localDialogTheme.textTheme.bodyMedium!.color!,
            localDialogTheme.dialogTheme.backgroundColor!,
          );
          _expectReadable(
            localDialogTheme.inputDecorationTheme.helperStyle!.color!,
            localDialogTheme.inputDecorationTheme.fillColor!,
          );
          expect(
            localDialogTheme.textTheme.bodySmall!.fontSize,
            greaterThanOrEqualTo(13),
          );
          await tester.tap(find.text('取消 Cancel'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('打开面板'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          _expectReadable(
            sheetTheme!.textTheme.bodyMedium!.color!,
            sheetTheme!.bottomSheetTheme.modalBackgroundColor!,
          );
          await tester.tap(find.text('关闭面板'));
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
