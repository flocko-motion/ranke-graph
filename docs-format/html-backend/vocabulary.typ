// docs-format/html-backend/vocabulary.typ — a stub HTML rendering of the docs
// constructs, and the second half of the evidence that the format has two
// backends rather than one.
//
// It renders every name in shared/constructs.typ into HTML elements, and it is
// deliberately plain: classes and structure, no styling, no navigation. A real
// web backend (ranke-website) replaces it wholesale. What this file is for is
// the check in `make handbook-html`: the committed chapters under docs/ compile
// through it, so a construct that only print can render fails here rather than
// in a downstream repository.
//
// Read it as the worked example the authoring guide points at: this is the
// whole of what implementing the contract asks of a backend.
//
// The guide's §The two backends explains the two differences that matter.
// `image()` inlines a base64 data URI under HTML export, so `diagram` emits an
// <img> element naming the file. And glossarium builds its labels where a
// glossary is printed, which a web page has no place for, so `gls` reads
// `entries` directly and links to a glossary page instead.

#import "/shared/constructs.typ": constructs
#import "/shared/glossary.typ": entries

// Term lookup, built once from the 39 canonical entries.
#let _by-key = {
  let m = (:)
  for e in entries { m.insert(e.key, e) }
  m
}

#let _term(key, plural: false) = {
  let e = _by-key.at(key, default: none)
  if e == none { panic("gls: no glossary entry for '" + key + "'") }
  let word = if plural { e.short + "s" } else { e.short }
  html.elem("a", attrs: (href: "/glossary#" + key, class: "gls"), word)
}

// A term reference. The plural is the short form with an `s`, which is what the
// present entries need; an entry carrying its own irregular plural would be
// read here instead.
#let gls(key) = _term(key)
#let glspl(key) = _term(key, plural: true)

#let _defn-c = counter("definition")
#let _thm-c  = counter("theorem")
#let _cor-c  = counter("corollary")

#let _numbered(class, word, counter-, body) = {
  counter-.step()
  html.elem("div", attrs: (class: class), {
    html.elem("span", attrs: (class: "label"), context [#word #counter-.display().])
    body
  })
}

#let definition(body) = _numbered("definition", "Definition", _defn-c, body)
#let theorem(body) = _numbered("theorem", "Theorem", _thm-c, body)
#let corollary(body) = _numbered("corollary", "Corollary", _cor-c, body)

#let proof(body) = html.elem("div", attrs: (class: "proof"), {
  html.elem("span", attrs: (class: "label"), [Proof.])
  body
})

#let concept(term, body) = html.elem("aside", attrs: (class: "concept"), {
  html.elem("h4", [Definition: #emph(term)])
  body
})

#let part(label) = {
  html.elem("hr", attrs: (class: "part"))
  html.elem("p", attrs: (class: "part"), label)
}

// The branch point, and it is narrower than it looks: `image()` is what changes,
// `figure()` stays. Under HTML export `image()` inlines the file as a base64 data
// URI, which puts the bytes of every picture into the page, so this emits an <img>
// element naming the path instead. The figure around it survives, because that is
// what carries the caption and what `@fig:claim` resolves against — a bare
// html.elem cannot be referenced.
#let diagram(path, caption, width: 100%) = {
  assert(
    path.starts-with("/"),
    message: "diagram: path must begin with / and name a file from the project root, "
      + "as in \"/docs/assets/x.svg\"; got \"" + path + "\"",
  )
  figure(
    html.elem("img", attrs: (src: path, alt: "")),
    caption: caption,
    kind: image,
    supplement: [Figure],
  )
}

#let dref(label) = html.elem("em", attrs: (class: "dref"), [→ #label])

#let todo(body) = html.elem("span", attrs: (class: "todo"), body)
