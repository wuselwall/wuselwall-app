import 'package:wuselwall/core/server/server_address.dart';

/// An installer capability. Never include its token in diagnostics.
class SetupLink {
  const SetupLink(this.server, this.token);
  final Uri server;
  final String token;
}

/// Only the fragment carries the capability; query parameters are never accepted.
/// The destination is an exact HTTPS origin, not an arbitrary redirect URL.
SetupLink? parseSetupLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.path != '/' && uri.path.isNotEmpty) {
    return null;
  }
  try {
    final values = Uri.splitQueryString(uri.fragment);
    if (values.length != 2 || uri.fragment.split('&').length != 2) return null;
    final token = values['setup'];
    final address = values['server'];
    if (token == null ||
        !RegExp(r'^[0-9a-f]{24}$').hasMatch(token) ||
        address == null) {
      return null;
    }
    final server = parseServerAddress(address);
    if (server == null || address != server.toString()) return null;
    return SetupLink(server, token);
  } on FormatException {
    return null;
  }
}
