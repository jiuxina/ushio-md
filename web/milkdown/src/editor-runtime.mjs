import { AllSelection } from '@milkdown/prose/state';

/** Owns pending input until either its debounce expires or the host takes it. */
export const createContentChangeBuffer = ({
  emit,
  normalize = (markdown) => markdown,
  delayFor = () => 80,
}) => {
  let pending = null;
  let timer = null;
  const take = () => {
    if (timer != null) clearTimeout(timer);
    timer = null;
    if (pending == null) return null;
    const change = pending;
    pending = null;
    return { ...change, markdown: normalize(change.markdown) };
  };
  const flush = () => {
    const change = take();
    if (change != null) emit(change);
  };
  return {
    schedule(markdown, mode = 'full') {
      if (typeof markdown !== 'string') return;
      if (timer != null) clearTimeout(timer);
      pending = { markdown, mode };
      timer = setTimeout(flush, delayFor(markdown.length));
    },
    take,
    flush,
    cancel() {
      if (timer != null) clearTimeout(timer);
      timer = null;
      pending = null;
    },
    get pending() { return pending != null; },
  };
};

/** A frame consumes accumulated work, while work queued by rendering uses the next frame. */
export const createRenderScheduler = ({ requestFrame, render }) => {
  let frame = null;
  let content = false;
  let geometry = false;
  const schedule = (work = {}) => {
    content ||= work.content === true;
    geometry ||= work.geometry === true;
    if (frame != null || (!content && !geometry)) return;
    frame = requestFrame(() => {
      frame = null;
      const pending = { content, geometry };
      content = false;
      geometry = false;
      render(pending);
    });
  };
  return { schedule };
};

export const updateStyleProperty = (style, property, value, priority = '') => {
  if (style.getPropertyValue(property) === value
    && style.getPropertyPriority(property) === priority) return false;
  style.setProperty(property, value, priority);
  return true;
};

/** Flutter overlays remain outside visualViewport on Android adjustNothing. */
export const getCaretViewport = ({
  layoutHeight,
  viewportHeight = layoutHeight,
  keyboardInset = 0,
  toolbarHeight = 0,
  headerHeight = 0,
  lineHeight = 24,
}) => {
  const viewportExcludesKeyboard = layoutHeight - viewportHeight >= keyboardInset - 1;
  const visibleHeight = viewportExcludesKeyboard ? viewportHeight : layoutHeight - keyboardInset;
  return {
    top: headerHeight + lineHeight * 0.5,
    bottom: visibleHeight - toolbarHeight - lineHeight * 0.5,
    bottomPadding: 16 + keyboardInset + toolbarHeight,
  };
};

export const shouldRevealCaret = ({
  focused,
  composing = false,
  now,
  lastInteractionAt,
  force = false,
}) => Boolean(focused && (force || (!composing && now - lastInteractionAt <= 1200)));

export const selectEntireDocument = (view) => {
  if (!view?.state?.doc) return false;
  // Move focus out of embedded editors before applying the root selection.
  view.dom?.focus?.({ preventScroll: true });
  view.dispatch(view.state.tr.setSelection(new AllSelection(view.state.doc)));
  view.focus();
  return true;
};
