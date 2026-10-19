import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/supabase/api_client.dart';
import 'package:wuselwall/core/supabase/supabase_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/usual_week.dart';

/// Reads occurrences through the `occurrences` Edge Function and the `api.events`
/// view; every write is one `api` function, naming the acting profile (the server
/// checks it against the device). Presence is an event, so it has no writes of its own.
class CalendarRepository {
  const CalendarRepository(this._api);

  final ApiClient _api;

  /// Occurrences from [from] to [to], both inclusive local dates (at most 62 days).
  Future<Result<OccurrenceWindow>> occurrences(DateTime from, DateTime to) =>
      _api.function(
        'occurrences',
        body: {'from': isoDate(from), 'to': isoDate(to)},
        parse: (json) =>
            OccurrenceWindow.fromJson(json! as Map<String, dynamic>),
      );

  /// One event for the editor. Missing or deleted events are a [NotFoundFailure].
  Future<Result<CalendarEvent>> event(String id) async {
    final rows = await _api.select(
      'events',
      parse: CalendarEvent.fromJson,
      build: (q) => q.eq('id', id).limit(1),
    );
    return switch (rows) {
      Ok(:final value) when value.isNotEmpty => Ok(value.first),
      Ok() => const Err(NotFoundFailure(code: 'event_not_found')),
      Err(:final failure) => Err(failure),
    };
  }

  /// Inserts the event when it has no row yet, else updates it. Returns its id.
  Future<Result<String>> save({
    required String? actor,
    required CalendarEvent event,
  }) => _api.rpc(
    'event_save',
    params: {'p_actor': actor, 'p_event': event.toJson()},
    parse: (json) => (json! as Map<String, dynamic>)['id'] as String,
  );

  Future<Result<void>> delete({required String? actor, required String id}) =>
      _api.rpc(
        'event_delete',
        params: {'p_actor': actor, 'p_id': id},
        parse: (_) {},
      );

  /// Changes one occurrence of a series ([recurrenceId] is its original start). A
  /// [cancelled] occurrence is removed; [patch] holds the changed fields (title,
  /// starts_at, ends_at, start_date, end_date, location, status). Returns the override's id.
  Future<Result<String>> saveOverride({
    required String? actor,
    required String eventId,
    required DateTime recurrenceId,
    bool cancelled = false,
    Map<String, dynamic> patch = const {},
  }) => _api.rpc(
    'event_override_save',
    params: {
      'p_actor': actor,
      'p_event_id': eventId,
      'p_recurrence_id': recurrenceId.toUtc().toIso8601String(),
      'p_cancelled': cancelled,
      'p_patch': patch,
    },
    parse: (json) => (json! as Map<String, dynamic>)['id'] as String,
  );

  /// Takes an override away, so the series shows its rule again.
  Future<Result<void>> deleteOverride({
    required String? actor,
    required String eventId,
    required DateTime recurrenceId,
  }) => _api.rpc(
    'event_override_delete',
    params: {
      'p_actor': actor,
      'p_event_id': eventId,
      'p_recurrence_id': recurrenceId.toUtc().toIso8601String(),
    },
    parse: (_) {},
  );

  /// "Termine bis 17:00" for [profileId] on [date]; null clears it.
  Future<Result<void>> setBusyUntil({
    required String? actor,
    required String profileId,
    required DateTime date,
    TimeOfDay? until,
  }) => _api.rpc(
    'busy_until_set',
    params: {
      'p_actor': actor,
      'p_profile_id': profileId,
      'p_on_date': isoDate(date),
      'p_until': until == null ? null : clockOf(until),
    },
    parse: (_) {},
  );

  /// Every usual week the caller may see, one per member (`api.usual_weeks`).
  Future<Result<List<UsualWeek>>> usualWeeks() =>
      _api.select('usual_weeks', parse: UsualWeek.fromJson);

  /// Replaces [week] as a whole: its anchor and every slot.
  Future<Result<void>> setUsualWeek({
    required String? actor,
    required UsualWeek week,
  }) => _api.rpc(
    'member_usual_week_set',
    params: {
      'p_actor': actor,
      'p_profile_id': week.profileId,
      'p_anchor': week.anchor == null ? null : isoDate(week.anchor!),
      'p_slots': [for (final s in week.slots) s.toJson()],
    },
    parse: (_) {},
  );

  /// The previous server's single usual place ("Homeoffice", "zu Hause") for every
  /// day; both null clears it. Only for servers without the usual week.
  Future<Result<void>> setBaseline({
    required String? actor,
    required String profileId,
    PresenceState? state,
    String? label,
  }) => _api.rpc(
    'member_baseline_set',
    params: {
      'p_actor': actor,
      'p_profile_id': profileId,
      'p_state': state?.wire,
      'p_label': label,
    },
    parse: (_) {},
  );
}

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(apiClientProvider)),
);
