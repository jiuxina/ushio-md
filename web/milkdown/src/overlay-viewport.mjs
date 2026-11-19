/** Visible space shared by popups, including Flutter's adjustNothing overlays. */
export const getOverlayViewport = ({
  layoutHeight,
  viewportHeight = layoutHeight,
  viewportOffsetTop = 0,
  keyboardInset = 0,
  headerHeight = 0,
  toolbarHeight = 0,
  margin = 8,
}) => {
  const top = Math.max(0, viewportOffsetTop, headerHeight) + margin;
  const bottom = Math.max(top, Math.min(
    viewportOffsetTop + viewportHeight,
    layoutHeight - keyboardInset,
  ) - toolbarHeight - margin);
  return { top, bottom, height: bottom - top };
};

/** Coordinates use the popup's positioned parent, including its scroll offset. */
export const clampOverlayPosition = ({ left, top, width, height, bounds }) => ({
  left: Math.max(bounds.left, Math.min(left, bounds.right - width)),
  top: Math.max(bounds.top, Math.min(top, bounds.bottom - height)),
});
