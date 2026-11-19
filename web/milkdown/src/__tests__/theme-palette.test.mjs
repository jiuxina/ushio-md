import { describe, expect, it, vi } from 'vitest';
import { applyThemeColors } from '../theme-palette.mjs';

const createRoot = () => {
  const properties = new Map();
  return {
    properties,
    style: {
      setProperty: vi.fn((name, value) => properties.set(name, value)),
    },
  };
};

describe('document and overlay theme colors', () => {
  it('keeps a transparent document and an RGBA overlay independent', () => {
    const root = createRoot();
    applyThemeColors(root, {
      surface: 'transparent',
      background: 'rgba(10, 20, 30, 0)',
      onSurface: '#9370db',
      overlaySurface: 'rgba(24, 30, 40, 0.960)',
      overlayOnSurface: '#ffffff',
      overlayOnSurfaceVariant: '#d1d5db',
      overlayPrimary: '#a9bdf3',
      overlayOnPrimary: '#18212f',
      overlayPrimaryContainer: '#2b3141',
      overlayOnPrimaryContainer: '#b9c9f5',
      overlayError: '#ffb4ab',
      overlayOutline: '#737f91',
      overlayIcon: '#edf0f6',
      overlayMutedIcon: '#bcc5d4',
    });
    expect(root.properties.get('--milkdown-color-surface')).toBe('transparent');
    expect(root.properties.get('--milkdown-color-background')).toBe('rgba(10, 20, 30, 0)');
    expect(root.properties.get('--milkdown-color-on-surface')).toBe('#9370db');
    expect(root.properties.get('--ushio-overlay-surface')).toBe('rgba(24, 30, 40, 0.960)');
    expect(root.properties.get('--ushio-overlay-on-surface')).toBe('#ffffff');
    expect(root.properties.get('--ushio-overlay-on-surface-variant')).toBe('#d1d5db');
    expect(root.properties.get('--ushio-overlay-primary')).toBe('#a9bdf3');
    expect(root.properties.get('--ushio-overlay-on-primary')).toBe('#18212f');
    expect(root.properties.get('--ushio-overlay-primary-container')).toBe('#2b3141');
    expect(root.properties.get('--ushio-overlay-on-primary-container')).toBe('#b9c9f5');
    expect(root.properties.get('--ushio-overlay-error')).toBe('#ffb4ab');
    expect(root.properties.get('--ushio-overlay-outline')).toBe('#737f91');
    expect(root.properties.get('--ushio-overlay-icon')).toBe('#edf0f6');
    expect(root.properties.get('--ushio-overlay-muted-icon')).toBe('#bcc5d4');
  });

  it('leaves overlay defaults available for an older document-only payload', () => {
    const root = createRoot();
    applyThemeColors(root, { surface: '#fff0db', onSurface: '#243044' });
    expect([...root.properties]).toEqual([
      ['--milkdown-color-surface', '#fff0db'],
      ['--milkdown-color-on-surface', '#243044'],
    ]);
  });

  it('ignores unknown roles and non-string colors without touching styles', () => {
    const root = createRoot();
    applyThemeColors(root, null);
    applyThemeColors(root, 'invalid');
    applyThemeColors(root, {
      overlaySurface: null,
      overlayOnSurface: 123,
      arbitraryColor: '#000000',
      constructor: '#000000',
      toString: '#000000',
    });
    expect(root.style.setProperty).not.toHaveBeenCalled();
  });
});
