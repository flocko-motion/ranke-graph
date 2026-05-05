# P1 — Working notes

*Moved from `01-ranke-graph/notes.md` on 2026-05-04 — taxonomy was scoped out of P0 (it is not load-bearing for the ADT) and lives here, as opinionated implementation choice for the records use case (email, chat, voice messages, etc.).*

---

## Content Type Taxonomy

Three-part identifier: `content_type` + `encoding`.

- `content_type` = `category/type` (RankeDB-defined categories, application-extendable types)
- `encoding` = MIME-style `class/format` (application-defined, tells the parser how to read `content`)

### Source types (Level 0)
- `source/conversation` — communicative act with sender/receiver
- `source/media` — perceptual capture, content opaque until processed
- `source/record` — machine/objective observation of world-state
- `source/data` — structured information (defined by exclusion)
- `source/bulk` — container of other sources

### Derivation types (Level 1 — the cognitive layer)
Every L1 node is a thought — the output of a worker interpreting the graph.

**Resolved forms:** `conversation/*`, `image/*`, `video/*`
**Cognitive derivations:** `classification/*`, `observation/*`, `summary/*`, `fact/*`

### Encoding
MIME-style: `text/eml`, `image/png`, `audio/wav`, `application/pdf`.

### Design principle
*Few types, many encodings.* The diversity of the world lives in encodings, not in the type system. Each encoding is a micro-project: a parser.
