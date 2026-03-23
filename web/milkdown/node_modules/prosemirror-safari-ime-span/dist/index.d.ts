import { Plugin } from 'prosemirror-state';

/**
 * A plugin as a workaround for a bug in Safari that causes the composition
 * based IME to remove the empty HTML element with CSS `position: relative`.
 *
 * See also https://github.com/ProseMirror/prosemirror/issues/934
 *
 * @public @group Plugins
 */
declare const imeSpan: Plugin<undefined>;

export { imeSpan };
