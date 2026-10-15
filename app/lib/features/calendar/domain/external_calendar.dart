import 'package:flutter/material.dart' show Color;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';

/// A subscribed external calendar (FR-1.9): one row of `api.external_calendars`. The
/// server fetches its feed hourly; the apps only read and configure it (specs/05).
class ExternalCalendar {
  const ExternalCalendar({
    required this.id,
    required this.name,
    required this.urlHost,
    required this.colourHex,
    required this.memberIds,
    required this.showOnBoard,
    required this.active,
    this.lastFetchedAt,
    this.lastError,
  });

  factory ExternalCalendar.fromJson(Map<String, dynamic> json) =>
      ExternalCalendar(
        id: json['id'] as String,
        name: json['name'] as String,
        urlHost: json['url_host'] as String? ?? '',
        colourHex: json['colour_hex'] as String,
        memberIds: ((json['member_ids'] as List?) ?? const []).cast<String>(),
        showOnBoard: json['show_on_board'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
        lastFetchedAt: json['last_fetched_at'] == null
            ? null
            : DateTime.parse(json['last_fetched_at'] as String),
        lastError: json['last_error'] as String?,
      );

  final String id;
  final String name;

  /// The host of the feed address only (`www.fc-beispiel.de`). The full address is
  /// never sent to a device: it is a secret for guardians (`external_calendar_url`).
  final String urlHost;
  final String colourHex;

  /// Empty: the whole family.
  final List<String> memberIds;
  final bool showOnBoard;
  final bool active;

  /// The last fetch attempt, successful or not; null before the first one.
  final DateTime? lastFetchedAt;

  /// A short code (`http_404`, `timeout` …) or null after a successful fetch.
  final String? lastError;

  bool get wholeFamily => memberIds.isEmpty;

  /// The calendar's colour; null only for a value the server should never store.
  Color? get colour => colourFromHex(colourHex);
}

/// What the form or a toggle sends to `api.external_calendar_save`. A null field is
/// left out, so the server keeps the stored value (create: the server's defaults).
class ExternalCalendarDraft {
  const ExternalCalendarDraft({
    this.id,
    this.name,
    this.url,
    this.colourHex,
    this.memberIds,
    this.showOnBoard,
    this.active,
  });

  final String? id;
  final String? name;
  final String? url;
  final String? colourHex;
  final List<String>? memberIds;
  final bool? showOnBoard;
  final bool? active;

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    if (url != null) 'url': url,
    if (colourHex != null) 'colour_hex': colourHex,
    if (memberIds != null) 'member_ids': memberIds,
    if (showOnBoard != null) 'show_on_board': showOnBoard,
    if (active != null) 'active': active,
  };
}

/// The address as the server stores it: `https://`, with `webcal://` (what a calendar
/// app's subscribe link uses) taken as `https://`. Null when it is not a web address
/// at all; the server makes the final call on everything else.
String? normalizeCalendarUrl(String input) {
  var s = input.trim();
  if (s.toLowerCase().startsWith('webcal://')) {
    s = 'https://${s.substring('webcal://'.length)}';
  }
  if (s.length > 1000 || !s.toLowerCase().startsWith('https://')) return null;
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) return null;
  return s;
}

/// Why the last fetch failed, from the server's short code in `last_error`.
enum FetchProblem {
  unreachable,
  timeout,
  forbiddenHost,
  tooLarge,
  notIcs,

  /// `http_<status>`; the status is in [FetchErrorCode.httpStatus].
  http,
  internal,
  db,
  unknown;

  static FetchProblem parse(String code) => switch (code) {
    'unreachable' => unreachable,
    'timeout' => timeout,
    'forbidden_host' => forbiddenHost,
    'too_large' => tooLarge,
    'not_ics' => notIcs,
    'internal' => internal,
    'db' => db,
    _ when code.startsWith('http_') => http,
    _ => unknown,
  };
}

/// A parsed `last_error`: the problem and, for `http`, the status code.
class FetchErrorCode {
  const FetchErrorCode(this.problem, {this.httpStatus});

  factory FetchErrorCode.parse(String code) {
    final problem = FetchProblem.parse(code);
    return FetchErrorCode(
      problem,
      httpStatus: problem == FetchProblem.http
          ? int.tryParse(code.substring('http_'.length))
          : null,
    );
  }

  final FetchProblem problem;
  final int? httpStatus;
}

/// The outcome of an on-demand refresh (`calendar-import`).
enum RefreshStatus {
  refreshed,
  notModified,
  failed,

  /// Fetched less than five minutes ago: nothing was fetched.
  recent;

  static RefreshStatus parse(String? v) => switch (v) {
    'refreshed' => refreshed,
    'not_modified' => notModified,
    'recent' => recent,
    _ => failed,
  };
}

class CalendarRefresh {
  const CalendarRefresh({
    required this.calendarId,
    required this.status,
    this.rows,
    this.code,
  });

  factory CalendarRefresh.fromJson(Map<String, dynamic> json) =>
      CalendarRefresh(
        calendarId: json['calendar_id'] as String,
        status: RefreshStatus.parse(json['status'] as String?),
        rows: json['rows'] as int?,
        code: json['code'] as String?,
      );

  final String calendarId;
  final RefreshStatus status;

  /// Imported occurrences stored by a refreshed fetch.
  final int? rows;

  /// The fetch problem's short code when [status] is failed.
  final String? code;
}
