# MCP and AI assistants — on hold

Decision: 2026-10-24. No active milestone, release gate or commitment to resume.
[23 — After the Alpha](../23-roadmap-after-alpha.md#on-hold--mcp-and-ai-assistants)
is the backlog entry. Revisit only when a family has a concrete need and the product
explicitly chooses this work again.

## What is parked

- MCP connection setup, assistant key creation and assistant key lists in the apps.
- Assistant timetable proposals and their review/discard cards on Today and the timetable.
- The assistant prompt and clipboard instructions in timetable text import.
- OAuth and consent/grant management (old R3.1, Q15), assistant write scopes (old R3.2,
  Q16), assistant-origin markers (Q17) and further assistant proposal kinds.

Siri, Apple Shortcuts and other ordinary web-request automations remain under
**Apps and automations**. Timetable photo/PDF recognition on the family's own server,
structured JSON paste and their shared preview remain available. There is no assistant
connection or external AI service in these app flows.

## Retained implementation and design

This is a product/UI pause, not a database rollback or a server shutdown. No migration,
server contract, existing key, stored proposal or household data is changed. Existing MCP
clients and credentials continue to work on servers that expose the retained endpoint;
hiding the app controls does not revoke access. Older app releases remain compatible.

| Material | Where to pick it up |
|---|---|
| Original endpoint, tool and authorization design | [12, Part 2](../12-mcp-and-assistants.md#part-2--the-mcp-server), [ADR-007](../adr/ADR-007-assistant-integration.md), Q15–Q17 in [14](../14-open-questions.md) |
| MCP Edge Function, catalogs and read/proposal tools | `supabase/functions/mcp/`, `supabase/functions/_shared/mcp*` |
| Assistant keys, actor attribution and access tests | `supabase/migrations/20261016120000_assistant_keys.sql`, `supabase/tests/210_assistant_keys.test.sql` |
| Proposal payload and review design | [24](../24-school-import.md), `app/lib/features/school/{data,domain}/` and `openProposalsProvider` |
| Earlier UI, prompt translations, demo fixtures and widget tests | Git revision `4c2f4470e3cbcf768807c69982c807a84d4a9046` (before this pause): `shortcuts_page.dart`, `proposal_cards.dart`, `timetable_paste_sheet.dart`, `timetable_import_page.dart`, `demo_proposals.dart`, ARB files and their tests |

For example, `git show 4c2f4470e3cbcf768807c69982c807a84d4a9046:app/lib/features/school/ui/proposal_cards.dart`
retrieves the previous cards. Keep the historical specifications; the dated pause notices
take precedence over their original schedules and UI descriptions.

## Before resuming

1. Record the family's use case, intended data access and acceptance criterion; select a
   milestone deliberately. This is not automatically the next task after the Alpha.
2. Reassess the MCP protocol and authentication against current primary documentation.
   Decide how existing `wwa_` keys are managed, migrated or retired before restoring setup.
3. Review authorization, consent and attribution, especially the whole-family read scope
   and children's timetable data. Preserve actor/audit and household isolation tests.
4. Restore only the chosen UI; review proposal expiry, failure/retry behaviour and the
   supported previous-server window. Keep the manual and local OCR import paths working.
5. Update UI, server responses, guide and screenshot coverage in DE/EN/FR/ES, and coordinate
   a separate public-progress change in the website repository.

## Website progress handoff

The marketing repository publishes independently. This app change does not publish or
modify it. Remove MCP/AI assistant availability claims there and carry this copy into its
next public-progress update:

- **DE:** „MCP und KI-Assistenten sind vorerst zurückgestellt und aus der App-Oberfläche
  entfernt. Die bisherigen Arbeiten bleiben für eine spätere Neubewertung erhalten.
  Siri, Kurzbefehle und andere Automationen bleiben verfügbar.“
- **EN:** “MCP and AI assistants are on hold and removed from the app interface. The work
  is retained for possible reconsideration. Siri, Shortcuts and other automations remain
  available.”
- **FR:** « MCP et les assistants IA sont mis en pause et retirés de l’interface de l’app.
  Le travail est conservé pour un éventuel réexamen. Siri, Raccourcis et les autres
  automatisations restent disponibles. »
- **ES:** « MCP y los asistentes de IA quedan en pausa y se retiran de la interfaz de la
  app. El trabajo se conserva para una posible revisión. Siri, Atajos y otras
  automatizaciones siguen disponibles. »
