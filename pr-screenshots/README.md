# Pull request screenshots

Pictures that show what a pull request changes on a screen: the same view before and after.
They are here for the reviewer, in the pull request's diff and in its description. They are
not part of the app, the family guide, the store listings or the server release.

- One folder per pull request, named after its branch without the type prefix:
  `feat/289-pack-items` → `pr-screenshots/289-pack-items/`.
  `node scripts/pr-screenshots.mjs --dir` prints it.
- `before-<view>.png` and `after-<view>.png` share a row of the description's table; any
  other name stands alone.
- `node scripts/pr-screenshots.mjs` prints the Markdown for the description, with links to
  the pushed commit.
- Demo data only: the repository is public.

## Why nothing here reaches a build

- The app bundles only what `app/pubspec.yaml` lists under `app/`.
- The family guide is built from `docs/`; its own screenshots are generated into
  `docs/public/screenshots/` and never committed.
- The server release is assembled from named files by `scripts/build-server-release.sh`.
- `.gitattributes` marks the folder `export-ignore`, so a source archive leaves it out.
- `scripts/repository-boundaries.test.mjs` fails when one of these starts reading it.

## Pruning

A folder may be deleted from `main` once its pull request is merged (a `chore/` pull
request). The description's links name the pull request's commit and keep working.

How to take the pictures: [.agents/skills/pr-screenshots/SKILL.md](../.agents/skills/pr-screenshots/SKILL.md).
