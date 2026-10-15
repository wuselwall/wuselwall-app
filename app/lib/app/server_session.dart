import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the running app may ask of the bootstrap that chose its server
/// (lib/app/bootstrap.dart, ADR-018).
class ServerSession {
  ServerSession({this.leave, this._pendingEnrolCode});

  /// Forgets the server, signs this device out of it and returns to the server choice.
  /// Null for a build that names its own server.
  final Future<void> Function()? leave;

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
