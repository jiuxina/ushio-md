// Debug script to analyze the actual markdown content
// Run with: node "d:\download\xm\mdreader\web\milkdown\debug-actual-markdown.mjs"

const markdown = `## 我是标题

![1.00](images/JPEG_20260324_223740_5715113118730621642.jpg)

d
dfdddd

1

1
1

1

1

1
1
1
1

1

1

1

1

1

1
1
1

1

1
1

1

1

1

1
1
1

1
1
1
1

1
1

1

1
1
1
1
1

1
1
1
1

1

1
1
1

11
1
1

11

11
1
11
1
1
1
1
11
1
1
1
1
1
1
1
1
1
1
1
1
1
1
1
1
1
11
1
1
1
1

# 个

**好***写题*~~文本~~

1. <br />

* \[ ]

> <br />

\`

\`\`\`

[](https://example.com)
\`\`\`

\`

| 列1 | 列2 | 列3 |
| -- | -- | -- |
| 内容 | 内容 | 内容 |
| 内容 | 内容 | 内容 |

<br />

<br />

#`;

const collectMarkdownImageSources = (markdown) => {
  if (typeof markdown !== 'string' || !markdown.includes('![')) return [];
  const lines = markdown.split('\n');
  const result = [];
  let activeFence = null;
  const imagePattern = /!\[[^\]]*]\(([^)\n]+)\)/g;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i] || '';
    const trimmed = line.trim();
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
    if (activeFence) continue;

    imagePattern.lastIndex = 0;
    let match = imagePattern.exec(line);
    while (match) {
      const rawSrc = (match[1] || '').trim();
      if (rawSrc) {
        result.push(rawSrc);
      }
      match = imagePattern.exec(line);
    }
  }

  return result;
};

const collectFenceLanguages = (markdown) => {
  if (typeof markdown !== 'string' || (!markdown.includes('```') && !markdown.includes('~~~'))) return [];
  const lines = markdown.split('\n');
  const result = [];
  let inFence = false;
  const isFenceLine = (line) => /^\s*(```|~~~)/.test((line || '').trim());
  const extractFenceLanguageRaw = (line) => {
    const trimmed = (line || '').trim();
    const match = trimmed.match(/^(```|~~~)\s*([^\s`~]+)?/);
    if (!match) return '';
    return (match[2] || '').trim();
  };
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (!isFenceLine(line)) continue;
    if (!inFence) {
      result.push(extractFenceLanguageRaw(line));
    }
    inFence = !inFence;
  }
  return result;
};

console.log('=== Actual Markdown Analysis ===\n');

console.log('[Step 1] Markdown image sources:');
const imageSources = collectMarkdownImageSources(markdown);
console.log(`  Count: ${imageSources.length}`);
imageSources.forEach((src, i) => {
  console.log(`  [${i}]: ${src}`);
});

console.log('\n[Step 2] Fence languages:');
const fenceLanguages = collectFenceLanguages(markdown);
console.log(`  Count: ${fenceLanguages.length}`);
fenceLanguages.forEach((lang, i) => {
  console.log(`  [${i}]: "${lang}"`);
});

console.log('\n[Step 3] Key findings:');
console.log('  - Image count:', imageSources.length);
console.log('  - Code block count:', fenceLanguages.length);
console.log('  - Empty language code blocks:', fenceLanguages.filter(l => !l).length);

// Check for the problematic code block
console.log('\n[Step 4] Code block details:');
const lines = markdown.split('\n');
let inFence = false;
let fenceStart = -1;
let fenceCount = 0;
for (let i = 0; i < lines.length; i++) {
  const trimmed = lines[i].trim();
  if (/^(```|~~~)/.test(trimmed)) {
    if (!inFence) {
      fenceStart = i;
      fenceCount++;
      const langMatch = trimmed.match(/^(```|~~~)\s*([^\s`~]+)?/);
      const lang = langMatch ? (langMatch[2] || '').trim() : '';
      console.log(`  Code block ${fenceCount} at line ${i + 1}: language="${lang}"`);
    }
    inFence = !inFence;
  }
}
