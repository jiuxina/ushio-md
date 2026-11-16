import katex from 'katex';
import 'katex/dist/katex.min.css';
import './pdf-math.css';

const formula = document.getElementById('formula');
const math = document.getElementById('math');
const baseline = document.getElementById('baseline');
let maxWidth = 1;

const positiveNumber = (value) => Number.isFinite(value) && value > 0;

async function measure() {
  formula.style.transform = '';
  // Discover the fonts needed by the newly inserted KaTeX DOM before reading
  // fonts.ready; its previous promise may already be fulfilled.
  formula.getBoundingClientRect();
  await document.fonts.ready;
  if ([...document.fonts].some((face) => face.status === 'error')) {
    throw new Error('Formula font failed to load');
  }
  const rect = formula.getBoundingClientRect();
  if (!positiveNumber(rect.width) || !positiveNumber(rect.height)) {
    throw new Error('Invalid formula dimensions');
  }
  const scale = Math.min(1, maxWidth / rect.width);
  formula.style.transform = `scale(${scale})`;
  const scaled = formula.getBoundingClientRect();
  const base = baseline.getBoundingClientRect();
  const pixelRatio = window.devicePixelRatio || 1;
  const bounds = {
    invalid: false,
    x: scaled.left,
    y: scaled.top,
    width: Math.ceil(scaled.width + 2),
    height: Math.ceil(scaled.height + 2),
    baseline: Math.max(0, base.top - scaled.top),
    pixelRatio,
  };
  if (Object.entries(bounds).some(([key, value]) =>
    key !== 'invalid' && (!Number.isFinite(value) || value < 0))) {
    throw new Error('Invalid formula bounds');
  }
  return bounds;
}

window.__USHIO_PDF_MATH__ = {
  async render({ tex, displayMode, fontSizePx, maxWidthPx }) {
    if (!positiveNumber(fontSizePx) || !positiveNumber(maxWidthPx)) {
      throw new Error('Invalid formula rendering size');
    }
    const pixelRatio = window.devicePixelRatio || 1;
    // Leave native screenshot padding inside the maximum bitmap dimension.
    maxWidth = Math.min(maxWidthPx, 8192 / pixelRatio - 8);
    formula.style.fontSize = `${fontSizePx}px`;
    formula.style.transform = '';
    try {
      katex.render(tex, math, {
        displayMode,
        throwOnError: true,
        strict: 'ignore',
        trust: false,
        output: 'html',
      });
    } catch (error) {
      if (error instanceof katex.ParseError) return { invalid: true };
      throw error;
    }
    return measure();
  },
  measure,
};
window.flutter_inappwebview?.callHandler('pdf_math_ready');
