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
# FIVE MODES:
#
#   (default)    fetch unconditionally — `make docs`, for when you want the copy
#                replaced whatever the stamp says.
#   --if-moved   fetch only when the remote ref has moved off the stamp, which is
#                one 40-byte `git ls-remote` against a 1.8 MB clone. This is the
#                mode `make verify` runs, so a gate cannot read a stale cache.
#   --release R  fetch releases/download/R/ranke-docs.tar.gz (R "latest" for
#                releases/latest/download/...) instead of cloning. No git at
#                all — for a build that cannot clone, or a consumer that wants
#                to trace to a released version rather than a branch tip, the
#                same discipline tools/go.mod already holds ranke-go to. The
#                tarball carries its own stamp (see --bundle), so --if-moved's
#                freshness check reads a release-fetched tree exactly as it
#                reads a cloned one.
#   --place      write the vocabulary shims and touch nothing else. No network.
#                ranke-graph itself runs this against its own working tree; a
#                consumer needs it only to re-place after deleting a shim.
#   --bundle F   pack the documents of the tree you are standing in into the
#                tarball F. No network. ranke-graph's own `make docs-bundle`
#                runs this, to publish what --release downloads; a consumer
#                has no use for it.
#
# THE DOCUMENT SET IS DEFINED ONCE, in collect_documents() below, and the clone
# copy and --bundle both go through it. A tarball and a clone therefore give
# the same tree, so a gate cannot pass on one delivery path and fail on the
# other — and --release, reading a tarball ranke-graph's own current script
# built, cannot serve a tree assembled by a consumer's stale cached copy of
# this file either.
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
#   RANKE_GRAPH_RELEASE ?= latest
#
#   docs-release: $(RANKE_FETCHER)
#   	@PAPERS_DIR=$(PAPERS_DIR) DOCS_DIR=docs $(RANKE_FETCHER) --release $(RANKE_GRAPH_RELEASE)
#
#   upgrade:
#   	@rm -f $(RANKE_FETCHER)
#   	@$(MAKE) $(RANKE_FETCHER)
#
# WHY UPGRADE REFRESHES IT: $(RANKE_FETCHER) is a file target with no prerequisite,
# so make builds it once and the cached copy then stands for good. A consumer goes
# on running the script it first downloaded, missing every fix and every new
# document directory since. `upgrade` already means "bring everything to latest" in
# a consumer, so refreshing the cached script there is what makes that sentence
# true. The same holds for every script a consumer caches from here,
# release-cycle.sh among them.
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
bundle_out=""
release_ref="latest"
case "${1:-}" in
	--if-moved) mode="if-moved" ;;
	--place)    mode="place" ;;
	--bundle)   mode="bundle"; bundle_out="${2:-}"
	            [ -n "$bundle_out" ] || { echo "fetch-ranke-docs: --bundle needs a tarball path" >&2; exit 2; } ;;
	--release)  mode="release"; release_ref="${2:-latest}" ;;
	"")         ;;
	*) echo "fetch-ranke-docs: unknown argument '$1' — the modes are --if-moved, --place, --bundle and --release" >&2; exit 2 ;;
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

# THE DOCUMENT SET. The numbered paper directories, shared/, spec/, docs-spec/,
# glossary/, TYPST_VERSION and the licence — with figure sources, working notes
# and built PDFs left out. No gate reads any of those, and 02-ranke-db/drawio
# alone was 968 KB of the 976 KB a full copy carried; without it the whole set
# is 117 KB.
#
# docs-spec/examples/ ships too: it is the worked example the specification
# points at (a reference chapter tree, a stub HTML backend), and every backend
# author needs it. Leaving it out forced a consumer to fetch the fixture file
# by file through the GitHub trees API instead of reading it from the release.
#
# TYPST_VERSION travels with the papers, not separately: it names the Typst
# release that renders THESE documents (shared/handbook.typ among them)
# correctly, so it is a fact about this fetch, the same as vocabulary.typ is —
# not a pin a consumer decides and maintains on its own, which is what let
# ranke-db's copy drift silently until something downstream noticed.
#
# ranke-graph's own docs/ tree is absent on purpose: its chapters import a
# `vocabulary.typ` that would not resolve where they landed, so a copy here is a
# tree that cannot be built. The authoring guide names where it lives.
#
# Hidden entries are dropped too. A clone carries none inside the document set,
# but --bundle reads a working tree, which carries whatever a local tool left
# there — and a release must ship the documents, not somebody's editor state.
# The same reasoning excludes the two gitignored shims `make docs-place` writes
# into the example tree: a consumer supplies those themselves (the format's own
# design), so shipping a local dev's copy would ship the wrong ones.
doc_excludes=(
	--exclude=drawio
	--exclude=notes.md
	--exclude=quotes.md
	--exclude='*.pdf'
	--exclude='.*'
	--exclude='docs-spec/examples/docs-tree/vocabulary.typ'
	--exclude='docs-spec/examples/docs-tree/handbook.typ'
)

