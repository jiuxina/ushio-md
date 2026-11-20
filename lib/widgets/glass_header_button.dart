import 'package:flutter/material.dart';

import '../utils/app_style.dart';
import 'app_surface.dart';

/// 头部图标按钮：与卡片共用玻璃与内容衬底，图标按真实底色解析。
class GlassHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool isActive;
  final String? tooltip;

  const GlassHeaderButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.iconSize = 20,
    this.iconColor,
    this.isActive = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final appStyle = Theme.of(context).extension<AppStyleTheme>()!;
    final extent = size < 48 ? 48.0 : size;
    final button = AppSurface.builder(
      role: SurfaceRole.modal,
      width: extent,
      height: extent,
      borderRadius: BorderRadius.circular(12),
      prominent: appStyle.useBorderlessButtons,
      builder: (context) {
        final theme = Theme.of(context);
        final palette = appStyle.resolveSurface(theme, role: SurfaceRole.modal);
        final foreground = palette.ensureForeground(
          iconColor ??
              (isActive ? theme.colorScheme.primary : context.appIconColor),
          minimumContrast: 3,
        );
        return Semantics(
          button: true,
          enabled: onPressed != null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Center(
                child: Icon(icon, size: iconSize, color: foreground),
              ),
            ),
          ),
        );
      },
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}
