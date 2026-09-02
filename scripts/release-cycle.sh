#!/usr/bin/env bash
# Cut a release from the default branch as a self-contained cycle: resolve the
# version; run a consumer's own pre-tag steps if it has any (changelog stamp,
# compliance checks — anything that must be true or done once the version is
# known and before it is merged); (if on a feature branch) rebase, push, open a
# PR, wait for its checks, merge it into the default branch so the tag points at
# MERGED code; tag
# the merged tip; push the tag (which triggers the release workflow); then
# return to the branch you started on. It never leaves you on — or commits
# directly to — the default branch: you can't push to main, you only release
# from it.
#
# THIS SCRIPT IS THE SHARED ONE. It lives in ranke-graph and serves every
# consumer — ranke-go, ranke-ts, ranke-db, ranke-tools, ranke-website — so the
# git mechanics of a release (branch resolution, the merge-then-tag dance, the
# wait for CI) are written once. A consumer downloads it and runs it from
# `make release`; see BOOTSTRAP below.
#
# WHAT DIFFERS PER CONSUMER lives in that consumer's OWN repo, as scripts at
# three fixed names — convention, not configuration, so `make release` is the
# same line in every Makefile and a repo's release behaviour is legible by
# listing scripts/, not by reading env vars threaded through a recipe:
#
#   scripts/release-next-version.sh    executable, optional. Prints the next
#                                       version (with the leading v) on stdout.
#                                       Present: a bump word is refused rather
#                                       than ignored, since a version derived
#                                       from another source, a package mirroring
#                                       an upstream say, has nothing for one to
#                                       mean. Absent: this script bumps the
#                                       latest tag by the required bump word
#                                       itself.
#   scripts/release-pretag.sh          executable, optional. Runs once the
#                                       version is known and before the
#                                       feature-branch merge, so anything it
#                                       commits (a stamped changelog, a
#                                       generated file) rides the same PR the
#                                       tag is eventually cut from. Non-zero
#                                       exit aborts the release. Reads
#                                       NEXT_VERSION, DEFAULT_BRANCH,
#                                       START_BRANCH, LATEST_VERSION from the
#                                       environment. Absent: no step runs.
#   scripts/release-feature-branch-only  existence checked only, need not be
#                                       executable or non-empty. Present:
#                                       releasing from the default branch is
#                                       refused outright rather than allowed
#                                       with a sync check — a repo whose
#                                       process is feature-branch-only (ranke-ts)
#                                       says so here instead of tolerating a
#                                       shortcut nothing else in it expects.
#
# WHY CONVENTION AND NOT A FORK: the alternative to these three names is a
# fifth copy of this file with one block edited, which is the exact failure
# this script exists to end — two dirty-tree-check and bump-word-check bugs
# already had to be hand-applied to four copies of it before this one existed.
#
# Usage: release-cycle.sh <major|minor|patch>   (aliases: breaking|feature|fix)
#        release-cycle.sh   (no bump word — refused unless
#                            scripts/release-next-version.sh exists)
#
# ── BOOTSTRAP ────────────────────────────────────────────────────────────────
#
# Cache the script, so an offline run has it:
#
#   RELEASE_CYCLER     := bin/release-cycle.sh
#   RANKE_GRAPH_RAW    := https://raw.githubusercontent.com/rankegraph/ranke-graph
#   RELEASE_CYCLER_URL := $(RANKE_GRAPH_RAW)/main/scripts/release-cycle.sh
#
#   $(RELEASE_CYCLER):
#   	@mkdir -p $(dir $@) && curl -fsSL $(RELEASE_CYCLER_URL) -o $@ && chmod +x $@
#
#   release: check-clean-tree check-release-bump verify $(RELEASE_CYCLER)
#   	@$(RELEASE_CYCLER) $(filter major minor patch breaking feature fix,$(MAKECMDGOALS))
#
# bin/ is gitignored: the script is fetched infrastructure, never vendored, so a
# consumer cannot drift from the shared one. ranke-graph itself, being the
# source, runs ./scripts/release-cycle.sh directly instead — see this repo's
# own Makefile.
set -euo pipefail

NEXT_VERSION_HOOK="scripts/release-next-version.sh"
PRETAG_HOOK="scripts/release-pretag.sh"
FEATURE_ONLY_MARKER="scripts/release-feature-branch-only"

bump="${1:-}"
has_version_hook=0
[ -x "$NEXT_VERSION_HOOK" ] && has_version_hook=1

if [ "$has_version_hook" -eq 1 ]; then
	if [ -n "$bump" ]; then
		echo "release-cycle: $NEXT_VERSION_HOOK exists — the version is derived, so a bump word ('$bump') means nothing here" >&2
		exit 1
	fi
