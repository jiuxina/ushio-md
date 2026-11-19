import 'package:flutter/material.dart';

import '../utils/app_style.dart';
import 'app_surface.dart';
import 'readable_surface_scope.dart';

AppStyleTheme _styleFor(ThemeData theme) =>
    theme.extension<AppStyleTheme>() ??
    AppStyleTheme.resolve(
      brightness: theme.brightness,
      colorScheme: theme.colorScheme,
      backgroundColor: theme.scaffoldBackgroundColor,
      textSecondary: theme.colorScheme.onSurfaceVariant,
      buttonStyleMode: AppButtonStyleMode.classic,
      cardOpacity: 1,
    );

/// An ordinary dialog route with a palette independent of card transparency.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool? requestFocus,
}) {
  final source = Theme.of(context);
  final palette = _styleFor(
    source,
  ).resolveSurface(source, role: SurfaceRole.modal);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    traversalEdgeBehavior: traversalEdgeBehavior,
    requestFocus: requestFocus,
    builder: (context) => Theme(
      data: source,
      child: ReadableSurfaceScope(palette: palette, builder: builder),
    ),
  );
}

/// A single glass/content backing with safe, scrollable sheet contents.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = true,
  double scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = true,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  bool? requestFocus,
}) {
  final source = Theme.of(context);
  final style = _styleFor(source);
  final radius = shape is RoundedRectangleBorder
      ? shape.borderRadius.resolve(Directionality.of(context))
      : const BorderRadius.vertical(top: Radius.circular(24));
  final preferredColor = backgroundColor != null && backgroundColor.a > 0
      ? backgroundColor
      : null;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierLabel: barrierLabel,
    elevation: elevation ?? 0,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    requestFocus: requestFocus,
    builder: (context) => Theme(
      data: source.copyWith(
        extensions: [
          ...source.extensions.values.where(
            (extension) => extension is! AppStyleTheme,
          ),
          style,
        ],
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AppSurface.builder(
          role: SurfaceRole.modal,
          color: preferredColor,
          borderRadius: radius,
          width: double.infinity,
          builder: (context) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: builder(context),
            ),
          ),
        ),
      ),
    ),
  );
}
