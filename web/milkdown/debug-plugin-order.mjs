// Debug script to trace remark plugin order effects
// Run with: node "d:\download\xm\mdreader\web\milkdown\debug-plugin-order.mjs"

import { unified } from 'unified';
import remarkParse from 'remark-parse';

// Simulate the remarkImageBlockPlugin behavior
function visitImage(ast) {
  const visit = (tree, type, callback) => {
    if (tree.type === type) {
      callback(tree, 0, tree);
    }
    if (tree.children) {
      let i = 0;
      while (i < tree.children.length) {
        const node = tree.children[i];
        const result = callback(node, i, tree);
        if (result === 'skip') {
          i++;
        } else if (typeof result === 'number') {
          i = result;
        } else {
          i++;
        }
        visit(node, type, callback);
      }
    }
  };

  visit(ast, 'paragraph', (node, index, parent) => {
    if (node.children?.length !== 1) return;
    const firstChild = node.children[0];
    if (!firstChild || firstChild.type !== 'image') return;
    const { url, alt, title } = firstChild;
    const newNode = {
      type: 'image-block',
      url,
      alt,
      title
    };
    parent.children.splice(index, 1, newNode);
  });

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

console.log('=== Plugin Order Effects Debug ===\n');

testCases.forEach(testCase => {
  console.log(`\n--- ${testCase.name} ---`);
  console.log(`Input:\n${testCase.markdown}\n`);

  const processor = unified().use(remarkParse);
  const tree = processor.parse(testCase.markdown);

  console.log('Before visitImage:');
  console.log(JSON.stringify(tree, null, 2));

  const transformed = visitImage(JSON.parse(JSON.stringify(tree)));

  console.log('\nAfter visitImage:');
  console.log(JSON.stringify(transformed, null, 2));
});
