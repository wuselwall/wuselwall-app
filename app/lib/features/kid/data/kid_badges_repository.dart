import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// A badge definition, and whether the child has earned it.
class KidBadge {
  const KidBadge({
    required this.id,
    required this.title,
    required this.earned,
    this.description,
    this.iconKey,
  });

  final String id;
  final String title;
  final String? description;
  final String? iconKey;
  final bool earned;
}

/// The badges of one child, read through the `api` views `badge_definitions` and
/// `badge_awards` (specs/06). No write: earning is the server's job.
class KidBadgesRepository {
  const KidBadgesRepository(this._api);

  final ApiClient _api;

  Future<Result<List<KidBadge>>> badges(String profileId) async {
    final defs = await _api.select(
      'badge_definitions',
      parse: (row) => (
        id: row['id'] as String,
        title: row['title'] as String,
        description: row['description'] as String?,
        iconKey: row['icon_key'] as String?,
      ),
    );
    final awards = await _api.select(
      'badge_awards',
      parse: (row) => (
        profileId: row['profile_id'] as String,
        badgeId: row['badge_definition_id'] as String,
      ),
      build: (q) => q.eq('profile_id', profileId),
    );
    if (defs case Err(:final failure)) return Err(failure);
    if (awards case Err(:final failure)) return Err(failure);
    final earned = {
      for (final a in awards.valueOrNull!)
        if (a.profileId == profileId) a.badgeId,
    };
    return Ok([
      for (final b in defs.valueOrNull!)
        KidBadge(
          id: b.id,
          title: b.title,
          description: b.description,
          iconKey: b.iconKey,
          earned: earned.contains(b.id),
        ),
    ]);
  }
}

final kidBadgesRepositoryProvider = Provider<KidBadgesRepository>(
  (ref) => KidBadgesRepository(ref.watch(apiClientProvider)),
);
