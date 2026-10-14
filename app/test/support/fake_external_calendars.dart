import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/calendar/data/external_calendars_repository.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';

/// In-memory subscriptions that record every write and refresh. A save or refresh
/// answers [saveResult] or [refreshResult] when given, else succeeds.
class FakeExternalCalendarsRepository implements ExternalCalendarsRepository {
  FakeExternalCalendarsRepository({
    List<ExternalCalendar> calendars = const [],
    this.refreshResult,
    this.saveResult,
  }) : items = [...calendars];

  final List<ExternalCalendar> items;

  /// Answers [refresh]; null: a refreshed fetch of three rows.
  final Result<CalendarRefresh>? refreshResult;

  /// Answers [save] for new calendars; null: the id `ext-new`.
  final Result<String>? saveResult;

  final saved = <({String? actor, ExternalCalendarDraft draft})>[];
  final deleted = <({String? actor, String id})>[];
  final refreshed = <({String? actor, String calendarId})>[];

  @override
  Future<Result<List<ExternalCalendar>>> calendars() async => Ok(items);

  @override
  Future<Result<String>> save({
    required String? actor,
    required ExternalCalendarDraft draft,
  }) async {
    saved.add((actor: actor, draft: draft));
    return saveResult ?? const Ok('ext-new');
  }

  @override
  Future<Result<void>> delete({
    required String? actor,
    required String id,
  }) async {
    deleted.add((actor: actor, id: id));
    return const Ok(null);
  }

  @override
  Future<Result<CalendarRefresh>> refresh({
    required String? actor,
    required String calendarId,
  }) async {
    refreshed.add((actor: actor, calendarId: calendarId));
    return refreshResult ??
        Ok(
          CalendarRefresh(
            calendarId: calendarId,
            status: RefreshStatus.refreshed,
            rows: 3,
          ),
        );
  }
}
