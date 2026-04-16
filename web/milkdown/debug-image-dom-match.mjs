// Debug script to trace the complete image matching issue
// Run with: node "d:\download\xm\mdreader\web\milkdown\debug-image-dom-match.mjs"

import { unified } from 'unified';
import remarkParse from 'remark-parse';
import remarkInlineLinks from 'remark-inline-links';

// Simulate the remarkImageBlockPlugin behavior
function visitImage(ast) {
  const nodesToReplace = [];

  // First, collect all nodes to replace
  const visit = (tree, parent = null, index = 0) => {
    if (tree.type === 'paragraph') {
      if (tree.children?.length === 1 && tree.children[0].type === 'image') {
        nodesToReplace.push({ node: tree, parent, index });
      }
    }
    if (tree.children) {
      tree.children.forEach((child, i) => {
        visit(child, tree, i);
      });
    }
  };

  visit(ast);

  // Then replace them
  for (const { node, parent, index } of nodesToReplace) {
    if (parent && parent.children) {
      const firstChild = node.children[0];
      const newNode = {
        type: 'image-block',
        url: firstChild.url,
        alt: firstChild.alt,
        title: firstChild.title
      };
      parent.children[index] = newNode;
    }
  }

  return ast;
}

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
];

// Simulate collectMarkdownImageSources from main.js
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

// Extract all images from AST (simulating DOM query)
function extractImagesFromAst(ast) {
  const images = [];

  const visit = (node, depth = 0) => {
    if (node.type === 'image' || node.type === 'image-block') {
      images.push({
        type: node.type,
        url: node.url,
        alt: node.alt,
        depth
      });
    }
    if (node.children) {
      node.children.forEach(child => visit(child, depth + 1));
    }
  };

  visit(ast);
  return images;
}

console.log('=== Image DOM Match Debug ===\n');

testCases.forEach(testCase => {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`--- ${testCase.name} ---`);
  console.log(`Input:\n${testCase.markdown}\n`);

  // Step 1: Collect from markdown source (what main.js does)
  const markdownImageSources = collectMarkdownImageSources(testCase.markdown);
  console.log(`\n[Step 1] Markdown image sources (from regex):`);
  markdownImageSources.forEach((src, i) => {
    console.log(`  [${i}]: ${src}`);
  });

  // Step 2: Parse and transform (what Milkdown does)
  const processor = unified().use(remarkParse);
  const tree = processor.parse(testCase.markdown);

  console.log(`\n[Step 2] Parsed AST (before remark-inline-links):`);
  console.log(JSON.stringify(tree, null, 2));

  // Step 3: Apply remark-inline-links
  const processorWithLinks = unified().use(remarkParse).use(remarkInlineLinks);
  const treeWithLinks = processorWithLinks.parse(testCase.markdown);
  const transformedWithLinks = processorWithLinks.runSync(treeWithLinks, testCase.markdown);

  console.log(`\n[Step 3] After remark-inline-links:`);
  console.log(JSON.stringify(transformedWithLinks, null, 2));

  // Step 4: Apply image-block transformation
  const treeWithImageBlock = visitImage(JSON.parse(JSON.stringify(transformedWithLinks)));

  console.log(`\n[Step 4] After remarkImageBlockPlugin:`);
  console.log(JSON.stringify(treeWithImageBlock, null, 2));

  // Step 5: Extract images from AST (simulating DOM query)
  const astImages = extractImagesFromAst(treeWithImageBlock);

  console.log(`\n[Step 5] Images in AST (simulating DOM query):`);
  astImages.forEach((img, i) => {
    console.log(`  [${i}]: type=${img.type}, url="${img.url}"`);
  });

  // Step 6: Show the matching that would happen
  console.log(`\n[Step 6] Index-based matching (current behavior):`);
  astImages.forEach((img, i) => {
    const matchedSrc = markdownImageSources[i];
    const match = img.url === matchedSrc ? '✓ MATCH' : '✗ MISMATCH';
    console.log(`  DOM[${i}] ("${img.url}") ↔ Markdown[${i}] ("${matchedSrc || 'N/A'}") → ${match}`);
  });
});
