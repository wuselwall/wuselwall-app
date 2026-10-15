import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/calendar/data/external_calendars_repository.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';

/// In-memory subscriptions that record every write and refresh. A save or refresh
/// answers [saveResult] or [refreshResult] when given, else succeeds. [url] answers
/// from [urls] (calendar id to full address) unless [urlResult] is given.
class FakeExternalCalendarsRepository implements ExternalCalendarsRepository {
  FakeExternalCalendarsRepository({
    List<ExternalCalendar> calendars = const [],
    this.refreshResult,
    this.saveResult,
    this.urls = const {},
    this.urlResult,
  }) : items = [...calendars];

  final List<ExternalCalendar> items;

  /// The full feed address per calendar id, as a guardian's `external_calendar_url` gives it.
  final Map<String, String> urls;

  /// Answers [url] when given (a failure, for instance).
  final Result<String>? urlResult;

  final urlRequested = <String>[];

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
  Future<Result<String>> url({
    required String? actor,
    required String id,
  }) async {
    urlRequested.add(id);
    if (urlResult != null) return urlResult!;
    final url = urls[id];
    return url == null
        ? const Err(NotFoundFailure(code: 'external_calendar_not_found'))
        : Ok(url);
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
