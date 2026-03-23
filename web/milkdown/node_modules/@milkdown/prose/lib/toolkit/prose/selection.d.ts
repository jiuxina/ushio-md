import type { NodeType, Node as ProseNode, ResolvedPos } from '../../model';
import type { EditorState, Selection } from '../../state';
import type { Predicate } from './types';
export interface ContentNodeWithPos {
    pos: number;
    start: number;
    depth: number;
    node: ProseNode;
}
export declare function findParentNodeClosestToPos(predicate: Predicate): ($pos: ResolvedPos) => ContentNodeWithPos | undefined;
export declare function findParentNode(predicate: Predicate): (selection: Selection) => ContentNodeWithPos | undefined;
export declare function findSelectedNodeOfType(selection: Selection, nodeType: NodeType): ContentNodeWithPos | undefined;
export type FindNodeInSelectionResult = {
    hasNode: boolean;
    pos: number;
    target: ProseNode | null;
};
export declare const findNodeInSelection: (state: EditorState, node: NodeType) => FindNodeInSelectionResult;
//# sourceMappingURL=selection.d.ts.map