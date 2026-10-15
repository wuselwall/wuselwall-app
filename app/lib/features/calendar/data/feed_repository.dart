import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';

/// Which school entries a subscription carries (`filter.school`, specs/05).
enum FeedSchool {
  off,
  day,
  lessons;

  static FeedSchool parse(String v) => switch (v) {
    'day' => day,
    'lessons' => lessons,
    _ => off,
  };
}

/// What one subscription sees (`api.feed_tokens.filter`). Empty member and calendar
/// lists mean everything. New subscriptions carry appointments only (specs/05).
class FeedFilter {
  const FeedFilter({
    this.profileIds = const [],
    this.calendarIds = const [],
    this.kinds = const {'appointment'},
    this.school = FeedSchool.off,
    this.subscribed = false,
  });

  factory FeedFilter.fromJson(Map<String, dynamic> json) => FeedFilter(
    profileIds: [...?(json['profile_ids'] as List?)?.cast<String>()],
    calendarIds: [...?(json['calendar_ids'] as List?)?.cast<String>()],
    kinds: {...?(json['kinds'] as List?)?.cast<String>()},
    school: FeedSchool.parse(json['school'] as String? ?? 'off'),
    subscribed: json['subscribed'] == true,
  );

  final List<String> profileIds;
  final List<String> calendarIds;

  /// Subset of `appointment`, `presence`.
  final Set<String> kinds;
  final FeedSchool school;

  /// Whether the imported calendars (FR-1.9) are part of the feed. Off by default: sharing is a
  /// deliberate act. A subscription saved before the key existed reads as off.
  final bool subscribed;

  Map<String, dynamic> toJson() => {
    'profile_ids': profileIds,
    'calendar_ids': calendarIds,
    'kinds': kinds.toList(),
    'school': school.name,
    'subscribed': subscribed,
  };
}

/// One row of `api.feed_tokens`. The token itself is never stored, so it is not here.
class FeedToken {
  const FeedToken({
    required this.id,
    required this.label,
    required this.filter,
    required this.createdAt,
    required this.fetchCount,
    this.lastFetchedAt,
    this.revokedAt,
  });

  factory FeedToken.fromJson(Map<String, dynamic> json) => FeedToken(
    id: json['id'] as String,
    label: json['label'] as String,
    filter: FeedFilter.fromJson(json['filter'] as Map<String, dynamic>),
    createdAt: DateTime.parse(json['created_at'] as String),
    lastFetchedAt: json['last_fetched_at'] == null
        ? null
        : DateTime.parse(json['last_fetched_at'] as String),
    fetchCount: json['fetch_count'] as int? ?? 0,
    revokedAt: json['revoked_at'] == null
        ? null
        : DateTime.parse(json['revoked_at'] as String),
  );

  final String id;
  final String label;
  final FeedFilter filter;
  final DateTime createdAt;
  final DateTime? lastFetchedAt;
  final int fetchCount;
  final DateTime? revokedAt;

  bool get revoked => revokedAt != null;
}

/// The reply of `api.feed_token_create`: the only time the token is known.
class CreatedFeedToken {
  const CreatedFeedToken({required this.id, required this.token});

  final String id;
  final String token;
}

/// The subscription address for [token]: `<supabaseUrl>/functions/v1/ics/<token>.ics`.
/// The `webcal://` form is the same address with the scheme that opens the calendar
/// app's subscribe dialog directly (specs/05, "Subscribing").
String feedAddress(String supabaseUrl, String token) {
  final base = supabaseUrl.endsWith('/')
      ? supabaseUrl.substring(0, supabaseUrl.length - 1)
      : supabaseUrl;
  return '$base/functions/v1/ics/$token.ics';
}

String webcalAddress(String httpsAddress) =>
    httpsAddress.replaceFirst(RegExp(r'^https?://'), 'webcal://');

/// Subscription tokens. Guardian-only writes; every call goes through `api`.
class FeedRepository {
  const FeedRepository(this._api);

  final ApiClient _api;

  Future<Result<List<FeedToken>>> tokens() => _api.select(
    'feed_tokens',
    parse: FeedToken.fromJson,
    build: (q) => q.order('created_at'),
  );

  /// Creates a subscription. The token comes back once and is never stored.
  Future<Result<CreatedFeedToken>> create({
    required String? actor,
    required String label,
    required FeedFilter filter,
  }) => _api.rpc(
    'feed_token_create',
    params: {'p_actor': actor, 'p_label': label, 'p_filter': filter.toJson()},
    parse: (json) {
      final m = json! as Map<String, dynamic>;
      return CreatedFeedToken(
        id: m['id'] as String,
        token: m['token'] as String,
      );
    },
  );

  Future<Result<void>> revoke({required String? actor, required String id}) =>
      _api.rpc(
        'feed_token_revoke',
        params: {'p_actor': actor, 'p_id': id},
        parse: (_) {},
      );
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepository(ref.watch(apiClientProvider)),
);
