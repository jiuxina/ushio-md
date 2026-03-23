// src/index.ts
import {
  Plugin,
  PluginKey
} from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";

// src/browser.ts
var nav = typeof navigator != "undefined" ? navigator : null;
var agent = nav && nav.userAgent || "";
var ie_edge = /Edge\/(\d+)/.exec(agent);
var ie_upto10 = /MSIE \d/.exec(agent);
var ie_11up = /Trident\/(?:[7-9]|\d{2,})\..*rv:(\d+)/.exec(agent);
var ie = !!(ie_upto10 || ie_11up || ie_edge);
var safari = !ie && !!nav && /Apple Computer/.test(nav.vendor);

// src/index.ts
var key = new PluginKey("safari-ime-span");
var isComposing = false;
var spec = {
  key,
  props: {
    decorations: createDecorations,
    handleDOMEvents: {
      compositionstart: () => {
        isComposing = true;
      },
      compositionend: () => {
        isComposing = false;
      }
    }
  }
};
function createDecorations(state) {
  const { $from, $to, to } = state.selection;
  if (isComposing && $from.sameParent($to)) {
    const deco = Decoration.widget(to, createSpan, {
      ignoreSelection: true,
      key: "safari-ime-span"
    });
    return DecorationSet.create(state.doc, [deco]);
  }
}
function createSpan(view) {
  const span = view.dom.ownerDocument.createElement("span");
  span.className = "ProseMirror-safari-ime-span";
  return span;
}
var imeSpan = new Plugin(safari ? spec : { key });
export {
  imeSpan
};