else
	case "$bump" in
		major | breaking) bump=major ;; # incompatible change
		minor | feature)  bump=minor ;; # backwards-compatible feature
		patch | fix)      bump=patch ;; # backwards-compatible fix
		*)
			echo "usage: release-cycle.sh <major|breaking | minor|feature | patch|fix>" >&2
			echo "  or add $NEXT_VERSION_HOOK to derive the version some other way" >&2
			exit 1
			;;
	esac
fi

git fetch --tags --force origin >/dev/null 2>&1 || true

# Computed before anything merges, so a pre-tag hook can check against it.
# `|| true`: no tags yet means grep exits 1, which pipefail would make fatal.
latest="$(git tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)"
latest="${latest:-v0.0.0}"

if [ "$has_version_hook" -eq 1 ]; then
	next="$(LATEST_VERSION="$latest" "./$NEXT_VERSION_HOOK")"
	case "$next" in
		v[0-9]*.[0-9]*.[0-9]*) ;;
		*) echo "release-cycle: $NEXT_VERSION_HOOK printed '$next', not a vX.Y.Z version" >&2; exit 1 ;;
	esac
else
	IFS=. read -r maj min pat <<<"${latest#v}"
	case "$bump" in
		major) maj=$((maj + 1)); min=0; pat=0 ;;
		minor) min=$((min + 1)); pat=0 ;;
		patch) pat=$((pat + 1)) ;;
	esac
	next="v${maj}.${min}.${pat}"
fi

default="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
default="${default:-main}"
start="$(git rev-parse --abbrev-ref HEAD)"

if [ -x "$PRETAG_HOOK" ]; then
	NEXT_VERSION="$next" DEFAULT_BRANCH="$default" START_BRANCH="$start" LATEST_VERSION="$latest" \
		"./$PRETAG_HOOK"
fi

# Always end back on the branch we started on — never park on the default branch.
trap 'git checkout --quiet "$start" 2>/dev/null || true' EXIT

# Waiting beats `--auto`, which needs "Allow auto-merge" on in each of six
# repositories. gh says "no checks reported" where a base requires none, and
# says it too in the seconds before checks register, hence the probes.
await_checks() {
	local pr="$1" out i
	for i in 1 2 3 4 5; do
		out="$(gh pr checks "$pr" 2>&1)" && return 0
		case "$out" in *"no checks reported"*) sleep 3; continue ;; esac
		echo "waiting for the pull request's checks…"
		gh pr checks "$pr" --watch --fail-fast
		return $?
	done
	return 0
}

if [ "$start" != "$default" ]; then
	# Feature branch: merge it into the default without switching this checkout.
	if ! command -v gh >/dev/null; then
		echo "on '$start' — releasing needs it merged to '$default'. Install gh (https://cli.github.com) or merge manually, then re-run." >&2
		exit 1
	fi
	git fetch origin "$default" >/dev/null 2>&1

	if git merge-base --is-ancestor "$start" "origin/$default"; then
		# RESUME. A run whose merge landed and whose tag did not leaves nothing to
		# open a PR from, and `gh pr create` on zero commits ahead fails.
		echo "'$start' is already on '$default' — tagging the merged tip"
		git rebase "origin/$default"
	else
		# Rebase first, so the PR is based on current '$default'. A conflict aborts
		# rather than leaving a half-finished rebase behind.
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
		await_checks "$start" || {
			echo "release-cycle: '$start' has a failing check — fix it, then re-run" >&2
			exit 1
		}
		echo "merging the pull request…"
		gh pr merge "$start" --merge
		git fetch origin "$default" >/dev/null 2>&1

		# A clean base for the next round: the merge kept our commits, so this fast-forwards.
		echo "rebasing '$start' onto origin/$default…"
		git checkout --quiet "$start"
		git rebase "origin/$default"
	fi
	target="origin/$default"
elif [ ! -e "$FEATURE_ONLY_MARKER" ]; then
	# Already on the default branch: require sync with origin so the tag
	# points at pushed code (never release unpushed local commits).
	if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$default" 2>/dev/null || git rev-parse HEAD)" ]; then
		echo "'$default' has commits not on origin — push them first" >&2
		exit 1
	fi
	target="HEAD"
else
	echo "on '$default' — this repo releases from a feature branch only ($FEATURE_ONLY_MARKER exists); switch and re-run" >&2
	exit 1
fi

echo "tagging ${latest} -> ${next} on ${default}"
git tag -a "$next" "$target" -m "release $next"
git push origin "$next"

# The tag-triggered workflow, so a failed publish surfaces here. Matched by the
# tagged SHA, since headBranch is unset for a tag push.
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
