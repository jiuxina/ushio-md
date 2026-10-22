/**
 * Phase 0 等价性裁判：markdown-scans.mjs / local-path.mjs 是从 main.js 原样外移的，
 * 对同一批语料必须与搬迁前的实现（legacy-scans.mjs，由 git HEAD 生成）产出逐字节相同的结果。
 * 后续阶段若改动这些扫描逻辑，本文件是唯一被允许出现「预期不同」断言的地方。
 */
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import { describe, expect, it } from 'vitest';

import * as legacy from './legacy-scans.mjs';
import {
  slugifyHeading,
  parseMarkdownOutline,
  isFenceLine,
  extractFenceLanguage,
  extractFenceLanguageRaw,
  extractGhostCodeLanguage,
  isFenceLanguageEchoLine,
  collectFenceLanguages,
  collectMarkdownImageSources,
  stripGhostCodeLanguageMarkers,
  wrapHtmlBlocksInCodeFence,
  setKnownCodeLanguages,
  findAppendSplitPoints,
} from '../markdown-scans.mjs';
import {
  decodeFileUriPath,
  normalizeLocalFsPath,
  normalizeBaseDirectoryPath,
  toAbsoluteLocalPath,
  buildLocalFileProxyUrl,
  preprocessImageUrlsInMarkdown,
  deproxyImageUrlsInMarkdown,
  LOCAL_FILE_SCHEME,
} from '../local-path.mjs';

setKnownCodeLanguages(legacy.KNOWN_CODE_LANGUAGES);

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../../..');

const synthetic = {
  'basic headings': '# Title\n\ntext\n\n## Sub 二\n\n### Deep\n',
  'setext headings': 'Title\n=====\n\nSub\n---\n\npara\n',
  'heading with trailing hashes': '# A ##\n\n### C ###\n',
  'duplicate headings': '## Same\n\n## Same\n\n## Same\n',
  'fence with hashes inside': '```\n# not a heading\n## nope\n```\n\nafter\n',
  'tilde fence': '~~~\n<div>x</div>\n~~~\n\n# real\n',
  'longer fence closes': '````\n```\nstill inside\n````\n\n# after\n',
  'unclosed fence': '# A\n\n```\n<div>never closed\n\n# B\n',
  'images mixed sources': '![a](rel/pic.png)\n\n![b](https://x.test/y.png)\n\n![c](data:image/png;base64,AAA)\n\n![d](/abs/z.png)\n\n![e](C:\\\\win\\\\p.png)\n',
  'image in fence ignored': '```\n![inside](fence.png)\n```\n\n![out](out.png)\n',
  'ghost language echo': '```\nconst a = 1;\n```\njs▾\n\n# after\n',
  'ghost arrow only': '```\nx\n```\n▾\n\ntext\n',
  'plain language name echo': '```\ncode\n```\n\njavascript\n\nmore\n',
  'blank line then ghost': '```\ncode\n```\n\npython▾\n\ntext\n',
  'html block div': 'para\n\n<div class="x">\n<p>hi</p>\n</div>\n\nafter\n',
  'html nested': '<div>\n  <div>\n    <p>a</p>\n  </div>\n</div>\n',
  'html table': '<table>\n<tr><td>a</td></tr>\n</table>\n',
  'html unclosed at eof': 'text\n\n<div>\n<p>no close\n',
  'html terminated by blanks': '<div>\n<p>a</p>\n</div>\n\n\nnext para\n',
  'inline html not wrapped': 'a <span>b</span> c\n\n<br>\n',
  'details summary': '<details>\n<summary>t</summary>\n<p>b</p>\n</details>\n',
  'html inside fence': '```\n<div>x</div>\n```\n\n<div>real</div>\n',
  'crlf doc': '# A\r\n\r\ntext\r\n\r\n<div>\r\n<p>x</p>\r\n</div>\r\n',
  'empty': '',
  'only newlines': '\n\n\n',
  'nonstring-ish': '![unterminated(pic\n\n#',
};

const realDocs = [];
for (const dir of ['docs', '.']) {
  const abs = path.join(repoRoot, dir);
  if (!fs.existsSync(abs)) continue;
  for (const name of fs.readdirSync(abs)) {
    if (!name.endsWith('.md')) continue;
    const file = path.join(abs, name);
    if (!fs.statSync(file).isFile()) continue;
    realDocs.push({ label: `${dir}/${name}`, text: fs.readFileSync(file, 'utf8') });
  }
}
if (realDocs.length === 0) throw new Error('no real markdown corpus found — test would be vacuous');

