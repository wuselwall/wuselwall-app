import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// What a key is for (specs/12): an Apple Shortcut, which reads and adds as its holder, or
/// an AI assistant over MCP, which only reads (family:read).
enum KeyKind {
  shortcut,
  assistant;

  /// A server before the assistant keys has shortcut keys only.
  static KeyKind parse(String? v) => v == 'assistant' ? assistant : shortcut;
}

/// One row of `api.shortcut_tokens` (specs/12): a key an Apple Shortcut or an assistant sends
/// to act as one person. The key itself is never stored, so it is not here.
class ShortcutToken {
  const ShortcutToken({
    required this.id,
    required this.profileId,
    required this.label,
    required this.createdAt,
    required this.useCount,
    this.kind = KeyKind.shortcut,
    this.lastUsedAt,
    this.revokedAt,
  });

  factory ShortcutToken.fromJson(Map<String, dynamic> json) => ShortcutToken(
    id: json['id'] as String,
    profileId: json['profile_id'] as String,
    label: json['label'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    useCount: json['use_count'] as int? ?? 0,
    kind: KeyKind.parse(json['kind'] as String?),
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
  final KeyKind kind;
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

/// The address an assistant connects to: `<supabaseUrl>/functions/v1/mcp` (specs/12 "Part 2").
String mcpAddress(String supabaseUrl) =>
    shortcutsAddress(supabaseUrl).replaceFirst(RegExp(r'/shortcuts$'), '/mcp');

/// Shortcut and assistant keys. A guardian issues and revokes them for anyone; a member issues and
/// revokes their own on their phone. Every call goes through `api`.
class ShortcutRepository {
  const ShortcutRepository(this._api);

  final ApiClient _api;

  Future<Result<List<ShortcutToken>>> tokens() => _api.select(
    'shortcut_tokens',
    parse: ShortcutToken.fromJson,
    build: (q) => q.order('created_at'),
  );

  /// Creates a key of [kind] for [profileId] (the acting person when null). It comes back
  /// once. An assistant key is for an adult only; the server says so otherwise.
  Future<Result<CreatedShortcutToken>> create({
    required String? actor,
    required String? profileId,
    required String label,
    KeyKind kind = KeyKind.shortcut,
  }) => _api.rpc(
    kind == KeyKind.assistant
        ? 'assistant_key_create'
        : 'shortcut_token_create',
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
