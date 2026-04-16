// Debug script to simulate syncRenderedDom behavior
// Run with: node "d:\download\xm\mdreader\web\milkdown\debug-sync-rendered-dom.mjs"

// Replicate key functions from main.js

const LOCAL_FILE_SCHEME = 'ushio-local-file';

const sanitizeImageSource = (src) => {
  if (typeof src !== 'string') return '';
  const trimmed = src.trim();
  if (!trimmed) return '';
  const markdownTitleMatch = trimmed.match(/^(\S+)\s+["'"""][\s\S]*["'"""]$/);
  if (markdownTitleMatch && markdownTitleMatch[1]) {
    return markdownTitleMatch[1].trim();
  }
  const firstSpace = trimmed.indexOf(' ');
  if (firstSpace > 0) {
    const suffix = trimmed.slice(firstSpace + 1).trim();
    if (suffix.startsWith('"') || suffix.startsWith("'") || suffix.startsWith('"')) {
      return trimmed.slice(0, firstSpace).trim();
    }
  }
  return trimmed;
};

const isExternalHref = (href) => {
  if (typeof href !== 'string') return false;
  return /^(?:https?:|\/\/)/i.test(href);
};

let currentBaseDirectory = 'D:/download/xm/mdreader/docs/qaa';

const normalizeLocalFsPath = (value) => {
  if (typeof value !== 'string') return '';
  const normalized = value.trim().replace(/\\/g, '/');
  if (!normalized) return '';
  if (/^\/[A-Za-z]:\//.test(normalized)) {
    return normalized.slice(1);
  }
  return normalized;
};

const normalizeBaseDirectoryPath = (baseDirectory) => {
  if (typeof baseDirectory !== 'string' || !baseDirectory.trim()) return '';
  const trimmed = baseDirectory.trim();
  if (trimmed.startsWith('file://')) {
    return normalizeLocalFsPath(decodeFileUriPath(trimmed));
  }
  return normalizeLocalFsPath(trimmed);
};

const toAbsoluteLocalPath = (pathLike) => {
  if (typeof pathLike !== 'string') return '';
  const raw = pathLike.trim();
  if (!raw) return '';
  if (raw.startsWith('file://')) {
    return normalizeLocalFsPath(decodeFileUriPath(raw));
  }
  if (/^[A-Za-z]:[\\/]/.test(raw)) {
    return normalizeLocalFsPath(raw);
  }
  if (raw.startsWith('/')) return raw;
  const base = normalizeBaseDirectoryPath(currentBaseDirectory);
  if (!base) return '';
  const normalizedBase = base.replace(/\/+$/, '');
  const normalizedRaw = raw.replace(/\\/g, '/').replace(/^\.\//, '');
  return `${normalizedBase}/${normalizedRaw}`;
};

const buildLocalFileProxyUrl = (absolutePath) => {
  if (typeof absolutePath !== 'string' || !absolutePath) return '';
  return `${LOCAL_FILE_SCHEME}://local?path=${encodeURIComponent(absolutePath)}`;
};

const resolveHref = (href) => {
  if (typeof href !== 'string') return '';
  if (isExternalHref(href)) return href;
  return href;
};

const resolveImageSrc = (src) => {
  const sanitized = sanitizeImageSource(src);
  if (!sanitized) return '';
  if (sanitized.startsWith(`${LOCAL_FILE_SCHEME}://`)) {
    return sanitized;
  }
  if (isExternalHref(sanitized) || sanitized.startsWith('data:') || sanitized.startsWith('blob:')) {
    return sanitized;
  }
  const absolutePath = toAbsoluteLocalPath(sanitized);
  if (!absolutePath) {
    return resolveHref(sanitized);
  }
  const proxyUrl = buildLocalFileProxyUrl(absolutePath);
  return proxyUrl || resolveHref(sanitized);
};

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

const testCases = [
  {
    name: '问题样例：标题 + 图片 + 链接',
    markdown: `# qaa.md

![1.00](images/JPEG_20260416_225916_5684911853037735770.jpg)

[链接文本](https://example.com)`,
    // Simulated DOM state - what ProseMirror renders
    domImages: [
      { src: 'images/JPEG_20260416_225916_5684911853037735770.jpg' }  // ProseMirror renders correctly
    ],
  },
  {
    name: '对照组：只有图片',
    markdown: `![1.00](images/test.jpg)`,
    domImages: [
      { src: 'images/test.jpg' }
    ],
  },
  {
    name: '问题场景模拟：DOM img src 为空',
    markdown: `# qaa.md

![1.00](images/JPEG_20260416_225916_5684911853037735770.jpg)

[链接文本](https://example.com)`,
    domImages: [
      { src: '' }  // Simulate empty src from ProseMirror
    ],
  },
];

console.log('=== syncRenderedDom Simulation ===\n');

testCases.forEach(testCase => {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`--- ${testCase.name} ---`);
  console.log(`Input:\n${testCase.markdown}\n`);

  // Step 1: Collect from markdown (what main.js does)
  const markdownImageSources = collectMarkdownImageSources(testCase.markdown);
  console.log('[Step 1] Markdown image sources:');
  markdownImageSources.forEach((src, i) => {
    console.log(`  [${i}]: ${src}`);
  });

  // Step 2: Simulate DOM query
  console.log('\n[Step 2] DOM images (simulated):');
  testCase.domImages.forEach((img, i) => {
    console.log(`  [${i}]: src="${img.src}"`);
  });

  // Step 3: Simulate syncRenderedDom processing
  console.log('\n[Step 3] syncRenderedDom processing:');
  testCase.domImages.forEach((domImg, imageIndex) => {
    const rawSrc = domImg.src || '';
    const sanitizedRawSrc = sanitizeImageSource(rawSrc);
    const markdownRawSrc = sanitizeImageSource(markdownImageSources[imageIndex] || '');

    console.log(`  Image ${imageIndex}:`);
    console.log(`    rawSrc:           "${rawSrc}"`);
    console.log(`    sanitizedRawSrc:  "${sanitizedRawSrc}"`);
    console.log(`    markdownRawSrc:   "${markdownRawSrc}"`);

    // This is the key logic from syncRenderedDom
    const preferredRawSrc = sanitizedRawSrc || markdownRawSrc || rawSrc;
    const resolvedSrc = resolveImageSrc(preferredRawSrc);
    const fallbackResolvedSrc = resolveImageSrc(markdownRawSrc || sanitizedRawSrc || rawSrc);

    console.log(`    preferredRawSrc:  "${preferredRawSrc}"`);
    console.log(`    resolvedSrc:      "${resolvedSrc}"`);
    console.log(`    fallbackResolvedSrc: "${fallbackResolvedSrc}"`);

    // Final result
    const finalSrc = resolvedSrc || domImg.src;
    console.log(`    FINAL src:        "${finalSrc}"`);

    // Check if there's a mismatch
    if (markdownRawSrc && rawSrc && rawSrc !== markdownRawSrc) {
      console.log(`    ⚠️ WARNING: DOM src differs from markdown src!`);
    }
    if (!sanitizedRawSrc && markdownRawSrc) {
      console.log(`    ℹ️ Using markdown source as fallback`);
    }
  });
});
