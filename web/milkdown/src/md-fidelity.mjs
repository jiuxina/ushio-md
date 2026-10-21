/**
 * Markdown 原样 round-trip 的定点修复。判据见 tools/roundtrip-fidelity.html。
 *
 * 三类改写会让「打开再保存」改掉用户文件，且都不是解析器的无损规范化：
 * 1. Crepe 的 image-block 把 mdast 的 alt 当作宽高比存储（toMarkdown 写
 *    `alt: ratio.toFixed(2)`），用户的 alt 文本在解析时就被丢掉 ⇒ 单独记一个 alt attr；
 * 2. commonmark 的 bullet_list 把 mdast 的 spread 原样（字符串 'false'）传给
 *    remark-stringify，而它按真值判断 ⇒ 每个紧凑列表都被插空行 ⇒ 显式转成布尔；
 * 3. ordered_list 的 parse 不读起始号、toMarkdown 硬编码 start: 1 ⇒ `3.` 变 `1.`。
 *
 * 其余规范化（`+`/`*` 统一成 `*`、`1)`→`1.`、Setext→ATX、引用链接展开、
 * 表格对齐空格、`---`→`***` 等）不改变语义，作为产品策略接受，不在本文件处理。
 */
import { $nodeSchema } from '@milkdown/utils';
import { bulletListAttr, listItemAttr, orderedListAttr } from '@milkdown/preset-commonmark';

const asBooleanSpread = (value) => value === true || value === 'true';

export const ushioBulletListSchema = $nodeSchema('bullet_list', (ctx) => ({
  content: 'listItem+',
  group: 'block',
  attrs: { spread: { default: false, validate: 'boolean' } },
  parseDOM: [{
    tag: 'ul',
    getAttrs: (dom) => ({ spread: dom.getAttribute('data-spread') === 'true' }),
  }],
  toDOM: (node) => [
    'ul',
    { ...ctx.get(bulletListAttr.key)(node), 'data-spread': node.attrs.spread },
    0,
  ],
  parseMarkdown: {
    match: ({ type, ordered }) => type === 'list' && !ordered,
    runner: (state, node, type) => {
      state.openNode(type, { spread: node.spread === true }).next(node.children).closeNode();
    },
  },
  toMarkdown: {
    match: (node) => node.type.name === 'bullet_list',
    runner: (state, node) => {
      state.openNode('list', undefined, {
        ordered: false,
        spread: asBooleanSpread(node.attrs.spread),
      }).next(node.content).closeNode();
    },
  },
}));

export const ushioOrderedListSchema = $nodeSchema('ordered_list', (ctx) => ({
  content: 'listItem+',
  group: 'block',
  attrs: {
    order: { default: 1, validate: 'number' },
    spread: { default: false, validate: 'boolean' },
  },
  parseDOM: [{
    tag: 'ol',
    getAttrs: (dom) => ({
      spread: dom.getAttribute('data-spread') === 'true',
      order: dom.hasAttribute('start') ? Number(dom.getAttribute('start')) : 1,
    }),
  }],
  toDOM: (node) => [
    'ol',
    {
      ...ctx.get(orderedListAttr.key)(node),
      ...(node.attrs.order === 1 ? {} : { start: node.attrs.order }),
      'data-spread': node.attrs.spread,
    },
    0,
  ],
  parseMarkdown: {
    match: ({ type, ordered }) => type === 'list' && !!ordered,
    runner: (state, node, type) => {
      state.openNode(type, {
        order: Number.isFinite(node.start) && node.start > 0 ? node.start : 1,
        spread: node.spread === true,
      }).next(node.children).closeNode();
    },
  },
  toMarkdown: {
    match: (node) => node.type.name === 'ordered_list',
    runner: (state, node) => {
      state.openNode('list', undefined, {
        ordered: true,
        start: Number(node.attrs.order) || 1,
        spread: asBooleanSpread(node.attrs.spread),
      }).next(node.content).closeNode();
    },
  },
}));

