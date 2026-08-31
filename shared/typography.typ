// shared/typography.typ — the series' look, as two show-rule functions.
//
// Held apart from any one document so the papers (shared/template.typ) and the
// handbooks (shared/handbook.typ) share one source for how a Ranke document
// reads on the page. `page-setup` is the sheet; `typography` is the text on it.
//
//   #show: page-setup
//   #show: typography

// Sheet geometry and page numbering.
#let page-setup(body) = {
  set page(
    paper: "a4",
    margin: (x: 2.5cm, top: 2.5cm, bottom: 3cm),
    numbering: "1",
  )
  body
}

// Body text, paragraphs, and the heading scale.
#let typography(body) = {
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

  body
}
