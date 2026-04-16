// Debug script to trace the parsing issue
// Run with: node --experimental-vm-modules web/milkdown/debug-parsing.mjs

import { unified } from 'unified';
import remarkParse from 'remark-parse';
import remarkInlineLinks from 'remark-inline-links';

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
    name: '代码块测试：标题 + 代码块 + 链接',
    markdown: `# 标题

\`\`\`javascript
const x = 1;
\`\`\`

[链接文本](https://example.com)`,
  },
];

function processMarkdown(markdown) {
  const processor = unified()
    .use(remarkParse)
    .use(remarkInlineLinks);

  const tree = processor.parse(markdown);
  const transformed = processor.runSync(tree, markdown);

  return { tree, transformed };
}

function inspectNode(node, depth = 0) {
  const indent = '  '.repeat(depth);
  let result = '';

  if (node.type === 'image') {
    result += `${indent}image: url="${node.url}" alt="${node.alt || ''}"\n`;
  } else if (node.type === 'link') {
    result += `${indent}link: url="${node.url}"\n`;
    if (node.children) {
      node.children.forEach(child => {
        result += inspectNode(child, depth + 1);
      });
    }
  } else if (node.type === 'code') {
    result += `${indent}code: lang="${node.lang || ''}" value="${node.value?.substring(0, 50)}..."\n`;
  } else if (node.type === 'heading') {
    result += `${indent}heading: depth=${node.depth}\n`;
    if (node.children) {
      node.children.forEach(child => {
        result += inspectNode(child, depth + 1);
      });
    }
  } else if (node.type === 'paragraph') {
    result += `${indent}paragraph:\n`;
    if (node.children) {
      node.children.forEach(child => {
        result += inspectNode(child, depth + 1);
      });
    }
  } else if (node.type === 'text') {
    result += `${indent}text: "${node.value}"\n`;
  } else {
    result += `${indent}${node.type}\n`;
    if (node.children) {
      node.children.forEach(child => {
        result += inspectNode(child, depth + 1);
      });
    }
  }

  return result;
}

console.log('=== Milkdown Parsing Debug ===\n');

testCases.forEach(testCase => {
  console.log(`\n--- ${testCase.name} ---`);
  console.log(`Input:\n${testCase.markdown}\n`);

  try {
    const { tree, transformed } = processMarkdown(testCase.markdown);

    console.log('Parsed tree (before remark-inline-links):');
    console.log(JSON.stringify(tree, null, 2));

    console.log('\nTransformed tree (after remark-inline-links):');
    console.log(inspectNode(transformed));

  } catch (error) {
    console.error('Error:', error.message);
    console.error(error.stack);
  }
});
