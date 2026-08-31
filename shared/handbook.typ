// shared/handbook.typ — the PRINT docs root.
//
// The document a part repo's docs/ tree compiles through. It carries the paper
// typography and nothing a paper needs that a handbook does not: no abstract,
// no author block, front matter of its own.
//
// Usage from a docs root (e.g. docs/index.typ):
//
//   #import "handbook.typ": *
//   #show: handbook.with(title: "…", subtitle: [ … ])
//   #include "01-claims.typ"
//
// The version comes from the build, not the source, so a handbook cut from a
// tag says so and one built from a working copy says `dev`:
//
//   typst compile --root . --input version=v0.21.0 docs/index.typ
//
// THE GLOSSARY APPENDIX IS NOT OPTIONAL. glossarium creates a term's label
// where the glossary is printed, so `#gls("claim")` in a chapter resolves only
// because this root prints an appendix after the body. A root that dropped it
// would fail every chapter that names a term.

#import "typography.typ": page-setup, typography
#import "glossary.typ": use-glossary, glossary-handbook
#import "vocabulary.typ": *

// "dev" unless the build says otherwise. Read once, at module evaluation.
#let version = sys.inputs.at("version", default: "dev")

#let handbook(
  title: "",
  subtitle: none,
  date: none,
  body,
) = {
  set document(title: title)
  show: page-setup
  show: typography
  show: use-glossary

  // Front matter: what this is, and which build it came from.
  align(center)[
    #text(size: 1.55em, weight: "bold")[#title]
    #if subtitle != none [
      \ #v(0.3em)
      #text(size: 1.0em, style: "italic")[#subtitle]
    ]
    \ #v(0.3em)
    #text(size: 0.85em, style: "italic")[
      #version#if date != none [ — #date]
    ]
  ]
  v(1.4em)

  outline(indent: 1em)

  pagebreak(weak: true)
  body

  // The series vocabulary, with the pages each term was named on. Printing this
  // is what makes a chapter's references resolve; see the note above.
  pagebreak(weak: true)
  [= Glossary <sec:glossary>]
  glossary-handbook()
}
