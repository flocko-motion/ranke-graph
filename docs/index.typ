// docs/index.typ — the root of this repository's own docs tree.
//
// A worked example of the Ranke documentation format, and the tree a part repo
// copies to start its own. The chapters are authored and committed; the two
// files they import, `vocabulary.typ` and `handbook.typ`, are placed by the
// build and gitignored — `make docs-place` puts the print backend there.
//
// Build:  make handbook       (PDF, through shared/handbook.typ)
//         make handbook-html  (HTML, through the stub backend in docs-format/)

#import "handbook.typ": *

#show: handbook.with(
  title: "The Ranke-Graph Foundation",
  subtitle: [A handbook for the foundation part, and a worked example of the
             documentation format],
  date: "2026-08-31",
)

This handbook covers the part of the ecosystem that defines the data structure
itself: what a claim is, how an archive is assembled from claims, and what an
implementation checks. It states how the pieces are used. What an implementation
must do is fixed in the normative specification, and why the structure takes
this form is argued in the foundation paper; this document cites both rather
than repeating either.

It is also the reference tree for the documentation format. Every construct the
format offers appears somewhere in these two chapters, so a part repo starting
its own docs has a compiling example of each. The format itself is stated in
_Ranke — The Documentation Format_.

#part[Part I — The record]

#include "01-claims.typ"

#part[Part II — The archive]

#include "02-archives.typ"
