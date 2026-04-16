// Debug script to trace image resolution
// Run with: node "d:\download\xm\mdreader\web\milkdown\debug-image-resolution.mjs"

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

const decodeFileUriPath = (value) => {
  if (typeof value !== 'string' || !value.startsWith('file://')) return '';
  try {
    return decodeURIComponent(new URL(value).pathname || '');
  } catch (_) {
    return value.replace(/^file:\/\//i, '');
  }
};

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

let currentBaseDirectory = '';

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
    baseDirectory: 'D:/download/xm/mdreader/docs/qaa',
  },
  {
    name: '对照组：只有图片',
    markdown: `![1.00](images/test.jpg)`,
    baseDirectory: 'D:/download/xm/mdreader/docs/qaa',
  },
];

console.log('=== Image Resolution Debug ===\n');

testCases.forEach(testCase => {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`--- ${testCase.name} ---`);
  console.log(`Base Directory: ${testCase.baseDirectory}`);
  console.log(`Input:\n${testCase.markdown}\n`);

  // Set base directory
  currentBaseDirectory = testCase.baseDirectory;

  // Step 1: Collect from markdown
  const markdownImageSources = collectMarkdownImageSources(testCase.markdown);
  console.log('[Step 1] Markdown image sources:');
  markdownImageSources.forEach((src, i) => {
    console.log(`  [${i}]: ${src}`);
  });

  // Step 2: Resolve each source
  console.log('\n[Step 2] Resolved image URLs:');
  markdownImageSources.forEach((src, i) => {
    const sanitized = sanitizeImageSource(src);
    const resolved = resolveImageSrc(src);
    console.log(`  [${i}]:`);
    console.log(`    Raw:       ${src}`);
    console.log(`    Sanitized: ${sanitized}`);
    console.log(`    Resolved:  ${resolved}`);
  });

  // Step 3: Simulate DOM matching
  console.log('\n[Step 3] Simulated DOM matching:');
  // In the problem case, DOM might have different order or count
  // Let's check what happens if DOM has fewer or more images

  // Scenario A: DOM img has no src initially (ProseMirror renders correctly)
  console.log('  Scenario A: DOM img has correct src from ProseMirror');
  const domImgSrc = markdownImageSources[0] || '';
  const markdownSrc = markdownImageSources[0] || '';
  const rawSrc = domImgSrc;
  const sanitizedRawSrc = sanitizeImageSource(rawSrc);
  const markdownRawSrc = sanitizeImageSource(markdownSrc);
  const preferredRawSrc = sanitizedRawSrc || markdownRawSrc || rawSrc;
  const resolvedSrc = resolveImageSrc(preferredRawSrc);
  console.log(`    DOM img src:     ${domImgSrc}`);
  console.log(`    Markdown src:    ${markdownSrc}`);
  console.log(`    Preferred raw:   ${preferredRawSrc}`);
  console.log(`    Resolved src:    ${resolvedSrc}`);
});
