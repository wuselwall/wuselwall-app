/// The project's own servers (ADR-018, decision 6), from `WW_FIRST_PARTY_HOSTS` in the
/// build's env file. Only these get the native Apple and Google sheets and passkeys: an
/// ID token addressed to this app must never be handed to another operator's server,
/// which could replay it to one of these.
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
