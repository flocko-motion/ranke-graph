// shared/template.typ — the paper root.
//
// A paper's page setup and title block. The constructs a paper writes with live
// in shared/vocabulary.typ and are re-exported here, so a paper still reaches
// everything through one import.
//
// Usage from a paper file (e.g. 01-ranke-graph/ranke-graph.typ):
//
//   #import "../shared/template.typ": *
//   #show: paper.with(
//     title:    "...",
//     author:   "...",
//     date:     "2026-05-03",
//     status:   "scaffold",
//     abstract: [ ... ],
//   )
//
// The handbooks have a root of their own, shared/handbook.typ; both draw their
// look from shared/typography.typ.

#import "typography.typ": page-setup, typography
#import "vocabulary.typ": *

#let paper(
  title: "",
  author: "",
  date: "",
  status: none,
  abstract: none,
  body,
) = {
  set document(title: title, author: author)
  show: page-setup
  show: typography

  // Title block
  align(center)[
    #text(size: 1.55em, weight: "bold")[#title]\
    #v(0.3em)
    #text(size: 1.0em)[#author]\
    #text(size: 0.85em, style: "italic")[
      #date#if status != none [ — #status]
    ]
  ]
  v(1.2em)

  if abstract != none {
    block[
      #text(weight: "bold")[Abstract.] #h(0.4em) #abstract
    ]
    v(0.8em)
  }

  body
}
