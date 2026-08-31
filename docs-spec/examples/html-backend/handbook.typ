// docs-spec/examples/html-backend/handbook.typ — the HTML docs root.
//
// The counterpart of shared/handbook.typ, and a short one. A web page gets its
// navigation and its glossary from the site around it, so this root writes the
// front matter and nothing else: no outline, and no glossary appendix, because
// the HTML `gls` links to a glossary page rather than to a label this document
// would have to create.

#import "vocabulary.typ": *

#let version = sys.inputs.at("version", default: "dev")

#let handbook(
  title: "",
  subtitle: none,
  date: none,
  body,
) = {
  set document(title: title)
  // Numbered headings, so a chapter's `@sec:integrity` resolves here as it does
  // in print. A root that leaves them unnumbered breaks every section reference.
  set heading(numbering: "1.1")

  html.elem("header", attrs: (class: "handbook-front"), {
    html.elem("h1", title)
    if subtitle != none { html.elem("p", attrs: (class: "subtitle"), subtitle) }
    html.elem("p", attrs: (class: "version"), {
      version
      if date != none [ — #date]
    })
  })

  body
}
