#!/usr/bin/env bash
# Fetch the ranke-graph documents into a consumer repository, and stamp the commit
# they came from.
#
# THIS SCRIPT IS THE SHARED ONE. It lives in ranke-graph and serves four
# consumers — ranke-go, ranke-db, ranke-tools, and ranke-website — so a change to
# how documents are fetched is made once. A consumer downloads it and runs it;
# see BOOTSTRAP below.
#
# WHY THE STAMP: gates read the fetched copy — rule-citations and rule-vectors read
# the spec, rqlgate reads rql.schema.json — and a copy fetched days ago looks
# exactly like one fetched a minute ago. Before the stamp there was no way to ask
# which spec a green run was measured against, which is how ranke-ts shipped a gate
# reading six-day-old vectors. The stamp turns "is this current?" into a comparison.
#
# THREE MODES:
#
#   (default)    fetch unconditionally — `make docs`, for when you want the copy
#                replaced whatever the stamp says.
#   --if-moved   fetch only when the remote ref has moved off the stamp, which is
#                one 40-byte `git ls-remote` against a 1.8 MB clone. This is the
#                mode `make verify` runs, so a gate cannot read a stale cache.
#   --place      write the vocabulary shims and touch nothing else. No network.
#                ranke-graph itself runs this against its own working tree; a
#                consumer needs it only to re-place after deleting a shim.
#
# FAILING RATHER THAN GUESSING: --if-moved with no reachable remote cannot establish
# freshness, so it fails instead of passing blind on whatever is on disk — the same
# stance the gates take on a missing spec. Working offline is a deliberate ask:
# RANKE_DOCS_OFFLINE=1 keeps the copy you have, and RANKE_SPEC / RANKE_RQL_SCHEMA
# point the gates at a copy of your own.
#
# ── INTERFACE ────────────────────────────────────────────────────────────────
#
#   RANKE_GRAPH_REPO    the documents repo
#                       (default https://github.com/rankegraph/ranke-graph)
#   RANKE_GRAPH_REF     the branch or tag to read (default main)
#   PAPERS_DIR          where the fetched copy lands, repo-relative
#                       (default docs/papers)
#   DOCS_DIR            where the chapters live, repo-relative. Set it and the
#                       script writes `vocabulary.typ` and `handbook.typ` there,
#                       which is what a chapter's `#import "vocabulary.typ": *`
#                       resolves to. Left unset, no shim is written — the right
#                       default for a consumer that wants the spec and no
#                       handbook of its own.
#   SHARED_DIR          what those shims point at, repo-relative
#                       (default $PAPERS_DIR/shared)
#   RANKE_DOCS_OFFLINE  non-empty: keep the copy on disk, check nothing
#
# Run it from the consumer's repository root; every path above is taken relative
# to the working directory.
#
# ── BOOTSTRAP ────────────────────────────────────────────────────────────────
#
# Cache the script, so an offline run has it:
#
#   RANKE_GRAPH_REF   ?= main
#   RANKE_FETCHER     := bin/fetch-ranke-docs.sh
#   RANKE_FETCHER_URL := https://raw.githubusercontent.com/rankegraph/ranke-graph/$(RANKE_GRAPH_REF)/scripts/fetch-ranke-docs.sh
#
#   $(RANKE_FETCHER):
#   	@mkdir -p $(dir $@) && curl -fsSL $(RANKE_FETCHER_URL) -o $@ && chmod +x $@
#
#   docs: $(RANKE_FETCHER)
#   	@RANKE_GRAPH_REF=$(RANKE_GRAPH_REF) PAPERS_DIR=$(PAPERS_DIR) DOCS_DIR=docs $(RANKE_FETCHER)
#
#   docs-current: $(RANKE_FETCHER)
#   	@RANKE_GRAPH_REF=$(RANKE_GRAPH_REF) PAPERS_DIR=$(PAPERS_DIR) DOCS_DIR=docs $(RANKE_FETCHER) --if-moved
#
# bin/ is gitignored: the script is fetched infrastructure, never vendored, so a
# consumer cannot drift from the shared one.

set -euo pipefail

repo="${RANKE_GRAPH_REPO:-https://github.com/rankegraph/ranke-graph}"
ref="${RANKE_GRAPH_REF:-main}"
dir="${PAPERS_DIR:-docs/papers}"
docs="${DOCS_DIR:-}"
shared="${SHARED_DIR:-$dir/shared}"
stamp="$dir/.ranke-graph-sha"

