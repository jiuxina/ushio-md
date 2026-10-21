/**
 * HTML 块：真正的 ProseMirror 节点，取代「包成 ```html-block 伪代码块」的旧做法。
 *
 * 旧做法的代价（实测，见 docs/milkdown-performance-baseline.md §5.12/§5.13）：
 * 每个 HTML 块会拿到一个真 CodeMirror 实例和一个 Vue 组件（桌面 2.94ms/块挂载
 * 外加一段异步重高亮尾巴），然后这个 DOM 又被隐藏、内容改在 overlay 里显示；
 * 并且 ```html-block 围栏会随序列化写进用户的 .md 文件。
 *
 * 载入边界仍然会把裸 HTML 包成围栏（wrapHtmlBlocksInCodeFence），因为 CommonMark
 * 的 HTML block 在块内空行处就会结束，不包会被截断。区别只在：
 * - 解析时由这里的 remark 插件把伪围栏改写成独立 mdast 类型，交给独立节点承载；
 * - 序列化时直接吐 mdast `html`，于是落盘的是原样 HTML，没有伪围栏。
 *
 * toDOM 刻意保留 `milkdown-code-block` 这个类名和 `pre[data-language="html-block"]`
 * 结构：渲染收尾里的 overlay 机器（隐藏规则、语言判定、占位高回写）全靠这两个钩子
 * 定位目标，保持形状不变才能把改动面限制在「不再实例化编辑器」这一件事上。
 */
import { $nodeSchema, $remark } from '@milkdown/utils';

export const HTML_BLOCK_LANGUAGE = 'html-block';
export const HTML_BLOCK_NODE = 'ushio_html_block';

/** 伪围栏在 mdast 里的中转类型。独立命名是为了不去和 commonmark 的 code_block 抢匹配。 */
const MDAST_HTML_BLOCK = 'ushioHtmlBlock';

const isHtmlBlockFence = (node) => node.type === 'code'
  && String(node.lang || '').trim().toLowerCase() === HTML_BLOCK_LANGUAGE;

const rewriteHtmlBlockFences = (tree) => {
  const walk = (parent) => {
    const children = parent.children;
    if (!Array.isArray(children)) return;
    for (let i = 0; i < children.length; i += 1) {
      const child = children[i];
      if (isHtmlBlockFence(child)) {
        children[i] = { type: MDAST_HTML_BLOCK, value: typeof child.value === 'string' ? child.value : '' };
        continue;
      }
      if (child && child.children) walk(child);
    }
  };
  walk(tree);
};

export const remarkHtmlBlockFence = $remark('ushio-remark-html-block-fence', () => () => rewriteHtmlBlockFences);

export const ushioHtmlBlockSchema = $nodeSchema(HTML_BLOCK_NODE, () => ({
  atom: true,
  group: 'block',
  attrs: {
    value: { default: '', validate: 'string' },
  },
  toDOM: (node) => [
    'div',
    {
      class: 'milkdown-code-block',
      'data-ushio-html-block-slot': '1',
    },
    ['pre', { 'data-language': HTML_BLOCK_LANGUAGE }, node.attrs.value],
  ],
  parseDOM: [{
    tag: 'div[data-ushio-html-block-slot="1"]',
    getAttrs: (dom) => ({ value: dom.textContent || '' }),
  }],
  parseMarkdown: {
    match: ({ type }) => type === MDAST_HTML_BLOCK,
    runner: (state, node, type) => {
      state.addNode(type, { value: typeof node.value === 'string' ? node.value : '' });
    },
  },
  toMarkdown: {
    match: (node) => node.type.name === HTML_BLOCK_NODE,
    runner: (state, node) => {
      // mdast 的 html 节点会被 remark-stringify 原样写出，这就是「原样 round-trip」。
      state.addNode('html', undefined, node.attrs.value);
    },
  },
}));
