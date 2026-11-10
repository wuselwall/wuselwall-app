# Security

WuselWall holds a family's calendar, tasks and children's names on a server the family runs
itself. Please report anything that could expose or damage that data privately.

## Reporting

Use **[Report a vulnerability](https://github.com/wuselwall/wuselwall-app/security/advisories/new)**
(GitHub's private reporting). Do not open a public issue, and do not include a real
family's data, keys or setup links in a report.

Helpful: the app and server versions, how the server is run (release on your own hardware,
rented server, hosted Supabase project), the steps, and what an attacker gains.

A fix is released as a new app and server release, and the advisory is published with it.

## Supported versions

The newest app release and the newest server release. Each app release also speaks the
previous server API version (ADR-018), but fixes are not ported to older releases:
update with `wuselwall update <version>`.

## Checking a server release

Every server release is signed. `wuselwall update` verifies the signature before anything
from the archive runs; the family guide's server pages describe how to check a download by
hand.

The threat model and the reviews so far are in
[specs/11](specs/11-security-and-privacy.md) and
[specs/19](specs/19-security-and-architecture-review.md).
