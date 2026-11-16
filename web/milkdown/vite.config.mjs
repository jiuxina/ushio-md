import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';

// KaTeX 的 CSS 为每个字体家族声明 woff2 + woff + ttf 三份，目标 WebView 全部支持
// woff2，回退字体纯属死重（~1.1MB），且 ttf/woff 只有极少数设备才会用到。
function katexWoff2Only() {
  return {
    name: 'katex-woff2-only',
    enforce: 'pre',
    transform(code, id) {
      if (!id.includes('katex') || !id.endsWith('.css')) return null;
      const patched = code.replace(
        /url\(([^)]*\.woff2)\)\s*format\(["']woff2["']\)\s*,[^;}]*/g,
        'url($1) format("woff2")',
      );
      return patched === code ? null : { code: patched, map: null };
    },
  };
}

export default defineConfig({
  base: './',
  resolve: {
    alias: {
      // 用精选语言表替换全量注册表，砍掉 legacy-modes 与 20+ 个 lang-* 语法包。
      '@codemirror/language-data': fileURLToPath(
        new URL('./src/cm-languages.js', import.meta.url),
      ),
    },
  },
  plugins: [katexWoff2Only()],
  build: {
    target: 'es2020',
    cssCodeSplit: true,
    rollupOptions: {
      input: {
        editor: fileURLToPath(new URL('./index.html', import.meta.url)),
        pdfMath: fileURLToPath(new URL('./pdf-math.html', import.meta.url)),
      },
    },
    // 全部资源平铺在 dist 根目录：Flutter 的 assets/milkdown_web/ 声明不递归，
    // 且本地服务器按 documentRoot + path 直接映射。
    assetsDir: '',
    // 资源不内联成 base64：JS 拆成独立文件才能被 WebView 的 HTTP 缓存与 V8 代码缓存
    // 复用（内联脚本每次打开文档都要重新解析+编译 2.4MB），字体只在真正渲染公式时
    // 才需要下载。
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 4096,
    emptyOutDir: true,
  },
  server: {
    host: '0.0.0.0',
    port: 4173,
  },
});
