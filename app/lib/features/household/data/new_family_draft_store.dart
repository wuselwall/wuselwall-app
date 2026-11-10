import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wuselwall/core/logging/log.dart';
import 'package:wuselwall/core/storage/app_secure_storage.dart';

/// H1's editable choices only. Capabilities (setup/founder codes) are never a draft.
class NewFamilyDraft {
  const NewFamilyDraft({
    required this.familyName,
    required this.displayName,
    required this.swatch,
    required this.seedExamples,
  });

  final String familyName;
  final String displayName;
  final int swatch;
  final bool seedExamples;
}

/// Local, device-bound recovery, isolated by server and signed-in account. Writes are
/// ordered so a slow earlier save cannot replace newer typing or resurrect a cleared draft.
class NewFamilyDraftStore {
  NewFamilyDraftStore({FlutterSecureStorage? storage})
    : _storage = storage ?? appSecureStorage;

  final FlutterSecureStorage _storage;
  Future<void> _pending = Future.value();

  String _key(String server, String userId) =>
      'wuselwall.new-family.${base64Url.encode(utf8.encode(jsonEncode([server, userId])))}';

  Future<NewFamilyDraft?> read(String server, String userId) async {
    await _pending;
    try {
      final raw = await _storage.read(key: _key(server, userId));
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return NewFamilyDraft(
        familyName: data['family'] as String,
        displayName: data['name'] as String,
        swatch: data['swatch'] as int,
        seedExamples: data['examples'] as bool,
      );
    } on Object {
      // A missing/unreadable draft must never prevent setup. Do not log personal data.
      return null;
    }
  }

  Future<void> save(String server, String userId, NewFamilyDraft draft) =>
      _enqueue(
        () => _storage.write(
          key: _key(server, userId),
          value: jsonEncode({
            'family': draft.familyName,
            'name': draft.displayName,
            'swatch': draft.swatch,
            'examples': draft.seedExamples,
          }),
        ),
      );

  Future<void> clear(String server, String userId) =>
      _enqueue(() => _storage.delete(key: _key(server, userId)));

  Future<void> _enqueue(Future<void> Function() operation) {
    _pending = _pending.then((_) async {
      try {
        await operation();
      } on Object {
        logError('Saving the new-family draft failed');
      }
    });
    return _pending;
  }
}

final newFamilyDraftStoreProvider = Provider<NewFamilyDraftStore>(
  (ref) => NewFamilyDraftStore(),
);
