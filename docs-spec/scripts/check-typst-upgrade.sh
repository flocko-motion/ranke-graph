#!/usr/bin/env bash
# Checks a pinned Typst version (G-TYPST, docs-spec) against Typst's latest
# GitHub release. Reads TYPST_VERSION from the current directory; run it from
# a repository root that carries one, or pass the file's path.
#
# Reports only — a version bump is a real decision (does everything still
# compile, does anything rely on old behaviour), never written automatically.
#
# Usage: check-typst-upgrade.sh [path-to-TYPST_VERSION]
#        check-typst-upgrade.sh --help

set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
	sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
	exit 0
fi

pin_file="${1:-TYPST_VERSION}"
if [ ! -f "$pin_file" ]; then
	echo "check-typst-upgrade: no $pin_file here — run this from a repository root that pins one, or pass its path" >&2
	exit 1
fi

if ! command -v curl > /dev/null 2>&1; then
	echo "check-typst-upgrade: needs curl, which isn't on PATH" >&2
	exit 1
fi

have="$(cat "$pin_file")"

response="$(curl -fsSL https://api.github.com/repos/typst/typst/releases/latest 2>/dev/null)" || {
	echo "check-typst-upgrade: could not reach Typst's GitHub releases (network down, or rate-limited) — try again shortly" >&2
	exit 1
}

latest="$(echo "$response" | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
if [ -z "$latest" ]; then
	echo "check-typst-upgrade: could not find a tag_name in the response — has the GitHub API changed?" >&2
	exit 1
fi

if [ "$latest" = "$have" ]; then
	echo "TYPST_VERSION is current: $have"
else
	echo "TYPST_VERSION $have -> $latest available"
	echo "  bump: echo $latest > $pin_file, then verify the build still passes"
fi
