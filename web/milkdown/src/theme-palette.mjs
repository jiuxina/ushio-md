const colorVariables = Object.freeze({
  primary: '--milkdown-color-primary',
  onPrimary: '--milkdown-color-on-primary',
  secondary: '--milkdown-color-secondary',
  onSecondary: '--milkdown-color-on-secondary',
  surface: '--milkdown-color-surface',
  onSurface: '--milkdown-color-on-surface',
  background: '--milkdown-color-background',
  onBackground: '--milkdown-color-on-background',
  error: '--milkdown-color-error',
  onError: '--milkdown-color-on-error',
  outline: '--milkdown-color-outline',
  shadow: '--milkdown-color-shadow',
  overlaySurface: '--ushio-overlay-surface',
  overlayOnSurface: '--ushio-overlay-on-surface',
  overlayOnSurfaceVariant: '--ushio-overlay-on-surface-variant',
  overlayPrimary: '--ushio-overlay-primary',
  overlayOnPrimary: '--ushio-overlay-on-primary',
  overlayPrimaryContainer: '--ushio-overlay-primary-container',
  overlayOnPrimaryContainer: '--ushio-overlay-on-primary-container',
  overlayError: '--ushio-overlay-error',
  overlayOutline: '--ushio-overlay-outline',
  overlayIcon: '--ushio-overlay-icon',
  overlayMutedIcon: '--ushio-overlay-muted-icon',
});

/** Overlay colors are independent of document colors, which may be transparent. */
export const applyThemeColors = (root, colors) => {
  if (!colors || typeof colors !== 'object') return;
  Object.entries(colors).forEach(([key, value]) => {
    const variable = colorVariables[key];
    if (typeof variable !== 'string' || typeof value !== 'string') return;
    root.style.setProperty(variable, value);
  });
};
