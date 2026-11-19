import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mdreader/utils/app_style.dart';
import 'package:mdreader/utils/constants.dart';
import 'package:mdreader/utils/theme_tones.dart';

const _backdrops = [
  Colors.black,
  Colors.white,
  Color(0xFF808080),
  Color(0xFFFF00FF),
  Color(0xFF00FF00),
];

void _expectReadable(ReadableSurfacePalette palette) {
  for (final backdrop in _backdrops) {
    final rendered = Color.alphaBlend(palette.surface, backdrop);
    for (final foreground in [
      palette.onSurface,
      palette.onSurfaceVariant,
      palette.primary,
      palette.error,
      palette.ensureForeground(const Color(0xFF39AA64)),
    ]) {
      expect(
        ReadableSurfacePalette.contrastRatio(foreground, rendered),
        greaterThanOrEqualTo(4.5),
        reason: '${palette.role}: $foreground on $rendered',
      );
    }
    for (final foreground in [
      palette.icon,
      palette.mutedIcon,
      palette.outline,
    ]) {
      expect(
        ReadableSurfacePalette.contrastRatio(foreground, rendered),
        greaterThanOrEqualTo(3),
      );
    }
  }
  for (final pair in [
    (palette.onPrimary, palette.primary),
    (palette.onPrimaryContainer, palette.primaryContainer),
    (palette.onError, palette.error),
    (palette.onErrorContainer, palette.errorContainer),
    (palette.onSurface, palette.insetSurface),
    (palette.onSurfaceVariant, palette.insetSurface),
  ]) {
    expect(
      ReadableSurfacePalette.contrastRatio(pair.$1, pair.$2),
      greaterThanOrEqualTo(4.5),
    );
  }
}

void main() {
  group('readable content surfaces', () {
    for (final brightness in Brightness.values) {
      final schemes = brightness == Brightness.dark
          ? AppConstants.darkThemeSchemes
          : AppConstants.lightThemeSchemes;
      for (final scheme in schemes) {
        test('${brightness.name} ${scheme.name}: all styles and opacities', () {
          final colors = ThemeTones.scheme(
            brightness: brightness,
            primary: const Color(0xFF557788),
            themeScheme: scheme,
            error: AppConstants.errorColor,
          );
          for (final style in AppButtonStyleMode.values) {
            for (final opacity in [0.4, 0.7, 1.0]) {
              for (final custom in [
                null,
                const Color(0xFF08090B),
                const Color(0xFFF8F7F3),
                const Color(0xFF777777),
              ]) {
                final appStyle = AppStyleTheme.resolve(
                  brightness: brightness,
                  colorScheme: colors,
                  backgroundColor: scheme.background,
                  textSecondary: scheme.textSecondary,
                  buttonStyleMode: style,
                  cardOpacity: opacity,
                  customCardColor: custom,
                  customIconColor: const Color(0xFF888888),
                );
                // Deliberately use the opposite foreground to the paper.
                final theme = ThemeData(
                  brightness: brightness,
                  colorScheme: colors,
                  textTheme: TextTheme(
                    bodyMedium: TextStyle(
                      color: brightness == Brightness.dark
                          ? const Color(0xFF111111)
                          : const Color(0xFFF4F4F4),
                    ),
                  ),
                  extensions: [appStyle],
                );
                for (final role in [SurfaceRole.card, SurfaceRole.modal]) {
                  final palette = appStyle.resolveSurface(theme, role: role);
                  expect(
                    palette.surface.a,
                    greaterThanOrEqualTo(
                      role == SurfaceRole.modal ? 0.94 : 0.88,
                    ),
                  );
                  _expectReadable(palette);
                  final inset = palette.forInset();
                  expect(inset.surface.a, 1);
                  _expectReadable(inset);
                }
              }
            }
          }
        });
      }
    }

    test('already readable custom text and icon keep their RGB values', () {
      const foreground = Color(0xFF123456);
      final palette = ReadableSurfacePalette.resolve(
        role: SurfaceRole.card,
        base: Colors.white,
        opacity: 0.4,
        brightness: Brightness.light,
        foreground: foreground,
        secondaryForeground: foreground,
        primary: foreground,
        error: foreground,
        icon: foreground,
        mutedIcon: foreground,
        outline: foreground,
      );
      expect(palette.onSurface, foreground);
      expect(palette.onSurfaceVariant, foreground);
      expect(palette.icon, foreground);
      expect(palette.ensureForeground(foreground), foreground);
      expect(palette.surface.a, 0.88);
    });

    test(
      'middle gray increases the backing when no single foreground works',
      () {
        final palette = ReadableSurfacePalette.resolve(
          role: SurfaceRole.card,
          base: const Color(0xFF757575),
          opacity: 0.4,
          brightness: Brightness.light,
          foreground: const Color(0xFF777777),
          secondaryForeground: const Color(0xFF888888),
          primary: const Color(0xFF999999),
          error: Colors.red,
          icon: Colors.grey,
          mutedIcon: Colors.grey,
          outline: Colors.grey,
        );
        expect(palette.surface.a, greaterThan(0.88));
        _expectReadable(palette);
      },
    );
  });
}
