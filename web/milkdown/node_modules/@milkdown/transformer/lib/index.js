import { createNodeInParserFail, parserMatchError, serializerMatchError, stackOverFlow } from "@milkdown/exception";
import { Mark } from "@milkdown/prose/model";
//#region src/utility/stack.ts
var StackElement = class {};
var Stack = class {
	constructor() {
		this.elements = [];
		this.size = () => {
			return this.elements.length;
		};
		this.top = () => {
			return this.elements.at(-1);
		};
		this.push = (node) => {
			this.top()?.push(node);
		};
		this.open = (node) => {
			this.elements.push(node);
		};
		this.close = () => {
			const el = this.elements.pop();
			if (!el) throw stackOverFlow();
			return el;
		};
	}
};
//#endregion
//#region src/parser/stack-element.ts
var ParserStackElement = class ParserStackElement extends StackElement {
	constructor(type, content, attrs) {
		super();
		this.type = type;
		this.content = content;
		this.attrs = attrs;
	}
	push(node, ...rest) {
		this.content.push(node, ...rest);
	}
	pop() {
		return this.content.pop();
	}
	static create(type, content, attrs) {
		return new ParserStackElement(type, content, attrs);
	}
};
//#endregion
//#region src/parser/state.ts
var ParserState = class extends Stack {
	#marks = Mark.none;
	static {
		this.create = (schema, remark) => {
			const state = new this(schema);
			return (text) => {
				state.run(remark, text);
				return state.toDoc();
			};
		};
	}
	constructor(schema) {
		super();
		this.injectRoot = (node, nodeType, attrs) => {
			this.openNode(nodeType, attrs);
			this.next(node.children);
			return this;
		};
		this.openNode = (nodeType, attrs) => {
			this.open(ParserStackElement.create(nodeType, [], attrs));
			return this;
		};
		this.closeNode = () => {
			try {
				this.#closeNodeAndPush();
			} catch (e) {
				console.error(e);
			}
			return this;
		};
		this.addNode = (nodeType, attrs, content) => {
			try {
				this.#addNodeAndPush(nodeType, attrs, content);
			} catch (e) {
				console.error(e);
			}
			return this;
		};
		this.openMark = (markType, attrs) => {
			this.#marks = markType.create(attrs).addToSet(this.#marks);
			return this;
		};
		this.closeMark = (markType) => {
			this.#marks = markType.removeFromSet(this.#marks);
			return this;
		};
		this.addText = (text) => {
			try {
				const topElement = this.top();
				if (!topElement) throw stackOverFlow();
				const prevNode = topElement.pop();
				const currNode = this.schema.text(text, this.#marks);
				if (!prevNode) {
					topElement.push(currNode);
					return this;
				}
				const merged = this.#maybeMerge(prevNode, currNode);
				if (merged) {
					topElement.push(merged);
					return this;
				}
				topElement.push(prevNode, currNode);
				return this;
			} catch (e) {
				console.error(e);
				return this;
			}
		};
		this.build = () => {
			let doc;
			do
				doc = this.#closeNodeAndPush();
			while (this.size());
			return doc;
		};
		this.next = (nodes = []) => {
			[nodes].flat().forEach((node) => this.#runNode(node));
			return this;
		};
		this.toDoc = () => this.build();
		this.run = (remark, markdown) => {
			const tree = remark.runSync(remark.parse(markdown), markdown);
			this.next(tree);
			return this;
		};
		this.schema = schema;
	}
	#hasText = (node) => node.isText;
	#maybeMerge = (a, b) => {
		if (this.#hasText(a) && this.#hasText(b) && Mark.sameSet(a.marks, b.marks)) return this.schema.text(a.text + b.text, a.marks);
	};
	#matchTarget = (node) => {
		const result = Object.values({
			...this.schema.nodes,
			...this.schema.marks
		}).find((x) => {
			return x.spec.parseMarkdown.match(node);
		});
		if (!result) throw parserMatchError(node);
		return result;
	};
	#runNode = (node) => {
		const type = this.#matchTarget(node);
		type.spec.parseMarkdown.runner(this, node, type);
	};
	#closeNodeAndPush = () => {
		this.#marks = Mark.none;
		const element = this.close();
		return this.#addNodeAndPush(element.type, element.attrs, element.content);
	};
	#addNodeAndPush = (nodeType, attrs, content) => {
		const node = nodeType.createAndFill(attrs, content, this.#marks);
		if (!node) throw createNodeInParserFail(nodeType, attrs, content);
		this.push(node);
		return node;
	};
};
//#endregion
//#region src/serializer/stack-element.ts
var SerializerStackElement = class SerializerStackElement extends StackElement {
	constructor(type, children, value, props = {}) {
		super();
		this.type = type;
		this.children = children;
		this.value = value;
		this.props = props;
		this.push = (node, ...rest) => {
			if (!this.children) this.children = [];
			this.children.push(node, ...rest);
		};
		this.pop = () => this.children?.pop();
	}
	static {
		this.create = (type, children, value, props = {}) => new SerializerStackElement(type, children, value, props);
	}
};
//#endregion
//#region src/serializer/state.ts
var isFragment = (x) => Object.prototype.hasOwnProperty.call(x, "size");
var SerializerState = class extends Stack {
	#marks = Mark.none;
	static {
		this.create = (schema, remark) => {
			const state = new this(schema);
			return (content) => {
				state.run(content);
				return state.toString(remark);
			};
		};
	}
	constructor(schema) {
		super();
		this.openNode = (type, value, props) => {
			this.open(SerializerStackElement.create(type, void 0, value, props));
			return this;
		};
		this.closeNode = () => {
			this.#closeNodeAndPush();
			return this;
		};
		this.addNode = (type, children, value, props) => {
			this.#addNodeAndPush(type, children, value, props);
			return this;
		};
		this.withMark = (mark, type, value, props) => {
			this.#openMark(mark, type, value, props);
			return this;
		};
		this.closeMark = (mark) => {
			this.#closeMark(mark);
			return this;
		};
		this.build = () => {
			let doc = null;
			do
				doc = this.#closeNodeAndPush();
			while (this.size());
			return doc;
		};
		this.next = (nodes) => {
			if (isFragment(nodes)) {
				nodes.forEach((node) => {
					this.#runNode(node);
				});
				return this;
			}
			this.#runNode(nodes);
			return this;
		};
		this.toString = (remark) => remark.stringify(this.build());
		this.run = (tree) => {
			this.next(tree);
			return this;
		};
		this.schema = schema;
	}
	#matchTarget = (node) => {
		const result = Object.values({
			...this.schema.nodes,
			...this.schema.marks
		}).find((x) => {
			return x.spec.toMarkdown.match(node);
		});
		if (!result) throw serializerMatchError(node.type);
		return result;
	};
	#runProseNode = (node) => {
		return this.#matchTarget(node).spec.toMarkdown.runner(this, node);
	};
	#runProseMark = (mark, node) => {
		return this.#matchTarget(mark).spec.toMarkdown.runner(this, mark, node);
	};
	#runNode = (node) => {
		const { marks } = node;
		const getPriority = (x) => x.type.spec.priority ?? 50;
		if ([...marks].sort((a, b) => getPriority(a) - getPriority(b)).every((mark) => !this.#runProseMark(mark, node))) this.#runProseNode(node);
		marks.forEach((mark) => this.#closeMark(mark));
	};
	#searchType = (child, type) => {
		if (child.type === type) return child;
		if (child.children?.length !== 1) return child;
		const searchNode = (node) => {
			if (node.type === type) return node.value != null ? null : node;
			if (node.children?.length !== 1) return null;
			const [firstChild] = node.children;
			if (!firstChild) return null;
			return searchNode(firstChild);
		};
		const target = searchNode(child);
		if (!target) return child;
		const tmp = target.children ? [...target.children] : void 0;
		const node = {
			...child,
			children: tmp
		};
		node.children = tmp;
		target.children = [node];
		return target;
	};
	#maybeMergeChildren = (node) => {
		const { children } = node;
		if (!children) return node;
		node.children = children.reduce((nextChildren, child, index) => {
			if (index === 0) return [child];
			const last = nextChildren.at(-1);
			if (last && last.isMark && child.isMark) {
				child = this.#searchType(child, last.type);
				const { children: currChildren, ...currRest } = child;
				const { children: prevChildren, ...prevRest } = last;
				if (child.type === last.type && currChildren && prevChildren && JSON.stringify(currRest) === JSON.stringify(prevRest)) {
					const next = {
						...prevRest,
						children: [...prevChildren, ...currChildren]
					};
					return nextChildren.slice(0, -1).concat(this.#maybeMergeChildren(next));
				}
			}
			return nextChildren.concat(child);
		}, []);
		return node;
	};
	#createMarkdownNode = (element) => {
		const node = {
			...element.props,
			type: element.type
		};
		if (element.children) node.children = element.children;
		if (element.value) node.value = element.value;
		return node;
	};
	#moveSpaces = (element, onPush) => {
		let startSpaces = "";
		let endSpaces = "";
		const children = element.children;
		let first = -1;
		let last = -1;
		const findIndex = (node) => {
			if (!node) return;
			node.forEach((child, index) => {
				if (child.type === "text" && child.value) {
					if (first < 0) first = index;
					last = index;
				}
			});
		};
		if (children) {
			findIndex(children);
			const lastChild = children?.[last];
			const firstChild = children?.[first];
			if (lastChild && lastChild.value.endsWith(" ")) {
				const text = lastChild.value;
				const trimmed = text.trimEnd();
				endSpaces = text.slice(trimmed.length);
				lastChild.value = trimmed;
			}
			if (firstChild && firstChild.value.startsWith(" ")) {
				const text = firstChild.value;
				const trimmed = text.trimStart();
				startSpaces = text.slice(0, text.length - trimmed.length);
				firstChild.value = trimmed;
			}
		}
		if (startSpaces.length) this.#addNodeAndPush("text", void 0, startSpaces);
		const result = onPush();
		if (endSpaces.length) this.#addNodeAndPush("text", void 0, endSpaces);
		return result;
	};
	#closeNodeAndPush = (trim = false) => {
		const element = this.close();
		const onPush = () => this.#addNodeAndPush(element.type, element.children, element.value, element.props);
		if (trim) return this.#moveSpaces(element, onPush);
		return onPush();
	};
	#addNodeAndPush = (type, children, value, props) => {
		const element = SerializerStackElement.create(type, children, value, props);
		const node = this.#maybeMergeChildren(this.#createMarkdownNode(element));
		this.push(node);
		return node;
	};
	#openMark = (mark, type, value, props) => {
		if (mark.isInSet(this.#marks)) return this;
		this.#marks = mark.addToSet(this.#marks);
		return this.openNode(type, value, {
			...props,
			isMark: true
		});
	};
	#closeMark = (mark) => {
		if (!mark.isInSet(this.#marks)) return;
		this.#marks = mark.type.removeFromSet(this.#marks);
		this.#closeNodeAndPush(true);
	};
};
//#endregion
export { ParserState, SerializerState, Stack, StackElement };

//# sourceMappingURL=index.js.map