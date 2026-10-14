import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';

/// The getting-started card (specs/20). The server derives the items; the app only
/// asks for them, dismisses one, or brings the whole card back. Every call names the
/// acting profile, and the server answers nothing for a member or a kiosk.
class GettingStartedRepository {
  const GettingStartedRepository(this._api);

  final ApiClient _api;

  /// The shown items in card order: open and done, without the dismissed ones.
  Future<Result<List<GettingStartedItem>>> items({required String actor}) =>
      _api.rpc(
        'getting_started',
        params: {'p_actor': actor},
        parse: (json) => [
          for (final row in (json as List?) ?? const [])
            ?GettingStartedItem.fromJson(row as Map<String, dynamic>),
        ],
      );

  /// Hides [item] for the household, or for [actor] alone when it is set_pin.
  Future<Result<void>> dismiss({
    required String actor,
    required StartItem item,
  }) => _api.rpc(
    'getting_started_dismiss',
    params: {'p_actor': actor, 'p_item': item.wire},
    parse: (_) {},
  );

  /// Shows the card again: the household's dismissals and [actor]'s own go.
  Future<Result<void>> restore({required String actor}) => _api.rpc(
    'getting_started_restore',
    params: {'p_actor': actor},
    parse: (_) {},
  );
}

final gettingStartedRepositoryProvider = Provider<GettingStartedRepository>(
  (ref) => GettingStartedRepository(ref.watch(apiClientProvider)),
);
