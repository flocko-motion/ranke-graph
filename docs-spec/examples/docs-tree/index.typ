// docs-spec/examples/docs-tree/index.typ — the reference tree for the documentation
// format, and the fixture that proves it.
//
// A documentation tree written in the format, calling every construct a chapter
// may use at least once. The prose is Typst's `lorem` on purpose: this tree is
// scaffolding to copy, not documentation to read, and placeholder text is the
// only kind that cannot fall out of step with the papers.
//
// To start a tree of your own, copy this directory into your repository as
// `docs/`, then:
//   * replace the lorem with your prose, and the chapter names with yours;
//   * update the diagram() paths — they are project-absolute and currently
//     point into docs-spec/examples/docs-tree/;
//   * keep index.typ as the root, one file per chapter, pictures in assets/.
// `vocabulary.typ` and `handbook.typ` are placed by the build; never commit them.
//
// Build: make example (PDF) / make example-html (HTML, stub backend)

#import "handbook.typ": *

#show: handbook.with(
  title: "An Example Documentation Tree",
  subtitle: [Every construct a chapter may use, called once, with placeholder
             prose],
  date: "2026-08-31",
)

This tree is the worked example accompanying _Ranke — The Documentation
Format_. It exists to be copied, and to be compiled: `make example` builds it
through the print backend and `make example-html` builds the same files through
the stub HTML backend, so a construct that renders only one way fails the gate
here rather than in a repository downstream.

The prose below is placeholder text. What is worth reading is the source.

#part[Part I — Common constructs]

#include "01-first.typ"

#part[Part II — Manual constructs]

#include "02-second.typ"
