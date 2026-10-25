import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_templates.dart';

/// The family's event templates and the suggestions counted from its history
/// (specs/28). Only for servers that announce `event-templates`; the built-in
/// templates live in the app.
class EventTemplatesRepository {
  const EventTemplatesRepository(this._api);

  final ApiClient _api;

  Future<Result<List<EventTemplate>>> templates() => _api.select(
    'event_templates',
    parse: EventTemplate.fromJson,
    build: (q) => q.order('created_at'),
  );

  /// Inserts [template], or updates it when it has an id. Returns its id.
  Future<Result<String>> save({
    required String? actor,
    required EventTemplate template,
  }) => _api.rpc(
    'event_template_save',
    params: {'p_actor': actor, 'p_template': template.toJson()},
    parse: (json) => (json! as Map<String, dynamic>)['id'] as String,
  );

  Future<Result<void>> delete({required String? actor, required String id}) =>
      _api.rpc(
        'event_template_delete',
        params: {'p_actor': actor, 'p_id': id},
        parse: (_) {},
      );

  /// What the family often enters, best first; [on] is the day the new event is for,
  /// so its usual weekday ranks first.
  Future<Result<List<EventTemplate>>> suggestions({
    required DateTime on,
    int limit = 4,
  }) => _api.rpc(
    'event_suggestions',
    params: {'p_on': isoDate(on), 'p_limit': limit},
    parse: (json) => [
      for (final row in json as List? ?? const [])
        EventTemplate.fromSuggestion(row as Map<String, dynamic>),
    ],
  );

  /// Never suggests [signature] again ([hidden] false shows it again).
  Future<Result<void>> hideSuggestion({
    required String? actor,
    required String signature,
    bool hidden = true,
  }) => _api.rpc(
    'event_suggestion_hide',
    params: {'p_actor': actor, 'p_signature': signature, 'p_hidden': hidden},
    parse: (_) {},
  );
}

final eventTemplatesRepositoryProvider = Provider<EventTemplatesRepository>(
  (ref) => EventTemplatesRepository(ref.watch(apiClientProvider)),
);
