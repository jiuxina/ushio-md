This is a plugin that adds a type of selection for focusing places
that don't allow regular selection (such as positions that have a leaf
block node, table, or the end of the document both before and after
them). By default, leaf blocks and isolating nodes will allow gap
cursors to appear next to them. You can add a `creatGapCursor: true`
property to a block node's spec to make them appear next to other
nodes as well.

You'll probably want to load `style/gapcursor.css`, which contains
basic styling for the simulated cursor (as a short, blinking
horizontal stripe).

By default, gap cursor are only allowed in places where the default
content node (in the schema content constraints) is a textblock node.
You can customize this by adding an `allowGapCursor` property to your
node specs—if it's true, gap cursor are allowed everywhere in that
node, if it's `false` they are never allowed.

@gapCursor

@GapCursor
