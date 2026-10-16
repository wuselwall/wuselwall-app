import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// One row of `api.shortcut_tokens` (specs/12 "Part 1"): a key an Apple Shortcut sends to
/// act as one person. The key itself is never stored, so it is not here.
class ShortcutToken {
  const ShortcutToken({
    required this.id,
    required this.profileId,
    required this.label,
    required this.createdAt,
    required this.useCount,
    this.lastUsedAt,
    this.revokedAt,
  });

  factory ShortcutToken.fromJson(Map<String, dynamic> json) => ShortcutToken(
    id: json['id'] as String,
    profileId: json['profile_id'] as String,
    label: json['label'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    useCount: json['use_count'] as int? ?? 0,
    lastUsedAt: json['last_used_at'] == null
        ? null
        : DateTime.parse(json['last_used_at'] as String),
    revokedAt: json['revoked_at'] == null
        ? null
        : DateTime.parse(json['revoked_at'] as String),
  );

  final String id;

  /// The person the key acts as.
  final String profileId;
  final String label;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int useCount;
  final DateTime? revokedAt;

  bool get revoked => revokedAt != null;
}

/// The reply of `api.shortcut_token_create`: the only time the key is known.
class CreatedShortcutToken {
  const CreatedShortcutToken({required this.id, required this.token});

  final String id;
  final String token;
}

/// The address a shortcut calls: `<supabaseUrl>/functions/v1/shortcuts`, followed by the
/// action (`/shopping`, `/today`, …; docs/settings/shortcuts.md).
String shortcutsAddress(String supabaseUrl) {
  final base = supabaseUrl.endsWith('/')
      ? supabaseUrl.substring(0, supabaseUrl.length - 1)
      : supabaseUrl;
  return '$base/functions/v1/shortcuts';
}

/// Shortcut keys. A guardian issues and revokes them for anyone; a member issues and
/// revokes their own on their phone. Every call goes through `api`.
class ShortcutRepository {
  const ShortcutRepository(this._api);

  final ApiClient _api;

  Future<Result<List<ShortcutToken>>> tokens() => _api.select(
    'shortcut_tokens',
    parse: ShortcutToken.fromJson,
    build: (q) => q.order('created_at'),
  );

  /// Creates a key for [profileId] (the acting person when null). It comes back once.
  Future<Result<CreatedShortcutToken>> create({
    required String? actor,
    required String? profileId,
    required String label,
  }) => _api.rpc(
    'shortcut_token_create',
    params: {'p_actor': actor, 'p_profile': profileId, 'p_label': label},
    parse: (json) {
      final m = json! as Map<String, dynamic>;
      return CreatedShortcutToken(
        id: m['id'] as String,
        token: m['token'] as String,
      );
    },
  );

  Future<Result<void>> revoke({required String? actor, required String id}) =>
      _api.rpc(
        'shortcut_token_revoke',
        params: {'p_actor': actor, 'p_id': id},
        parse: (_) {},
      );
}

final shortcutRepositoryProvider = Provider<ShortcutRepository>(
  (ref) => ShortcutRepository(ref.watch(apiClientProvider)),
);
