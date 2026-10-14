import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';

/// Subscribed external calendars. Reads are views; writes are guardian-only `api`
/// functions; the refresh is the `calendar-import` Edge Function (with the caller's JWT).
abstract interface class ExternalCalendarsRepository {
  Future<Result<List<ExternalCalendar>>> calendars();

  /// Creates (no id in [draft]) or updates a calendar. Returns its id.
  Future<Result<String>> save({
    required String? actor,
    required ExternalCalendarDraft draft,
  });

  Future<Result<void>> delete({required String? actor, required String id});

  /// Fetches the feed now, unless it was fetched less than five minutes ago.
  Future<Result<CalendarRefresh>> refresh({
    required String? actor,
    required String calendarId,
  });
}

class SupabaseExternalCalendarsRepository
    implements ExternalCalendarsRepository {
  const SupabaseExternalCalendarsRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<ExternalCalendar>>> calendars() => _api.select(
    'external_calendars',
    parse: ExternalCalendar.fromJson,
    build: (q) => q.order('name'),
  );

  @override
  Future<Result<String>> save({
    required String? actor,
    required ExternalCalendarDraft draft,
  }) => _api.rpc(
    'external_calendar_save',
    params: {'p_actor': actor, 'p_calendar': draft.toJson()},
    parse: (json) => (json! as Map<String, dynamic>)['id'] as String,
  );

  @override
  Future<Result<void>> delete({required String? actor, required String id}) =>
      _api.rpc(
        'external_calendar_delete',
        params: {'p_actor': actor, 'p_id': id},
        parse: (_) {},
      );

  @override
  Future<Result<CalendarRefresh>> refresh({
    required String? actor,
    required String calendarId,
  }) => _api.function(
    'calendar-import',
    body: {'calendar_id': calendarId, 'actor_profile_id': ?actor},
    parse: (json) => CalendarRefresh.fromJson(json! as Map<String, dynamic>),
  );
}

final externalCalendarsRepositoryProvider =
    Provider<ExternalCalendarsRepository>(
      (ref) =>
          SupabaseExternalCalendarsRepository(ref.watch(apiClientProvider)),
    );
