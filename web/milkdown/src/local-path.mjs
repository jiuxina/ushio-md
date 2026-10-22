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

// 图片目标是「不含空白的非右括号串」或尖括号包裹；title 是可选的尾巴。
// 旧正则把 `pic.png "标题"` 整段当路径，改写了 src 也吃掉了 title。
const IMAGE_DESTINATION_PATTERN = /(!\[[^\]]*]\()(<[^>\n]*>|[^\s)\n]+)(\s+(?:"[^"\n]*"|'[^'\n]*'|\([^()\n]*\)))?(\s*\))/g;

const transformImageDestinations = (markdown, mapDestination) => {
  const lines = markdown.split('\n');
  const result = [];
  let activeFence = null;

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

    result.push(line.replace(
      IMAGE_DESTINATION_PATTERN,
      (match, prefix, destinationToken, titlePart, suffix) => {
        const bracketed = destinationToken.startsWith('<') && destinationToken.endsWith('>');
        const destination = bracketed ? destinationToken.slice(1, -1) : destinationToken;
        const replacement = mapDestination(destination);
        if (replacement == null) return match;
        const nextToken = bracketed ? `<${replacement}>` : replacement;
        return `${prefix}${nextToken}${titlePart || ''}${suffix}`;
      },
    ));
  }

  return result.join('\n');
};

/**
 * Pre-process markdown to replace relative image URLs with custom scheme URLs.
 * This ensures Milkdown renders the correct URLs from the start, avoiding the
 * browser trying to load relative URLs from localhost:8080.
 */
export const preprocessImageUrlsInMarkdown = (markdown, baseDirectory) => {
  if (typeof markdown !== 'string' || !markdown.includes('![')) return markdown;
  if (!baseDirectory) return markdown;

  return transformImageDestinations(markdown, (destination) => {
    const trimmedSrc = destination.trim();
    // Skip if already a custom scheme URL, external URL, data URI, or absolute path
    if (trimmedSrc.startsWith(LOCAL_FILE_SCHEME + '://')) return null;
    if (trimmedSrc.startsWith('http://') || trimmedSrc.startsWith('https://')) return null;
    if (trimmedSrc.startsWith('data:')) return null;
    if (trimmedSrc.startsWith('blob:')) return null;
    if (trimmedSrc.startsWith('/')) return null;
    if (/^[A-Za-z]:[\\/]/.test(trimmedSrc)) return null;

    // Convert relative path to custom scheme URL
    const absolutePath = toAbsoluteLocalPath(trimmedSrc, baseDirectory);
    if (!absolutePath) return null;
    return buildLocalFileProxyUrl(absolutePath) || null;
  });
};

/**
 * 序列化出口的反向映射：把代理 URL 还原成相对路径。代理 URL 只是渲染用的，
 * 落盘必须回到用户在文件里写的原样；否则只要编辑过一次，图片路径就被永久改写。
 */
export const deproxyImageUrlsInMarkdown = (markdown, baseDirectory) => {
  if (typeof markdown !== 'string' || !markdown.includes(`${LOCAL_FILE_SCHEME}://`)) return markdown;
  const base = normalizeBaseDirectoryPath(baseDirectory).replace(/\/+$/, '');
  if (!base) return markdown;

  return transformImageDestinations(markdown, (destination) => {
    if (!destination.startsWith(`${LOCAL_FILE_SCHEME}://`)) return null;
    let absolutePath = '';
    try {
      // searchParams.get 已经解码过一次，不能再 decodeURIComponent。
      absolutePath = new URL(destination).searchParams.get('path') || '';
    } catch (_) {
      return null;
    }
    if (!absolutePath || !absolutePath.startsWith(`${base}/`)) return null;
    return absolutePath.slice(base.length + 1);
  });
};
