# ADR-019: Separate marketing source and publish docs with GitHub Pages

**Status:** Accepted; GitHub Pages active 2026-10-24 after the app repository became public.
HTTPS and live DE/EN/FR/ES checks passed. See the
[cutover status](../website-and-docs-migration.md#activation-status--2026-10-24) for the website and legacy-link handoff.

## Context

The marketing website, app/backend and VitePress documentation shared a repository.
Marketing CI/deployment and private operator/legal content should not be prerequisites
for building or contributing to the app. Family documentation should remain versioned
with the screens it explains, but be delivered through GitHub Pages.

## Decision

- Create private `wuselwall/wuselwall-website`. Import the tracked Astro website at its
  root, with its license/provenance, independent dependencies, CI and deployment tools.
  The source snapshot is app commit `106ba1c2603c3e97e25d0d2611f5dce36ca1bb4d`.
- Remove `website/`, website-only compose/deploy tooling and its CI/audit job from the
  app repository. The app/backend, VitePress source, screenshot tooling and shared app
  brand assets remain here. Store artwork must not depend on private website files.
- Keep screenshot generation here; export selected copies explicitly to the marketing
  repository. Neither CI pipeline checks out the other's private repository.
- Prepare `docs.wuselwall.app` as the documentation's GitHub Pages custom domain, with
  root base `/`, German at `/` and English at `/en/`. PRs build on ephemeral hosted
  runners without production credentials. Pages publishing uses OIDC and narrowly
  scoped permissions, not the website server's SSH credentials.
- Keep Pages opt-in (`DOCS_PAGES_ENABLED=true`). Pages is activated once this repository
  is made public (the operator's decision; no paid plan). DNS, domain verification,
  Pages settings and HTTPS must be configured before cutover.
- The marketing website stays on the operator's own server, deployed from a checkout
  with `scripts/remote-web.sh` in the website repository; only the guide moves to Pages.
  Its `docsOnPages` switch keeps links and the privacy policy on `/docs/` until cutover.
- Preserve the old `/docs/` service and links until the custom domain is working.
  Then apply path-preserving redirects and update app/store copy in both languages.
  Keep public app-link verification files at `wuselwall.app/.well-known/`; their host
  does not move with documentation.
- The two prepared PRs require human merge. This decision does not authorize changing
  visibility, secrets, DNS, production configuration or live deployment.

## Alternatives

Keeping separate jobs in one repository does not separate marketing ownership/access.
Moving VitePress into the marketing repository would detach docs from the app revision.
Using a default project Pages URL avoids DNS, but the operator chose the custom domain.
Rewriting the app's history is unnecessary: the migration is forward-only, and the
website's prior history remains in the original repository. This is not a historical
sensitive-data purge or proof that the app repository is safe to publish.

## Consequences

App contributors need no marketing access. Marketing legal/progress/screenshot updates
need a separate coordinated PR. Making this repository public and the DNS
cutover remain manual gates; source changes are not proof of a live migration.
See the [execution and rollback checklist](../website-and-docs-migration.md).
