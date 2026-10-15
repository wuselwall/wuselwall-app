import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/today/domain/notice.dart';

/// The notices on the adult Today tab (specs/20 J2, J4). The server derives them and
/// decides who sees which; the app lists them and sends "Gesehen". A server from an
/// older release has no such function: the call fails and the caller shows nothing.
class NoticesRepository {
  const NoticesRepository(this._api);

  final ApiClient _api;

  /// The notices [actor] has not dismissed yet, newest first.
  Future<Result<List<AppNotice>>> notices({required String actor}) => _api.rpc(
    'notices',
    params: {'p_actor': actor},
    parse: (json) => [
      for (final row in (json as List?) ?? const [])
        ?AppNotice.fromJson(row as Map<String, dynamic>),
    ],
  );

  /// Hides the notice for [actor] only.
  Future<Result<void>> dismiss({required String actor, required String key}) =>
      _api.rpc(
        'notice_dismiss',
        params: {'p_actor': actor, 'p_key': key},
        parse: (_) {},
      );
}

final noticesRepositoryProvider = Provider<NoticesRepository>(
  (ref) => NoticesRepository(ref.watch(apiClientProvider)),
);