collect_documents() {
	local src="$1" dst="$2"
	local members=() d
	for d in "$src"/[0-9]*-*/; do [ -d "$d" ] && members+=("$(basename "$d")"); done
	for d in shared spec docs-spec glossary; do [ -d "$src/$d" ] && members+=("$d"); done
	[ -f "$src/LICENSE" ] && members+=(LICENSE)
	[ -f "$src/TYPST_VERSION" ] && members+=(TYPST_VERSION)
	[ ${#members[@]} -gt 0 ] || { echo "fetch-ranke-docs: $src holds no documents" >&2; return 1; }
	mkdir -p "$dst"
	tar -C "$src" -cf - "${doc_excludes[@]}" "${members[@]}" | tar -C "$dst" -xf -
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

if [ "$mode" = "bundle" ]; then
	work=$(mktemp -d)
	trap 'rm -rf "$work"' EXIT
	collect_documents . "$work/ranke-docs"
	# Stamped inside, as the clone path stamps what it writes, so a tree taken
	# from the tarball answers "which commit is this?" the same way.
	git rev-parse HEAD > "$work/ranke-docs/.ranke-graph-sha" 2>/dev/null \
		|| echo "fetch-ranke-docs: no commit to stamp the bundle with" >&2
	mkdir -p "$(dirname "$bundle_out")"
	tar -C "$work" -czf "$bundle_out" ranke-docs
	echo ">> wrote $bundle_out — $(find "$work/ranke-docs" -type f | wc -l | tr -d ' ') file(s), $(du -h "$bundle_out" | cut -f1)"
	exit 0
fi

if [ "$mode" = "release" ]; then
	if [ "$release_ref" = "latest" ]; then
		url="$repo/releases/latest/download/ranke-docs.tar.gz"
	else
		url="$repo/releases/download/$release_ref/ranke-docs.tar.gz"
	fi
	echo ">> fetching ranke-graph documents from $url"
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	if ! curl -fsSL "$url" -o "$tmp/ranke-docs.tar.gz"; then
		echo "fetch-ranke-docs: cannot fetch $url — check the release and the asset both exist" >&2
		exit 1
	fi
	tar -C "$tmp" -xzf "$tmp/ranke-docs.tar.gz"

	# Replaced whole, as the clone path replaces $dir whole: a paper withdrawn
	# upstream must disappear here too.
	rm -rf "$dir"
	mkdir -p "$(dirname "$dir")"
	mv "$tmp/ranke-docs" "$dir"

	if ! have_gated; then
		echo "fetch-ranke-docs: $url carries no spec/ranke-spec.typ and spec/rql.schema.json — the gates have nothing to read" >&2
		exit 1
	fi
	if [ -n "$docs" ] && [ ! -f "$shared/vocabulary.typ" ]; then
		echo "fetch-ranke-docs: $url carries no $shared/vocabulary.typ — DOCS_DIR has nothing to point at" >&2
		exit 1
	fi
	# The tarball carries its own .ranke-graph-sha (--bundle wrote it), landing at
	# $stamp with the rest of the tree — nothing to write here, and --if-moved
	# reads it exactly as it reads a clone's.
	place_shims
	echo ">> pulled $(find "$dir" -name '*.typ' | wc -l | tr -d ' ') document(s) from $release_ref, stamped $(cat "$stamp" 2>/dev/null || echo 'unstamped')"
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
collect_documents "$tmp" "$dir"

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
