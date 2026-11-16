import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('katex', () => ({
  default: {
    render: vi.fn(),
    ParseError: class ParseError extends Error {},
  },
}));

describe('PDF math layout lifecycle', () => {
  let events;
  let rect;
  let baselineTop;
  let renderer;

  beforeEach(async () => {
    vi.resetModules();
    events = [];
    rect = { left: 2, top: 2, width: 80, height: 30 };
    baselineTop = 24;
    const formula = {
      style: {},
      getBoundingClientRect() {
        events.push('layout');
        return rect;
      },
    };
    const elements = {
      formula,
      math: {},
      baseline: {
        getBoundingClientRect: () => ({ top: baselineTop }),
      },
    };
    vi.stubGlobal('document', {
      getElementById: (id) => elements[id],
      fonts: {
        get ready() {
          events.push('fonts');
          return Promise.resolve();
        },
        [Symbol.iterator]: () => [][Symbol.iterator](),
      },
    });
    vi.stubGlobal('window', { devicePixelRatio: 2 });
    await import('../pdf-math.js');
    renderer = window.__USHIO_PDF_MATH__;
  });

  afterEach(() => vi.unstubAllGlobals());

  it('forces font discovery before awaiting font readiness', async () => {
    await renderer.render({
      tex: 'x_i',
      displayMode: false,
      fontSizePx: 48,
      maxWidthPx: 200,
    });

    expect(events.indexOf('layout')).toBeLessThan(events.indexOf('fonts'));
  });

  it('remeasures bounds and baseline after the native viewport is resized', async () => {
    await renderer.render({
      tex: 'x_i',
      displayMode: false,
      fontSizePx: 48,
      maxWidthPx: 200,
    });
    rect = { left: 2, top: 2, width: 70, height: 36 };
    baselineTop = 29;

    expect(await renderer.measure()).toMatchObject({
      x: 2,
      y: 2,
      width: 72,
      height: 38,
      baseline: 27,
      pixelRatio: 2,
    });
  });

  it('rejects nonfinite dimensions before native screenshot allocation', async () => {
    await expect(
      renderer.render({
        tex: 'x',
        displayMode: false,
        fontSizePx: Number.NaN,
        maxWidthPx: 200,
      }),
    ).rejects.toThrow();
  });
});
