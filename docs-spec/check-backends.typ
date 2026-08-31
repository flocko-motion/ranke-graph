// docs-spec/check-backends.typ — the contract, checked.
//
// shared/constructs.typ sorts the vocabulary into common, paper and manual.
// This compiles both backends and fails the build if either leaves a name it
// owes unbound, so a construct added to a group is a construct its backends
// must gain before the gate goes green again.
//
// The two owe different sets. Print serves the papers as well as the manuals,
// so it binds all three groups. A web backend binds what a chapter may use —
// common + manual — and is never asked for a proof.
//
// It checks the names, which is what a machine can check. Whether a backend
// renders a construct sensibly is settled by `make example` and
// `make example-html` compiling the same chapters.
//
// Compile:  typst compile --root .. check-backends.typ

#import "/shared/constructs.typ": common, paper, manual, constructs, all, unbound
#import "/shared/vocabulary.typ" as print-backend
#import "/docs-spec/examples/html-backend/vocabulary.typ" as html-backend

#let check(name, backend, names, owed) = {
  let missing = unbound(backend, names: names)
  if missing.len() > 0 {
    panic(name + " leaves " + str(missing.len()) + " construct(s) unbound: " + missing.join(", "))
  }
  [- #raw(name) binds all #names.len() of #owed. \ ]
}

#set page(width: 14cm, height: auto, margin: 1cm)
= Construct contract

#check("shared/vocabulary.typ", print-backend, all, "common + paper + manual")
#check("docs-spec/examples/html-backend/vocabulary.typ", html-backend, constructs, "common + manual")

/ common: #common.map(raw).join(", ")
/ paper: #paper.map(raw).join(", ")
/ manual: #manual.map(raw).join(", ")
