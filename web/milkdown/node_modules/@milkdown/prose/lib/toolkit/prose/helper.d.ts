import type { Slice, NodeType, Node as ProseNode } from '../../model';
import type { Transaction } from '../../state';
export declare function cloneTr(tr: Transaction): Transaction;
export declare function equalNodeType(nodeType: NodeType | NodeType[], node: ProseNode): boolean;
export declare function isTextOnlySlice(slice: Slice): ProseNode | false;
//# sourceMappingURL=helper.d.ts.map