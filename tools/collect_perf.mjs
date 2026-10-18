#!/usr/bin/env node
/**
 * 路线 A Phase 0：从 logcat 里取 USHIO_PERF 样本并按基线阈值出表。
 *
 * main.js 的 console.log 会以两条路径进 logcat：
 *   I flutter : [WebView Console] USHIO_PERF {...}
 *   I chromium: [INFO:CONSOLE(n)] "USHIO_PERF {...}"
 * 本机 adb forward 到 webview_devtools_remote 会被权限层拒绝，所以走 logcat。
 *
 * 用法：
 *   node tools/collect_perf.mjs --parse build/mdbench/perf.log
 *   node tools/collect_perf.mjs --adb emulator-5554 --keys 200 --gap 60 --out build/mdbench/perf.log
 */
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const ADB = process.env.ADB || path.join(
  process.env.LOCALAPPDATA || '', 'Android/Sdk/platform-tools/adb.exe',
);

const args = (() => {
  const out = { keys: 0, gap: 60, adb: null, parse: null, file: null, tag: '', minChars: 0 };
  const a = process.argv.slice(2);
  for (let i = 0; i < a.length; i++) {
    const k = a[i];
    if (k === '--adb') out.adb = a[++i];
    else if (k === '--keys') out.keys = Number(a[++i]) || 0;
    else if (k === '--gap') out.gap = Number(a[++i]) || 60;
    else if (k === '--parse') out.parse = a[++i];
    else if (k === '--out') out.file = a[++i];
    else if (k === '--tag') out.tag = a[++i];
    // 冷启动采样里会混进预热 WebView 的 4 字符空文档样本，必须能按规模过滤，
    // 否则 P50 会被空文档拉低，得出「很快」的假结论。
    else if (k === '--min-chars') out.minChars = Number(a[++i]) || 0;
  }
  return out;
})();

const adb = (cmd) => spawnSync(ADB, args.adb ? ['-s', args.adb].concat(cmd) : cmd, { encoding: 'utf8' });

// logcat 里一行可能被截断或带尾随引号，所以不用单个正则，改成花括号配对提取。
const extractSamples = (line) => {
  const out = [];
  let from = 0;
  for (;;) {
    const i = line.indexOf('USHIO_PERF ', from);
    if (i < 0) break;
    from = i + 11;
    let depth = 0, end = -1, inStr = false, esc = false;
    for (let j = i + 11; j < line.length; j++) {
      const ch = line[j];
      if (esc) { esc = false; continue; }
      if (ch === '\\') { if (inStr) esc = true; continue; }
      if (ch === '"') { inStr = !inStr; continue; }
      if (inStr) continue;
      if (ch === '{') depth += 1;
      else if (ch === '}') { depth -= 1; if (depth === 0) { end = j; break; } }
    }
    if (end < 0) continue; // 截断行：跳过，不当成样本
    try { out.push(JSON.parse(line.slice(i + 11, end + 1))); } catch (_) { /* 脏行跳过 */ }
    from = end + 1;
  }
  return out;
};

const parseLog = (text) => {
  const samples = [];
  for (const line of text.split(/\r?\n/)) {
    if (line.indexOf('USHIO_PERF ') < 0) continue;
    samples.push(...extractSamples(line));
  }
  return samples;
};

const pct = (sorted, p) => (sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * p))] : null);
const stat = (vals) => {
  const v = vals.filter((x) => typeof x === 'number' && Number.isFinite(x)).sort((a, b) => a - b);
  if (!v.length) return null;
  const r = (x) => Math.round(x * 100) / 100;
  return { n: v.length, p50: r(pct(v, 0.5)), p95: r(pct(v, 0.95)), max: r(v[v.length - 1]) };
};
const fmt = (label, s) => (s
  ? `  ${label.padEnd(16)} n=${String(s.n).padStart(4)}  p50=${String(s.p50).padStart(8)}ms  p95=${String(s.p95).padStart(8)}ms  max=${String(s.max).padStart(9)}ms`
  : `  ${label.padEnd(16)} （无样本）`);

