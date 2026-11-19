import { describe, expect, it } from 'vitest';
import { clampOverlayPosition, getOverlayViewport } from '../overlay-viewport.mjs';

describe('popup viewport bounds', () => {
  it('subtracts Flutter keyboard and chrome in an adjustNothing WebView', () => {
    expect(getOverlayViewport({
      layoutHeight: 800,
      keyboardInset: 300,
      headerHeight: 80,
      toolbarHeight: 48,
    })).toEqual({ top: 88, bottom: 444, height: 356 });
  });

  it('does not subtract the keyboard twice when the browser already resized', () => {
    expect(getOverlayViewport({
      layoutHeight: 800,
      viewportHeight: 500,
      keyboardInset: 300,
      headerHeight: 80,
      toolbarHeight: 48,
    })).toEqual({ top: 88, bottom: 444, height: 356 });
  });

  it('clamps a tall popup inside a short visible area and a scrolled parent', () => {
    const viewport = getOverlayViewport({
      layoutHeight: 600,
      viewportHeight: 600,
      keyboardInset: 330,
      headerHeight: 80,
      toolbarHeight: 48,
    });
    expect(viewport).toEqual({ top: 88, bottom: 214, height: 126 });
    expect(clampOverlayPosition({
      left: 250,
      top: 0,
      width: 296,
      height: viewport.height,
      bounds: {
        left: 8,
        right: 312,
        top: viewport.top + 400,
        bottom: viewport.bottom + 400,
      },
    })).toEqual({ left: 16, top: 488 });
  });

  it('accounts for a shifted visual viewport and returns zero remaining space safely', () => {
    expect(getOverlayViewport({
      layoutHeight: 800,
      viewportHeight: 400,
      viewportOffsetTop: 120,
      keyboardInset: 280,
      headerHeight: 80,
      toolbarHeight: 48,
    })).toEqual({ top: 128, bottom: 464, height: 336 });
    expect(getOverlayViewport({
      layoutHeight: 400,
      keyboardInset: 300,
      headerHeight: 80,
      toolbarHeight: 48,
    })).toEqual({ top: 88, bottom: 88, height: 0 });
  });
});
