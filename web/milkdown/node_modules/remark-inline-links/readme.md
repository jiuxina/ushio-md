# remark-inline-links

[![Build][build-badge]][build]
[![Coverage][coverage-badge]][coverage]
[![Downloads][downloads-badge]][downloads]
[![Size][size-badge]][size]
[![Sponsors][sponsors-badge]][collective]
[![Backers][backers-badge]][collective]
[![Chat][chat-badge]][chat]

**[remark][]** plugin to turn references and definitions into normal links and
images.

## Contents

*   [What is this?](#what-is-this)
*   [When should I use this?](#when-should-i-use-this)
*   [Install](#install)
*   [Use](#use)
*   [API](#api)
    *   [`unified().use(remarkInlineLinks)`](#unifieduseremarkinlinelinks)
*   [Types](#types)
*   [Compatibility](#compatibility)
*   [Security](#security)
*   [Related](#related)
*   [Contribute](#contribute)
*   [License](#license)

## What is this?

This package is a [unified][] ([remark][]) plugin to turn references
(`[text][id]`, `![alt][id]`) and definitions (`[id]: url`) into links
(`[text](url)`) and images (`![alt](url)`).

## When should I use this?

This project is useful when you want to transform markdown and prefer that it
uses links and images.
“Normal” links and images are well known whereas references and definitions
are somewhat uncommon.
Long URLs in source code can make reading markdown difficult though.

Two different plugins, [`remark-defsplit`][remark-defsplit] and
[`remark-reference-links`][remark-reference-links], do the inverse: turn
links and images into references and definitions.

## Install

This package is [ESM only][esm].
In Node.js (version 16+), install with [npm][]:

```sh
npm install remark-inline-links
```

In Deno with [`esm.sh`][esmsh]:

```js
import remarkInlineLinks from 'https://esm.sh/remark-inline-links@7'
```

In browsers with [`esm.sh`][esmsh]:

```html
<script type="module">
  import remarkInlineLinks from 'https://esm.sh/remark-inline-links@7?bundle'
</script>
```

## Use

Say we have the following file `example.md`:

```markdown
[foo], [foo][], [bar][foo].

![foo], ![foo][], ![bar][foo].

[foo]: http://example.com "Example Domain"
```

…and a module `example.js`:

```js
import {remark} from 'remark'
import remarkInlineLinks from 'remark-inline-links'
import {read} from 'to-vfile'

const file = await remark()
  .use(remarkInlineLinks)
  .process(await read('example.md'))

console.log(String(file))
```

…then running `node example.js` yields:

```markdown
[foo](http://example.com "Example Domain"), [foo](http://example.com "Example Domain"), [bar](http://example.com "Example Domain").

![foo](http://example.com "Example Domain"), ![foo](http://example.com "Example Domain"), ![bar](http://example.com "Example Domain").
```

## API

This package exports no identifiers.
The default export is [`remarkInlineLinks`][api-remark-inline-links].

### `unified().use(remarkInlineLinks)`

Turn references and definitions into normal links and images.

## Types

This package is fully typed with [TypeScript][].

###### Parameters

There are no parameters.

###### Returns

Transform ([`Transformer`][unified-transformer]).

## Compatibility

Projects maintained by the unified collective are compatible with maintained
versions of Node.js.

When we cut a new major release, we drop support for unmaintained versions of
Node.
This means we try to keep the current release line, `remark-inline-links@^7`,
compatible with Node.js 16.

This plugin works with `unified` version 3+ and `remark` version 4+.

## Security

Use of `remark-inline-links` does not involve **[rehype][]** (**[hast][]**) or
user content so there are no openings for
[cross-site scripting (XSS)][wiki-xss] attacks.

## Related

*   [`remark-reference-links`][remark-reference-links]
    — change links and images to references with separate definitions,
    w/ IDs based on hostnames of URLs
*   [`remark-defsplit`][remark-defsplit]
    — change links and images to references with separate definitions,
    w/ numeric IDs
*   [`remark-unlink`](https://github.com/remarkjs/remark-unlink)
    — remove all links, references, and definitions

## Contribute

See [`contributing.md`][contributing] in [`remarkjs/.github`][health] for ways
to get started.
See [`support.md`][support] for ways to get help.

This project has a [code of conduct][coc].
By interacting with this repository, organization, or community you agree to
abide by its terms.

## License

[MIT][license] © [Titus Wormer][author]

<!-- Definitions -->

[build-badge]: https://github.com/remarkjs/remark-inline-links/workflows/main/badge.svg

[build]: https://github.com/remarkjs/remark-inline-links/actions

[coverage-badge]: https://img.shields.io/codecov/c/github/remarkjs/remark-inline-links.svg

[coverage]: https://codecov.io/github/remarkjs/remark-inline-links

[downloads-badge]: https://img.shields.io/npm/dm/remark-inline-links.svg

[downloads]: https://www.npmjs.com/package/remark-inline-links

[size-badge]: https://img.shields.io/bundlejs/size/remark-inline-links

[size]: https://bundlejs.com/?q=remark-inline-links

[sponsors-badge]: https://opencollective.com/unified/sponsors/badge.svg

[backers-badge]: https://opencollective.com/unified/backers/badge.svg

[collective]: https://opencollective.com/unified

[chat-badge]: https://img.shields.io/badge/chat-discussions-success.svg

[chat]: https://github.com/remarkjs/remark/discussions

[npm]: https://docs.npmjs.com/cli/install

[esm]: https://gist.github.com/sindresorhus/a39789f98801d908bbc7ff3ecc99d99c

[esmsh]: https://esm.sh

[health]: https://github.com/remarkjs/.github

[contributing]: https://github.com/remarkjs/.github/blob/main/contributing.md

[support]: https://github.com/remarkjs/.github/blob/main/support.md

[coc]: https://github.com/remarkjs/.github/blob/main/code-of-conduct.md

[license]: license

[author]: https://wooorm.com

[hast]: https://github.com/syntax-tree/hast

[rehype]: https://github.com/rehypejs/rehype

[remark]: https://github.com/remarkjs/remark

[remark-defsplit]: https://github.com/remarkjs/remark-defsplit

[remark-reference-links]: https://github.com/remarkjs/remark-reference-links

[typescript]: https://www.typescriptlang.org

[unified]: https://github.com/unifiedjs/unified

[unified-transformer]: https://github.com/unifiedjs/unified#transformer

[wiki-xss]: https://en.wikipedia.org/wiki/Cross-site_scripting

[api-remark-inline-links]: #unifieduseremarkinlinelinks
