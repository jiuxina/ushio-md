import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The surface carrying the content, independently of its glass decoration.
enum SurfaceRole { card, modal, inset }

/// A resolved palette whose foregrounds remain readable over any backdrop.
///
/// A translucent fill is checked over black and white before it is painted on
/// top of glass. This bounds the possible background colors without reading
/// images, sampling the screen, or doing work on every animation frame.
@immutable
class ReadableSurfacePalette {
  const ReadableSurfacePalette._({
    required this.role,
    required this.surface,
    required this.insetSurface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.icon,
    required this.mutedIcon,
    required this.outline,
    required this.brightness,
    required List<Color> backgrounds,
  }) : _backgrounds = backgrounds;

  final SurfaceRole role;
  final Color surface;
  final Color insetSurface;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color icon;
  final Color mutedIcon;
  final Color outline;
  final Brightness brightness;
  final List<Color> _backgrounds;

  static ReadableSurfacePalette resolve({
    required SurfaceRole role,
    required Color base,
    required double opacity,
    required Brightness brightness,
    required Color foreground,
    required Color secondaryForeground,
    required Color primary,
    required Color error,
    required Color icon,
    required Color mutedIcon,
    required Color outline,
  }) {
    final opaqueBase = base.withValues(alpha: 1);
    final minimumOpacity = switch (role) {
      SurfaceRole.card => 0.88,
      SurfaceRole.modal => 0.94,
      SurfaceRole.inset => 1.0,
    };
    final requestedOpacity = opacity.isFinite ? opacity.clamp(0.0, 1.0) : 1.0;
    var alpha = math.max(minimumOpacity, requestedOpacity);
    late Color surface;
    late Color inset;
    late List<Color> backgrounds;

    // Near middle gray neither a dark nor a light foreground may work over
    // both extremes. Increase the backing instead of chasing the backdrop.
    while (true) {
      surface = opaqueBase.withValues(alpha: alpha);
      inset = Color.alphaBlend(
        (contrastRatio(Colors.black, opaqueBase) >=
                    contrastRatio(Colors.white, opaqueBase)
                ? Colors.white
                : Colors.black)
            .withValues(alpha: 0.035),
        opaqueBase,
      );
      backgrounds = [
        Color.alphaBlend(surface, Colors.black),
        Color.alphaBlend(surface, Colors.white),
        inset,
      ];
      if (_canResolve(backgrounds, 4.5) || alpha >= 1) break;
      alpha = math.min(1.0, alpha + 0.01);
    }

    Color text(Color preferred) =>
        _resolveForeground(preferred, backgrounds, minimumContrast: 4.5);
    final accent = text(primary);
    final failure = text(error);
    final accentContainer = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      opaqueBase,
    );
    final failureContainer = Color.alphaBlend(
      failure.withValues(alpha: 0.10),
      opaqueBase,
    );
    return ReadableSurfacePalette._(
      role: role,
      surface: surface,
      insetSurface: inset,
      onSurface: text(foreground),
      onSurfaceVariant: text(secondaryForeground),
      primary: accent,
      onPrimary: _resolveForeground(foreground, [accent], minimumContrast: 4.5),
      primaryContainer: accentContainer,
      onPrimaryContainer: _resolveForeground(primary, [
        accentContainer,
      ], minimumContrast: 4.5),
      error: failure,
      onError: _resolveForeground(foreground, [failure], minimumContrast: 4.5),
      errorContainer: failureContainer,
      onErrorContainer: _resolveForeground(error, [
        failureContainer,
      ], minimumContrast: 4.5),
      icon: _resolveForeground(icon, backgrounds, minimumContrast: 3),
      mutedIcon: _resolveForeground(mutedIcon, backgrounds, minimumContrast: 3),
      outline: _resolveForeground(outline, backgrounds, minimumContrast: 3),
      brightness: brightness,
      backgrounds: List.unmodifiable(backgrounds),
    );
  }

  /// Resolve a semantic status color against the same content backing.
  Color ensureForeground(Color preferred, {double minimumContrast = 4.5}) =>
      _resolveForeground(
        preferred,
        _backgrounds,
        minimumContrast: minimumContrast,
      );

  /// Insets are an opaque tonal step, not another transparent glass layer.
  ReadableSurfacePalette forInset() => resolve(
    role: SurfaceRole.inset,
    base: insetSurface,
    opacity: 1,
    brightness: brightness,
    foreground: onSurface,
    secondaryForeground: onSurfaceVariant,
    primary: primary,
    error: error,
    icon: icon,
    mutedIcon: mutedIcon,
    outline: outline,
  );

  static double contrastRatio(Color foreground, Color background) {
    final rendered = Color.alphaBlend(foreground, background);
    final a = rendered.computeLuminance();
    final b = background.computeLuminance();
    return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
  }

  static bool _meets(
    Color foreground,
    List<Color> backgrounds,
    double minimum,
  ) {
    // Leave a little room for the eight-bit colors sent to the WebView.
    return backgrounds.every(
      (background) => contrastRatio(foreground, background) >= minimum + 0.01,
    );
  }

  static bool _canResolve(List<Color> backgrounds, double minimum) =>
      _meets(Colors.black, backgrounds, minimum) ||
      _meets(Colors.white, backgrounds, minimum);

  static Color _resolveForeground(
    Color preferred,
    List<Color> backgrounds, {
    required double minimumContrast,
  }) {
    final opaque = Color(preferred.withValues(alpha: 1).toARGB32());
    if (_meets(opaque, backgrounds, minimumContrast)) return opaque;

    Color? closest;
    var closestAmount = double.infinity;
    for (final endpoint in [Colors.black, Colors.white]) {
      if (!_meets(endpoint, backgrounds, minimumContrast)) continue;
      var low = 0.0;
      var high = 1.0;
      var candidate = endpoint;
      for (var step = 0; step < 16; step++) {
        final amount = (low + high) / 2;
        final mixed = Color(Color.lerp(opaque, endpoint, amount)!.toARGB32());
        if (_meets(mixed, backgrounds, minimumContrast)) {
          high = amount;
          candidate = mixed;
        } else {
          low = amount;
        }
      }
      if (high < closestAmount) {
        closestAmount = high;
        closest = candidate;
      }
    }
    // resolve() has already made sure one endpoint works for normal text.
    // A caller requesting a higher ratio still gets the better endpoint.
    return closest ??
        (backgrounds
                    .map(
                      (background) => contrastRatio(Colors.black, background),
                    )
                    .reduce(math.min) >=
                backgrounds
                    .map(
                      (background) => contrastRatio(Colors.white, background),
                    )
                    .reduce(math.min)
            ? Colors.black
            : Colors.white);
  }
}