const corpus = [
  ...Object.entries(synthetic).map(([label, text]) => ({ label: `synthetic:${label}`, text })),
  ...realDocs,
];

describe('外移函数与搬迁前逐字节等价', () => {
  const cases = [
    ['slugifyHeading', slugifyHeading, legacy.slugifyHeading, (t) => t.split('\n')],
    ['parseMarkdownOutline', parseMarkdownOutline, legacy.parseMarkdownOutline, (t) => [t]],
    ['isFenceLine', isFenceLine, legacy.isFenceLine, (t) => t.split('\n')],
    ['extractFenceLanguage', extractFenceLanguage, legacy.extractFenceLanguage, (t) => t.split('\n')],
    ['extractFenceLanguageRaw', extractFenceLanguageRaw, legacy.extractFenceLanguageRaw, (t) => t.split('\n')],
    ['extractGhostCodeLanguage', extractGhostCodeLanguage, legacy.extractGhostCodeLanguage, (t) => t.split('\n')],
    ['isFenceLanguageEchoLine', isFenceLanguageEchoLine, legacy.isFenceLanguageEchoLine, (t) => t.split('\n')],
    ['collectFenceLanguages', collectFenceLanguages, legacy.collectFenceLanguages, (t) => [t]],
    ['collectMarkdownImageSources', collectMarkdownImageSources, legacy.collectMarkdownImageSources, (t) => [t]],
    ['stripGhostCodeLanguageMarkers', stripGhostCodeLanguageMarkers, legacy.stripGhostCodeLanguageMarkers, (t) => [t]],
    ['wrapHtmlBlocksInCodeFence', wrapHtmlBlocksInCodeFence, legacy.wrapHtmlBlocksInCodeFence, (t) => [t]],
  ];

  for (const [name, fn, legacyFn, split] of cases) {
    it(`${name} 在 ${corpus.length} 份语料上一致`, () => {
      for (const { label, text } of corpus) {
        for (const input of split(text)) {
          expect(fn(input), `${name} @ ${label}`).toEqual(legacyFn(input));
        }
      }
    });
  }
});

describe('路径与图片预处理等价（baseDirectory 由形参注入）', () => {
  const bases = ['', '/Documents/notes', 'file:///F:/xm/docs', 'F:\\xm\\docs\\', '/a/b/', 'C:/x'];
  const paths = ['pic.png', './pic.png', 'sub/pic.png', 'sub\\pic.png', '/abs.png', 'C:\\win.png', 'file:///F:/x/p.png', 'https://x.test/p.png'];

  it('path helpers 一致', () => {
    for (const v of [...paths, '', '  ', 'file://bad%']) {
      expect(decodeFileUriPath(v)).toBe(legacy.decodeFileUriPath(v));
      expect(normalizeLocalFsPath(v)).toBe(legacy.normalizeLocalFsPath(v));
      expect(buildLocalFileProxyUrl(v)).toBe(legacy.buildLocalFileProxyUrl(v));
    }
    for (const base of bases) {
      expect(normalizeBaseDirectoryPath(base)).toBe(legacy.normalizeBaseDirectoryPath(base));
      legacy.setCurrentBaseDirectory(base);
      for (const p of paths) {
        expect(toAbsoluteLocalPath(p, base), `toAbsoluteLocalPath(${p}, ${base})`).toBe(legacy.toAbsoluteLocalPath(p));
      }
    }
    legacy.setCurrentBaseDirectory('');
  });

  it('preprocessImageUrlsInMarkdown 一致（带 title 图片除外，见下一条）', () => {
    const docs = [...Object.values(synthetic), ...realDocs.map((d) => d.text)];
    // 2026-10-22 起 title 不再被旧正则吞进 URL（真机数据损坏修复），
    // 这是有意与搬迁前实现不同；含这类图片的文档由下一条单独断言。
    const titledImage = /!\[[^\]]*]\([^)\n]*\s+(?:"[^"\n]*"|'[^'\n]*'|\([^()\n]*\))\)/;
    for (const base of ['', '/Documents/notes', 'F:\\xm\\docs']) {
      legacy.setCurrentBaseDirectory(base);
      for (const text of docs) {
        if (titledImage.test(text)) continue;
        expect(preprocessImageUrlsInMarkdown(text, base)).toBe(legacy.preprocessImageUrlsInMarkdown(text));
      }
    }
    legacy.setCurrentBaseDirectory('');
  });

  it('带 title 的图片是有意改变：旧实现把 title 并进 URL，新实现保留', () => {
    const base = '/Documents/notes';
    const text = '![a](pic.png "t")';
    legacy.setCurrentBaseDirectory(base);
    expect(legacy.preprocessImageUrlsInMarkdown(text)).toContain(encodeURIComponent('pic.png "t"'));
    expect(preprocessImageUrlsInMarkdown(text, base)).toBe(
      `![a](${LOCAL_FILE_SCHEME}://local?path=${encodeURIComponent('/Documents/notes/pic.png')} "t")`,
    );
    legacy.setCurrentBaseDirectory('');
  });

  it('LOCAL_FILE_SCHEME 未变', () => {
    expect(LOCAL_FILE_SCHEME).toBe('ushio-local-file');
  });
});

