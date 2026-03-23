var ve = (e, t, r) => {
  if (!t.has(e))
    throw TypeError("Cannot " + r);
};
var s = (e, t, r) => (ve(e, t, "read from private field"), r ? r.call(e) : t.get(e)), d = (e, t, r) => {
  if (t.has(e))
    throw TypeError("Cannot add the same private member more than once");
  t instanceof WeakSet ? t.add(e) : t.set(e, r);
}, c = (e, t, r, i) => (ve(e, t, "write to private field"), i ? i.call(e, r) : t.set(e, r), r);
import { createSlice as o, createTimer as v, Container as Se, Clock as We, Ctx as Ye } from "@milkdown/ctx";
import { Schema as $e, DOMParser as qe, Node as He } from "@milkdown/prose/model";
import de from "remark-parse";
import he from "remark-stringify";
import { unified as le } from "unified";
import { callCommandBeforeEditorView as Je, ctxCallOutOfScope as Pe, docTypeError as Fe } from "@milkdown/exception";
import { ParserState as Ge, SerializerState as Qe } from "@milkdown/transformer";
import { customInputRules as Ue } from "@milkdown/prose";
import { chainCommands as Xe, deleteSelection as Ze, joinBackward as xe, selectNodeBackward as et, baseKeymap as tt } from "@milkdown/prose/commands";
import { undoInputRule as rt } from "@milkdown/prose/inputrules";
import { keymap as st } from "@milkdown/prose/keymap";
import { PluginKey as Re, Plugin as be, EditorState as it } from "@milkdown/prose/state";
import { EditorView as nt } from "@milkdown/prose/view";
function k(e, t) {
  return e.meta = {
    package: "@milkdown/core",
    group: "System",
    ...t
  }, e;
}
const De = {
  strong: (e, t, r, i) => {
    const n = e.marker || r.options.strong || "*", a = r.enter("strong"), h = r.createTracker(i);
    let m = h.move(n + n);
    return m += h.move(
      r.containerPhrasing(e, {
        before: m,
        after: n,
        ...h.current()
      })
    ), m += h.move(n + n), a(), m;
  },
  emphasis: (e, t, r, i) => {
    const n = e.marker || r.options.emphasis || "*", a = r.enter("emphasis"), h = r.createTracker(i);
    let m = h.move(n);
    return m += h.move(
      r.containerPhrasing(e, {
        before: m,
        after: n,
        ...h.current()
      })
    ), m += h.move(n), a(), m;
  }
}, L = o({}, "editorView"), V = o({}, "editorState"), G = o([], "initTimer"), ke = o({}, "editor"), ue = o([], "inputRules"), N = o([], "prosePlugins"), pe = o([], "remarkPlugins"), fe = o([], "nodeView"), ye = o([], "markView"), P = o(le().use(de).use(he), "remark"), Q = o({
  handlers: De
}, "remarkStringifyOptions"), W = v("ConfigReady");
function ot(e) {
  const t = (r) => (r.record(W), async () => (await e(r), r.done(W), () => {
    r.clearTimer(W);
  }));
  return k(t, {
    displayName: "Config"
  }), t;
}
const M = v("InitReady");
function at(e) {
  const t = (r) => (r.inject(ke, e).inject(N, []).inject(pe, []).inject(ue, []).inject(fe, []).inject(ye, []).inject(Q, {
    handlers: De
  }).inject(P, le().use(de).use(he)).inject(G, [W]).record(M), async () => {
    await r.waitTimers(G);
    const i = r.get(Q);
    return r.set(P, le().use(de).use(he, i)), r.done(M), () => {
      r.remove(ke).remove(N).remove(pe).remove(ue).remove(fe).remove(ye).remove(Q).remove(P).remove(G).clearTimer(M);
    };
  });
  return k(t, {
    displayName: "Init"
  }), t;
}
const R = v("SchemaReady"), U = o([], "schemaTimer"), b = o({}, "schema"), X = o([], "nodes"), Z = o([], "marks");
function Te(e) {
  var t;
  return {
    ...e,
    parseDOM: (t = e.parseDOM) == null ? void 0 : t.map((r) => ({ priority: e.priority, ...r }))
  };
}
const Ee = (e) => (e.inject(b, {}).inject(X, []).inject(Z, []).inject(U, [M]).record(R), async () => {
  await e.waitTimers(U);
  const t = e.get(P), i = e.get(pe).reduce((m, f) => m.use(f.plugin, f.options), t);
  e.set(P, i);
  const n = Object.fromEntries(e.get(X).map(([m, f]) => [m, Te(f)])), a = Object.fromEntries(e.get(Z).map(([m, f]) => [m, Te(f)])), h = new $e({ nodes: n, marks: a });
  return e.set(b, h), e.done(R), () => {
    e.remove(b).remove(X).remove(Z).remove(U).clearTimer(R);
  };
});
k(Ee, {
  displayName: "Schema"
});
var T, g;
class Ie {
  constructor() {
    d(this, T, void 0);
    d(this, g, void 0);
    c(this, T, new Se()), c(this, g, null), this.setCtx = (t) => {
      c(this, g, t);
    };
  }
  get ctx() {
    return s(this, g);
  }
  /// Register a command into the manager.
  create(t, r) {
    const i = t.create(s(this, T).sliceMap);
    return i.set(r), i;
  }
  get(t) {
    return s(this, T).get(t).get();
  }
  remove(t) {
    return s(this, T).remove(t);
  }
  call(t, r) {
    if (s(this, g) == null)
      throw Je();
    const n = this.get(t)(r), a = s(this, g).get(L);
    return n(a.state, a.dispatch, a);
  }
}
T = new WeakMap(), g = new WeakMap();
function Et(e = "cmdKey") {
  return o(() => () => !1, e);
}
const je = o(new Ie(), "commands"), x = o([R], "commandsTimer"), Y = v("CommandsReady"), Ve = (e) => {
  const t = new Ie();
  return t.setCtx(e), e.inject(je, t).inject(x, [R]).record(Y), async () => (await e.waitTimers(x), e.done(Y), () => {
    e.remove(je).remove(x).clearTimer(Y);
  });
};
k(Ve, {
  displayName: "Commands"
});
const $ = v("ParserReady"), Me = () => {
  throw Pe();
}, q = o(Me, "parser"), ee = o([], "parserTimer"), Ne = (e) => (e.inject(q, Me).inject(ee, [R]).record($), async () => {
  await e.waitTimers(ee);
  const t = e.get(P), r = e.get(b);
  return e.set(q, Ge.create(r, t)), e.done($), () => {
    e.remove(q).remove(ee).clearTimer($);
  };
});
k(Ne, {
  displayName: "Parser"
});
const H = v("SerializerReady"), te = o([], "serializerTimer"), _e = () => {
  throw Pe();
}, re = o(_e, "serializer"), ze = (e) => (e.inject(re, _e).inject(te, [R]).record(H), async () => {
  await e.waitTimers(te);
  const t = e.get(P), r = e.get(b);
  return e.set(re, Qe.create(r, t)), e.done(H), () => {
    e.remove(re).remove(te).clearTimer(H);
  };
});
k(ze, {
  displayName: "Serializer"
});
const se = o("", "defaultValue"), ie = o((e) => e, "stateOptions"), ne = o([], "editorStateTimer"), J = v("EditorStateReady");
function ct(e, t, r) {
  if (typeof e == "string")
    return t(e);
  if (e.type === "html")
    return qe.fromSchema(r).parse(e.dom);
  if (e.type === "json")
    return He.fromJSON(r, e.value);
  throw Fe(e);
}
const mt = new Re("MILKDOWN_STATE_TRACKER");
function dt(e) {
  const t = Xe(
    rt,
    Ze,
    xe,
    et
  );
  return e.Backspace = t, e;
}
const Ke = (e) => (e.inject(se, "").inject(V, {}).inject(ie, (t) => t).inject(ne, [$, H, Y]).record(J), async () => {
  await e.waitTimers(ne);
  const t = e.get(b), r = e.get(q), i = e.get(ue), n = e.get(ie), a = e.get(N), h = e.get(se), m = ct(h, r, t), f = [
    ...a,
    new be({
      key: mt,
      state: {
        init: () => {
        },
        apply: (Be, F, ft, Le) => {
          e.set(V, Le);
        }
      }
    }),
    Ue({ rules: i }),
    st(dt(tt))
  ];
  e.set(N, f);
  const B = n({
    schema: t,
    doc: m,
    plugins: f
  }), l = it.create(B);
  return e.set(V, l), e.done(J), () => {
    e.remove(se).remove(V).remove(ie).remove(ne).clearTimer(J);
  };
});
k(Ke, {
  displayName: "EditorState"
});
const oe = v("EditorViewReady"), ae = o([], "editorViewTimer"), ce = o({}, "editorViewOptions"), me = o(null, "root"), we = o(null, "rootDOM"), ge = o({}, "rootAttrs");
function ht(e, t) {
  const r = document.createElement("div");
  r.className = "milkdown", e.appendChild(r), t.set(we, r);
  const i = t.get(ge);
  return Object.entries(i).forEach(([n, a]) => r.setAttribute(n, a)), r;
}
function lt(e) {
  e.classList.add("editor"), e.setAttribute("role", "textbox");
}
const ut = new Re("MILKDOWN_VIEW_CLEAR"), Ae = (e) => (e.inject(me, document.body).inject(L, {}).inject(ce, {}).inject(we, null).inject(ge, {}).inject(ae, [J]).record(oe), async () => {
  await e.wait(M);
  const t = e.get(me) || document.body, r = typeof t == "string" ? document.querySelector(t) : t;
  e.update(N, (f) => [
    new be({
      key: ut,
      view: (B) => {
        const l = r ? ht(r, e) : void 0;
        return (() => {
          if (l && r) {
            const F = B.dom;
            r.replaceChild(l, F), l.appendChild(F);
          }
        })(), {
          destroy: () => {
            l != null && l.parentNode && (l == null || l.parentNode.replaceChild(B.dom, l)), l == null || l.remove();
          }
        };
      }
    }),
    ...f
  ]), await e.waitTimers(ae);
  const i = e.get(V), n = e.get(ce), a = Object.fromEntries(e.get(fe)), h = Object.fromEntries(e.get(ye)), m = new nt(r, {
    state: i,
    nodeViews: a,
    markViews: h,
    ...n
  });
  return lt(m.dom), e.set(L, m), e.done(oe), () => {
    m == null || m.destroy(), e.remove(me).remove(L).remove(ce).remove(we).remove(ge).remove(ae).clearTimer(oe);
  };
});
k(Ae, {
  displayName: "EditorView"
});
var pt = /* @__PURE__ */ ((e) => (e.Idle = "Idle", e.OnCreate = "OnCreate", e.Created = "Created", e.OnDestroy = "OnDestroy", e.Destroyed = "Destroyed", e))(pt || {}), j, p, y, D, _, z, u, w, O, K, S, E, A, C, I;
const Ce = class Ce {
  constructor() {
    d(this, j, void 0);
    d(this, p, void 0);
    d(this, y, void 0);
    d(this, D, void 0);
    d(this, _, void 0);
    d(this, z, void 0);
    d(this, u, void 0);
    d(this, w, void 0);
    d(this, O, void 0);
    d(this, K, void 0);
    d(this, S, void 0);
    d(this, E, void 0);
    d(this, A, void 0);
    d(this, C, void 0);
    d(this, I, void 0);
    c(this, j, !1), c(this, p, "Idle"), c(this, y, []), c(this, D, () => {
    }), c(this, _, new Se()), c(this, z, new We()), c(this, u, /* @__PURE__ */ new Map()), c(this, w, /* @__PURE__ */ new Map()), c(this, O, new Ye(s(this, _), s(this, z))), c(this, K, () => {
      const t = ot(async (i) => {
        await Promise.all(s(this, y).map((n) => n(i)));
      }), r = [
        Ee,
        Ne,
        ze,
        Ve,
        Ke,
        Ae,
        at(this),
        t
      ];
      s(this, S).call(this, r, s(this, w));
    }), c(this, S, (t, r) => {
      t.forEach((i) => {
        const n = s(this, O).produce(s(this, j) ? i.meta : void 0), a = i(n);
        r.set(i, { ctx: n, handler: a, cleanup: void 0 });
      });
    }), c(this, E, (t, r = !1) => Promise.all(
      [t].flat().map((i) => {
        const n = s(this, u).get(i), a = n == null ? void 0 : n.cleanup;
        return r ? s(this, u).delete(i) : s(this, u).set(i, { ctx: void 0, handler: void 0, cleanup: void 0 }), typeof a == "function" ? a() : a;
      })
    )), c(this, A, async () => {
      await Promise.all([...s(this, w).entries()].map(([t, { cleanup: r }]) => typeof r == "function" ? r() : r)), s(this, w).clear();
    }), c(this, C, (t) => {
      c(this, p, t), s(this, D).call(this, t);
    }), c(this, I, (t) => [...t.entries()].map(async ([r, i]) => {
      const { ctx: n, handler: a } = i;
      if (!a)
        return;
      const h = await a();
      t.set(r, { ctx: n, handler: a, cleanup: h });
    })), this.enableInspector = (t = !0) => (c(this, j, t), this), this.onStatusChange = (t) => (c(this, D, t), this), this.config = (t) => (s(this, y).push(t), this), this.removeConfig = (t) => (c(this, y, s(this, y).filter((r) => r !== t)), this), this.use = (t) => {
      const r = [t].flat();
      return r.flat().forEach((i) => {
        s(this, u).set(i, {
          ctx: void 0,
          handler: void 0,
          cleanup: void 0
        });
      }), s(this, p) === "Created" && s(this, S).call(this, r, s(this, u)), this;
    }, this.remove = async (t) => s(this, p) === "OnCreate" ? (console.warn("[Milkdown]: You are trying to remove plugins when the editor is creating, this is not recommended, please check your code."), new Promise((r) => {
      setTimeout(() => {
        r(this.remove(t));
      }, 50);
    })) : (await s(this, E).call(this, [t].flat(), !0), this), this.create = async () => s(this, p) === "OnCreate" ? this : (s(this, p) === "Created" && await this.destroy(), s(this, C).call(this, "OnCreate"), s(this, K).call(this), s(this, S).call(this, [...s(this, u).keys()], s(this, u)), await Promise.all(
      [
        s(this, I).call(this, s(this, w)),
        s(this, I).call(this, s(this, u))
      ].flat()
    ), s(this, C).call(this, "Created"), this), this.destroy = async (t = !1) => s(this, p) === "Destroyed" || s(this, p) === "OnDestroy" ? this : s(this, p) === "OnCreate" ? new Promise((r) => {
      setTimeout(() => {
        r(this.destroy(t));
      }, 50);
    }) : (t && c(this, y, []), s(this, C).call(this, "OnDestroy"), await s(this, E).call(this, [...s(this, u).keys()], t), await s(this, A).call(this), s(this, C).call(this, "Destroyed"), this), this.action = (t) => t(s(this, O)), this.inspect = () => s(this, j) ? [...s(this, w).values(), ...s(this, u).values()].map(({ ctx: t }) => {
      var r;
      return (r = t == null ? void 0 : t.inspector) == null ? void 0 : r.read();
    }).filter((t) => !!t) : (console.warn("[Milkdown]: You are trying to collect inspection when inspector is disabled, please enable inspector by `editor.enableInspector()` first."), []);
  }
  /// Create a new editor instance.
  static make() {
    return new Ce();
  }
  /// Get the ctx of the editor.
  get ctx() {
    return s(this, O);
  }
  /// Get the status of the editor.
  get status() {
    return s(this, p);
  }
};
j = new WeakMap(), p = new WeakMap(), y = new WeakMap(), D = new WeakMap(), _ = new WeakMap(), z = new WeakMap(), u = new WeakMap(), w = new WeakMap(), O = new WeakMap(), K = new WeakMap(), S = new WeakMap(), E = new WeakMap(), A = new WeakMap(), C = new WeakMap(), I = new WeakMap();
let Oe = Ce;
export {
  Ie as CommandManager,
  Y as CommandsReady,
  W as ConfigReady,
  Oe as Editor,
  J as EditorStateReady,
  pt as EditorStatus,
  oe as EditorViewReady,
  M as InitReady,
  $ as ParserReady,
  R as SchemaReady,
  H as SerializerReady,
  Ve as commands,
  je as commandsCtx,
  x as commandsTimerCtx,
  ot as config,
  Et as createCmdKey,
  se as defaultValueCtx,
  ke as editorCtx,
  Ke as editorState,
  V as editorStateCtx,
  ie as editorStateOptionsCtx,
  ne as editorStateTimerCtx,
  Ae as editorView,
  L as editorViewCtx,
  ce as editorViewOptionsCtx,
  ae as editorViewTimerCtx,
  ct as getDoc,
  at as init,
  G as initTimerCtx,
  ue as inputRulesCtx,
  ye as markViewCtx,
  Z as marksCtx,
  fe as nodeViewCtx,
  X as nodesCtx,
  Ne as parser,
  q as parserCtx,
  ee as parserTimerCtx,
  N as prosePluginsCtx,
  P as remarkCtx,
  pe as remarkPluginsCtx,
  Q as remarkStringifyOptionsCtx,
  ge as rootAttrsCtx,
  me as rootCtx,
  we as rootDOMCtx,
  Ee as schema,
  b as schemaCtx,
  U as schemaTimerCtx,
  ze as serializer,
  re as serializerCtx,
  te as serializerTimerCtx
};
//# sourceMappingURL=index.es.js.map
