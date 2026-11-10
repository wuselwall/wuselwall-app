<!-- A feature or a fix closes its issue, and that issue is in a release milestone.
     Docs, chores, CI and dependency updates need no issue. CONTRIBUTING.md has the rules. -->
Closes #

## What changes

<!-- For a family or an operator, then for the code. The title becomes the commit on main
     and a line of the release notes: a plain sentence, no prefix. -->

## How it was checked

<!-- Commands run and what they showed; screenshots for a changed screen. -->

## Checklist

- [ ] Texts a family reads exist in German, English, French and Spanish
- [ ] `flutter analyze` and `flutter test`; pgTAP for backend changes
- [ ] A migration is forward-only and works with the previous app release; `api_version` raised if the contract changed
- [ ] The family guide (`docs/`, four languages) and the specification (`specs/`, `AGENTS.md`) match the change
- [ ] No operator's server, host, path or key in any committed file
