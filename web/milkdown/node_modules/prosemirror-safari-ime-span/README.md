# prosemirror-safari-ime-span

[![NPM version](https://img.shields.io/npm/v/prosemirror-safari-ime-span?color=a1b858&label=)](https://www.npmjs.com/package/prosemirror-safari-ime-span)

This module exports a [ProseMirror] plugin to work around the bug in Safari
where [IME] text replacement removes empty nodes when the composition finishes.
See also [prosemirror#934] for more details.

## Usage

```ts
import { imeSpan } from 'prosemirror-safari-ime-span'
```

## License

MIT

[ProseMirror]: https://prosemirror.net/
[IME]: https://developer.mozilla.org/en-US/docs/Glossary/Input_method_editor
[prosemirror#934]: https://github.com/ProseMirror/prosemirror/issues/934
