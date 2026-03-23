import type { EditorView } from '../../view';
type Point = [top: number, left: number];
export declare function calculateNodePosition(view: EditorView, target: HTMLElement, handler: (selectedRect: DOMRect, targetRect: DOMRect, parentRect: DOMRect) => Point): void;
interface Rect {
    left: number;
    right: number;
    top: number;
    bottom: number;
}
export declare function calculateTextPosition(view: EditorView, target: HTMLElement, handler: (start: Rect, end: Rect, targetRect: DOMRect, parentRect: DOMRect) => Point): void;
export declare function posToDOMRect(view: EditorView, from: number, to: number): DOMRect;
export {};
//# sourceMappingURL=index.d.ts.map