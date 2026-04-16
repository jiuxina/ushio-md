// Debug script to check remark-inline-links interaction with remarkImageBlockPlugin
// Run with: node "d:\download\xm\mdreader\web\milkdown\debug-remark-interaction.mjs"

import { unified } from 'unified';
import remarkParse from 'remark-parse';
import remarkInlineLinks from 'remark-inline-links';

// Simulate the remarkImageBlockPlugin behavior
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

const testCases = [
  {
    name: '问题样例：标题 + 图片 + 链接',
    markdown: `# qaa.md

![1.00](images/JPEG_20260416_225916_5684911853037735770.jpg)

[链接文本](https://example.com)`,
  },
  {
    name: '引用式链接测试',
    markdown: `# 标题

![图片][img-ref]

[链接文本](https://example.com)

[img-ref]: images/test.jpg`,
  },
];

console.log('=== Remark Plugin Interaction Debug ===\n');

testCases.forEach(testCase => {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`--- ${testCase.name} ---`);
  console.log(`Input:\n${testCase.markdown}\n`);

  // Test 1: Parse with remarkParse only
  const processor1 = unified().use(remarkParse);
  const tree1 = processor1.parse(testCase.markdown);
  console.log('[Step 1] After remark-parse:');
  console.log(JSON.stringify(tree1, (key, value) => {
    if (key === 'position') return undefined;
    return value;
  }, 2));

  // Test 2: Apply remark-inline-links
  const processor2 = unified().use(remarkParse).use(remarkInlineLinks);
  const tree2 = processor2.parse(testCase.markdown);
  const transformed2 = processor2.runSync(tree2, testCase.markdown);
  console.log('\n[Step 2] After remark-inline-links:');
  console.log(JSON.stringify(transformed2, (key, value) => {
    if (key === 'position') return undefined;
    return value;
  }, 2));

  // Test 3: Apply image-block transformation
  const tree3 = visitImage(JSON.parse(JSON.stringify(transformed2)));
  console.log('\n[Step 3] After remarkImageBlockPlugin:');
  console.log(JSON.stringify(tree3, (key, value) => {
    if (key === 'position') return undefined;
    return value;
  }, 2));

  // Extract image info
  console.log('\n[Step 4] Image info extraction:');
  const extractImages = (node, depth = 0) => {
    if (node.type === 'image' || node.type === 'image-block') {
      console.log(`  Found ${node.type}: url="${node.url}" alt="${node.alt}"`);
    }
    if (node.children) {
      node.children.forEach(child => extractImages(child, depth + 1));
    }
  };
  extractImages(tree3);
});
