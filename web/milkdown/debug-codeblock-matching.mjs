// Debug script to check code block language matching
// Run with: node "d:\download\xm\mdreader\web\milkdown\debug-codeblock-matching.mjs"

const isFenceLine = (line) => /^\s*(```|~~~)/.test((line || '').trim());

const extractFenceLanguageRaw = (line) => {
  const trimmed = (line || '').trim();
  const match = trimmed.match(/^(```|~~~)\s*([^\s`~]+)?/);
  if (!match) return '';
  return (match[2] || '').trim();
};

const collectFenceLanguages = (markdown) => {
  if (typeof markdown !== 'string' || (!markdown.includes('```') && !markdown.includes('~~~'))) return [];
  const lines = markdown.split('\n');
  const result = [];
  let inFence = false;
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (!isFenceLine(line)) continue;
    if (!inFence) {
      result.push(extractFenceLanguageRaw(line));
    }
    inFence = !inFence;
  }
  return result;
};

const testCases = [
  {
    name: '代码块测试：标题 + 代码块 + 链接',
    markdown: `# 标题

\`\`\`javascript
const x = 1;
\`\`\`

[链接文本](https://example.com)`,
    // Simulated DOM state - what Milkdown renders
    domCodeBlocks: [
      { language: 'javascript' }  // Expected: should match
    ],
  },
  {
    name: '代码块测试：标题 + 代码块 + 链接 (语言丢失)',
    markdown: `# 标题

\`\`\`javascript
const x = 1;
\`\`\`

[链接文本](https://example.com)`,
    // Simulated DOM state - language not detected
    domCodeBlocks: [
      { language: '' }  // Missing language in DOM
    ],
  },
  {
    name: '多个代码块测试',
    markdown: `# 标题

\`\`\`python
print("hello")
\`\`\`

中间文字

\`\`\`javascript
const x = 1;
\`\`\`

[链接文本](https://example.com)`,
    domCodeBlocks: [
      { language: 'python' },
      { language: 'javascript' }
    ],
  },
];

console.log('=== Code Block Language Matching Debug ===\n');

testCases.forEach(testCase => {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`--- ${testCase.name} ---`);
  console.log(`Input:\n${testCase.markdown}\n`);

  // Step 1: Collect from markdown
  const fenceLanguages = collectFenceLanguages(testCase.markdown);
  console.log('[Step 1] Fence languages from markdown:');
  fenceLanguages.forEach((lang, i) => {
    console.log(`  [${i}]: "${lang}"`);
  });

  // Step 2: Simulate DOM query
  console.log('\n[Step 2] DOM code blocks (simulated):');
  testCase.domCodeBlocks.forEach((block, i) => {
    console.log(`  [${i}]: language="${block.language}"`);
  });

  // Step 3: Simulate matching logic
  console.log('\n[Step 3] Matching analysis:');
  testCase.domCodeBlocks.forEach((domBlock, codeBlockIndex) => {
    const markdownLanguage = fenceLanguages[codeBlockIndex] || '';
    const domLanguage = domBlock.language;

    console.log(`  Code block ${codeBlockIndex}:`);
    console.log(`    DOM language:      "${domLanguage}"`);
    console.log(`    Markdown language: "${markdownLanguage}"`);

    // This is the fallback chain from main.js
    const finalLanguage = domLanguage || markdownLanguage;
    console.log(`    Final language:    "${finalLanguage}"`);

    if (domLanguage && domLanguage !== markdownLanguage && markdownLanguage) {
      console.log(`    ⚠️ WARNING: DOM language differs from markdown!`);
    }
    if (!domLanguage && markdownLanguage) {
      console.log(`    ℹ️ Using markdown source as fallback`);
    }
  });

  // Step 4: Check for index mismatch
  console.log('\n[Step 4] Index mismatch check:');
  const markdownCount = fenceLanguages.length;
  const domCount = testCase.domCodeBlocks.length;
  if (markdownCount !== domCount) {
    console.log(`  ⚠️ COUNT MISMATCH: Markdown has ${markdownCount} code blocks, DOM has ${domCount}`);
  } else {
    console.log(`  ✓ Count matches: ${markdownCount} code blocks`);
  }
});
