import type { MarkType, Node, NodeType, ResolvedPos } from '../../model';
import type { Predicate } from './types';
export interface NodeWithPos {
    pos: number;
    node: Node;
}
export interface NodeWithFromTo {
    from: number;
    to: number;
    node: Node;
}
export declare function flatten(node: Node, descend?: boolean): NodeWithPos[];
export declare function findChildren(predicate: Predicate): (node: Node, descend?: boolean) => NodeWithPos[];
export declare function findChildrenByMark(node: Node, markType: MarkType, descend?: boolean): NodeWithPos[];
export declare function findParent(predicate: Predicate): ($pos: ResolvedPos) => NodeWithFromTo | undefined;
export declare function findParentNodeType($pos: ResolvedPos, nodeType: NodeType): NodeWithFromTo | undefined;
//# sourceMappingURL=node.d.ts.map