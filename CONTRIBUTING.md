# Contributing

How a change gets from an idea into a release. It applies to everyone who works on this
repository, people and coding agents alike; [AGENTS.md](AGENTS.md) has the architecture
and code rules.

```
issue ──► milestone ──► branch ──► pull request ──► checks ──► squash merge ──► release
(what)    (which        feat/…     "Closes #n"      required    one commit       tags, builds,
           release)                                             on main          notes, rollover
```

## Issues

- **Every feature and every fix starts as an issue**, opened with one of the forms
  (Feature, Bug, Task). One outcome per issue, with acceptance criteria as checkboxes.
- **An issue is planned when it is in a release milestone.** Milestones are releases, named
  like the app tag: `v1.12.0`. A new issue without one carries `needs-triage` until a
  maintainer assigns it. The open milestone with the lowest version is the next release.
- The four roadmap stages of [specs/13](specs/13-roadmap.md) are the labels `stage-1` to
  `stage-4`. `decision` marks a product decision the owner has to take first.
- Documentation, chores, CI changes and dependency updates may have an issue (form "Task")
  but do not need one.
- A security problem is never a public issue: see [SECURITY.md](SECURITY.md).

## Branches

`main` is protected: no direct pushes, no force pushes, changes only by pull request. Branch
from `main` and name the branch by its type; the prefix sets the pull request's type label.

| Prefix | Type label | Needs an issue |
|---|---|---|
| `feat/` | `enhancement` | yes |
| `fix/` | `bug` | yes |
| `docs/` | `documentation` | no |
| `chore/`, `refactor/`, `test/`, `build/`, `perf/` | `chore` | no |
| `ci/` | `ci` | no |
| `dependabot/` | `dependencies` | no |

Put the issue number in the name when there is one: `feat/142-quick-add`. A label set by
hand wins over the prefix.

## Pull requests

- The title is a plain sentence about the change ("A lower bottom bar on phones"), without
  a prefix. It becomes the commit on `main` and a line of the release notes.
- A feature or a fix writes `Closes #<issue>` in the description. Fill in the template's
  "How it was checked".
- Keep a pull request to one outcome. Commits inside it are yours to arrange: they are
  squashed.
- Open it as a draft while it is unfinished.

The `triage` workflow ([scripts/pr-policy.mjs](scripts/pr-policy.mjs)) then does the
bookkeeping: it sets the type label from the branch prefix, gives the pull request the
milestone of its issue (or the next release's, when it needs no issue), and reports the
status **`pr-policy`**. That status fails when

- no type can be told (unknown branch prefix and no type label),
- a feature or a fix closes no issue, or
- the issue is not in an open release milestone.

It is checked again when the description, the labels or a milestone change, also the
issue's. Linking an issue in the sidebar raises no event: edit the description afterwards.

### Required before a merge

| Check | From |
|---|---|
| `app`, `scripts`, `audit` | `ci.yml`: format, analysis, unit and widget tests, script tests, the dependency audit |
| `required` | `backend-ci.yml`: migrations, pgTAP, Edge Function tests and the integration test when the backend changed |
| `pr-policy` | `triage.yml`, as above |

Merging is **squash only**, with no bypass for administrators. Turn on auto-merge
(`gh pr merge --squash --auto`) and the pull request merges when the checks pass; the
branch is deleted. Once merged, the pull request and its issues move to the next release's
milestone if they were planned for a later one: a milestone lists what the release ships.

Dependency updates come from Dependabot weekly, grouped, after a one-week cooldown. They
are reviewed and merged by a person, never automatically.

## Releases

A release is an app tag `v<version>` and, usually, a server tag `server-v<version>` on the
same commit of `main`; the two numbers are independent
([specs/10](specs/10-deployment-and-ops.md#other-families-servers)). Versions follow
semantic versioning: a minor for features, a patch for fixes only, a major when an older
app or server stops working with it.

1. **Qualify the candidate**: run `candidate-evidence` on the head of `main`
   ([qualification/README.md](qualification/README.md)).
2. **Plan**: Actions → `release` → Run workflow. It is a dry run by default and prints the
   plan: both tags, the milestone it closes and the open issues it would move.

   ```
   gh workflow run release.yml -f dry_run=true
   ```
3. **Cut**: run it again with `dry_run=false` and a one-line summary.

   ```
   gh workflow run release.yml -f dry_run=false -f summary="Quick-add on Today"
   ```

   The version is the next open milestone's unless `-f version=1.11.1` names one;
   `-f server=patch|minor|major|none` moves the server version (default `minor`).
   The workflow ([scripts/release.mjs](scripts/release.mjs)) then
   - refuses a commit without a passing qualification,
   - creates the two annotated tags,
   - publishes the app's GitHub release with notes generated from the merged pull requests
     ([.github/release.yml](.github/release.yml) sorts them by type label),
   - starts `ci`, `backend-ci`, `release-android`, `release-ios` and `server-release` on the
     tags, and `docs` on `main` (the guide's compatibility table reads the tags),
   - closes the milestone, opens the next one and moves what is still open into it.
4. **Approve**: the release builds wait for the `release-promotion` environment. After the
   approval, Android and iOS builds go to the stores' test tracks, the signed APK is attached
   to the app's GitHub release, and the signed server archive is published as its own
   GitHub release with the same generated notes.

Release tags are protected: they cannot be moved or deleted. A release that went wrong is
followed by a new patch release, never replaced.

Updating a server to the new release is the operator's own step and never part of this
workflow: back up, then `wuselwall update <version>`
([specs/10](specs/10-deployment-and-ops.md#changing-the-database)).

## Repository settings

The settings this workflow relies on are written down and applied by
[scripts/github-settings.sh](scripts/github-settings.sh): squash-only merging, auto-merge,
deleting merged branches, the labels, private vulnerability reporting and the rulesets in
[.github/rulesets/](.github/rulesets/) (`main`: pull request, linear history, the required
checks; release tags: no deletion, no update). Change a setting there and run the script,
so the repository and the file stay the same.

Workflows pin every action to a commit, run with the least permissions they need, and keep
jobs that hold a write token or a signing secret apart from jobs that run a contributor's
code.
