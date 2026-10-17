/// The project's own servers (ADR-018, decision 6), from `WW_FIRST_PARTY_HOSTS` in the
/// build's env file. Only these get passkeys: their domain is the one in the apps'
/// associated domains, so a passkey made for it must never be offered to another
/// operator's server.
const _hosts = String.fromEnvironment('WW_FIRST_PARTY_HOSTS');

List<String> get firstPartyHosts => [
  for (final h in _hosts.split(','))
    if (h.trim().isNotEmpty) h.trim().toLowerCase(),
];

bool isFirstParty(Uri server) =>
    server.scheme == 'https' &&
    firstPartyHosts.contains(server.host.toLowerCase());

/// The server every build before ADR-018's server choice had compiled in: the first
/// first-party host. A device updated from such a build has a session but no stored
/// server, and keeps talking to this one.
Uri? get legacyServer => firstPartyHosts.isEmpty
    ? null
    : Uri(scheme: 'https', host: firstPartyHosts.first);
