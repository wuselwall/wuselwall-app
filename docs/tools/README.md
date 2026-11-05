# Family guide workflow

The guide is written for families. German pages live at the root of `docs/`;
English, French and Spanish pages use the same routes under `en/`, `fr/` and `es/`.
Product decisions and developer documentation belong in `specs/`.

## Edit and preview

From the repository root:

```bash
npm ci
npm run docs:dev
```

Update all four languages in the same change. Keep existing heading anchors when
rewriting a section: other pages and older app releases may link directly to them.
Use short, complete examples that explain the action and its result. Check screen
labels against `app/l10n/app_{en,de,fr,es}.arb` and behaviour against the implementation.

## Capture screenshots

Screenshots use the Flutter web demo and sample data. No family server is contacted.
Install Flutter and Playwright's browser first:

```bash
npx playwright install chromium
```

On Linux, install missing Chromium system dependencies once with
`sudo npx playwright install-deps chromium` if the browser cannot launch.

Build the current demo and capture every screen:

```bash
npm run docs:screenshots
```

For a focused edit, rebuild the demo, then name only the captures you need:

```bash
npm run docs:demo
node docs/tools/screenshots.mjs setup-claim usual-week meals-shopping-preview
```

Each capture produces DE/EN/FR/ES images in light and dark. The images live in the
git-ignored `docs/public/screenshots/` directory. CI regenerates them before publication.
The capture script reuses an existing demo build; rebuild it after app changes.

Add a new capture to `screenshots.mjs`, then place it beside the instructions it explains:

```vue
<Shot name="setup-claim" alt="Setup key and email address before creating the family" />
```

Add `wide` for tablet and wall screenshots. Translate the alternative text in every
guide language. The component selects the reader's language and theme automatically.

## Validate before publishing

```bash
npm run docs:check
npm run docs:build
npm run docs:browser
```

`docs:check` checks translated routes and screenshot coverage. `docs:build` checks
page links. `docs:browser` checks the built guide's language switching, search, themes,
images and mobile navigation. A fresh checkout needs the full screenshot capture first.

The documentation workflow builds pull requests and publishes `main` changes
to GitHub Pages when `DOCS_PAGES_ENABLED=true`. The marketing website has its own
repository and publication workflow.

## Export for the marketing repository

After building the demo, write a chosen set outside the generated guide directory:

```bash
SHOT_LANGS=de,en,fr,es SHOT_OUT=/tmp/wuselwall-screenshots node docs/tools/screenshots.mjs wall-board wall-child-week shopping-phone kid-shopping
```

Copy the export explicitly into the website repository. Its CI does not check out
the app source. Screenshot output is for illustration, not native release qualification.
