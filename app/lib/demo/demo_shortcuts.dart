import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/shortcuts/data/shortcut_repository.dart';

/// Keys for the screenshots: the father's phone, in use, the daughter's tablet, never used
/// yet, and the mother's assistant. A new key is made up and kept until the demo is reloaded.
class DemoShortcutRepository implements ShortcutRepository {
  DemoShortcutRepository()
    : _tokens = [
        ShortcutToken(
          id: 's-1',
          profileId: DemoData.papa,
          label: 'iPhone',
          createdAt: DateTime(2026, 10, 2),
          lastUsedAt: DateTime.now().subtract(const Duration(hours: 2)),
          useCount: 34,
        ),
        ShortcutToken(
          id: 's-2',
          profileId: DemoData.daughter,
          label: 'iPad',
          createdAt: DateTime(2026, 10, 9),
          useCount: 0,
        ),
        ShortcutToken(
          id: 's-3',
          profileId: DemoData.mama,
          label: 'Claude',
          createdAt: DateTime(2026, 10, 12),
          lastUsedAt: DateTime.now().subtract(const Duration(days: 1)),
          useCount: 7,
          kind: KeyKind.assistant,
        ),
      ];

  final List<ShortcutToken> _tokens;

  @override
  Future<Result<List<ShortcutToken>>> tokens() async => Ok(List.of(_tokens));

  @override
  Future<Result<CreatedShortcutToken>> create({
    required String? actor,
    required String? profileId,
    required String label,
    KeyKind kind = KeyKind.shortcut,
  }) async {
    final id = 's-${_tokens.length + 1}';
    _tokens.add(
      ShortcutToken(
        id: id,
        profileId: profileId ?? DemoData.papa,
        label: label,
        createdAt: DateTime.now(),
        useCount: 0,
        kind: kind,
      ),
    );
    return Ok(
      CreatedShortcutToken(
        id: id,
        token: kind == KeyKind.assistant
            ? 'wwa_demo-key-not-valid-on-any-server-000000'
            : 'wws_demo-key-not-valid-on-any-server-000000',
      ),
    );
  }

  @override
  Future<Result<void>> revoke({
    required String? actor,
    required String id,
  }) async {
    final i = _tokens.indexWhere((t) => t.id == id);
    if (i >= 0) {
      final t = _tokens[i];
      _tokens[i] = ShortcutToken(
        id: t.id,
        profileId: t.profileId,
        label: t.label,
        createdAt: t.createdAt,
        lastUsedAt: t.lastUsedAt,
        useCount: t.useCount,
        kind: t.kind,
        revokedAt: DateTime.now(),
      );
    }
    return const Ok(null);
  }
}