// listItem 的 spread 同样以字符串传给 remark-stringify，嵌套列表会因此被插空行
// （顶层列表的紧凑度由 list 节点决定，所以只有嵌套场景暴露）。
export const ushioListItemSchema = $nodeSchema('list_item', (ctx) => {
  // GFM 的 task-list 扩展给 list_item 加了 checked attr；覆盖同名 schema 时必须
  // 把这段行为一并发回来，否则任务列表会退化成普通项目符号。
  const baseDom = (node) => [
    'li',
    {
      ...ctx.get(listItemAttr.key)(node),
      'data-label': node.attrs.label,
      'data-list-type': node.attrs.listType,
      'data-spread': node.attrs.spread,
    },
    0,
  ];
  const taskDom = (node) => [
    'li',
    {
      'data-item-type': 'task',
      'data-label': node.attrs.label,
      'data-list-type': node.attrs.listType,
      'data-spread': node.attrs.spread,
      'data-checked': node.attrs.checked,
    },
    0,
  ];
  const baseAttrs = (node) => ({
    label: node.label != null ? `${node.label}.` : '•',
    listType: node.label != null ? 'ordered' : 'bullet',
    spread: node.spread === true,
  });
  return {
    group: 'listItem',
    content: 'paragraph block*',
    attrs: {
      label: { default: '•', validate: 'string' },
      listType: { default: 'bullet', validate: 'string' },
      spread: { default: true, validate: 'boolean' },
      checked: { default: null, validate: 'boolean|null' },
    },
    defining: true,
    parseDOM: [
      {
        tag: 'li[data-item-type="task"]',
        getAttrs: (dom) => ({
          label: dom.getAttribute('data-label'),
          listType: dom.getAttribute('data-list-type'),
          spread: dom.getAttribute('data-spread') === 'true',
          checked: dom.hasAttribute('data-checked') ? dom.getAttribute('data-checked') === 'true' : null,
        }),
      },
      {
        tag: 'li',
        getAttrs: (dom) => ({
          label: dom.getAttribute('data-label'),
          listType: dom.getAttribute('data-list-type'),
          spread: dom.getAttribute('data-spread') === 'true',
          checked: null,
        }),
      },
    ],
    toDOM: (node) => (node.attrs.checked == null ? baseDom(node) : taskDom(node)),
    parseMarkdown: {
      match: ({ type }) => type === 'listItem',
      runner: (state, node, type) => {
        state.openNode(type, {
          ...baseAttrs(node),
          checked: node.checked == null ? null : Boolean(node.checked),
        });
        state.next(node.children);
        state.closeNode();
      },
    },
    toMarkdown: {
      match: (node) => node.type.name === 'list_item',
      runner: (state, node) => {
        const spread = asBooleanSpread(node.attrs.spread);
        if (node.attrs.checked == null) {
          state.openNode('listItem', undefined, { spread });
        } else {
          state.openNode('listItem', undefined, {
            spread,
            label: node.attrs.label,
            listType: node.attrs.listType,
            checked: node.attrs.checked,
          });
        }
        state.next(node.content);
        state.closeNode();
      },
    },
  };
});

const IMAGE_DATA_TYPE = 'image-block';

export const ushioImageBlockSchema = $nodeSchema('image-block', () => ({
  inline: false,
  group: 'block',
  selectable: true,
  draggable: true,
  isolating: true,
  marks: '',
  atom: true,
  priority: 100,
  attrs: {
    src: { default: '', validate: 'string' },
    caption: { default: '', validate: 'string' },
    ratio: { default: 1, validate: 'number' },
    alt: { default: '', validate: 'string' },
  },
  parseDOM: [{
    tag: `img[data-type="${IMAGE_DATA_TYPE}"]`,
    getAttrs: (dom) => ({
      src: dom.getAttribute('src') || '',
      caption: dom.getAttribute('caption') || '',
      ratio: Number(dom.getAttribute('ratio') ?? 1),
      alt: dom.getAttribute('alt') || '',
    }),
  }],
  toDOM: (node) => ['img', { 'data-type': IMAGE_DATA_TYPE, ...node.attrs }],
  parseMarkdown: {
    match: ({ type }) => type === 'image-block',
    runner: (state, node, type) => {
      const alt = typeof node.alt === 'string' ? node.alt : '';
      let ratio = Number(alt);
      if (!Number.isFinite(ratio) || ratio === 0) ratio = 1;
      state.addNode(type, { src: node.url, caption: node.title || '', ratio, alt });
    },
  },
  toMarkdown: {
    match: (node) => node.type.name === 'image-block',
    runner: (state, node) => {
      const ratio = Number(node.attrs.ratio);
      state.openNode('paragraph');
      state.addNode('image', undefined, undefined, {
        title: node.attrs.caption,
        url: node.attrs.src,
        // 有原始 alt 就保留原文；没有才沿用 Crepe 把 ratio 写进 alt 的格式。
        alt: node.attrs.alt || `${(Number.isFinite(ratio) && ratio > 0 ? ratio : 1).toFixed(2)}`,
      });
      state.closeNode();
    },
  },
}));

/**
 * 只认「首行 ---、闭合 ---、中间至少一行 key:」的 YAML frontmatter。
 * 不要求 key 是为了不误伤「两个分隔线夹一段普通文字」；要求 key 能排除这种误判。
 */
const FRONTMATTER_PATTERN = /^(---\r?\n)([\s\S]*?)(\r?\n---[ \t]*)((?:\r?\n[ \t]*)*)/;

export const splitFrontmatter = (markdown) => {
  if (typeof markdown !== 'string') return { frontmatter: '', body: markdown };
  const match = FRONTMATTER_PATTERN.exec(markdown);
  if (!match) return { frontmatter: '', body: markdown };
  if (!/^[ \t]*[A-Za-z0-9_.-]+[ \t]*:/m.test(match[2])) return { frontmatter: '', body: markdown };
  return { frontmatter: match[0], body: markdown.slice(match[0].length) };
};
