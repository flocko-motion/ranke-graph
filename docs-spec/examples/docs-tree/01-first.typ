#import "vocabulary.typ": *

= A chapter using the common constructs <ch:first>

Every construct in the *common* group is called below at least once. The prose
is `lorem` and means nothing; the calls are real, and are what you copy.

#lorem(40)

#concept("A term the chapter defines")[
  #lorem(28)
]

== A labelled section <sec:labelled>

#lorem(25) A glossary term renders like this — #gls("claim") — and its plural
like this: #glspl("closure"). The keys are those in `shared/glossary.typ`.

#lorem(30) A pointer to where a subject is treated at length renders as a short
aside. #dref[foundation paper §Claims]

== Pictures and code <sec:figures>

#diagram(
  "/docs-spec/examples/docs-tree/assets/diagram.svg",
  [A caption. The path is project-absolute, so update it when you copy this
   tree into your own `docs/`.],
  width: 70%,
) <fig:placeholder>

@fig:placeholder is referenced by its label, and @sec:labelled shows that a
section reference resolves the same way. Both must work in either backend.

#listing[
```
$ some-command --with-a-flag
  output line one
  output line two
```
]

== A rule this document fixes <sec:rules>

A manual may state guarantees of its own, each with a stable id, so an
application can cite one:

#rule("X-EXAMPLE", "GUARANTEE")[#lorem(22)]

Restating a rule the normative specification already owns is the thing to avoid;
cite its id instead. See `G-CITE`.

#todo[Placeholder prose, rendered so it is visible on the page and greppable in
the source.]
