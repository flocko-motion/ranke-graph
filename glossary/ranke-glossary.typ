// glossary/ranke-glossary.typ — standalone, series-wide terminology reference.
//
// A companion document to the Ranke-Graph paper series. Each paper defines its
// own terms in prose; this collects them in one place for quick lookup and is
// deliberately EXTERNAL, so it costs no paper its page budget. In case of
// doubt the papers govern — and among them the foundation paper (Paper 01),
// which fixes the ADT, wins.
//
// Single-sourced from ../shared/glossary.typ (the `entries` list).
// Compile:  typst compile --root .. ranke-glossary.typ

#import "../shared/glossary.typ": *

#set document(title: "Ranke-Graph Series — Glossary")
#set page(paper: "a4", margin: (x: 2.5cm, top: 2.5cm, bottom: 3cm), numbering: "1")
#set text(size: 10.5pt, lang: "en")
#set par(justify: true, leading: 0.55em)
#show heading: set text(weight: "bold")

#show: use-glossary

#align(center)[
  #text(size: 1.5em, weight: "bold")[Ranke-Graph Series — Glossary] \
  #v(0.3em)
  #text(size: 0.9em, style: "italic")[Companion terminology reference]
]
#v(1em)

This glossary is a convenience reference to the vocabulary of the Ranke-Graph
paper series. The definitions here repeat, in condensed form, terms each paper
introduces in its own text; the papers themselves remain authoritative, and
where they might seem to disagree the foundation paper (Paper 01), which defines
the abstract data type, governs. Terms are grouped by the paper that introduces
them.

#v(0.5em)
#glossary-full()
