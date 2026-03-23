import { contextNotFound, ctxCallOutOfScope, timerNotFound } from "@milkdown/exception";
//#region src/context/container.ts
var Container = class {
	constructor() {
		this.sliceMap = /* @__PURE__ */ new Map();
		this.get = (slice) => {
			const context = typeof slice === "string" ? [...this.sliceMap.values()].find((x) => x.type.name === slice) : this.sliceMap.get(slice.id);
			if (!context) throw contextNotFound(typeof slice === "string" ? slice : slice.name);
			return context;
		};
		this.remove = (slice) => {
			const context = typeof slice === "string" ? [...this.sliceMap.values()].find((x) => x.type.name === slice) : this.sliceMap.get(slice.id);
			if (!context) return;
			this.sliceMap.delete(context.type.id);
		};
		this.has = (slice) => {
			if (typeof slice === "string") return [...this.sliceMap.values()].some((x) => x.type.name === slice);
			return this.sliceMap.has(slice.id);
		};
	}
};
//#endregion
//#region src/context/slice.ts
var Slice = class {
	#watchers = [];
	#value;
	#emit = () => {
		this.#watchers.forEach((watcher) => watcher(this.#value));
	};
	constructor(container, value, type) {
		this.set = (value) => {
			this.#value = value;
			this.#emit();
		};
		this.get = () => this.#value;
		this.update = (updater) => {
			this.#value = updater(this.#value);
			this.#emit();
		};
		this.type = type;
		this.#value = value;
		container.set(type.id, this);
	}
	on(watcher) {
		this.#watchers.push(watcher);
		return () => {
			this.#watchers = this.#watchers.filter((w) => w !== watcher);
		};
	}
	once(watcher) {
		const off = this.on((value) => {
			watcher(value);
			off();
		});
		return off;
	}
	off(watcher) {
		this.#watchers = this.#watchers.filter((w) => w !== watcher);
	}
	offAll() {
		this.#watchers = [];
	}
};
var SliceType = class {
	constructor(value, name) {
		this.id = Symbol(`Context-${name}`);
		this.name = name;
		this._defaultValue = value;
		this._typeInfo = () => {
			throw ctxCallOutOfScope();
		};
	}
	create(container, value = this._defaultValue) {
		return new Slice(container, value, this);
	}
};
var createSlice = (value, name) => new SliceType(value, name);
//#endregion
//#region src/inspector/inspector.ts
var Inspector = class {
	#meta;
	#container;
	#clock;
	#injectedSlices = /* @__PURE__ */ new Set();
	#consumedSlices = /* @__PURE__ */ new Set();
	#recordedTimers = /* @__PURE__ */ new Map();
	#waitTimers = /* @__PURE__ */ new Map();
	constructor(container, clock, meta) {
		this.read = () => {
			return {
				metadata: this.#meta,
				injectedSlices: [...this.#injectedSlices].map((slice) => ({
					name: typeof slice === "string" ? slice : slice.name,
					value: this.#getSlice(slice)
				})),
				consumedSlices: [...this.#consumedSlices].map((slice) => ({
					name: typeof slice === "string" ? slice : slice.name,
					value: this.#getSlice(slice)
				})),
				recordedTimers: [...this.#recordedTimers].map(([timer, { duration }]) => ({
					name: timer.name,
					duration,
					status: this.#getTimer(timer)
				})),
				waitTimers: [...this.#waitTimers].map(([timer, { duration }]) => ({
					name: timer.name,
					duration,
					status: this.#getTimer(timer)
				}))
			};
		};
		this.onRecord = (timerType) => {
			this.#recordedTimers.set(timerType, {
				start: Date.now(),
				duration: 0
			});
		};
		this.onClear = (timerType) => {
			this.#recordedTimers.delete(timerType);
		};
		this.onDone = (timerType) => {
			const timer = this.#recordedTimers.get(timerType);
			if (!timer) return;
			timer.duration = Date.now() - timer.start;
		};
		this.onWait = (timerType, promise) => {
			const start = Date.now();
			promise.finally(() => {
				this.#waitTimers.set(timerType, { duration: Date.now() - start });
			}).catch(console.error);
		};
		this.onInject = (sliceType) => {
			this.#injectedSlices.add(sliceType);
		};
		this.onRemove = (sliceType) => {
			this.#injectedSlices.delete(sliceType);
		};
		this.onUse = (sliceType) => {
			this.#consumedSlices.add(sliceType);
		};
		this.#container = container;
		this.#clock = clock;
		this.#meta = meta;
	}
	#getSlice = (sliceType) => {
		return this.#container.get(sliceType).get();
	};
	#getTimer = (timerType) => {
		return this.#clock.get(timerType).status;
	};
};
//#endregion
//#region src/plugin/ctx.ts
var Ctx = class Ctx {
	#container;
	#clock;
	#meta;
	#inspector;
	constructor(container, clock, meta) {
		this.produce = (meta) => {
			if (meta && Object.keys(meta).length) return new Ctx(this.#container, this.#clock, { ...meta });
			return this;
		};
		this.inject = (sliceType, value) => {
			const slice = sliceType.create(this.#container.sliceMap);
			if (value != null) slice.set(value);
			this.#inspector?.onInject(sliceType);
			return this;
		};
		this.remove = (sliceType) => {
			this.#container.remove(sliceType);
			this.#inspector?.onRemove(sliceType);
			return this;
		};
		this.record = (timerType) => {
			timerType.create(this.#clock.store);
			this.#inspector?.onRecord(timerType);
			return this;
		};
		this.clearTimer = (timerType) => {
			this.#clock.remove(timerType);
			this.#inspector?.onClear(timerType);
			return this;
		};
		this.isInjected = (sliceType) => this.#container.has(sliceType);
		this.isRecorded = (timerType) => this.#clock.has(timerType);
		this.use = (sliceType) => {
			this.#inspector?.onUse(sliceType);
			return this.#container.get(sliceType);
		};
		this.get = (sliceType) => this.use(sliceType).get();
		this.set = (sliceType, value) => this.use(sliceType).set(value);
		this.update = (sliceType, updater) => this.use(sliceType).update(updater);
		this.timer = (timer) => this.#clock.get(timer);
		this.done = (timer) => {
			this.timer(timer).done();
			this.#inspector?.onDone(timer);
		};
		this.wait = (timer) => {
			const promise = this.timer(timer).start();
			this.#inspector?.onWait(timer, promise);
			return promise;
		};
		this.waitTimers = async (slice) => {
			await Promise.all(this.get(slice).map((x) => this.wait(x)));
		};
		this.#container = container;
		this.#clock = clock;
		this.#meta = meta;
		if (meta) this.#inspector = new Inspector(container, clock, meta);
	}
	get meta() {
		return this.#meta;
	}
	get inspector() {
		return this.#inspector;
	}
};
//#endregion
//#region src/timer/clock.ts
var Clock = class {
	constructor() {
		this.store = /* @__PURE__ */ new Map();
		this.get = (timer) => {
			const meta = this.store.get(timer.id);
			if (!meta) throw timerNotFound(timer.name);
			return meta;
		};
		this.remove = (timer) => {
			this.store.delete(timer.id);
		};
		this.has = (timer) => {
			return this.store.has(timer.id);
		};
	}
};
//#endregion
//#region src/timer/timer.ts
var Timer = class {
	#promise = null;
	#listener = null;
	#eventUniqId;
	#status = "pending";
	constructor(clock, type) {
		this.start = () => {
			this.#promise ??= new Promise((resolve, reject) => {
				this.#listener = (e) => {
					if (!(e instanceof CustomEvent)) return;
					if (e.detail.id === this.#eventUniqId) {
						this.#status = "resolved";
						this.#removeListener();
						e.stopImmediatePropagation();
						resolve();
					}
				};
				this.#waitTimeout(() => {
					if (this.#status === "pending") this.#status = "rejected";
					this.#removeListener();
					reject(/* @__PURE__ */ new Error(`Timing ${this.type.name} timeout.`));
				});
				this.#status = "pending";
				addEventListener(this.type.name, this.#listener);
			});
			return this.#promise;
		};
		this.done = () => {
			const event = new CustomEvent(this.type.name, { detail: { id: this.#eventUniqId } });
			dispatchEvent(event);
		};
		this.#eventUniqId = Symbol(type.name);
		this.type = type;
		clock.set(type.id, this);
	}
	get status() {
		return this.#status;
	}
	#removeListener = () => {
		if (this.#listener) removeEventListener(this.type.name, this.#listener);
	};
	#waitTimeout = (ifTimeout) => {
		setTimeout(() => {
			ifTimeout();
		}, this.type.timeout);
	};
};
var TimerType = class {
	constructor(name, timeout = 3e3) {
		this.create = (clock) => {
			return new Timer(clock, this);
		};
		this.id = Symbol(`Timer-${name}`);
		this.name = name;
		this.timeout = timeout;
	}
};
var createTimer = (name, timeout = 3e3) => new TimerType(name, timeout);
//#endregion
export { Clock, Container, Ctx, Inspector, Slice, SliceType, Timer, TimerType, createSlice, createTimer };

//# sourceMappingURL=index.js.map