mode="fetch"
case "${1:-}" in
	--if-moved) mode="if-moved" ;;
	--place)    mode="place" ;;
	"")         ;;
	*) echo "fetch-ranke-docs: unknown argument '$1' — the modes are --if-moved and --place" >&2; exit 2 ;;
esac

# The files a gate opens. A stamp matching the remote says nothing about a copy
# half-deleted since, so freshness means the stamp AND these.
gated=("$dir/spec/ranke-spec.typ" "$dir/spec/rql.schema.json")

have_gated() {
	local f
	for f in "${gated[@]}"; do
		[ -f "$f" ] || return 1
	done
}

# The two files a chapter imports. Each is one line: the chapter names
# `vocabulary.typ`, the shim says which rendering lives behind it, and the
# project-absolute path means the chapter's own depth never enters into it.
# Compiling needs `--root` at the repository root, which is where that path
# starts.
place_shims() {
	[ -n "$docs" ] || return 0
	[ -d "$shared" ] || {
		echo "fetch-ranke-docs: no $shared to point the shims at" >&2
		return 1
	}
	mkdir -p "$docs"
	local name
	for name in vocabulary handbook; do
		cat > "$docs/$name.typ" <<-SHIM
			// Generated by fetch-ranke-docs.sh. Edits here are overwritten.
			// The print rendering of the docs constructs; see $shared/$name.typ.
			#import "/$shared/$name.typ": *
		SHIM
	done
	echo ">> placed $docs/vocabulary.typ and $docs/handbook.typ over $shared/"
}

if [ "$mode" = "place" ]; then
	place_shims
	exit 0
fi

if [ -n "${RANKE_DOCS_OFFLINE:-}" ]; then
	if have_gated; then
		echo ">> papers: offline, keeping $dir at $(cat "$stamp" 2>/dev/null || echo 'an unstamped copy')"
		place_shims
		exit 0
	fi
	echo "fetch-ranke-docs: RANKE_DOCS_OFFLINE is set and $dir holds no spec — there is nothing to keep" >&2
	exit 1
fi

# One ref, so one line: "<sha>\trefs/heads/main". An empty result means the ref is
# gone rather than the network being down, and both are fatal here.
remote_sha=""
if ! remote_sha=$(git ls-remote "$repo" "$ref" 2>/dev/null | awk 'NR==1 {print $1}') || [ -z "$remote_sha" ]; then
	echo "fetch-ranke-docs: cannot resolve $ref at $repo — unreachable remote, or the ref is gone" >&2
	echo "  offline: RANKE_DOCS_OFFLINE=1 keeps the copy on disk; RANKE_SPEC / RANKE_RQL_SCHEMA point the gates elsewhere" >&2
	exit 1
fi

if [ "$mode" = "if-moved" ] && have_gated && [ "$(cat "$stamp" 2>/dev/null)" = "$remote_sha" ]; then
	echo ">> papers: $dir is current at ${remote_sha:0:12} ($ref)"
	place_shims
	exit 0
fi

echo ">> fetching ranke-graph documents into $dir/ at ${remote_sha:0:12} ($ref)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone --depth 1 --branch "$ref" "$repo" "$tmp" >/dev/null 2>&1

# Replaced whole rather than merged: a paper withdrawn upstream must disappear here
# too, or a gate keeps citing what no longer exists.
rm -rf "$dir"
mkdir -p "$dir"
cp -r "$tmp"/[0-9]*-* "$dir"/
for d in shared spec glossary docs; do
	[ -d "$tmp/$d" ] && cp -r "$tmp/$d" "$dir"/
done
cp "$tmp/LICENSE" "$dir/LICENSE" 2>/dev/null || true

# Last, so an interrupted copy leaves no stamp claiming it is complete.
if ! have_gated; then
	echo "fetch-ranke-docs: $ref carries no spec/ranke-spec.typ and spec/rql.schema.json — the gates have nothing to read" >&2
	exit 1
fi
if [ -n "$docs" ] && [ ! -f "$shared/vocabulary.typ" ]; then
	echo "fetch-ranke-docs: $ref carries no $shared/vocabulary.typ — DOCS_DIR has nothing to point at" >&2
	exit 1
fi
echo "$remote_sha" > "$stamp"
place_shims
echo ">> pulled $(find "$dir" -name '*.typ' | wc -l | tr -d ' ') document(s), stamped ${remote_sha:0:12}"
