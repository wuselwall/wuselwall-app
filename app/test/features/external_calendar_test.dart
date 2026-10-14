import 'package:flutter/material.dart' show Color, TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';

Map<String, dynamic> _eventJson({bool withSource = false}) => {
  'id': 'e1',
  'event_id': 'e1',
  'recurrence_id': null,
  'calendar_id': 'cal',
  'title': 'Turnen',
  'location': 'TSV-Halle',
  'description': null,
  'kind': 'appointment',
  'presence_state': null,
  'status': 'confirmed',
  'importance': 'normal',
  'all_day': false,
  'start': '2026-10-19T13:00:00Z',
  'end': '2026-10-19T14:00:00Z',
  'local_start_date': '2026-10-19',
  'local_end_date': '2026-10-19',
  'local_starts': '15:00',
  'local_ends': '16:00',
  'attendee_ids': <String>['p1'],
  'is_recurring': false,
  'is_override': false,
  if (withSource) 'source': 'imported',
  if (withSource) 'colour_hex': '#1A4FA8',
};

void main() {
  group('occurrence source and colour', () {
    test('an older server sends neither field: an event, no colour', () {
      final o = Occurrence.fromJson(_eventJson());
      expect(o.source, OccurrenceSource.event);
      expect(o.isImported, isFalse);
      expect(o.colourHex, isNull);
    });

    test('an imported occurrence carries its source and calendar colour', () {
      final o = Occurrence.fromJson(_eventJson(withSource: true));
      expect(o.source, OccurrenceSource.imported);
      expect(o.isImported, isTrue);
      expect(o.colourHex, '#1A4FA8');
      expect(colourFromHex(o.colourHex), const Color(0xFF1A4FA8));
    });

    test('an unknown source is an event, a bad colour is no colour', () {
      final json = {..._eventJson(), 'source': 'mystery', 'colour_hex': 'blau'};
      final o = Occurrence.fromJson(json);
      expect(o.isImported, isFalse);
      expect(colourFromHex(o.colourHex), isNull);
      expect(colourFromHex(null), isNull);
      expect(colourFromHex('#12345'), isNull);
    });

    test('a parsed occurrence keeps its wall clock and attendees', () {
      final o = Occurrence.fromJson(_eventJson(withSource: true));
      expect(o.localStarts, const TimeOfDay(hour: 15, minute: 0));
      expect(o.attendeeIds, ['p1']);
    });
  });

  group('calendar address', () {
    test('webcal and https are stored as https, anything else is refused', () {
      expect(
        normalizeCalendarUrl('webcal://abfuhr.example.de/k.ics'),
        'https://abfuhr.example.de/k.ics',
      );
      expect(
        normalizeCalendarUrl('  WEBCAL://x.de/a.ics '),
        'https://x.de/a.ics',
      );
      expect(normalizeCalendarUrl(' https://x.de/k.ics'), 'https://x.de/k.ics');
      expect(normalizeCalendarUrl('http://x.de/k.ics'), isNull);
      expect(normalizeCalendarUrl('https://'), isNull);
      expect(normalizeCalendarUrl('Abfuhr'), isNull);
      expect(normalizeCalendarUrl(''), isNull);
    });
  });

  group('draft JSON', () {
    test('a create sends only the keys the form set', () {
      const draft = ExternalCalendarDraft(
        name: 'FC Spielplan',
        url: 'https://fc.example.de/s.ics',
        colourHex: '#1A4FA8',
        memberIds: ['p1'],
        showOnBoard: true,
      );
      expect(draft.toJson(), {
        'name': 'FC Spielplan',
        'url': 'https://fc.example.de/s.ics',
        'colour_hex': '#1A4FA8',
        'member_ids': ['p1'],
        'show_on_board': true,
      });
    });

    test('a toggle sends the id and the flag, nothing else', () {
      const draft = ExternalCalendarDraft(id: 'ext-1', active: false);
      expect(draft.toJson(), {'id': 'ext-1', 'active': false});
    });

    test('an empty member list is sent: the whole family', () {
      const draft = ExternalCalendarDraft(memberIds: []);
      expect(draft.toJson(), {'member_ids': <String>[]});
    });
  });

  group('server state', () {
    test('a calendar parses its row; no member ids means the whole family', () {
      final c = ExternalCalendar.fromJson({
        'id': 'ext-1',
        'name': 'Abfuhrkalender',
        'url': 'https://abfuhr.example.de/k.ics',
        'colour_hex': '#9A5300',
        'member_ids': <String>[],
        'show_on_board': true,
        'active': true,
        'last_fetched_at': '2026-10-14T08:00:00Z',
        'last_error': null,
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
      });
      expect(c.wholeFamily, isTrue);
      expect(c.showOnBoard, isTrue);
      expect(c.lastFetchedAt, DateTime.parse('2026-10-14T08:00:00Z'));
      expect(c.lastError, isNull);
    });

    test('a fetch problem code is parsed with its HTTP status', () {
      final notFound = FetchErrorCode.parse('http_404');
      expect(notFound.problem, FetchProblem.http);
      expect(notFound.httpStatus, 404);
      expect(FetchErrorCode.parse('timeout').problem, FetchProblem.timeout);
      expect(
        FetchErrorCode.parse('forbidden_host').problem,
        FetchProblem.forbiddenHost,
      );
      expect(FetchErrorCode.parse('too_large').problem, FetchProblem.tooLarge);
      expect(FetchErrorCode.parse('not_ics').problem, FetchProblem.notIcs);
      expect(FetchErrorCode.parse('db').problem, FetchProblem.db);
      expect(FetchErrorCode.parse('http_xyz').httpStatus, isNull);
      expect(FetchErrorCode.parse('gibberish').problem, FetchProblem.unknown);
    });

    test('a refresh reply parses each status', () {
      CalendarRefresh parse(String status, {int? rows, String? code}) =>
          CalendarRefresh.fromJson({
            'calendar_id': 'ext-1',
            'status': status,
            'rows': ?rows,
            'code': ?code,
          });
      expect(parse('refreshed', rows: 4).status, RefreshStatus.refreshed);
      expect(parse('refreshed', rows: 4).rows, 4);
      expect(parse('not_modified').status, RefreshStatus.notModified);
      expect(parse('recent').status, RefreshStatus.recent);
      final failed = parse('failed', code: 'unreachable');
      expect(failed.status, RefreshStatus.failed);
      expect(failed.code, 'unreachable');
    });
  });

  test('the palette colours are the same values the member colours use', () {
    // A calendar stores the palette's light value; resolving it gives that swatch back.
    final swatch = MemberPalette.resolve(MemberPalette.swatches.first.light);
    expect(swatch.key, MemberPalette.swatches.first.key);
  });
}
