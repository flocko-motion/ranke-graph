// shared/constructs.typ — THE CONSTRUCT CONTRACT.
//
// The series has two kinds of document. A PAPER argues a position and proves
// what it claims; a MANUAL tells a reader how something is used. They share a
// look, a glossary, and most of their constructs, and they part company at the
// few each kind needs alone.
//
// So the vocabulary is declared in three groups rather than one list:
//
//   common   both kinds use these
//   paper    shared/template.typ adds these, for the papers
//   manual   a docs chapter adds these
//
// `constructs` — common + manual — is what a docs chapter may use, and
// therefore what every rendering backend must bind. A web backend never renders
// a proof and is not asked to. shared/vocabulary.typ binds all three groups,
// since the print side serves both kinds.
//
// A construct added to a group is a construct its backends owe. Add it here, in
// shared/vocabulary.typ, in docs-spec/examples/html-backend/vocabulary.typ if the group
// reaches a chapter, and in the authoring guide's construct section, in one
// change; docs-spec/check-backends.typ fails until the backends follow.

#let common = (
  "concept",     // a prose-level definition, set apart
  "part",        // a divider between groups of chapters
  "diagram",     // a captioned picture, named by path
  "listing",     // a code block with room around it
  "rule",        // a normative statement with a citable id
  "dref",        // a pointer to where a subject is treated at length
  "todo",        // placeholder prose, visible on the page and greppable
  "gls",         // a glossary term
  "glspl",       // a glossary term, plural
)

#let paper = (
  "definition",  // a numbered formal definition
  "theorem",     // a numbered claim that is proved
  "corollary",   // a numbered claim following from one already made
  "proof",       // the argument for the preceding theorem or corollary
  "imageonside", // prose beside a picture the caller builds
)

#let manual = (
  "note",        // an aside worth knowing
  "warning",     // something the reader can lose or break
  "item",        // a named thing with a signature: a flag, a key, a field
  "example",     // a worked case
)

// What a docs chapter may use, and what a backend must bind.
#let constructs = common + manual

// Everything the print side carries, since it renders both kinds.
#let all = common + paper + manual

// The names a vocabulary module leaves unbound — empty when it holds up its end.
// Call it with the module itself:
//
//   #import "vocabulary.typ" as vocab
//   #assert.eq(unbound(vocab), ())
//   #assert.eq(unbound(vocab, names: all), ())   // for the print backend
#let unbound(vocabulary, names: constructs) = {
  let bound = dictionary(vocabulary)
  names.filter(name => not name in bound)
}
