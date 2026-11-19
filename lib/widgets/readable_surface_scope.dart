import 'package:flutter/material.dart';

import '../utils/app_style.dart';

/// Supplies local foregrounds without changing the user's saved appearance.
class ReadableSurfaceScope extends StatelessWidget {
  const ReadableSurfaceScope({
    super.key,
    required this.palette,
    required this.builder,
  });

  final ReadableSurfacePalette palette;
  final WidgetBuilder builder;

  static ReadableSurfacePalette? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SurfacePalette>()?.palette;

  @override
  Widget build(BuildContext context) {
    final source = Theme.of(context);
    final appStyle =
        source.extension<AppStyleTheme>() ??
        AppStyleTheme.resolve(
          brightness: source.brightness,
          colorScheme: source.colorScheme,
          backgroundColor: source.scaffoldBackgroundColor,
          textSecondary: source.colorScheme.onSurfaceVariant,
          buttonStyleMode: AppButtonStyleMode.classic,
          cardOpacity: 1,
        );
    final modal = palette.role == SurfaceRole.modal;
    final bodySize = modal ? 15.0 : 14.0;
    final titleSize = modal ? 20.0 : 16.0;

    TextStyle body(TextStyle? style, {bool secondary = false}) =>
        (style ?? const TextStyle()).copyWith(
          color: secondary ? palette.onSurfaceVariant : palette.onSurface,
          fontSize: secondary ? 13 : bodySize,
          height: secondary ? 1.45 : 1.5,
        );
    final textTheme = source.textTheme
        .apply(bodyColor: palette.onSurface, displayColor: palette.onSurface)
        .copyWith(
          titleLarge: body(source.textTheme.titleLarge).copyWith(
            fontSize: titleSize,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: body(
            source.textTheme.titleMedium,
          ).copyWith(fontSize: 16, height: 1.35, fontWeight: FontWeight.w600),
          titleSmall: body(
            source.textTheme.titleSmall,
          ).copyWith(fontSize: 16, height: 1.35, fontWeight: FontWeight.w600),
          bodyLarge: body(
            source.textTheme.bodyLarge,
          ).copyWith(fontSize: modal ? 15 : 16),
          bodyMedium: body(source.textTheme.bodyMedium),
          bodySmall: body(source.textTheme.bodySmall, secondary: true),
          labelLarge: body(
            source.textTheme.labelLarge,
          ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: body(source.textTheme.labelMedium, secondary: true),
          labelSmall: body(source.textTheme.labelSmall, secondary: true),
        );
    final colors = source.colorScheme.copyWith(
      surface: palette.surface,
      surfaceContainerLowest: palette.surface,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.insetSurface,
      surfaceContainerHigh: palette.insetSurface,
      surfaceContainerHighest: palette.insetSurface,
      onSurface: palette.onSurface,
      onSurfaceVariant: palette.onSurfaceVariant,
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      primaryContainer: palette.primaryContainer,
      onPrimaryContainer: palette.onPrimaryContainer,
      secondary: palette.primary,
      onSecondary: palette.onPrimary,
      secondaryContainer: palette.primaryContainer,
      onSecondaryContainer: palette.onPrimaryContainer,
      tertiary: palette.primary,
      onTertiary: palette.onPrimary,
      tertiaryContainer: palette.primaryContainer,
      onTertiaryContainer: palette.onPrimaryContainer,
      error: palette.error,
      onError: palette.onError,
      errorContainer: palette.errorContainer,
      onErrorContainer: palette.onErrorContainer,
      outline: palette.outline,
      outlineVariant: palette.onSurfaceVariant.withValues(alpha: 0.2),
      surfaceTint: Colors.transparent,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: palette.outline),
    );
    final scoped = source.copyWith(
      colorScheme: colors,
      textTheme: textTheme,
      iconTheme: source.iconTheme.copyWith(color: palette.icon),
      extensions: [
        ...source.extensions.values.where(
          (extension) => extension is! AppStyleTheme,
        ),
        appStyle.copyWith(
          iconColor: palette.icon,
          mutedIconColor: palette.mutedIcon,
          mutedSurface: palette.insetSurface,
          strongSurface: palette.insetSurface,
          cardSurface: palette.surface,
          outlineColor: palette.outline,
        ),
      ],
      dialogTheme: source.dialogTheme.copyWith(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: source.bottomSheetTheme.copyWith(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: source.listTileTheme.copyWith(
        textColor: palette.onSurface,
        iconColor: palette.icon,
        titleTextStyle: textTheme.bodyMedium,
        subtitleTextStyle: textTheme.bodySmall,
        selectedColor: palette.onPrimaryContainer,
        selectedTileColor: palette.primaryContainer,
      ),
      inputDecorationTheme: source.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: palette.insetSurface,
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: palette.primary,
        ),
        hintStyle: textTheme.bodySmall,
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: palette.error),
        errorMaxLines: 4,
        helperMaxLines: 4,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: palette.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: palette.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: palette.onPrimary,
          backgroundColor: palette.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: palette.onPrimary,
          backgroundColor: palette.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: palette.outline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.icon,
          minimumSize: const Size(48, 48),
        ),
      ),
      dividerTheme: source.dividerTheme.copyWith(
        color: palette.onSurfaceVariant.withValues(alpha: 0.2),
      ),
    );

    return _SurfacePalette(
      palette: palette,
      child: Theme(
        data: scoped,
        child: DefaultTextStyle(
          style: textTheme.bodyMedium!,
          child: IconTheme(
            data: scoped.iconTheme,
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }
}

class _SurfacePalette extends InheritedWidget {
  const _SurfacePalette({required this.palette, required super.child});

  final ReadableSurfacePalette palette;

  @override
  bool updateShouldNotify(_SurfacePalette oldWidget) =>
      oldWidget.palette != palette;
}
