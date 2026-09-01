#!/usr/bin/env bash
# scripts/release-cycle.sh's pre-tag hook (see its own header): stamps
# CHANGELOG.md's "## Unreleased" heading with the version about to be tagged,
# committing it on the branch being released so the merge carries it to the
# tag. Leaves a fresh empty "## Unreleased" behind, so the next change always
# has a section to write into rather than having to remember to create the
# heading.
#
# THE EMPTINESS CHECK IS WHAT MAKES THAT SAFE. Leaving a heading behind
# without it would mean the next release stamps an empty section and ships
# recording nothing, which is the one thing this step exists to prevent.
#
# Reads NEXT_VERSION, DEFAULT_BRANCH and START_BRANCH from the environment —
# release-cycle.sh exports them before running this.
set -euo pipefail

head="$(grep -m1 '^## ' CHANGELOG.md 2>/dev/null || true)"
case "$head" in
	"## $NEXT_VERSION"*) ;;
	"## Unreleased"*)
		if [ "$START_BRANCH" = "$DEFAULT_BRANCH" ]; then
			echo "changelog says '## Unreleased', and a release from '$DEFAULT_BRANCH' cannot commit the stamp" >&2
			echo "  head the entry '## $NEXT_VERSION — $(date +%F)', push, then re-run" >&2
			exit 1
		fi
		body="$(awk '/^## Unreleased/{f=1;next} /^## /{f=0} f' CHANGELOG.md | tr -d '[:space:]')"
		if [ -z "$body" ]; then
			echo "changelog's '## Unreleased' section is empty, so nothing is recorded for this release" >&2
			echo "  write what changed under it, commit, then re-run" >&2
			exit 1
		fi
		echo "stamping the changelog: ## Unreleased -> ## $NEXT_VERSION"
		sed -i "0,/^## Unreleased.*$/s//## $NEXT_VERSION — $(date +%F)/" CHANGELOG.md
		# A fresh section for whatever comes next. Inserted before the first
		# heading, so no version string has to be matched as a regex.
		tmp="$(mktemp)"
		awk 'BEGIN { done = 0 }
		     /^## / && !done { print "## Unreleased"; print ""; done = 1 }
		     { print }' CHANGELOG.md > "$tmp"
		mv "$tmp" CHANGELOG.md
		git add CHANGELOG.md
		git commit --quiet -m "doc: changelog for $NEXT_VERSION"
		;;
	*)
		echo "changelog's first entry is '${head:-<none>}', so nothing is recorded for this release" >&2
		echo "  add an '## Unreleased' section, commit, then re-run" >&2
		exit 1
		;;
esac