describe('findAppendSplitPoints（追加式渲染的切点）', () => {
  const lineAt = (md, off) => md.slice(md.lastIndexOf('\n', off - 1) + 1, md.indexOf('\n', off) < 0 ? md.length : md.indexOf('\n', off));
  const blankBefore = (md, off) => md.slice(md.lastIndexOf('\n', off - 2) + 1, off).trim() === '';

  it('文档不够长时不切（回退整篇替换）', () => {
    expect(findAppendSplitPoints('# 短\n\n正文\n', 40)).toEqual([]);
    expect(findAppendSplitPoints('', 40)).toEqual([]);
    expect(findAppendSplitPoints(null, 40)).toEqual([]);
  });

  it('切点都在空行之后、且彼此间隔不小于 minChunk', () => {
    const md = Array.from({ length: 60 }, (_, i) => `段落 ${i} 内容够长可以撑满一个分片。\n\n`).join('');
    const cuts = findAppendSplitPoints(md, 120);
    expect(cuts.length).toBeGreaterThan(1);
    let prev = 0;
    for (const c of cuts) {
      expect(blankBefore(md, c), `cut@${c} 前一行应是空行`).toBe(true);
      expect(c - prev).toBeGreaterThanOrEqual(120);
      prev = c;
    }
    for (let i = 1; i < cuts.length; i++) expect(cuts[i]).toBeGreaterThan(cuts[i - 1]);
  });

  it('绝不切进代码围栏内部（哪怕里面有空行和列表样子行）', () => {
    const inner = Array.from({ length: 40 }, (_, i) => `- [ ] 围栏里的假列表 ${i}\n\n`).join('');
    const md = `前段 ${'x'.repeat(200)}\n\n\`\`\`md\n${inner}\`\`\`\n\n后段 ${'y'.repeat(200)}\n\n`;
    const cuts = findAppendSplitPoints(md, 120);
    const fenceStart = md.indexOf('```');
    const fenceEnd = md.lastIndexOf('```');
    for (const c of cuts) {
      expect(c < fenceStart || c > fenceEnd, `cut@${c} 落在围栏内`).toBe(true);
    }
  });

  it('切点后第一行是列表项时不切（会把同一个松散列表拆成两个）', () => {
    const prose = Array.from({ length: 20 }, (_, i) => `正文 ${i} ${'z'.repeat(20)}\n\n`).join('');
    const md = `${prose}- 甲\n\n- 乙\n\n- 丙\n\n结尾 ${'e'.repeat(200)}\n\n`;
    const listStart = md.indexOf('- 甲');
    const cuts = findAppendSplitPoints(md, 120);
    for (const c of cuts) {
      if (c > listStart && c < md.indexOf('结尾')) {
        expect(/^\s*(?:[-*+]|\d+[.)])\s/.test(lineAt(md, c)), `cut@${c} 后面是列表项`).toBe(false);
      }
    }
  });

  it('整篇只有一个大列表时不产生切点', () => {
    const md = Array.from({ length: 200 }, (_, i) => `- 项 ${i} ${'q'.repeat(30)}\n\n`).join('');
    expect(findAppendSplitPoints(md, 120)).toEqual([]);
  });

  it('切点紧邻代码围栏时不切（判据实测会让序列化多出空行）', () => {
    let md = '';
    for (let i = 1; i <= 200; i++) md += `\`\`\`js\nfunction f${i}() {\n  return ${i};\n}\n\`\`\`\n\n正文 ${i} ${'T'.repeat(60)}\n\n`;
    const cuts = findAppendSplitPoints(md, 200);
    for (const c of cuts) {
      // 切点前的块与后的块都不能以围栏开头
      const prevLineStart = md.lastIndexOf('\n', md.lastIndexOf('\n', c - 2) - 1) + 1;
      expect(md.slice(c, c + 4).trimStart().startsWith('```')).toBe(false);
      expect(md.slice(prevLineStart, prevLineStart + 4)).not.toBe('```j');
    }
    // 该语料里每个块边界都紧邻围栏，应当完全切不出来
    expect(cuts).toEqual([]);
  });

  it('分片拼接后与原文完全一致（切点必须无缝）', () => {
    const md = Array.from({ length: 80 }, (_, i) => (i % 7 === 0
      ? `## 标题 ${i}\n\n\`\`\`js\nconst x=${i};\n\`\`\`\n\n`
      : `段落 ${i} ${'w'.repeat(60)}\n\n`)).join('');
    const cuts = findAppendSplitPoints(md, 200);
    expect(cuts.length).toBeGreaterThan(0);
    let rebuilt = '';
    let prev = 0;
    for (const c of cuts) { rebuilt += md.slice(prev, c); prev = c; }
    rebuilt += md.slice(prev);
    expect(rebuilt).toBe(md);
  });
});

