#!/usr/bin/env bash
#
# The quality gate. Every document must compile and the RQL schema must hold —
# `make verify`, which is also what a release runs before it tags anything.
#
# The gate runs in a fresh checkout, so this installs the one thing a bare
# machine lacks. Typst is pinned to the version release.yml builds with, so a
# document that compiles here compiles there. jq and node come from the image;
# the `schema` target says so itself when they are missing.

set -euo pipefail

TYPST_VERSION=0.15.0

if ! command -v typst > /dev/null 2>&1; then
	case "$(uname -m)" in
		x86_64)        arch=x86_64 ;;
		aarch64|arm64) arch=aarch64 ;;
		*) echo "check: no typst build for $(uname -m)" >&2; exit 1 ;;
	esac

	dir="${XDG_CACHE_HOME:-$HOME/.cache}/ranke-typst/$TYPST_VERSION-$arch"
	if [ ! -x "$dir/typst" ]; then
		url="https://github.com/typst/typst/releases/download/v$TYPST_VERSION/typst-$arch-unknown-linux-musl.tar.xz"
		echo "check: installing typst $TYPST_VERSION"
		mkdir -p "$dir"
		curl -fsSL "$url" | tar -xJ -C "$dir" --strip-components=1
	fi

	export PATH="$dir:$PATH"
fi

typst --version
make verify
