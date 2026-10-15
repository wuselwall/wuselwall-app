import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/server/server_info.dart';

/// The one server this installation talks to (ADR-018: one server per installation;
/// a device belongs to one household anyway). Kept next to the session in the
/// platform's secure storage.
class ServerStore {
  ServerStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'wuselwall.server';
  final FlutterSecureStorage _storage;

  Future<ServerInfo?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      final url = (json as Map<String, Object?>)['supabase_url'];
      return ServerInfo.fromDiscovery(json, origin: Uri.parse(url! as String));
    } catch (e, st) {
      logError(
        'Stored server unreadable; asking again',
        error: e,
        stackTrace: st,
      );
      await clear();
      return null;
    }
  }

  Future<void> write(ServerInfo server) =>
      _storage.write(key: _key, value: jsonEncode(server.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}
