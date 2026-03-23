/**
 * @typedef {import('mdast').Root} Root
 */

import {definitions} from 'mdast-util-definitions'
import {SKIP, visit} from 'unist-util-visit'

/**
 * Turn references and definitions into normal links and images.
 *
 * @returns
 *   Transform.
 */
export default function remarkInlineLinks() {
  /**
   * Transform.
   *
   * @param {Root} tree
   *   Tree.
   * @returns {undefined}
   *   Nothing.
   */
  return function (tree) {
    const definition = definitions(tree)

    visit(tree, function (node, index, parent) {
      if (
        node.type === 'definition' &&
        parent !== undefined &&
        typeof index === 'number'
      ) {
        parent.children.splice(index, 1)
        return [SKIP, index]
      }

      if (node.type === 'imageReference' || node.type === 'linkReference') {
        const def = definition(node.identifier)

        if (def && parent && typeof index === 'number') {
          parent.children[index] =
            node.type === 'imageReference'
              ? {type: 'image', url: def.url, title: def.title, alt: node.alt}
              : {
                  type: 'link',
                  url: def.url,
                  title: def.title,
                  children: node.children
                }
          return [SKIP, index]
        }
      }
    })
  }
}
