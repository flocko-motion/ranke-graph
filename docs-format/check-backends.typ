// docs-format/check-backends.typ — the contract, checked.
//
// shared/constructs.typ names what a rendering backend owes. This compiles both
// backends and fails the build if either leaves one of those names unbound, so
// a construct added to the list is a construct both backends must gain before
// the gate goes green again.
//
// It checks the names, which is what a machine can check. Whether a backend
// renders a construct sensibly is settled by `make handbook` and
// `make handbook-html` compiling the same chapters.
//
// Compile:  typst compile --root .. check-backends.typ

#import "/shared/constructs.typ": constructs, unbound
#import "/shared/vocabulary.typ" as print-backend
#import "/docs-format/html-backend/vocabulary.typ" as html-backend

#let check(name, backend) = {
  let missing = unbound(backend)
  if missing.len() > 0 {
    panic(name + " leaves " + str(missing.len()) + " construct(s) unbound: " + missing.join(", "))
  }
  [- #raw(name) binds all #constructs.len(). \ ]
}

#set page(width: 12cm, height: auto, margin: 1cm)
= Construct contract

#check("shared/vocabulary.typ", print-backend)
#check("docs-format/html-backend/vocabulary.typ", html-backend)

The contract: #constructs.map(c => raw(c)).join(", ").
