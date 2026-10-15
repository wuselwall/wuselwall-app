/// Reads a server's address from what a person typed, scanned or opened (ADR-018,
/// decision 3). Returns the origin (`https://host[:port]`), or null when [raw] holds
/// nothing that can be a server.
///
/// Accepted:
/// - a host or URL: `api.example.org`, `https://api.example.org/`, any path is dropped;
/// - a hosted Supabase project's reference ID (20 lowercase letters and digits), which
///   becomes `https://<id>.supabase.co`;
/// - the app's own QR payloads: `wuselwall://server?url=…` and the enrolment code
///   `wuselwall://enrol?code=…&server=…`;
/// - a pairing or invitation link that carries its server in the fragment:
///   `https://wuselwall.app/p/#CODE@api.example.org`.
///
/// Plain http only with [allowHttp] (debug builds talking to a laptop stack).
Uri? parseServerAddress(String raw, {bool allowHttp = false}) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  if (RegExp(r'^[a-z0-9]{20}$').hasMatch(text)) {
    return Uri(scheme: 'https', host: '$text.supabase.co');
  }

  final link = Uri.tryParse(text);
  if (link != null && link.scheme == 'wuselwall') {
    final server =
        link.queryParameters['server'] ?? link.queryParameters['url'];
    return server == null
        ? null
        : parseServerAddress(server, allowHttp: allowHttp);
  }
  if (link != null &&
      link.hasScheme &&
      link.fragment.contains('@') &&
      RegExp(r'^/[ip]/?$').hasMatch(link.path)) {
    final host = link.fragment.substring(link.fragment.lastIndexOf('@') + 1);
    return parseServerAddress(Uri.decodeComponent(host), allowHttp: allowHttp);
  }

  final withScheme = text.contains('://') ? text : 'https://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  final secure = uri.scheme == 'https';
  if (!secure && !(allowHttp && uri.scheme == 'http')) return null;
  final host = uri.host.toLowerCase();
  final plausible =
      host == 'localhost' ||
      RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$').hasMatch(host) ||
      RegExp(r'^\[[0-9a-f:]+\]$').hasMatch(host);
  if (!plausible) return null;
  return Uri(
    scheme: uri.scheme,
    host: host,
    port: uri.hasPort ? uri.port : null,
  );
}

/// The address as a person reads it: no scheme for https, no trailing slash.
String displayServerAddress(Uri server) => server.scheme == 'https'
    ? server.authority
    : server.toString().replaceAll(RegExp(r'/$'), '');

/// What the server's QR code holds: an address any QR reader can show, and that
/// [parseServerAddress] reads back.
String serverQrPayload(Uri server) => server.toString();
