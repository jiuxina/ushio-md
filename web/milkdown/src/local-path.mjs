/**
 * 本地文件路径 / 代理 URL 的纯字符串处理。从 main.js 原样外移（Phase 0，行为不变）。
 * 搬迁前这些函数读模块级的 currentBaseDirectory；现在改为显式形参，由调用方传入。
 */

export const LOCAL_FILE_SCHEME = 'ushio-local-file';

export const decodeFileUriPath = (value) => {
  if (typeof value !== 'string' || !value.startsWith('file://')) return '';
  try {
    return decodeURIComponent(new URL(value).pathname || '');
  } catch (_) {
    return value.replace(/^file:\/\//i, '');
  }
};

export const normalizeLocalFsPath = (value) => {
  if (typeof value !== 'string') return '';
  const normalized = value.trim().replace(/\\/g, '/');
  if (!normalized) return '';
  if (/^\/[A-Za-z]:\//.test(normalized)) {
    return normalized.slice(1);
  }
  return normalized;
};

export const normalizeBaseDirectoryPath = (baseDirectory) => {
  if (typeof baseDirectory !== 'string' || !baseDirectory.trim()) return '';
  const trimmed = baseDirectory.trim();
  if (trimmed.startsWith('file://')) {
    return normalizeLocalFsPath(decodeFileUriPath(trimmed));
  }
  return normalizeLocalFsPath(trimmed);
};

export const toAbsoluteLocalPath = (pathLike, baseDirectory) => {
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
  const base = normalizeBaseDirectoryPath(baseDirectory);
  if (!base) return '';
  const normalizedBase = base.replace(/\/+$/, '');
  const normalizedRaw = raw.replace(/\\/g, '/').replace(/^\.\//, '');
  return `${normalizedBase}/${normalizedRaw}`;
};

export const buildLocalFileProxyUrl = (absolutePath) => {
  if (typeof absolutePath !== 'string' || !absolutePath) return '';
  return `${LOCAL_FILE_SCHEME}://local?path=${encodeURIComponent(absolutePath)}`;
};

/**
 * Pre-process markdown to replace relative image URLs with custom scheme URLs.
 * This ensures Milkdown renders the correct URLs from the start, avoiding the
 * browser trying to load relative URLs from localhost:8080.
 */
export const preprocessImageUrlsInMarkdown = (markdown, baseDirectory) => {
  if (typeof markdown !== 'string' || !markdown.includes('![')) return markdown;
  if (!baseDirectory) return markdown;

  const lines = markdown.split('\n');
  const result = [];
  let activeFence = null;
  const imagePattern = /(!\[[^\]]*]\()([^)\n]+)(\))/g;

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
      result.push(line);
      continue;
    }
    if (activeFence) {
      result.push(line);
      continue;
    }

    // Replace relative image URLs with custom scheme URLs
    const processedLine = line.replace(imagePattern, (match, prefix, src, suffix) => {
      const trimmedSrc = src.trim();
      // Skip if already a custom scheme URL, external URL, data URI, or absolute path
      if (trimmedSrc.startsWith(LOCAL_FILE_SCHEME + '://')) return match;
      if (trimmedSrc.startsWith('http://') || trimmedSrc.startsWith('https://')) return match;
      if (trimmedSrc.startsWith('data:')) return match;
      if (trimmedSrc.startsWith('blob:')) return match;
      if (trimmedSrc.startsWith('/')) return match;
      if (/^[A-Za-z]:[\\/]/.test(trimmedSrc)) return match;

      // Convert relative path to custom scheme URL
      const absolutePath = toAbsoluteLocalPath(trimmedSrc, baseDirectory);
      if (!absolutePath) return match;
      const proxyUrl = buildLocalFileProxyUrl(absolutePath);
      if (!proxyUrl) return match;

      return `${prefix}${proxyUrl}${suffix}`;
    });
    result.push(processedLine);
  }

  return result.join('\n');
};
