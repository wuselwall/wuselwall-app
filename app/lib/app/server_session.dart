import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/server/server_info.dart';
import 'package:wuselwall/core/server/server_link.dart';

/// A link handed to the running app, with what the bootstrap decided about it.
class LinkEvent {
  const LinkEvent(this.link, this.verdict, {this.current});

  final OpenedLink link;

  /// [LinkVerdict.proceed], [LinkVerdict.offerSwitch] or [LinkVerdict.otherServer]; the
  /// others never reach the app.
  final LinkVerdict verdict;

  /// The server the app is on.
  final Uri? current;
}

/// The server's discovery document, checked again while the app runs, names another
/// address or publishable key than the ones the app runs on. The app never takes them
/// over by itself: a changed document could come from someone who took over the
/// server's address, and the next start would send this device's refresh token there
/// (security review 2026-11-01, F7). It keeps the stored values and says so; the person
/// decides (`ServerChangeBanner`).
class ServerChange {
  const ServerChange(this.server, {required this.current});

  /// The server as the document now describes it.
  final ServerInfo server;

  /// The server the app runs on.
  final ServerInfo current;

  /// Whether the address changed, not only the key: reconnecting then signs this device
  /// out first, so its session never reaches the new address.
  bool get addressChanged => server.supabaseUrl != current.supabaseUrl;

  /// The same change seen again by a later check keeps the notice as it is.
  @override
  bool operator ==(Object other) =>
      other is ServerChange &&
      other.server.supabaseUrl == server.supabaseUrl &&
      other.server.publishableKey == server.publishableKey &&
      other.current.supabaseUrl == current.supabaseUrl &&
      other.current.publishableKey == current.publishableKey;

  @override
  int get hashCode => Object.hash(
    server.supabaseUrl,
    server.publishableKey,
    current.supabaseUrl,
    current.publishableKey,
  );
}

/// What the running app may ask of the bootstrap that chose its server
/// (lib/app/bootstrap.dart, ADR-018).
class ServerSession {
  ServerSession({
    this.leave,
    bool hasSetup = false,
    this._pendingEnrolCode,
    this.openLink,
    this.switchToLinkServer,
    LinkEvent? initialLink,
  }) : inbox = ValueNotifier(initialLink),
       setupPending = ValueNotifier(hasSetup);

  /// Forgets the server, signs this device out of it and returns to the server choice.
  /// Null for a build that names its own server.
  final Future<void> Function()? leave;

  /// Hands a link the person typed, scanned or pasted to the bootstrap, which decides
  /// like it does for a link the app was opened with (the verdict arrives in [inbox]).
  final Future<void> Function(OpenedLink link)? openLink;

  /// Leaves this server for the one [link] names and continues with the link. Only for
  /// a device nobody is signed in on.
  final Future<void> Function(OpenedLink link)? switchToLinkServer;

  /// The links waiting for the app to act on them: set by the bootstrap, cleared by
  /// whoever handles the link.
  final ValueNotifier<LinkEvent?> inbox;

  /// Non-secret signal used to skip the generic front door.
  final ValueNotifier<bool> setupPending;

  String? _pendingEnrolCode;

  bool get hasPendingEnrolCode => _pendingEnrolCode != null;

  /// An enrolment code that arrived together with the server (the QR code of
  /// Settings → Add device). Handed out once.
  String? takePendingEnrolCode() {
    final code = _pendingEnrolCode;
    _pendingEnrolCode = null;
    return code;
  }
}

final serverSessionProvider = Provider<ServerSession>((ref) => ServerSession());

/// A strip above every screen, for a mode nobody should forget they are in (the demo
/// household). Null: none.
final appBannerProvider = Provider<WidgetBuilder?>((ref) => null);
