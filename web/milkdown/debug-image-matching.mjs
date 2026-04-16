// Debug script to trace image source matching
// Run with: node "d:\download\xm\mdreader\web\milkdown\debug-image-matching.mjs"

const testCases = [
  {
    name: '问题样例：标题 + 图片 + 链接',
    markdown: `# qaa.md

![1.00](images/JPEG_20260416_225916_5684911853037735770.jpg)

[链接文本](https://example.com)`,
  },
  {
    name: '对照组：只有图片',
    markdown: `![1.00](images/test.jpg)`,
  },
  {
    name: '对照组：标题 + 图片',
    markdown: `# 标题

![1.00](images/test.jpg)`,
  },
  {
    name: '对照组：图片 + 链接',
    markdown: `![1.00](images/test.jpg)

[链接文本](https://example.com)`,
  },
  {
    name: '两个图片测试',
    markdown: `# 标题

![图片1](images/image1.jpg)

中间文字

![图片2](images/image2.jpg)

[链接](https://example.com)`,
  },
];

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

console.log('=== Image Source Matching Debug ===\n');

testCases.forEach(testCase => {
  console.log(`\n--- ${testCase.name} ---`);
  console.log(`Input:\n${testCase.markdown}\n`);

  const sources = collectMarkdownImageSources(testCase.markdown);
  console.log(`Collected image sources (${sources.length}):`);
  sources.forEach((src, i) => {
    console.log(`  [${i}]: ${src}`);
  });
});
