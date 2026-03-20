import 'package:flutter/material.dart';

import '../utils/app_style.dart';

class ThemedProgressDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String? label;
  final IconData icon;
  final Color? iconColor;

  const ThemedProgressDialog({
    super.key,
    required this.title,
    this.message,
    this.label,
    this.icon = Icons.hourglass_top_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appStyle = theme.extension<AppStyleTheme>() ??
        AppStyleTheme.resolve(
          brightness: theme.brightness,
          colorScheme: colorScheme,
          textSecondary: colorScheme.onSurfaceVariant,
          buttonStyleMode: AppButtonStyleMode.classic,
          cardOpacity: 0.72,
        );
    final accent = iconColor ?? colorScheme.primary;
    final surface = Color.alphaBlend(
      accent.withValues(alpha: appStyle.useBorderlessButtons ? 0.08 : 0.05),
      colorScheme.surface,
    );

    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          decoration: appStyle.surfaceDecoration(
            borderRadius: BorderRadius.circular(28),
            color: surface,
            prominent: appStyle.useBorderlessButtons,
            border: appStyle.useBorderlessButtons
                ? null
                : Border.all(
                    color: accent.withValues(alpha: 0.14),
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: appStyle.useBorderlessButtons
                        ? appStyle.prominentShadow
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                      Icon(icon, color: accent, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      label!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.45,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showThemedSnackBar(
  BuildContext context, {
  required String message,
  IconData icon = Icons.info_outline_rounded,
  Color? accentColor,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.of(context);
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final appStyle = theme.extension<AppStyleTheme>() ??
      AppStyleTheme.resolve(
        brightness: theme.brightness,
        colorScheme: colorScheme,
        textSecondary: colorScheme.onSurfaceVariant,
        buttonStyleMode: AppButtonStyleMode.classic,
        cardOpacity: 0.72,
      );
  final accent = accentColor ?? colorScheme.primary;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        padding: EdgeInsets.zero,
        content: Container(
          decoration: appStyle.surfaceDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Color.alphaBlend(
              accent.withValues(alpha: appStyle.useBorderlessButtons ? 0.10 : 0.06),
              colorScheme.surface,
            ),
            prominent: appStyle.useBorderlessButtons,
            border: appStyle.useBorderlessButtons
                ? null
                : Border.all(color: accent.withValues(alpha: 0.14)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
