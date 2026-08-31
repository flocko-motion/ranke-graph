// shared/constructs.typ — THE CONSTRUCT CONTRACT.
//
// The names a docs chapter may use, and therefore the names every rendering
// backend must bind. This list is the contract itself: it is declared here,
// once, so the print backend (shared/vocabulary.typ) and a web backend are each
// checked against the same list rather than against one another. A construct
// added here is a construct both backends owe.
//
// A chapter reaches these names through its sibling `vocabulary.typ`, whatever
// that file happens to render to; the authoring guide (docs-format/) states the
// rules and what each construct means.
//
// `imageonside` is deliberately absent. Its second argument is arbitrary
// content, so a chapter using it would have to build an image itself, which the
// no-raw-layout rule forbids. It stays a paper construct.

#let constructs = (
  "concept",
  "definition",
  "theorem",
  "corollary",
  "proof",
  "part",
  "diagram",
  "dref",
  "todo",
  "gls",
  "glspl",
)

// The constructs a vocabulary module leaves unbound — empty when it holds up its
// end of the contract. Call it with the module itself:
//
//   #import "vocabulary.typ" as vocab
//   #assert.eq(unbound(vocab), ())
#let unbound(vocabulary) = {
  let bound = dictionary(vocabulary)
  constructs.filter(name => not name in bound)
}
