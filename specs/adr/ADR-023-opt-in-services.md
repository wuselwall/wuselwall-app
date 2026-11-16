# ADR-023 — Opt-in services: weather and maps through the family's server, with the family's keys

**Status:** Accepted · 2026-11-15 · Amends P2 of
[23](../23-roadmap-after-alpha.md#the-test-every-item-passes) and its "Not on the roadmap" row
*Weather or traffic on the wall* (a third party stays excluded by default; a household may now
opt in), and NFR-9 of [02](../02-requirements.md); extends
[ADR-018](ADR-018-self-hosted-only.md); specified in [30](../30-trips.md#services).

## Context

Trip planning ([30](../30-trips.md), issue #265) asks questions the family's server cannot
answer from its own data: how warm is a place in October, what is the forecast at the
destination, where is a place, how far is it. Until now every outbound connection of a server
was named on one hand (the holiday feed, the calendars a family subscribes to, mail), and
weather was explicitly excluded.

Two designs were on the table on 2026-11-15:

- a climate table bundled with the app (no connection, coarse, a few hundred places), or
- services of the family's choice.

The owner chose the second: a plug-in framework in which a family adds weather and map
providers, with its own API keys where a provider needs one, and free providers among them.

## Decision

1. **Third-party services are possible, per household, and off by default.** A fresh server
   contacts no weather or map provider. A guardian switches a provider on in the settings and
   can switch it off again; switching it off stops every call at once.
2. **The server makes the call, never an app** (unchanged from P2). The apps keep their rule:
   no third-party host, no map SDK, no tiles fetched by a device. A map is a picture the
   server fetched. Opening a link, a phone number or an address hands over to the phone's own
   apps.
3. **A provider learns as little as the question needs**: coordinates (a destination's; the
   home place only for a route, rounded to two decimals), or the text of a place search. Never
   a name, an account, a household id, a date of travel beyond what a forecast implies, or
   anything from the calendar. The provider necessarily sees the server's address. The settings
   page says this for each provider before it is switched on (`receives` in the catalogue).
4. **A provider is a plug-in on the server**: one file that declares its id, its capabilities
   (`climate`, `forecast`, `geocode`, `route`, `map`), whether it needs a key, its hosts, its
   polite call budget and its attribution line. The hosts are constants of the file; no
   request to a host a household typed. The app learns the list from the server, so a provider
   is added by a server release alone.
5. **Keys belong to the family and are write-only.** A guardian types a key; it is stored in a
   table no device role can read (`app.service_secret`), read by the service role inside the
   Edge Function only after the caller's JWT, device and household were checked by the
   database (`api.service_request`), left out of the export, the audit and the logs, and shown
   as its last four characters. This is one more use of the service-role key with a user in
   the request, of the same shape as `calendar-import`.
6. **Who may cause a call**: an adult profile, not a child and not the wall. Children's
   devices hold a household session; without this rule a loop on one could spend a paid key.
   Every provider also has a daily ceiling the server enforces.
7. **Answers are cached as public facts** (`app.service_cache`: a coordinate's climate, a
   place's coordinates), without the household that asked.

## Alternatives considered

- **The bundled table.** No connection at all and the same for every family, but coarse, a
  data pipeline to maintain and no forecast, route or map. It can come back as a keyless
  provider inside this framework.
- **Keys in the server's environment** (the operator's `.env`). Simpler and out of the
  database, but the person who runs a server is not always the person who plans the vacation,
  and a hosted Supabase project has no comfortable place for it. The framework can read a key
  from the environment later without changing the model.
- **The apps calling the provider with the family's key.** Rules out the wall and the
  browser's CORS, puts the key on every phone, and breaks P2's first sentence.
- **One provider, hard-wired.** No key handling, but the choice of a third party is exactly
  what a family should make itself.
- **Encrypting the keys with Vault.** Not available alike on every Supabase stack the server
  must stay portable to (ADR-013, ADR-018). The key is as protected as the database's other
  secrets (the calendars' feed addresses with their tokens); the backup holds it, the export
  does not.

## Consequences

- P2 now reads: *a third party is contacted by the server, never by the apps; one a household
  switched on itself is that household's choice, and the settings name what it receives.* The
  project's own privacy policy describes the mechanism, not each provider: the provider's
  relationship is with the family that created the key. The website's policy text (its own
  repository) needs that paragraph in all its languages before a release with this feature is
  announced.
- The list of outbound hosts of a server is no longer fixed: it is the fixed list plus the
  hosts of the providers a household enabled. `wuselwall` operators who filter egress find the
  hosts in each plug-in file.
- A provider's terms are the family's to accept (a free tier's "non-commercial use", a paid
  key's price). The catalogue says `free`, `free_key` or `paid_key`; the server's ceilings are
  a courtesy, not a billing guard.
- Each plug-in is written from a provider's public documentation and tested against recorded
  answers. A provider that changes its interface fails closed (`service_failed`), and the next
  provider in the household's order is asked.
- Weather on the wall is no longer excluded on principle. It stays unbuilt; it would be a
  consumer of the `forecast` capability and its own decision under P6.
