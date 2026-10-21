/**
 * 代码块的 CodeMirror 延迟挂载。
 *
 * Crepe 的 CodeMirrorBlock 在 NodeView 构造函数里就 `new EditorView(...)`（每个代码块
 * 一个 CodeMirror + 一个 Vue app）。冷启动时哪怕整块在屏幕外也要付这笔钱：
 * §5.12 实测代码块同步挂载 +3.12ms/块，另有 ~3.5ms/块的异步语言装载，设备上放大 2.8–3.7×。
 *
 * 这里不重写 UI：包一层 NodeView，先用 <pre> 显示源码占位，满足任一条件再调用 Crepe
 * 原来的工厂函数挂载真正的节点视图：
 * - IntersectionObserver 判定进入视口（rootMargin 400px，滚到之前就已挂好）；
 * - 指针按下（用户要点语言选择/复制/编辑）；
 * - PM 调用 selectNode（键盘导航或点击选中）。
 *
 * 约束：真实 NodeView 没有 contentDOM、stopEvent 恒真，所以包装层也保持同样的契约；
 * idle 期 PM 不会碰内部 DOM，挂载后所有交互仍由 Crepe 自己处理。
 */
import { $view } from '@milkdown/utils';
import { codeBlockSchema } from '@milkdown/preset-commonmark';
import { codeBlockView } from '@milkdown/components/code-block';

const LAZY_ATTR = 'data-ushio-codeblock-lazy';

// 判据用：样式/计数类门禁需要所有代码块都进入真实形态，否则懒加载会把断言放水。
const lazyInstances = new Set();

class LazyCodeBlockView {
  constructor(node, view, getPos, createReal) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;
    this.createReal = createReal;
    this.real = null;
    lazyInstances.add(this);

    this.dom = document.createElement('div');
    this.dom.className = 'milkdown-code-block';
    this.dom.setAttribute('data-ushio-codeblock-host', '1');
    this.dom.setAttribute(LAZY_ATTR, '1');
    this.dom.setAttribute('contenteditable', 'false');

    this.pre = document.createElement('pre');
    this.code = document.createElement('code');
    this.pre.appendChild(this.code);
    this.dom.appendChild(this.pre);
    this.renderPlaceholder();

    this.onPointerDown = (event) => {
      event.preventDefault();
      this.mount();
    };
    this.dom.addEventListener('pointerdown', this.onPointerDown, true);

    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) this.mount();
    }, { rootMargin: '400px 0px' });
    this.observer.observe(this.dom);

    // 首屏兜底：IntersectionObserver 的首个回调要等一次渲染更新，后台标签页里可能迟迟不来。
    // 构造时 DOM 还没挂到文档上，所以等一拍再按几何判断一次。
    this.initialCheck = setTimeout(() => {
      this.initialCheck = null;
      if (this.real) return;
      const rect = this.dom.getBoundingClientRect();
      const viewportHeight = window.innerHeight || document.documentElement.clientHeight;
      if (rect.width > 0 && rect.bottom > -400 && rect.top < viewportHeight + 400) this.mount();
    }, 0);
  }

  renderPlaceholder() {
    const language = String(this.node.attrs?.language || '');
    this.code.textContent = this.node.textContent;
    this.code.className = language ? `language-${language}` : '';
  }

  mount() {
    if (this.real) return;
    if (this.initialCheck != null) {
      clearTimeout(this.initialCheck);
      this.initialCheck = null;
    }
    this.observer?.disconnect();
    this.observer = null;
    this.dom.removeEventListener('pointerdown', this.onPointerDown, true);

    const real = this.createReal(this.node, this.view, this.getPos);
    this.real = real;
    // 类名交给真实节点视图，避免外层与内层各算一次代码块。
    this.dom.classList.remove('milkdown-code-block');
    this.dom.removeAttribute(LAZY_ATTR);
    this.dom.replaceChildren(real.dom);
  }

  update(node) {
    if (node.type !== this.node.type) return false;
    this.node = node;
    if (this.real) return this.real.update(node);
    this.renderPlaceholder();
    return true;
  }

  selectNode() {
    this.mount();
    this.real?.selectNode?.();
  }

  deselectNode() {
    this.real?.deselectNode?.();
  }

  stopEvent(event) {
    return this.real ? this.real.stopEvent(event) : true;
  }

  ignoreMutation() {
    return true;
  }

  destroy() {
    lazyInstances.delete(this);
    if (this.initialCheck != null) {
      clearTimeout(this.initialCheck);
      this.initialCheck = null;
    }
    this.observer?.disconnect();
    this.observer = null;
    this.dom.removeEventListener('pointerdown', this.onPointerDown, true);
    this.real?.destroy?.();
    this.real = null;
  }
}

export const mountAllLazyCodeBlocks = () => {
  const instances = [...lazyInstances];
  for (const instance of instances) instance.mount();
  return instances.length;
};

export const lazyCodeBlockView = $view(codeBlockSchema.node, () => (
  (node, view, getPos) => new LazyCodeBlockView(
    node, view, getPos,
    // `codeBlockView.view` 就是节点工厂本身（由 $view 在插件执行时挂上），
    // 不是 (ctx) => factory。挂载时再取，确保 Crepe 的插件已经执行过。
    (n, v, g) => codeBlockView.view(n, v, g),
  )
));
