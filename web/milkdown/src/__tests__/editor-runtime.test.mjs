import { describe, expect, it, vi } from 'vitest';
import { Schema } from '@milkdown/prose/model';
import { AllSelection, EditorState } from '@milkdown/prose/state';
import {
  createContentChangeBuffer,
  createRenderScheduler,
  getCaretViewport,
  selectEntireDocument,
  shouldRevealCaret,
  updateStyleProperty,
} from '../editor-runtime.mjs';

describe('pending editor content', () => {
  it('returns the latest normalized input before the debounce without a late duplicate event', () => {
    vi.useFakeTimers();
    try {
      const emit = vi.fn();
      const buffer = createContentChangeBuffer({
        emit,
        normalize: (markdown) => markdown.replace(/\n+$/, '\n'),
        delayFor: () => 300,
      });
      buffer.schedule('first\n\n');
      buffer.schedule('last characters\n\n', 'code_sanitized');
      expect(buffer.take()).toEqual({
        markdown: 'last characters\n',
        mode: 'code_sanitized',
      });
      vi.runAllTimers();
      expect(emit).not.toHaveBeenCalled();
      expect(buffer.take()).toBeNull();
    } finally {
      vi.useRealTimers();
    }
  });

  it('flushes once on background and discards input belonging to a previous document', () => {
    vi.useFakeTimers();
    try {
      const emit = vi.fn();
      const buffer = createContentChangeBuffer({ emit, delayFor: () => 80 });
      expect(buffer.take()).toBeNull();
      buffer.schedule('new input');
      buffer.flush();
      buffer.flush();
      expect(emit).toHaveBeenCalledExactlyOnceWith({ markdown: 'new input', mode: 'full' });
      buffer.schedule('old document');
      buffer.cancel();
      vi.runAllTimers();
      expect(emit).toHaveBeenCalledTimes(1);
    } finally {
      vi.useRealTimers();
    }
  });
});

describe('render work scheduling', () => {
  it('coalesces document and geometry invalidations and never drops work queued during a frame', () => {
    const frames = [];
    const render = vi.fn((work) => {
      if (work.content) scheduler.schedule({ geometry: true });
    });
    const scheduler = createRenderScheduler({
      requestFrame: (callback) => { frames.push(callback); return frames.length; },
      render,
    });
    scheduler.schedule({ geometry: true });
    scheduler.schedule({ content: true });
    scheduler.schedule({ content: true });
    expect(frames).toHaveLength(1);
    frames.shift()();
    expect(render).toHaveBeenNthCalledWith(1, { content: true, geometry: true });
    expect(frames).toHaveLength(1);
    frames.shift()();
    expect(render).toHaveBeenNthCalledWith(2, { content: false, geometry: true });
    expect(frames).toHaveLength(0);
  });

  it('does not rewrite unchanged geometry styles', () => {
    const properties = new Map();
    const style = {
      getPropertyValue: (property) => properties.get(property)?.value || '',
      getPropertyPriority: (property) => properties.get(property)?.priority || '',
      setProperty: vi.fn((property, value, priority) => properties.set(property, { value, priority })),
    };
    expect(updateStyleProperty(style, 'top', '12px')).toBe(true);
    expect(updateStyleProperty(style, 'top', '12px')).toBe(false);
    expect(updateStyleProperty(style, 'height', '40px', 'important')).toBe(true);
    expect(updateStyleProperty(style, 'height', '40px', 'important')).toBe(false);
    expect(style.setProperty).toHaveBeenCalledTimes(2);
  });
});

describe('keyboard caret geometry', () => {
  it('subtracts keyboard only once and includes the visible toolbar in the scroll space', () => {
    const overlay = getCaretViewport({
      layoutHeight: 800,
      viewportHeight: 800,
      keyboardInset: 300,
      toolbarHeight: 48,
      headerHeight: 56,
      lineHeight: 24,
    });
    const resized = getCaretViewport({
      layoutHeight: 800,
      viewportHeight: 500,
      keyboardInset: 300,
      toolbarHeight: 48,
      headerHeight: 56,
      lineHeight: 24,
    });
    expect(overlay).toEqual(resized);
    expect(overlay.top).toBe(68);
    expect(overlay.bottom).toBe(440);
    expect(overlay.bottomPadding).toBe(364);
    expect(getCaretViewport({
      layoutHeight: 800, viewportHeight: 800, toolbarHeight: 0,
    }).bottomPadding).toBe(16);
  });

  it('reveals a focused caret after a pause when keyboard occlusion changes', () => {
    const paused = { focused: true, now: 5000, lastInteractionAt: 1000 };
    expect(shouldRevealCaret(paused)).toBe(false);
    expect(shouldRevealCaret({ ...paused, force: true })).toBe(true);
    expect(shouldRevealCaret({ ...paused, force: true, focused: false })).toBe(false);
    expect(shouldRevealCaret({ ...paused, lastInteractionAt: 4900, composing: true })).toBe(false);
  });
});

describe('whole document selection', () => {
  it('selects and replaces paragraphs, code and non-text nodes as one document', () => {
    const schema = new Schema({
      nodes: {
        doc: { content: 'block+' },
        paragraph: { content: 'text*', group: 'block' },
        code_block: { content: 'text*', group: 'block', code: true },
        image: { group: 'block', atom: true },
        text: {},
      },
    });
    const doc = schema.node('doc', null, [
      schema.node('paragraph', null, schema.text('before')),
      schema.node('code_block', null, schema.text('latest code input')),
      schema.node('image'),
      schema.node('paragraph', null, schema.text('after')),
    ]);
    let state = EditorState.create({ doc });
    const focus = vi.fn();
    const view = {
      get state() { return state; },
      dispatch: (transaction) => { state = state.apply(transaction); },
      focus,
    };
    expect(selectEntireDocument(view)).toBe(true);
    expect(state.selection).toBeInstanceOf(AllSelection);
    expect(state.selection.from).toBe(0);
    expect(state.selection.to).toBe(doc.content.size);
    expect(focus).toHaveBeenCalledOnce();
    state = state.apply(state.tr.insertText('replacement'));
    expect(state.doc.textContent).toBe('replacement');
    expect(state.doc.childCount).toBe(1);
  });
});
