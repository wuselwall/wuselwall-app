import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/server/setup_link.dart';

/// Short-lived installer capability, independent of the email/auth session. Uses
/// the same platform secure storage as auth (WebCrypto on HTTPS web origins).
class SetupStore {
  SetupStore({FlutterSecureStorage? storage, DateTime Function()? now})
    : _storage = storage ?? const FlutterSecureStorage(),
      _now = now ?? DateTime.now;
  static const _key = 'wuselwall.pending-setup';
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;

  Future<void> save(SetupLink link) async {
    // Validate even callers that did not use the link parser.
    if (!RegExp(r'^[0-9a-f]{24}$').hasMatch(link.token)) return;
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'server': link.server.toString(),
        'token': link.token,
        'expires': _now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
      }),
    );
  }

  Future<String?> read(Uri server) async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final token = data['token'] as String;
      if (data['server'] == server.toString() &&
          (data['expires'] as int) > _now().millisecondsSinceEpoch &&
          RegExp(r'^[0-9a-f]{24}$').hasMatch(token)) {
        return token;
      }
    } on Object {
      // Never log malformed storage: it may contain the capability.
    }
    await clear();
    return null;
  }

  Future<void> clear() => _storage.delete(key: _key);
}

final setupStoreProvider = Provider<SetupStore>((ref) => SetupStore());
