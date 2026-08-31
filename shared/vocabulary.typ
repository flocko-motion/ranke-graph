// shared/vocabulary.typ — the PRINT rendering of the docs constructs.
//
// One of two backends behind the same names. A docs chapter opens with
//
//   #import "vocabulary.typ": *
//
// and the build decides what lives at that path: a part repo's `make docs`
// puts this file's exports there, ranke-website puts an HTML rendering there.
// The chapter is the same file either way.
//
// shared/constructs.typ sorts the names into three groups — common, paper,
// manual. This file binds all three, because print serves both kinds of
// document: the papers reach it through shared/template.typ, a manual through
// shared/handbook.typ. A web backend binds common + manual and is never asked
// for a proof.
//
// Nothing here sets up a page: sheet geometry, front matter, and the glossary
// appendix belong to a document root, so the same construct renders into
// whatever root includes it.

#import "constructs.typ": common, paper, manual, all
#import "glossary.typ": gls, glspl

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
    #text(weight: "bold")[Definition:] #h(0.3em) #emph[#term] \
    #v(0.3em)
    #body
  ]
)

// A captioned picture, named by path. This is the branch point between the two
// backends: print embeds the file, an HTML backend emits an <img> element
// pointing at it, since `image()` in HTML export inlines a base64 data URI.
// A chapter labels the call to cite it:
//
//   #diagram("/docs/assets/x.svg", [ ... ]) <fig:x>
//
// THE PATH IS PROJECT-ABSOLUTE. Typst resolves a relative path against the file
// holding the `image()` call, which is this one, so a chapter writing
// "assets/x.svg" would send the print backend looking under shared/. A leading
// slash anchors the path at the project root instead, and then it means the same
// thing to whichever backend reads it. The assertion below turns the mistake
// into its own error rather than a puzzling one about a missing file.
#let diagram(path, caption, width: 100%) = {
  assert(
    path.starts-with("/"),
    message: "diagram: path must begin with / and name a file from the project root, "
      + "as in \"/docs/assets/x.svg\"; got \"" + path + "\"",
  )
  figure(image(path, width: width), caption: caption)
}

// Small italic forward/backward pointer, e.g. #dref[D1, §4]
#let dref(label) = text(style: "italic")[→ #label]

// Scaffold placeholder text — easy to spot visually and easy to grep for.
#let todo(body) = text(fill: rgb("#888"), style: "italic", body)

// ── Common: also used by the papers and the normative documents ──────────

// A code listing. The space beneath keeps a following #rule from reading as the
// listing's caption — the reason the spec and the authoring guide each grew a
// copy of this before it lived here.
//
// The spacing is what was duplicated and what is shared. `size` stays a
// parameter because it is a real difference between documents rather than an
// accident: the specification's type listings are long and set smaller, at
// 0.82em, and holding it here keeps that document rendering as it did.
#let listing(body, size: 0.85em) = block(below: 1.4em)[
  #show raw: set text(size: size)
  #body
]

// A normative statement: a stable citation handle, the party it binds, and the
// statement itself, as a hanging label so a page of them scans.
//
// `tier` is free text, because what a rule binds differs by document — the
// specification says FORCED or FREE, the authoring guide says CHAPTER, BACKEND
// or BUILD. Each document names its own tiers; the rendering is shared.
#let rule(id, tier, body) = block(above: 0.6em, below: 0.6em, inset: (left: 0.2em))[
  #grid(columns: (8.5em, 1fr), column-gutter: 0.6em,
    [#text(weight: "bold")[#id] \ #text(size: 0.78em, fill: rgb("#666"))[#tier]],
    [#body])
]

// ── Manual: what a chapter telling a reader how something is used needs ──

// Two levels, and deliberately only two. A third ('caution', 'important',
// 'tip') sits between these in no way an author can decide quickly, so the
// choice becomes a coin toss and the levels stop meaning anything.
//   note     worth knowing, and the reader loses nothing by reading on
//   warning  the reader can lose data, money, or time
#let _admonition(label, weight-, body) = block(
  stroke: (left: weight- + black),
  inset: (left: 0.8em, y: 0.5em),
  spacing: 0.9em,
  width: 100%,
  { text(weight: "bold")[#label]; h(0.4em); body },
)

#let note(body) = _admonition("Note.", 0.5pt, body)
#let warning(body) = _admonition("Warning.", 1.5pt, body)

// A named thing with a signature: a command-line flag, a configuration key, an
// API field, a construct. The workhorse of reference documentation.
#let item(signature, body) = block(above: 0.7em, below: 0.7em)[
  #raw(signature, lang: "typc") \
  #block(inset: (left: 1.2em), body)
]

// A worked case. The title is optional, since an example following the prose it
// illustrates often needs no name of its own.
#let example(body, title: none) = block(spacing: 0.9em, {
  text(weight: "bold")[Example#if title != none [: #title].]
  h(0.4em)
  body
})

// ── Paper: the formal apparatus, outside the chapter contract ────────────

// Text beside a figure/table/diagram, with an optional full-width
// continuation below it — a native stand-in for float-style text wrap.
// Split the prose manually: `lefttext` sits beside `rightimage`,
// `bottomtext` continues underneath at full width.
//
// Outside the construct contract: `rightimage` is arbitrary content, so a
// caller builds the picture itself. The papers use it; a chapter uses
// `diagram` instead.
#let imageonside(lefttext, rightimage, bottomtext: none, marginleft: 0em, margintop: 0.5em) = {
  set par(justify: true)
  grid(columns: 2, column-gutter: 1em, lefttext, rightimage)
  set par(justify: false)
  block(inset: (left: marginleft, top: -margintop), bottomtext)
}
