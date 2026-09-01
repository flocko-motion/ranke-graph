#!/usr/bin/env bash
# Cut a release from the default branch as a self-contained cycle: ensure the
# tree is clean; (if on a feature branch) push it, open + merge a PR into the
# default branch so the tag points at MERGED code; tag the merged tip; push the
# tag (which triggers the release workflow); then return to the branch you
# started on. It never leaves you on — or commits directly to — the default
# branch: you can't push to main, you only release from it.
#
# Usage: make release <major|minor|patch>   (aliases: breaking|feature|fix)
#   Needs `gh` when run from a feature branch.
set -euo pipefail

bump="${1:-}"
case "$bump" in
	major | breaking) bump=major ;; # incompatible change
	minor | feature)  bump=minor ;; # backwards-compatible feature
	patch | fix)      bump=patch ;; # backwards-compatible fix
	*)
		echo "usage: make release <major|breaking | minor|feature | patch|fix>" >&2
		exit 1
		;;
esac

git fetch --tags --force origin >/dev/null 2>&1 || true

# 1. The version this run will cut, computed before anything is merged so the
#    changelog can be checked against it. Bump from the latest RELEASE tag,
#    ignoring non-semver and prerelease tags.
# `|| true`: on the first release there are no tags, so grep matches nothing and
# exits 1; under `set -o pipefail` that aborts the assignment before the
# `:-v0.0.0` fallback can apply. Swallow it so the fallback works.
latest="$(git tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)"
latest="${latest:-v0.0.0}"
IFS=. read -r maj min pat <<<"${latest#v}"
case "$bump" in
	major) maj=$((maj + 1)); min=0; pat=0 ;;
	minor) min=$((min + 1)); pat=0 ;;
	patch) pat=$((pat + 1)) ;;
esac
next="v${maj}.${min}.${pat}"

default="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
default="${default:-main}"
start="$(git rev-parse --abbrev-ref HEAD)"

# 2. The changelog names the release being cut, so the tagged tree carries it.
#    An "## Unreleased" heading is stamped and committed here, on the branch
#    being released, so the merge carries it to the tag. A fresh empty one is
#    left in its place, so the next change always has a section to write into
#    rather than having to remember to create the heading.
#
#    THE EMPTINESS CHECK IS WHAT MAKES THAT SAFE. Leaving a heading behind
#    without it would mean the next release stamps an empty section and ships
#    recording nothing, which is the one thing this step exists to prevent.
head="$(grep -m1 '^## ' CHANGELOG.md 2>/dev/null || true)"
case "$head" in
	"## $next"*) ;;
	"## Unreleased"*)
		if [ "$start" = "$default" ]; then
			echo "changelog says '## Unreleased', and a release from '$default' cannot commit the stamp" >&2
			echo "  head the entry '## $next — $(date +%F)', push, then re-run" >&2
			exit 1
		fi
		body="$(awk '/^## Unreleased/{f=1;next} /^## /{f=0} f' CHANGELOG.md | tr -d '[:space:]')"
		if [ -z "$body" ]; then
			echo "changelog's '## Unreleased' section is empty, so nothing is recorded for this release" >&2
			echo "  write what changed under it, commit, then re-run" >&2
			exit 1
		fi
		echo "stamping the changelog: ## Unreleased -> ## $next"
		sed -i "0,/^## Unreleased.*$/s//## $next — $(date +%F)/" CHANGELOG.md
		# A fresh section for whatever comes next. Inserted before the first
		# heading, so no version string has to be matched as a regex.
		tmp="$(mktemp)"
		awk 'BEGIN { done = 0 }
		     /^## / && !done { print "## Unreleased"; print ""; done = 1 }
		     { print }' CHANGELOG.md > "$tmp"
		mv "$tmp" CHANGELOG.md
		git add CHANGELOG.md
		git commit --quiet -m "doc: changelog for $next"
		;;
	*)
		echo "changelog's first entry is '${head:-<none>}', so nothing is recorded for this release" >&2
		echo "  add an '## Unreleased' section, commit, then re-run" >&2
		exit 1
		;;
esac

# Always end back on the branch we started on — never park on the default branch.
trap 'git checkout --quiet "$start" 2>/dev/null || true' EXIT

if [ "$start" != "$default" ]; then
	# 3. Feature branch: push it, open a PR if there isn't one, and merge it into
	#    the default branch — without switching this checkout — so the tag comes
	#    off the merged tip.
	if ! command -v gh >/dev/null; then
		echo "on '$start' — releasing needs it merged to '$default'. Install gh (https://cli.github.com) or merge manually, then re-run." >&2
		exit 1
	fi
	# Rebase onto the latest default first, so the PR is based on current
	# '$default' and merges cleanly. Abort cleanly on conflict rather than
	# leaving a half-finished rebase behind.
	git fetch origin "$default" >/dev/null 2>&1
	echo "rebasing '$start' onto origin/$default…"
	if ! git rebase "origin/$default"; then
		git rebase --abort 2>/dev/null || true
		echo "rebase onto origin/$default hit conflicts — resolve them, then re-run" >&2
		exit 1
	fi
	echo "pushing '$start' and merging it into '$default'…"
	git push --force-with-lease -u origin "$start"
	if [ -z "$(gh pr list --head "$start" --state open --json number --jq '.[0].number' 2>/dev/null)" ]; then
		echo "opening a pull request…"
		gh pr create --base "$default" --head "$start" --fill
	fi
	echo "merging the pull request…"
	gh pr merge "$start" --merge
	git fetch origin "$default" >/dev/null 2>&1
	target="origin/$default"

	# Bring the branch we started on up onto the merged default, so it's a clean
	# base for the next round of work (the merge kept our commits, so this
	# fast-forwards rather than replaying).
	echo "rebasing '$start' onto origin/$default…"
	git checkout --quiet "$start"
	git rebase "origin/$default"
else
	# Already on the default branch: require sync with origin so the tag points at
	# pushed code (never release unpushed local commits).
	if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$default" 2>/dev/null || git rev-parse HEAD)" ]; then
		echo "'$default' has commits not on origin — push them first" >&2
		exit 1
	fi
	target="HEAD"
fi

# 4. Tag the merged tip and push the tag.
echo "tagging ${latest} -> ${next} on ${default}"
git tag -a "$next" "$target" -m "release $next"
git push origin "$next"

# 5. Wait for the tag-triggered release workflow, so a failed build or publish
#    surfaces here instead of silently. Match the run by the tagged commit's SHA
#    (reliable for tag pushes, where headBranch is unset).
if command -v gh >/dev/null; then
	sha="$(git rev-parse "$target")"
	echo "waiting for the release workflow…"
	run_id=""
	for _ in $(seq 1 30); do
		run_id="$(gh run list --workflow=release.yml --json databaseId,headSha \
			--jq "map(select(.headSha == \"$sha\"))[0].databaseId" 2>/dev/null || true)"
		[ -n "$run_id" ] && [ "$run_id" != "null" ] && break
		sleep 2
	done
	if [ -z "$run_id" ] || [ "$run_id" = "null" ]; then
		echo "  tag pushed, but no release run appeared — check: gh run list --workflow=release.yml" >&2
	elif gh run watch "$run_id" --exit-status; then
		echo "release ${next} published ✓ (back on '$start')"
		exit 0
	else
		echo "release ${next} FAILED in CI — see: gh run view $run_id --log-failed" >&2
		exit 1
	fi
fi
echo "pushed ${next} — the release workflow triggers on the tag. Back on '$start'."
