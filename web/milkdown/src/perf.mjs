/**
 * 路线 A Phase 0 的度量插桩。
 *
 * 目标：把「每停顿」与「每帧」两条热路径的真实成本变成 logcat 里可读的数字，
 * 用来回填 docs/milkdown-performance-baseline.md 里 7 个月没有数据的阈值表。
 *
 * 出数据走 console.log：main.js 的日志会以 `[WebView Console]` 与 chromium CONSOLE
 * 两路进 logcat，`adb logcat -d -s flutter` 即可取，无需 Chrome DevTools
 * （本机 adb forward 到 webview_devtools_remote 会被权限层拒绝）。
 *
 * 事件对：
 *   ev:"boot"   一次会话一条（crepe.create 耗时、文档规模）
 *   ev:"chain"  每次停顿一条（markdownUpdated 里 4 段串行成本）
 *   ev:"settle" 每次停顿一条（notifyRenderComplete 的 rAF 收尾成本 + 窗口累计）
 *   ev:"dump"   主动索取的环形缓冲
 */

const RING_LIMIT = 240;

const state = {
  enabled: true,
  ring: [],
  window: null,
  lastKeyDownAt: 0,
  lastSettleAt: 0,
};

export const perfNow = () => (typeof performance !== 'undefined' ? performance.now() : Date.now());

const newWindow = () => ({
  chainCount: 0,
  sanitizeHit: 0,
  fullRebuild: 0,
  hintCalls: 0,
  hintMs: 0,
  caretCalls: 0,
  caretMs: 0,
  longestFrameMs: 0,
});

const win = () => {
  if (!state.window) state.window = newWindow();
  return state.window;
};

const round = (v) => (typeof v === 'number' ? Math.round(v * 100) / 100 : v);

export const perfSetEnabled = (on) => { state.enabled = Boolean(on); };
export const perfEnabled = () => state.enabled;

export const perfStart = () => {
  state.window = newWindow();
  state.lastKeyDownAt = 0;
  state.lastSettleAt = 0;
};

export const perfMarkKeyDown = () => { state.lastKeyDownAt = perfNow(); };

export const perfNoteHint = (ms) => { const w = win(); w.hintCalls += 1; w.hintMs += ms; };
export const perfNoteCaret = (ms) => { const w = win(); w.caretCalls += 1; w.caretMs += ms; };

const windowSummary = (w) => ({
  chain: w.chainCount,
  sanitize: w.sanitizeHit,
  rebuild: w.fullRebuild,
  hintCalls: w.hintCalls,
  hintAvgMs: w.hintCalls ? round(w.hintMs / w.hintCalls) : 0,
  caretCalls: w.caretCalls,
  caretAvgMs: w.caretCalls ? round(w.caretMs / w.caretCalls) : 0,
  longestFrameMs: round(w.longestFrameMs),
});

/** markdownUpdated 每停顿的串行链。 */
export const perfRecordChain = (timings, sizes = {}) => {
  if (!state.enabled) return;
  const w = win();
  w.chainCount += 1;
  if (timings.sanitizeHit) w.sanitizeHit += 1;
  if (timings.fullRebuild) w.fullRebuild += 1;
  emit({
    ev: 'chain',
    t: Math.round(perfNow()),
    sinceKeyMs: state.lastKeyDownAt ? Math.round(perfNow() - state.lastKeyDownAt) : null,
    ...sizes,
    ...mapTimings(timings),
  });
};

/** notifyRenderComplete 的 rAF 收尾；顺带把窗口累计清零。 */
export const perfRecordSettle = (timings, sizes = {}) => {
  if (!state.enabled) return;
  const w = win();
  const sample = {
    ev: 'settle',
    t: Math.round(perfNow()),
    sinceKeyMs: state.lastKeyDownAt ? Math.round(perfNow() - state.lastKeyDownAt) : null,
    sinceSettleMs: state.lastSettleAt ? Math.round(perfNow() - state.lastSettleAt) : null,
    win: windowSummary(w),
    ...sizes,
    ...mapTimings(timings),
  };
  state.lastSettleAt = perfNow();
  state.window = newWindow();
  emit(sample);
};

const mapTimings = (timings) => {
  const out = {};
  for (const [k, v] of Object.entries(timings)) out[k] = round(v);
  return out;
};

/** 里程碑事件（boot / firstPaint / fullResync 等）。 */
export const perfRecordEvent = (name, details = {}) => {
  if (!state.enabled) return;
  emit({ ev: name, t: Math.round(perfNow()), ...mapTimings(details) });
};

export const perfSnapshot = () => ({ ...windowSummary(win()), ringSize: state.ring.length });

export const perfDump = () => {
  emit({ ev: 'dump', t: Math.round(perfNow()), count: state.ring.length, ring: state.ring });
};

const emit = (sample) => {
  if (state.ring.length >= RING_LIMIT) state.ring.shift();
  state.ring.push(sample);
  try {
    console.log(`USHIO_PERF ${JSON.stringify(sample)}`);
  } catch (_) {
    /* console 不可用绝不能影响编辑功能 */
  }
};

/** long-animation-frame 在 WebView 123+ 才有；不支持就静默跳过。 */
export const perfObserveFrames = () => {
  if (typeof PerformanceObserver === 'undefined') return false;
  try {
    const observer = new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        const w = win();
        const dur = entry.duration || 0;
        if (dur > w.longestFrameMs) w.longestFrameMs = dur;
      }
    });
    observer.observe({ type: 'long-animation-frame', buffered: false });
    return true;
  } catch (_) {
    return false;
  }
};
