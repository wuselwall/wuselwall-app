import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/application/birthday_providers.dart'
    show birthdaysOn;
import 'package:wuselwall/features/school/domain/school_models.dart';

/// The month grid's 42 days: six weeks from the Monday on or before the first of
/// [month]. Calendar days, so a clock change in between never shifts a date.
List<DateTime> monthGridDays(DateTime month) {
  final first = DateTime(month.year, month.month);
  final monday = DateTime(
    first.year,
    first.month,
    first.day - (first.weekday - DateTime.monday),
  );
  return [
    for (var i = 0; i < 42; i++)
      DateTime(monday.year, monday.month, monday.day + i),
  ];
}

/// One day of the month view and what it shows (specs/05 "Views"): the public holiday,
/// the birthdays, the Ferien it lies in, the key appointments and traditions by name,
/// and only the number of everything else.
class MonthDay {
  const MonthDay({
    required this.date,
    required this.inMonth,
    this.publicHoliday,
    this.birthdays = const [],
    this.ferien,
    this.notable = const [],
    this.others = 0,
  });

  final DateTime date;

  /// Whether the day belongs to the month in view (the grid's first and last days
  /// usually belong to the neighbours).
  final bool inMonth;

  /// The public holiday's name; null on an ordinary day.
  final String? publicHoliday;

  /// The members whose birthday it is, in board order. Shown whatever the birthday
  /// ambience says: the month view is information, the ambience is decoration.
  final List<Member> birthdays;

  /// The name of the school holidays covering the day; null outside them.
  final String? ferien;

  /// Key appointments and traditions, the all-day ones first, then by start.
  final List<Occurrence> notable;

  /// The other appointments of the day, only counted.
  final int others;
}

/// A stretch of Ferien inside one week row, columns [first] to [last] (0 = Monday).
/// [openStart] and [openEnd] say that the Ferien go on in the week before or after.
class FerienSpan {
  const FerienSpan({
    required this.first,
    required this.last,
    required this.name,
    this.openStart = false,
    this.openEnd = false,
  });

  final int first;
  final int last;
  final String name;
  final bool openStart;
  final bool openEnd;
}

/// The whole month view: six weeks of [MonthDay]s and the Ferien bands of each week.
class MonthPlan {
  MonthPlan._(this.month, this.weeks, this.ferien);

  /// Builds the plan for [month] from the window's [occurrences], the [members] (for
  /// birthdays), the [publicHolidays] by date and the school holidays [schoolHolidays]
  /// (only `kind` `holiday` makes Ferien; back-to-back ones are one stretch).
  factory MonthPlan.of({
    required DateTime month,
    required List<Occurrence> occurrences,
    required List<Member> members,
    required Map<DateTime, String> publicHolidays,
    required List<HolidayRecord> schoolHolidays,
  }) {
    final m = DateTime(month.year, month.month);
    final days = monthGridDays(m);
    final ferienRecords = [
      for (final h in schoolHolidays)
        if (h.kind == 'holiday') h,
    ];
    String? ferienOn(DateTime d) {
      for (final h in ferienRecords) {
        if (!d.isBefore(dateOnly(h.startsOn)) &&
            !d.isAfter(dateOnly(h.endsOn))) {
          return h.name;
        }
      }
      return null;
    }

    final shown = [
      for (final o in occurrences)
        if (!o.isPresence && o.status != EventStatus.cancelled) o,
    ];
    final weeks = <List<MonthDay>>[];
    final ferien = <List<FerienSpan>>[];
    for (var w = 0; w < 6; w++) {
      final row = <MonthDay>[];
      for (var i = 0; i < 7; i++) {
        final d = days[w * 7 + i];
        final today = [
          for (final o in shown)
            if (o.coversDay(d)) o,
        ];
        final notable = [
          for (final o in today)
            if (o.isKey || o.tradition) o,
        ]..sort(_byStart);
        row.add(
          MonthDay(
            date: d,
            inMonth: d.month == m.month && d.year == m.year,
            publicHoliday: publicHolidays[d],
            birthdays: birthdaysOn(d, members),
            ferien: ferienOn(d),
            notable: notable,
            others: today.length - notable.length,
          ),
        );
      }
      weeks.add(row);
      ferien.add(_spans(row, ferienOn));
    }
    return MonthPlan._(m, weeks, ferien);
  }

  /// The first day of the month in view.
  final DateTime month;

  /// Six rows of seven days, Monday first.
  final List<List<MonthDay>> weeks;

  /// The Ferien bands of each row, in the same order as [weeks].
  final List<List<FerienSpan>> ferien;
}

int _byStart(Occurrence a, Occurrence b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  return a.start.compareTo(b.start);
}

/// The stretches of consecutive Ferien days in one row, each named after the Ferien
/// of its first day.
List<FerienSpan> _spans(
  List<MonthDay> row,
  String? Function(DateTime) ferienOn,
) {
  final out = <FerienSpan>[];
  var i = 0;
  while (i < row.length) {
    final name = row[i].ferien;
    if (name == null) {
      i++;
      continue;
    }
    var j = i;
    while (j + 1 < row.length && row[j + 1].ferien != null) {
      j++;
    }
    final before = row[i].date;
    final after = row[j].date;
    out.add(
      FerienSpan(
        first: i,
        last: j,
        name: name,
        openStart:
            i == 0 &&
            ferienOn(DateTime(before.year, before.month, before.day - 1)) !=
                null,
        openEnd:
            j == row.length - 1 &&
            ferienOn(DateTime(after.year, after.month, after.day + 1)) != null,
      ),
    );
    i = j + 1;
  }
  return out;
}
