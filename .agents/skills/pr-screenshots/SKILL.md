---
name: pr-screenshots
description: Take and publish the pictures of a pull request that changes what a family sees in this repository (a screen, a widget, a colour, a text layout, an icon). Use it whenever a change touches the app's UI, before opening or updating the pull request. It covers where the pictures live (pr-screenshots/, outside every build), how to take before and after pictures without a device, and how to show them in the pull request's description.
---

# Pictures for a pull request that changes the UI

A pull request that changes what a family sees shows it: the same view before and after.
The pictures are committed on the pull request's branch in their own folder, which no build
reads, and the description links to them.

## Where they live

```sh
node scripts/pr-screenshots.mjs --dir     # → pr-screenshots/<branch without its type prefix>
```

- One folder per pull request: `feat/289-pack-items` uses `pr-screenshots/289-pack-items/`.
- `before-<view>.png` and `after-<view>.png` with the same `<view>` become one row of a
  Before/After table. Any other name stands alone (`wall-dark.png`).
- Nowhere else. `app/`, `docs/` and `server/` are build inputs: a picture there ships to
  families. [pr-screenshots/README.md](../../../pr-screenshots/README.md) says why
  this folder does not.
- Few and small: only the views that changed, cropped to what matters, PNG, under 500 KB
  each (the script warns above that).
- **Demo data only.** The repository is public. Never a picture of a real family's server,
  names, calendar or address.

## Taking them

Take the "before" pictures from `origin/main` and the "after" pictures from the branch, the
same way, at the same size, in the same language and theme. A second worktree at
`origin/main` (`git worktree add --detach .worktrees/<slug>-before origin/main`) gives the
"before" state without disturbing the work; remove it afterwards.

**The web demo** shows whole screens. It runs on in-memory data, no server:

```sh
cd app && flutter build web -t lib/main_demo.dart --release -o build/web-demo-<slug>
```

Serve that folder and capture it with Playwright, modelled on
[docs/tools/screenshots.mjs](../../../docs/tools/screenshots.mjs): the same static server,
the viewports (phone 390×844, tablet 1024×768, wall 1280×800), the browser locale for the
language, and Flutter's semantics to tap by label. The URL chooses the view:
`/?scenario=adult&still=1#/<route>`. `still=1` stops every animation, so two runs give the
same picture. The scenarios are listed at the top of
[app/lib/main_demo.dart](../../../app/lib/main_demo.dart) (`adult`, `kid`, `kiosk`, `setup`,
…). Write the capture script in a temporary folder, not in the repository.

**A widget-test render** shows one widget or sheet when no demo route reaches it: a
throwaway test that pumps the widget, loads the app's fonts with `FontLoader` (the test
font draws boxes otherwise), sets `debugDisableShadows = false`, and writes the picture with
`matchesGoldenFile('<absolute path>.png')` under `flutter test --update-goldens`. Delete the
test afterwards; it is not part of the change.

Look at every picture before committing it: the right view, nothing cut off, no placeholder
boxes instead of text.

## Showing them in the pull request

1. Commit the folder on the pull request's branch and push.
2. `node scripts/pr-screenshots.mjs` prints the Markdown. Paste it under "How it was
   checked" of the description (`gh pr edit <number> --body-file <file>`).
3. Say what each picture is: a web-demo capture or a widget-test render, never "tested on a
   phone" unless it was.
4. After a rebase or a force-push, run the script again and replace the block: the links
   name the commit.

The links point at the pushed commit, not at the branch. The branch is deleted on merge;
the commit stays reachable through the pull request, so the description keeps its pictures
even when the folder is pruned from `main` later.

A pull request that changes no screen has no folder here.
