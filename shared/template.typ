// shared/template.typ — common layout for the Ranke papers.
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

#let paper(
  title: "",
  author: "",
  date: "",
  status: none,
  abstract: none,
  body,
) = {
  set document(title: title, author: author)
  set page(
    paper: "a4",
    margin: (x: 2.5cm, top: 2.5cm, bottom: 3cm),
    numbering: "1",
  )
  set text(size: 10.5pt, lang: "en")
  set par(justify: true, leading: 0.55em)
  set block(spacing: 0.7em)

  set heading(numbering: "1.1")
  show heading.where(level: 1): it => {
    set text(size: 1.25em, weight: "bold")
    block(above: 1.4em, below: 0.7em, it)
  }
  show heading.where(level: 2): it => {
    set text(size: 1.1em, weight: "bold")
    block(above: 1.1em, below: 0.5em, it)
  }
  show heading.where(level: 3): it => {
    set text(weight: "bold")
    block(above: 0.9em, below: 0.4em, it)
  }

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

// Visual-only Part divider — does not affect section numbering.
#let part(label) = {
  v(1.4em)
  align(center, text(size: 1.05em, weight: "bold", style: "italic", label))
  v(0.4em)
  line(length: 100%, stroke: 0.5pt + gray)
  v(0.4em)
}

// Theorem-like environments (sequential global numbering).
// Section-relative numbering can be added later by binding to heading counter.

#let _defn-c = counter("definition")
#let _thm-c  = counter("theorem")
#let _cor-c  = counter("corollary")

#let definition(body) = {
  _defn-c.step()
  block(spacing: 0.9em, {
    context [*Definition #_defn-c.display().*]
    h(0.4em)
    body
  })
}

#let theorem(body) = {
  _thm-c.step()
  block(spacing: 0.9em, {
    context [*Theorem #_thm-c.display().*]
    h(0.4em)
    emph(body)
  })
}

#let corollary(body) = {
  _cor-c.step()
  block(spacing: 0.9em, {
    context [*Corollary #_cor-c.display().*]
    h(0.4em)
    emph(body)
  })
}

#let proof(body) = {
  block(spacing: 0.9em, {
    [*Proof.*]
    h(0.4em)
    body
    h(1fr)
    [$square.stroked$]
  })
}

// Concept callout — for central prose-level definitions (Part I).
// Visually distinct from formal #definition[] used in math sections.
#let concept(term, body) = block(
  stroke: 0.5pt + black,
  inset: 1em,
  spacing: 1em,
  width: 100%,
  [
    #text(weight: "bold")[Definition: #term] \
    #v(0.3em)
    #body
  ]
)

// Small italic forward/backward pointer, e.g. #dref[D1, §4]
#let dref(label) = text(style: "italic")[→ #label]

// Scaffold placeholder text — easy to spot visually and easy to grep for.
#let todo(body) = text(fill: rgb("#888"), style: "italic", body)
