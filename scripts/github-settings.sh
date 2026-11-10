#!/usr/bin/env bash
# The repository's GitHub settings as code (CONTRIBUTING.md "Repository settings"): merge
# options, labels and the rulesets in .github/rulesets/. Run by a repository administrator
# with the gh CLI; safe to run again, it only sets what is written here.
#
#   scripts/github-settings.sh [repo] [labels] [rulesets]      (no argument = all three)
#   scripts/github-settings.sh ruleset .github/rulesets/release-tags.json
#
# Not here, because they hold reviewers or secrets and are set once by hand: the
# environments release-promotion (required reviewers, no administrator bypass, the tags
# v* and server-v*) and server-release (the signing key, the tags server-v*).
set -euo pipefail
cd "$(dirname "$0")/.."
repo=${GH_REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}

settings() {
  # One commit per pull request on main, titled like the pull request; merged branches go.
  gh api -X PATCH "repos/$repo" \
    -F allow_squash_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false \
    -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY \
    -F allow_auto_merge=true -F delete_branch_on_merge=true -F allow_update_branch=true \
    --jq '"merge settings: squash only, auto-merge, branches deleted after the merge"'
  gh api -X PUT "repos/$repo/private-vulnerability-reporting" >/dev/null
  echo "private vulnerability reporting: on"
}

label() { gh label create "$1" --repo "$repo" --color "$2" --description "$3" --force >/dev/null; echo "label: $1"; }

labels() {
  # Types: every pull request has one (scripts/pr-policy.mjs, .github/release.yml).
  label enhancement a2eeef "Type: a feature. Needs an issue in a release milestone"
  label bug d73a4a "Type: a fix. Needs an issue in a release milestone"
  label documentation 0075ca "Type: the family guide, the specification or other documentation"
  label chore c5def5 "Type: maintenance that changes nothing a family sees"
  label ci bfd4f2 "Type: workflows, runners and the release tooling"
  label dependencies 0366d6 "Type: a dependency update"
  # Triage and release notes.
  label needs-triage fbca04 "An issue that is not in a release milestone yet"
  label skip-release-notes ededed "Left out of the generated release notes"
  # The four roadmap stages (specs/13); milestones are releases.
  label stage-1 5319e7 "Roadmap stage 1: everyday essentials"
  label stage-2 5319e7 "Roadmap stage 2: a lighter day"
  label stage-3 5319e7 "Roadmap stage 3: family Alpha"
  label stage-4 5319e7 "Roadmap stage 4: ready for other families"
}

ruleset() {
  local file=$1 name id
  name=$(node -p 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).name' "$file")
  id=$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\") | .id")
  if [ -n "$id" ]; then gh api -X PUT "repos/$repo/rulesets/$id" --input "$file" >/dev/null
  else gh api -X POST "repos/$repo/rulesets" --input "$file" >/dev/null; fi
  echo "ruleset: $name"
}

rulesets() { for file in .github/rulesets/*.json; do ruleset "$file"; done; }

[ $# -gt 0 ] || set -- repo labels rulesets
while [ $# -gt 0 ]; do
  case $1 in
    repo) settings ;;
    labels) labels ;;
    rulesets) rulesets ;;
    ruleset) ruleset "${2:?usage: github-settings.sh ruleset <file>}"; shift ;;
    *) echo "usage: github-settings.sh [repo] [labels] [rulesets] | ruleset <file>" >&2; exit 2 ;;
  esac
  shift
done
