// Debug script to trace complete transformation chain
// Run with: node "d:\download\xm\mdreader\web\milkdown\debug-transform-chain.mjs"

import { unified } from 'unified';
import remarkParse from 'remark-parse';
import remarkInlineLinks from 'remark-inline-links';

// Simulate the remarkImageBlockPlugin behavior (from @milkdown/components)
function visitImage(ast) {
  const nodesToReplace = [];

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

// Simulate parseMarkdown runner (from @milkdown/components/image-block)
function parseImageBlock(node) {
  const src = node.url;
  const caption = node.title;
  let ratio = Number(node.alt || 1);
  if (Number.isNaN(ratio) || ratio === 0) ratio = 1;
  return {
    type: 'image-block-node',
    attrs: { src, caption, ratio }
  };
}

// Simulate parseMarkdown runner for inline image (from @milkdown/preset-commonmark)
function parseInlineImage(node) {
  const url = node.url;
  const alt = node.alt;
  const title = node.title;
  return {
    type: 'image-node',
    attrs: { src: url, alt, title }
  };
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
  {
    name: '图片 + 链接（无标题）',
    markdown: `![1.00](images/test.jpg)

[链接文本](https://example.com)`,
  },
];

console.log('=== Complete Transform Chain Debug ===\n');

testCases.forEach(testCase => {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`--- ${testCase.name} ---`);
  console.log(`Input:\n${testCase.markdown}\n`);

  // Step 1: Parse with remark
  const processor = unified().use(remarkParse).use(remarkInlineLinks);
  const tree = processor.parse(testCase.markdown);
  const transformed = processor.runSync(tree, testCase.markdown);

  console.log('[Step 1] After remark-parse + remark-inline-links:');
  console.log(JSON.stringify(transformed, null, 2));

  // Step 2: Apply remarkImageBlockPlugin
  const treeWithImageBlock = visitImage(JSON.parse(JSON.stringify(transformed)));

  console.log('\n[Step 2] After remarkImageBlockPlugin:');
  console.log(JSON.stringify(treeWithImageBlock, null, 2));

  // Step 3: Simulate parseMarkdown (what Milkdown does internally)
  console.log('\n[Step 3] Simulated ProseMirror node attrs:');

  const visitForParsing = (node) => {
    if (node.type === 'image-block') {
      const pmNode = parseImageBlock(node);
      console.log(`  image-block: attrs = ${JSON.stringify(pmNode.attrs)}`);
    } else if (node.type === 'image') {
      const pmNode = parseInlineImage(node);
      console.log(`  image (inline): attrs = ${JSON.stringify(pmNode.attrs)}`);
    }
    if (node.children) {
      node.children.forEach(visitForParsing);
    }
  };

  visitForParsing(treeWithImageBlock);

  // Step 4: Check for potential issues
  console.log('\n[Step 4] Analysis:');

  const allImages = [];
  const visitCollect = (node) => {
    if (node.type === 'image-block') {
      allImages.push({ type: 'image-block', url: node.url });
    } else if (node.type === 'image') {
      allImages.push({ type: 'image', url: node.url });
    }
    if (node.children) {
      node.children.forEach(visitCollect);
    }
  };
  visitCollect(treeWithImageBlock);

  if (allImages.length === 0) {
    console.log('  WARNING: No images found in AST!');
  } else {
    allImages.forEach((img, i) => {
      console.log(`  Image ${i}: type="${img.type}", url="${img.url}"`);
    });
  }
});
