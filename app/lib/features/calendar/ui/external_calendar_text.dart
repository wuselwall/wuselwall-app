import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';

/// The friendly sentence for a fetch problem's short code (`last_error`, or the code
/// of a failed refresh).
String fetchProblemText(AppLocalizations l10n, String code) {
  final error = FetchErrorCode.parse(code);
  return switch (error.problem) {
    FetchProblem.unreachable => l10n.extCalErrUnreachable,
    FetchProblem.timeout => l10n.extCalErrTimeout,
    FetchProblem.forbiddenHost => l10n.extCalErrForbiddenHost,
    FetchProblem.tooLarge => l10n.extCalErrTooLarge,
    FetchProblem.notIcs => l10n.extCalErrNotIcs,
    FetchProblem.http when error.httpStatus == 404 => l10n.extCalErrHttp404,
    FetchProblem.http when error.httpStatus != null => l10n.extCalErrHttp(
      error.httpStatus!,
    ),
    FetchProblem.internal => l10n.extCalErrInternal,
    FetchProblem.db => l10n.extCalErrDb,
    FetchProblem.http || FetchProblem.unknown => l10n.extCalErrUnknown,
  };
}

/// What an on-demand refresh reports, in one sentence.
String refreshResultText(AppLocalizations l10n, CalendarRefresh refresh) =>
    switch (refresh.status) {
      RefreshStatus.refreshed => l10n.extCalRefreshed(refresh.rows ?? 0),
      RefreshStatus.notModified => l10n.extCalNotModified,
      RefreshStatus.recent => l10n.extCalRecent,
      RefreshStatus.failed => l10n.extCalRefreshFailed(
        fetchProblemText(l10n, refresh.code ?? 'unknown'),
      ),
    };

/// "vor 12 Min." and the like, from the feed page's wording.
String agoText(AppLocalizations l10n, DateTime at, DateTime now) {
  final d = now.difference(at);
  return d.inMinutes < 1
      ? l10n.feedAgoJustNow
      : d.inMinutes < 60
      ? l10n.feedAgoMinutes(d.inMinutes)
      : d.inHours < 24
      ? l10n.feedAgoHours(d.inHours)
      : l10n.feedAgoDays(d.inDays);
}

/// The status line under a calendar's name: paused, not yet loaded, the friendly
/// error, or when it was last updated.
String calendarStatusText(
  AppLocalizations l10n,
  ExternalCalendar calendar,
  DateTime now,
) {
  if (!calendar.active) return l10n.extCalStatusPaused;
  final fetched = calendar.lastFetchedAt;
  if (fetched == null) return l10n.extCalStatusNever;
  final error = calendar.lastError;
  if (error != null) return fetchProblemText(l10n, error);
  return l10n.extCalStatusUpdated(agoText(l10n, fetched, now));
}