describe('记录当前语义（回归哨兵，非等价性）', () => {
  it('wrapHtml 是幂等的：已包成 html-block 的不会再包一层', () => {
    const once = wrapHtmlBlocksInCodeFence('<div>\n<p>x</p>\n</div>\n');
    expect(once).toBe('```html-block\n<div>\n<p>x</p>\n</div>\n```\n');
    expect(wrapHtmlBlocksInCodeFence(once)).toBe(once);
  });

  it('ghost 语言回显会被并入围栏信息', () => {
    expect(stripGhostCodeLanguageMarkers('```\nx\n```\njs▾\n')).toBe('``` js\nx\n```\n');
  });

  it('代码围栏里的 # 不会被当标题', () => {
    expect(parseMarkdownOutline('```\n# a\n```\n\n# b\n').map((h) => h.text)).toEqual(['b']);
  });

  it('html-block 伪围栏会出现在落盘串里（Phase 5 待修的保真缺口，此处锁定现状）', () => {
    expect(wrapHtmlBlocksInCodeFence('<table>\n<tr><td>a</td></tr>\n</table>\n')).toContain('```html-block');
  });

  it('相对图片会被改写成自定义 scheme 绝对路径（Phase 4 待修的保真缺口，此处锁定现状）', () => {
    legacy.setCurrentBaseDirectory('/Documents/notes');
    const out = preprocessImageUrlsInMarkdown('![a](pic.png)', '/Documents/notes');
    expect(out).toBe(`![a](${LOCAL_FILE_SCHEME}://local?path=${encodeURIComponent('/Documents/notes/pic.png')})`);
    legacy.setCurrentBaseDirectory('');
  });

  it('语料规模足以代表真实文档', () => {
    expect(realDocs.length).toBeGreaterThanOrEqual(10);
  });
});

describe('图片路径代理可逆（2026-10-22 真机发现）', () => {
  const base = '/Documents/notes';

  it('title 不进入代理 URL', () => {
    const out = preprocessImageUrlsInMarkdown('![说明文字](pic.png "图片标题")', base);
    expect(out).toBe(
      `![说明文字](${LOCAL_FILE_SCHEME}://local?path=${encodeURIComponent('/Documents/notes/pic.png')} "图片标题")`,
    );
  });

  it('代理 URL 在序列化出口还原为相对路径（含 title）', () => {
    const input = '![说明文字](images/pic.png "图片标题")\n';
    expect(deproxyImageUrlsInMarkdown(preprocessImageUrlsInMarkdown(input, base), base)).toBe(input);
  });

  it('围栏内的图片不参与代理，也不参与还原', () => {
    const input = '```\n![a](pic.png "t")\n```\n';
    expect(preprocessImageUrlsInMarkdown(input, base)).toBe(input);
    const proxied = `\`\`\`\n![a](${LOCAL_FILE_SCHEME}://local?path=${encodeURIComponent('/Documents/notes/pic.png')})\n\`\`\`\n`;
    expect(deproxyImageUrlsInMarkdown(proxied, base)).toBe(proxied);
  });
});
