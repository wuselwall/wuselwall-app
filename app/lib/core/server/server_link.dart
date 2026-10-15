import 'package:wuselwall/core/server/server_address.dart';

/// Invitation and pairing links carry the household's server in their fragment
/// (ADR-018, decision 8; specs/20 "Choosing the server"):
/// `https://wuselwall.app/i/#<token>@api.example.org`, the same for `/p/#<code>`. The
/// fragment never reaches the links site. Links without `@host` (older builds) stay valid
/// and mean "the server this app is on".

/// The host the links site is served from.
const linkSiteHost = 'wuselwall.app';

final _invitationPath = RegExp(r'^(/en)?/i/?$');
final _pairingPath = RegExp(r'^(/en)?/p(/[^/]*)?/?$');
final _tokenPattern = RegExp(r'^[0-9a-f]{32}$');
final _codePattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$');

/// What kind of secret a link carries.
enum LinkKind { invitation, pairing }

/// A secret read from typed, scanned or opened text, with the server it names, if any.
class LinkSecret {
  const LinkSecret(this.secret, {this.server});

  /// The normalised secret: an 8-symbol code (upper case) or a 32-hex token.
  final String secret;

  /// The server's origin from the `@host` part, or null for a link without one.
  final Uri? server;

  @override
  bool operator ==(Object other) =>
      other is LinkSecret && other.secret == secret && other.server == server;

  @override
  int get hashCode => Object.hash(secret, server);

  @override
  String toString() => 'LinkSecret($secret, $server)';
}

/// A link the app was opened with (or one scanned or pasted): which flow it starts, the
/// secret and the server.
class OpenedLink {
  const OpenedLink(this.kind, this.secret, {this.server});

  final LinkKind kind;
  final String secret;
  final Uri? server;

  @override
  bool operator ==(Object other) =>
      other is OpenedLink &&
      other.kind == kind &&
      other.secret == secret &&
      other.server == server;

  @override
  int get hashCode => Object.hash(kind, secret, server);
}

/// The server as it goes after the `@`: the host, with the port only when it is not the
/// scheme's default.
String linkServerHost(Uri server) {
  final defaultPort = server.scheme == 'http' ? 80 : 443;
  final host = server.host.contains(':') ? '[${server.host}]' : server.host;
  return server.hasPort && server.port != defaultPort
      ? '$host:${server.port}'
      : host;
}

/// The fragment of a link: the secret, and `@host` when the server is known.
String linkFragment(String secret, Uri? server) =>
    server == null ? secret : '$secret@${linkServerHost(server)}';

/// Whether [a] and [b] are the same server: same host and port (the scheme only decides
/// the default port).
bool sameServer(Uri a, Uri b) =>
    a.host.toLowerCase() == b.host.toLowerCase() && a.port == b.port;

/// Reads an opened, scanned or pasted `https://wuselwall.app/i/…` or `/p/…` link (also
/// under `/en/`). Returns null for anything else.
OpenedLink? parseAppLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme || uri.host != linkSiteHost) return null;
  // Pairing and invitation codes share one alphabet; the path says which this is.
  if (_invitationPath.hasMatch(uri.path)) {
    final parsed = parseInvitation(raw);
    return parsed == null
        ? null
        : OpenedLink(LinkKind.invitation, parsed.secret, server: parsed.server);
  }
  if (_pairingPath.hasMatch(uri.path)) {
    final parsed = parsePairingCode(raw);
    return parsed == null
        ? null
        : OpenedLink(LinkKind.pairing, parsed.secret, server: parsed.server);
  }
  return null;
}

/// Reads a secret out of typed or scanned text: the 8-symbol code (any case, with or
/// without the hyphen), the token, or an invitation link `…/i/#<secret>[@host]`; a typed
/// `CODE@host` works too. Returns the normalised secret with the server it names, or null
/// when [raw] holds neither or names a host that cannot be a server.
LinkSecret? parseInvitation(String raw) {
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  final String body;
  if (uri != null && uri.hasScheme) {
    if (uri.host != linkSiteHost || !_invitationPath.hasMatch(uri.path)) {
      return null;
    }
    body = uri.fragment;
  } else {
    body = text;
  }
  final (:secret, :host) = _split(body);
  final s = secret.replaceAll(RegExp(r'[\s-]'), '');
  final String? normalised;
  if (s.length == 32 && _tokenPattern.hasMatch(s.toLowerCase())) {
    normalised = s.toLowerCase();
  } else {
    normalised = _codePattern.hasMatch(s.toUpperCase())
        ? s.toUpperCase()
        : null;
  }
  return normalised == null ? null : _withServer(normalised, host);
}

/// Reads a pairing code out of typed or scanned text: the bare code (with or without the
/// hyphen, in any case), `CODE@host`, or a WuselWall link `…/p/#<code>[@host]` (or, as
/// the first builds made it, `…/p/<code>`). Returns null when [raw] holds no plausible
/// code.
LinkSecret? parsePairingCode(String raw) {
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  final String body;
  if (uri != null && uri.hasScheme) {
    if (uri.host != linkSiteHost || !_pairingPath.hasMatch(uri.path)) {
      return null;
    }
    body = uri.fragment.isNotEmpty
        ? uri.fragment
        : (uri.pathSegments.isEmpty ? '' : uri.pathSegments.last);
  } else {
    body = text;
  }
  final (:secret, :host) = _split(body);
  final code = secret.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  return _codePattern.hasMatch(code) ? _withServer(code, host) : null;
}

/// Splits `secret@host` at the last `@`. Without one, the host is null.
({String secret, String? host}) _split(String text) {
  final at = text.lastIndexOf('@');
  return at < 0
      ? (secret: text, host: null)
      : (secret: text.substring(0, at), host: text.substring(at + 1));
}

LinkSecret? _withServer(String secret, String? host) {
  if (host == null) return LinkSecret(secret);
  final server = parseServerAddress(host);
  // A link names a host, so a bare 20-character project ID (which the address parser
  // accepts) or something without a dot is not one.
  final plausible =
      server != null &&
      (server.host.contains('.') || server.host == 'localhost') &&
      !host.contains('/');
  return plausible ? LinkSecret(secret, server: server) : null;
}

/// What to do with a link, given the server the app is on (if any) and whether somebody
/// is signed in on this device.
enum LinkVerdict {
  /// The link names no server and the app has none: ask for the server's address.
  needsServer,

  /// No server yet: connect to the link's, then continue with the link.
  connect,

  /// The link belongs to the server the app is on: continue.
  proceed,

  /// Another server, nobody signed in: offer to switch.
  offerSwitch,

  /// Another server, somebody signed in: say so; never switch silently.
  otherServer,
}

LinkVerdict decideLink({
  required Uri? linkServer,
  required Uri? current,
  required bool signedIn,
}) {
  if (linkServer == null) {
    return current == null ? LinkVerdict.needsServer : LinkVerdict.proceed;
  }
  if (current == null) return LinkVerdict.connect;
  if (sameServer(linkServer, current)) return LinkVerdict.proceed;
  return signedIn ? LinkVerdict.otherServer : LinkVerdict.offerSwitch;
}
