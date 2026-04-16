// Debug script to trace preprocessing functions
// Run with: node web/milkdown/debug-preprocessing.mjs

const testCases = [
  {
    name: '问题样例：标题 + 图片 + 链接',
    markdown: `# qaa.md

![1.00](images/JPEG_20260416_225916_5684911853037735770.jpg)

[链接文本](https://example.com)`,
  },
  {
    name: '代码块测试',
    markdown: `# 标题

\`\`\`javascript
const x = 1;
\`\`\`

[链接文本](https://example.com)`,
  },
];

// Replicate the preprocessing functions from main.js

const neutralizeSetextHeadingSyntax = (markdown) => {
  if (typeof markdown !== 'string' || !markdown.includes('\n')) return markdown;
  const lines = markdown.split('\n');
  if (lines.length < 2) return markdown;
  const output = [...lines];
  let activeFence = null;
  let changed = false;

  for (let i = 0; i < lines.length; i += 1) {
    const trimmed = (lines[i] || '').trim();
    const fenceMatch = trimmed.match(/^(`{3,}|~{3,})/);
    if (fenceMatch) {
      const marker = fenceMatch[1] || '';
      const markerChar = marker[0] || '';
      const markerLength = marker.length;
      if (!activeFence) {
        activeFence = { markerChar, markerLength };
      } else if (activeFence.markerChar === markerChar && markerLength >= activeFence.markerLength) {
        activeFence = null;
      }
      continue;
    }
    if (activeFence || i <= 0) continue;

    const underlineMatch = trimmed.match(/^(=+|-+)\s*$/);
    if (!underlineMatch) continue;

    const prevTrimmed = (lines[i - 1] || '').trim();
    if (!prevTrimmed) continue;
    if (/^(#{1,6})\s+/.test(prevTrimmed)) continue;
    if (/^\s*>/.test(prevTrimmed)) continue;
    if (/^\s*(```|~~~)/.test(prevTrimmed)) continue;

    const escaped = `${underlineMatch[1][0]}\\${underlineMatch[1].slice(1)}`;
    const suffixMatch = lines[i].match(/\s*$/);
    output[i] = `${escaped}${suffixMatch ? suffixMatch[0] : ''}`;
    changed = true;
  }

  return changed ? output.join('\n') : markdown;
};

const isFenceLine = (line) => /^\s*(```|~~~)/.test((line || '').trim());

const GHOST_CODE_LANGUAGE_MARKER_RE = /^[^\s`~]{1,40}$/;

const extractGhostCodeLanguage = (line) => {
  const token = (line || '').trim();
  const arrowMatch = token.match(/^(.+?)[▾▼▿▽⌄˅∨]$/u);
  if (!arrowMatch) return '';
  const language = (arrowMatch[1] || '').trim();
  if (!language) return '';
  if (!GHOST_CODE_LANGUAGE_MARKER_RE.test(language)) return '';
  return language;
};

const extractFenceLanguage = (line) => {
  const trimmed = (line || '').trim();
  const match = trimmed.match(/^(```|~~~)\s*([^\s`~]+)?/);
  if (!match) return '';
  return (match[2] || '').trim().toLowerCase();
};

const extractFenceLanguageRaw = (line) => {
  const trimmed = (line || '').trim();
  const match = trimmed.match(/^(```|~~~)\s*([^\s`~]+)?/);
  if (!match) return '';
  return (match[2] || '').trim();
};

const isFenceLanguageEchoLine = (line, expectedLanguage = '') => {
  const token = (line || '').trim().toLowerCase();
  if (!token || !GHOST_CODE_LANGUAGE_MARKER_RE.test(token)) return false;
  // Simplified version without KNOWN_CODE_LANGUAGES
  return Boolean(expectedLanguage) && token === expectedLanguage;
};

const stripGhostCodeLanguageMarkers = (markdown) => {
  if (typeof markdown !== 'string') return markdown;
  if (!markdown.includes('```') && !markdown.includes('~~~')) return markdown;
  const lines = markdown.split('\n');
  const output = [];
  let inFence = false;
  let currentFenceLanguage = '';
  let currentFenceOutputIndex = -1;
  let changed = false;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];

    if (isFenceLine(line)) {
      const wasInFence = inFence;
      inFence = !inFence;
      if (!wasInFence && inFence) {
        currentFenceLanguage = extractFenceLanguage(line);
        currentFenceOutputIndex = output.length;
      }
      output.push(line);

      if (wasInFence && !inFence) {
        let j = i + 1;
        let sawGhost = false;
        let sawBlank = false;
        let detectedGhostLanguage = '';
        while (j < lines.length) {
          const next = (lines[j] || '').trim();
          if (!next) {
            sawBlank = true;
            j += 1;
            continue;
          }
          const ghostLanguage = extractGhostCodeLanguage(next);
          if (ghostLanguage) {
            sawGhost = true;
            if (!detectedGhostLanguage) {
              detectedGhostLanguage = ghostLanguage;
            }
            j += 1;
            continue;
          }
          if (isFenceLanguageEchoLine(next, currentFenceLanguage)) {
            sawGhost = true;
            if (!detectedGhostLanguage) {
              detectedGhostLanguage = next;
            }
            j += 1;
            continue;
          }
          break;
        }

        if (sawGhost) {
          changed = true;
          const normalizedGhostLanguage = (detectedGhostLanguage || '').trim();
          if (
            !currentFenceLanguage
            && normalizedGhostLanguage
            && currentFenceOutputIndex >= 0
            && currentFenceOutputIndex < output.length
          ) {
            const openingFenceLine = output[currentFenceOutputIndex] || '';
            const patchedOpeningFenceLine = openingFenceLine.replace(
              /^(\s*)(```|~~~)(.*)$/u,
              (full, leading, marker, suffix) => {
                if ((suffix || '').trim()) return full;
                return `${leading}${marker} ${normalizedGhostLanguage}`;
              },
            );
            if (patchedOpeningFenceLine !== openingFenceLine) {
              output[currentFenceOutputIndex] = patchedOpeningFenceLine;
            }
          }
          if (sawBlank && output[output.length - 1] !== '') {
            output.push('');
          }
          i = j - 1;
        }
        currentFenceOutputIndex = -1;
      }
      continue;
    }

    output.push(line);
  }

  return changed ? output.join('\n') : markdown;
};

console.log('=== Preprocessing Functions Debug ===\n');

testCases.forEach(testCase => {
  console.log(`\n--- ${testCase.name} ---`);
  console.log(`Input:\n${testCase.markdown}\n`);

  const afterSetext = neutralizeSetextHeadingSyntax(testCase.markdown);
  console.log(`After neutralizeSetextHeadingSyntax:\n${afterSetext}\n`);
  console.log(`Changed: ${afterSetext !== testCase.markdown}`);

  const afterGhost = stripGhostCodeLanguageMarkers(afterSetext);
  console.log(`After stripGhostCodeLanguageMarkers:\n${afterGhost}\n`);
  console.log(`Changed: ${afterGhost !== afterSetext}`);

  console.log(`\nFinal output equals input: ${afterGhost === testCase.markdown}`);
});