const report = (samples, tag) => {
  const chain = samples.filter((s) => s.ev === 'chain');
  const settle = samples.filter((s) => s.ev === 'settle');
  const boot = samples.filter((s) => s.ev === 'boot');
  const wins = settle.map((s) => s.win || {});

  console.log(`\n=== USHIO_PERF ${tag ? `[${tag}] ` : ''}样本 ${samples.length} 条（chain ${chain.length} / settle ${settle.length} / boot ${boot.length}）===`);
  if (boot.length) {
    const b = boot[boot.length - 1];
    console.log(`  开档: crepe.create=${b.crepeCreateMs}ms  源字符=${b.sourceChars}  全文=${b.fullChars}  渐进渲染=${b.progressive ? '是' : '否'}  long-frame 探针=${b.longFrameObserver ? '可用' : '不可用'}`);
  }
  const chars = settle.map((s) => s.chars).filter(Boolean);
  const blocks = settle.map((s) => s.topBlocks).filter(Boolean);
  if (chars.length) console.log(`  文档规模: ${Math.max(...chars)} 字符 / ${Math.max(...blocks)} 顶层块`);

  console.log('\n-- 每停顿：markdownUpdated 串行链（阶段一改造的直接对象）--');
  console.log(fmt('链总计', stat(chain.map((s) => s.totalMs))));
  console.log(fmt('stripGhost', stat(chain.map((s) => s.stripMs))));
  console.log(fmt('wrapHtml', stat(chain.map((s) => s.wrapMs))));
  console.log(fmt('preprocessImg', stat(chain.map((s) => s.preImgMs))));
  console.log(fmt('replaceAll整篇', stat(chain.filter((s) => s.rebuildMs > 0).map((s) => s.rebuildMs))));
  const hits = chain.filter((s) => s.sanitizeHit).length;
  const rebuilds = chain.filter((s) => s.fullRebuild).length;
  console.log(`  code_sanitized 命中 ${hits}/${chain.length} 次；其中整篇重建 ${rebuilds} 次`);

  console.log('\n-- 每停顿：notifyRenderComplete 的 rAF 收尾 --');
  console.log(fmt('syncRenderedDom', stat(settle.map((s) => s.syncMs))));
  console.log(fmt('emitOutline', stat(settle.map((s) => s.outlineMs))));
  console.log(fmt('activeHints', stat(settle.map((s) => s.hintMs))));
  console.log(fmt('historyState', stat(settle.map((s) => s.historyMs))));
  console.log(fmt('收尾总计', stat(settle.map((s) => s.settleTotalMs))));
  console.log(fmt('按键→收尾', stat(settle.map((s) => s.sinceKeyMs))));

  console.log('\n-- 每帧路径（停顿窗口内累计）--');
  console.log(fmt('hints 均次', stat(wins.map((w) => w.hintAvgMs))));
  console.log(fmt('caret 均次', stat(wins.map((w) => w.caretAvgMs))));
  console.log(`  窗口内 hint 调用合计=${wins.reduce((a, w) => a + (w.hintCalls || 0), 0)}，caret 合计=${wins.reduce((a, w) => a + (w.caretCalls || 0), 0)}`);
  console.log(fmt('最长帧', stat(wins.map((w) => w.longestFrameMs))));

  const perSettle = settle.map((s) => (s.chainTotalMs || 0) + (s.settleTotalMs || 0));
  const chainBySettle = new Map();
  for (const c of chain) chainBySettle.set(c.t, (chainBySettle.get(c.t) || 0) + (c.totalMs || 0));
  const total = stat(settle.map((s) => (s.settleTotalMs || 0) + (chainBySettle.get(s.t) || 0)));
  console.log('\n-- 与 docs/milkdown-performance-baseline.md 阈值对照（输入延迟）--');
  if (total) {
    console.log(`  每停顿 JS 合计: p50=${total.p50}ms p95=${total.p95}ms max=${total.max}ms`);
    console.log(`  阈值 Avg<=120ms / P95<=220ms / Max<=350ms  =>  ${total.p95 <= 220 && total.max <= 350 ? 'PASS' : 'FAIL'}`);
  } else {
    console.log('  无样本，未测到（不要拿空表当通过）');
  }
};

let text = '';
if (args.parse) {
  text = fs.readFileSync(args.parse, 'utf8');
} else if (args.adb) {
  adb(['logcat', '-c']);
  console.log(`清空 logcat；开始 ${args.keys} 次按键（间隔 ${args.gap}ms）。请在 3 秒内确认编辑器已获焦。`);
  yieldSleep(3000);
  for (let i = 0; i < args.keys; i++) {
    adb(['shell', 'input', 'keyevent', 'KEYCODE_A']);
    yieldSleep(args.gap);
  }
  yieldSleep(1200);
  text = adb(['logcat', '-d', '-s', 'flutter', 'chromium']).stdout || '';
} else {
  console.error('需要 --parse <log-file> 或 --adb <serial>');
  process.exit(2);
}

function yieldSleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

const sizeOf = (s) => (typeof s.chars === 'number' ? s.chars
  : (typeof s.fullChars === 'number' ? s.fullChars : null));

let samples = parseLog(text);
// 冷启动采样会混进预热 WebView 的 4 字符空文档样本；不按规模过滤的话 P50 会被
// 空文档拉低，得出「很快」的假结论。
if (args.minChars > 0) {
  const before = samples.length;
  samples = samples.filter((s) => {
    const size = sizeOf(s);
    return size === null ? true : size >= args.minChars;
  });
  console.log(`按 --min-chars ${args.minChars} 过滤：${before} -> ${samples.length} 条样本`);
}
if (args.file) fs.writeFileSync(args.file, text, 'utf8');
if (!samples.length) {
  console.error('没解析到任何 USHIO_PERF 样本。检查：profile 包是否装上、编辑器是否开着、logcat 标签是否含 flutter/chromium。');
  process.exit(1);
}
report(samples, args.tag);
console.log(`\n原始样本 JSON 可行版：\n${samples.slice(-6).map((s) => JSON.stringify(s)).join('\n')}`);
