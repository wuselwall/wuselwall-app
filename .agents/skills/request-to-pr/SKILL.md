---
name: request-to-pr
description: The path every request takes in this repository, from the first edit to an open pull request. Use it before changing any file here (a feature, a fix, documentation, CI, a chore, however small), and again when the work is ready to commit. It covers the worktree, the issue and branch name, the checks, the commit, the push and the pull request.
---

# From a request to a pull request

Every request that changes a file in this repository is worked in its own git worktree and
ends in a pull request. Commit, push and open the pull request without being asked: the
request is not finished while the change exists only on disk. Merging is the one step that
waits for the owner.

A request that changes no file (a question, a look at CI, operating a server, cutting a
release with the `release` workflow) needs neither a worktree nor a pull request.

## 1. Before the first edit

1. **A follow-up to an open pull request continues there.** `gh pr list --state open` and
   `git worktree list` show whether the branch and its worktree exist. Work in that
   worktree and push to that branch; do not open a second pull request for the same outcome.
2. **A feature or a fix needs its issue first**, in a release milestone
   ([AGENTS.md](../../../AGENTS.md) "Development workflow",
   [CONTRIBUTING.md](../../../CONTRIBUTING.md)). Documentation, chores, CI and dependency
   changes need none.
3. **Name the branch by type**: `feat/<issue>-<slug>`, `fix/<issue>-<slug>`, `docs/<slug>`,
   `chore/<slug>`, `ci/<slug>`. The prefix sets the pull request's label.
4. **Cut the worktree from the current `main` of the remote**, from the repository's main
   checkout:

   ```sh
   git fetch origin main
   git worktree add .worktrees/<slug> -b <type>/<issue>-<slug> origin/main
   cd .worktrees/<slug>
   ```

   `.worktrees/` is the one place for worktrees. Never switch the branch of the main
   checkout or of another worktree, and never edit files there: other sessions and other
   agents work in them at the same time.
5. **A new worktree has no git-ignored files and no installed packages.** Install what the
   task needs (`npm ci` at the root, `flutter pub get` and `flutter gen-l10n` in `app/`).
   Copy a git-ignored settings file (`app/env/dev.json`, `scripts/remote.env`) from the main
   checkout only when the task needs it, and never commit it.

## 2. While working

- Every path you read, edit or run is inside the worktree. A command that starts in the main
  checkout tests the wrong code.
- Keep the pull request to one outcome. A second outcome found on the way gets its own
  issue, or its own worktree and pull request.
- A change to what a family sees needs pictures: follow the skill
  [pr-screenshots](../pr-screenshots/SKILL.md) before the pull request is opened.

## 3. Check

Run what the change touches and keep the output for the pull request:

| Changed | Run |
|---|---|
| `app/` | in `app/`: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --no-pub --fatal-infos`, `flutter test` |
| `supabase/` | pgTAP (`npm run db:test` on the local stack); Deno checks for Edge Functions |
| `scripts/`, `qualification/`, `docs/tools/` | `node --test` on the tests beside the changed file |
| `docs/` | `npm run docs:check:source` |
| texts a family reads | all four languages (`app/l10n/`, `docs/`) |

The pull request template's checklist names the rest: the family guide and the specification
match the change, a migration is forward-only, and no operator's server appears in a
committed file.

## 4. Commit, push, open the pull request

1. `git status` and `git diff`: commit only what belongs to the request. No secrets, no
   git-ignored settings, no build output.
2. Commit in the worktree and push the branch: `git push -u origin <branch>`. Commit messages
   are plain sentences; they are squashed on merge.
3. Write the description from [.github/pull_request_template.md](../../../.github/pull_request_template.md)
   into a file outside the repository and open the pull request:

   ```sh
   gh pr create --base main --title "<plain sentence, no prefix>" --body-file <file>
   ```

   The title becomes the commit on `main` and a line of the release notes. A feature or a
   fix writes `Closes #<issue>`. "How it was checked" holds the commands that were run and
   what they showed, the pictures of a changed screen, and what was not checked. Open it as
   a draft (`--draft`) while it is unfinished. Do not set labels or the milestone: the
   `triage` workflow does.
4. Watch the checks (`gh pr checks <number> --watch`) and fix the cause of a failing one in
   the same worktree; never weaken a check to pass it.
5. End the request with the pull request's link, what was checked and what stays open.

## 5. After the merge

Merge only when the owner asked for it (`gh pr merge --squash --auto`). When the pull
request is merged or closed, remove the worktree and the local branch from the main
checkout:

```sh
git worktree remove .worktrees/<slug>
git branch -D <branch>
```
