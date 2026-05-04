# Conformance test data

> **Status: mock — placeholder structure only.**
> The actual conformance suite will be built alongside the reference
> implementations of the Ranke-Graph ADT.

## What this is for

A binary conformance test suite for the Ranke-Graph ADT defined in the paper alongside this directory.
Each implementation loads the example graphs, executes the listed operations,
and compares the resulting hashes against the `expected` values.
Conformance is decidable: hashes match, or they don't.

## Layout

```
testdata/
├── README.md                 # this file
├── graphs/                   # example graph instances
│   ├── g001.<ext>            # one file per graph, in canonical encoding
│   ├── g002.<ext>
│   └── ...
└── operations.<ext>          # operations + expected results
```

## Format

The on-disk format follows the reference implementation
(see [`github.com/flocko-motion/ranke-go`](https://github.com/flocko-motion/ranke-go)
and [`github.com/flocko-motion/ranke-py`](https://github.com/flocko-motion/ranke-py)).
The paper itself does not commit to a specific encoding;
it specifies the *qualities* the encoding must have (§4.4),
and the reference implementations make a concrete choice that satisfies them.

The `operations.<ext>` file lists test cases of the form:

- `union(g_a, g_b) → expected_hash`
- `insert(g_a, node_x) → expected_hash`
- `intersect(g_a, g_b) → expected_hash`
- `difference(g_a, g_b) → expected_hash`
- `hash(g_a) → expected_hash`

Any implementation that produces matching hashes for every operation conforms.

## Mock files

The current contents are placeholders to lock the structure;
they do not contain real data and will be replaced once the reference
implementations land.
