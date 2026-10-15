import 'package:wuselwall/core/server/server_info.dart';

/// The newest app–server contract this app speaks (`api.server_info()`'s api_version).
/// Raise it with the migration that raises the server's.
const appApiVersion = 1;

/// Whether this app and a server can work together (ADR-018, decision 5).
enum Compatibility {
  ok,

  /// The server is more than one contract behind this app: its operator must update.
  serverTooOld,

  /// The server needs a newer app than this one: update the app.
  appTooOld,
}

/// Each app release supports the current contract and the one before it; a newer
/// server keeps working with the previous app release, until its `min_app_version`
/// says otherwise.
Compatibility compatibility(ServerInfo server, String appVersion) {
  if (server.apiVersion < appApiVersion - 1) return Compatibility.serverTooOld;
  if (compareVersions(appVersion, server.minAppVersion) < 0) {
    return Compatibility.appTooOld;
  }
  return Compatibility.ok;
}

/// Compares `major.minor.patch` versions; anything after `+` or `-` is ignored.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split(RegExp('[+-]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final x = parts(a);
  final y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}
