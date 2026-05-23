import 'package:flutter/material.dart';

import '../utils/app_style.dart';
import '../utils/responsive_layout.dart';

class DesktopNavigationDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const DesktopNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class DesktopNavigationShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DesktopNavigationDestination> destinations;
  final Widget child;

  const DesktopNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appStyle = theme.extension<AppStyleTheme>()!;
    final railWidth = ResponsiveLayout.navigationRailWidth(context);

    return Row(
      children: [
        Container(
          width: railWidth,
          decoration: BoxDecoration(
            color: appStyle.scaledSurfaceColor(theme.colorScheme, alpha: 0.82),
            border: Border(
              right: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.35),
              ),
            ),
            boxShadow: appStyle.useBorderlessButtons
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(4, 0),
                      spreadRadius: -12,
                    ),
                  ]
                : null,
          ),
          child: NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            backgroundColor: Colors.transparent,
            minWidth: railWidth,
            groupAlignment: -0.82,
            labelType: NavigationRailLabelType.all,
            useIndicator: true,
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
