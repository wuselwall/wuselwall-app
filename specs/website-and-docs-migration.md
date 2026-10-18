# Website separation and documentation cutover

## Target layout

| Repository | Owns | Delivery |
|---|---|---|
| `wuselwall/wuselwall-app` (visibility unchanged) | App, backend, specs, VitePress source and screenshot generator | Existing app/server releases; prepared GitHub Pages docs |
| `wuselwall/wuselwall-website` (private) | Astro marketing/legal pages, public app-link files, copied screenshots, website container and deploy helper | Independent website CI and explicitly authorized deploy |

The intended docs address is **https://docs.wuselwall.app/** (English `/en/`).
The old address is still operationally significant until cutover. No command in this
plan authorizes an unreviewed production operation.

## Phase 1 — review and merge source separation

1. Review the private website import PR. Its provenance is the tracked website snapshot
   from app SHA `106ba1c2603c3e97e25d0d2611f5dce36ca1bb4d`; no ignored environment,
   credentials, full app history or backend source should be imported.
2. Verify its independent `npm ci`, normal/strict legal build, SEO output, app-link
   verification files, screenshot import and deploy-helper checks. Configure the new
   repository's production environment protections and required website secrets through
   the operator's approved secret-management process; secret values cannot be copied
   out of the old GitHub repository via the API and are not requested in chat.
3. Review/merge the app separation PR. App CI must not reference `website/`, its lockfile
   or the private marketing checkout. Docs and store-artwork generation stay functional.
4. Coordinate PR #58's pending CI/docs remediation by intent: it overlaps `ci.yml` and
   `docs.yml`. Do not reintroduce removed website jobs, SSH docs publishing or persistent
   PR runners when either branch is updated. Rerun checks on the actual merged candidate.
5. Do not delete the old live website deployment or static `/docs/` directory. Source
   removal is not server cleanup. Existing builds and deep links keep working.

## Phase 2 — satisfy Pages and DNS prerequisites

- The app repository remains private by explicit choice. Obtain an eligible GitHub plan
  for private-repository Pages, or separately authorize publication after a safety review.
  Removing files in a forward commit does **not** remove them from history.
- In app Settings → Pages, choose **GitHub Actions** as the build source and configure
  custom domain **docs.wuselwall.app**. Verify domain ownership as GitHub instructs before
  exposing DNS; a checked-in CNAME alone does not configure an Actions Pages domain.
- Configure the DNS **CNAME `docs` → `wuselwall.github.io`** (no `/path/`), confirm there
  are no conflicting A/AAAA records for that hostname, and follow GitHub's current
  domain-verification requirements. Prefer DNS-only during initial certificate setup;
  any proxying must be separately checked against GitHub Pages guidance.
- Confirm Pages eligibility, DNS validation, HTTPS certificate provisioning and
  environment access. Do not claim the domain is live until it answers correctly.
- Set repository variable **`DOCS_PAGES_ENABLED=true`** only after these checks. On `main`,
  trigger the docs workflow or push a qualifying docs change. PRs never publish.

## Phase 3 — verify and switch traffic

1. Verify a successful exact-head Pages deployment and the published homepage, English
   homepage, nested guide pages, assets, search and screenshots. Test a direct deep-link
   refresh, mobile navigation and light/dark shots. Check CNAME and sitemap output.
2. Update marketing links and bilingual privacy disclosures for GitHub Pages' hosting
   and IP processing; do not claim GitHub has the old server's no-log behavior.
3. Only then configure the existing marketing front end to redirect `/docs` and
   `/docs/<path>` to `https://docs.wuselwall.app/` and the matching `<path>`, preserving
   language and query strings. Test `/docs/en/guide/setup` and `/docs/settings/shortcuts`.
4. Update app help/Shortcuts copy and Play listing docs URLs in DE/EN in a separate
   release-safe change once the target is reachable. This preparation intentionally
   leaves existing shipped links unchanged. Retain redirects for old app releases.
5. Retire old docs SSH credentials/runner access only after verification; review scopes
   rather than deleting secrets or production files during source migration.

## Screenshots and brand assets

Generate screenshots in the app repository with `npm run docs:screenshots`.
The website import tool accepts an explicit local source directory; export only the
needed generated assets and commit the WebP copies in the website repository. Do not
share a writable checkout or require a cross-repository token for normal builds.
The app's Play listing script reads the retained `docs/public/logo.svg`.

## Rollback and boundaries

Before cutover, keep `DOCS_PAGES_ENABLED` unset/false: builds upload preview artifacts
but do not publish; the existing server continues serving the last deployed docs.
After cutover, if verification fails, disable Pages publishing and restore the previously
working website routing/static snapshot through an authorized deployment. Do not point
old links at an unavailable host, delete backups or reset any household's database.

No repository visibility change, DNS write, secret transfer, production deploy,
app/server release or automatic merge is part of these PRs. Such actions require their
own approval. The private website can be reviewed independently of Pages eligibility.
