import 'dart:convert';

/// Whether the session of [accessToken] signed in within [within] of [now] (specs/20 J6:
/// deleting the account needs a recent sign-in). Reads the token's `amr` claim, the methods
/// the session was signed in with and when. A refreshed session keeps its original entries,
/// so only a fresh sign-in counts. The server checks the same claim; this only avoids a call
/// that is certain to be refused.
bool signedInRecently(
  String accessToken, {
  required DateTime now,
  Duration within = const Duration(minutes: 5),
}) {
  final cutoff = now.millisecondsSinceEpoch ~/ 1000 - within.inSeconds;
  return _amrTimes(accessToken).any((t) => t > cutoff);
}

/// The Unix times (seconds) of the `amr` entries; empty when the token has none or is malformed.
List<int> _amrTimes(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return const [];
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) return const [];
    final amr = payload['amr'];
    if (amr is! List) return const [];
    return [
      for (final entry in amr)
        if (entry is Map && entry['timestamp'] is int)
          entry['timestamp'] as int,
    ];
  } on FormatException {
    return const [];
  }
}
