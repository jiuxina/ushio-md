import type { Attrs } from '../../model';
import type { Transaction } from '../../state';
export interface Captured {
    group: string | undefined;
    fullMatch: string;
    start: number;
    end: number;
}
export interface BeforeDispatch {
    match: string[];
    start: number;
    end: number;
    tr: Transaction;
}
export interface Options {
    getAttr?: (match: RegExpMatchArray) => Attrs;
    updateCaptured?: (captured: Captured) => Partial<Captured>;
    beforeDispatch?: (options: BeforeDispatch) => void;
}
//# sourceMappingURL=common.d.ts.map