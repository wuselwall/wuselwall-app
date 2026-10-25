/// The repeat choices the event editor offers, and their RFC 5545 form (specs/05
/// "Recurrence", specs/15 "Maintaining a rota"). The editor builds rules only from
/// this subset; a stored rule it cannot reproduce exactly is kept as [RepeatKind.custom]
/// and written back unchanged.
library;

enum RepeatKind {
  never,
  daily,
  weekly,
  biweekly,
  monthly,
  yearly,
  specificDays,
  custom,
}

/// A monthly rule keeps the start's day of month, or its weekday in the month.
enum MonthlyMode { dayOfMonth, nthWeekday, lastWeekday }

enum RepeatEnd { never, until, count }

const _dayCodes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// ISO weekday (1 = Monday) to its RRULE code.
String dayCode(int weekday) => _dayCodes[weekday - 1];

/// "20261231": the UNTIL form the API accepts for a date.
String untilCode(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// The number of the start's weekday within its month: 1 for the first Friday.
int nthOf(DateTime start) => (start.day - 1) ~/ 7 + 1;

/// True when no later week of the same weekday is in the month.
bool isLastWeekdayOf(DateTime start) =>
    start.day + 7 > DateTime(start.year, start.month + 1, 0).day;

/// An immutable repeat choice. [days] are the explicit dates of a rota (the start day
/// is implied and never stored); [custom] and [customRdates] hold a rule the editor
/// cannot represent, so it is written back as it was read.
class Recurrence {
  const Recurrence({
    this.kind = RepeatKind.never,
    this.weekdays = const {},
    this.monthly = MonthlyMode.dayOfMonth,
    this.end = RepeatEnd.never,
    this.until,
    this.count = 10,
    this.days = const {},
    this.custom,
    this.customRdates = const [],
  });

  /// Parses a stored rule. [rrule] is null for a rota (or a single event), and
  /// [rdates] holds the explicit dates. Anything that does not survive a round trip
  /// through [toRrule] becomes [RepeatKind.custom].
  factory Recurrence.fromStored({
    required DateTime start,
    required String? rrule,
    required List<DateTime> rdates,
  }) {
    final day = _dateOnly(start);
    if (rrule == null) {
      if (rdates.isEmpty) return const Recurrence();
      return Recurrence(
        kind: RepeatKind.specificDays,
        days: {day, for (final d in rdates) _dateOnly(d)},
      );
    }
    final custom = Recurrence(
      kind: RepeatKind.custom,
      custom: rrule,
      customRdates: rdates,
    );
    if (rdates.isNotEmpty) return custom;
    final parsed = _parseRule(rrule, day);
    if (parsed == null) return custom;
    return parsed.toRrule(day) == rrule ? parsed : custom;
  }

  final RepeatKind kind;

  /// Weekly and every-2-weeks rules: the chosen weekdays (ISO numbers, 1 = Monday).
  final Set<int> weekdays;
  final MonthlyMode monthly;
  final RepeatEnd end;
  final DateTime? until;
  final int count;

  /// [RepeatKind.specificDays]: the selected dates, the start day included.
  final Set<DateTime> days;

  /// [RepeatKind.custom]: the stored RRULE body and its explicit dates.
  final String? custom;
  final List<DateTime> customRdates;

  /// Whether this choice offers an end ("Ende der Wiederholung").
  bool get hasEnd => switch (kind) {
    RepeatKind.daily ||
    RepeatKind.weekly ||
    RepeatKind.biweekly ||
    RepeatKind.monthly ||
    RepeatKind.yearly => true,
    _ => false,
  };

  Recurrence copyWith({
    RepeatKind? kind,
    Set<int>? weekdays,
    MonthlyMode? monthly,
    RepeatEnd? end,
    DateTime? until,
    int? count,
    Set<DateTime>? days,
  }) => Recurrence(
    kind: kind ?? this.kind,
    weekdays: weekdays ?? this.weekdays,
    monthly: monthly ?? this.monthly,
    end: end ?? this.end,
    until: until ?? this.until,
    count: count ?? this.count,
    days: days ?? this.days,
    custom: custom,
    customRdates: customRdates,
  );

  /// The RRULE body for a series starting on [start], or null when there is none
  /// (single events and rotas).
  String? toRrule(DateTime start) {
    final parts = switch (kind) {
      RepeatKind.never || RepeatKind.specificDays => null,
      RepeatKind.custom => null,
      RepeatKind.daily => ['FREQ=DAILY'],
      RepeatKind.weekly => ['FREQ=WEEKLY', _byDay(weekdays, start)],
      RepeatKind.biweekly => [
        'FREQ=WEEKLY',
        'INTERVAL=2',
        _byDay(weekdays, start),
      ],
      RepeatKind.monthly => switch (monthly) {
        MonthlyMode.dayOfMonth => ['FREQ=MONTHLY', 'BYMONTHDAY=${start.day}'],
        MonthlyMode.nthWeekday => [
          'FREQ=MONTHLY',
          'BYDAY=${nthOf(start)}${dayCode(start.weekday)}',
        ],
        MonthlyMode.lastWeekday => [
          'FREQ=MONTHLY',
          'BYDAY=-1${dayCode(start.weekday)}',
        ],
      },
      RepeatKind.yearly => ['FREQ=YEARLY'],
    };
    if (kind == RepeatKind.custom) return custom;
    if (parts == null) return null;
    return [
      ...parts,
      if (hasEnd && end == RepeatEnd.until && until != null)
        'UNTIL=${untilCode(until!)}',
      if (hasEnd && end == RepeatEnd.count) 'COUNT=$count',
    ].join(';');
  }

  /// The explicit dates to store with the rule: the rota's days without the start,
  /// which the server includes itself.
  List<DateTime> rdatesFor(DateTime start) {
    if (kind == RepeatKind.custom) return customRdates;
    if (kind != RepeatKind.specificDays) return const [];
    final first = _dateOnly(start);
    return [
      for (final d in days)
        if (d != first) d,
    ]..sort();
  }

  /// Whether the rule has a weekday set that is empty (a validation error).
  bool get needsWeekdays =>
      (kind == RepeatKind.weekly || kind == RepeatKind.biweekly) &&
      weekdays.isEmpty;

  static String _byDay(Set<int> weekdays, DateTime start) {
    final picked = weekdays.isEmpty ? {start.weekday} : weekdays;
    final codes = [for (final w in picked.toList()..sort()) dayCode(w)];
    return 'BYDAY=${codes.join(',')}';
  }
}

/// Reads the supported subset of an RRULE body into a choice, or null. The caller
/// checks the round trip, so anything odd (extra parts, UTC until) falls through.
Recurrence? _parseRule(String rule, DateTime start) {
  const allowed = {'FREQ', 'INTERVAL', 'COUNT', 'UNTIL', 'BYDAY', 'BYMONTHDAY'};
  final map = <String, String>{};
  for (final part in rule.split(';')) {
    final eq = part.indexOf('=');
    if (eq <= 0) return null;
    final key = part.substring(0, eq);
    if (!allowed.contains(key) || map.containsKey(key)) return null;
    map[key] = part.substring(eq + 1);
  }
  final interval = int.tryParse(map['INTERVAL'] ?? '1');
  if (interval == null) return null;

  var end = RepeatEnd.never;
  DateTime? until;
  var count = 10;
  if (map.containsKey('UNTIL') && map.containsKey('COUNT')) return null;
  if (map.containsKey('UNTIL')) {
    final raw = map['UNTIL']!;
    if (!RegExp(r'^\d{8}$').hasMatch(raw)) return null;
    until = DateTime(
      int.parse(raw.substring(0, 4)),
      int.parse(raw.substring(4, 6)),
      int.parse(raw.substring(6, 8)),
    );
    end = RepeatEnd.until;
  }
  if (map.containsKey('COUNT')) {
    final parsed = int.tryParse(map['COUNT']!);
    if (parsed == null || parsed < 1) return null;
    count = parsed;
    end = RepeatEnd.count;
  }

  final freq = map['FREQ'];
  final byDay = map['BYDAY'];
  final byMonthDay = map['BYMONTHDAY'];
  switch (freq) {
    case 'DAILY':
      if (interval != 1 || byDay != null || byMonthDay != null) return null;
      return Recurrence(
        kind: RepeatKind.daily,
        end: end,
        until: until,
        count: count,
      );
    case 'WEEKLY':
      if (byDay == null || byMonthDay != null) return null;
      if (interval != 1 && interval != 2) return null;
      final weekdays = <int>{};
      for (final code in byDay.split(',')) {
        final index = _dayCodes.indexOf(code);
        if (index < 0) return null;
        weekdays.add(index + 1);
      }
      return Recurrence(
        kind: interval == 2 ? RepeatKind.biweekly : RepeatKind.weekly,
        weekdays: weekdays,
        end: end,
        until: until,
        count: count,
      );
    case 'MONTHLY':
      if (interval != 1) return null;
      if (byMonthDay != null && byDay == null) {
        if (int.tryParse(byMonthDay) == null) return null;
        return Recurrence(
          kind: RepeatKind.monthly,
          monthly: MonthlyMode.dayOfMonth,
          end: end,
          until: until,
          count: count,
        );
      }
      if (byDay != null && byMonthDay == null && !byDay.contains(',')) {
        final match = RegExp(r'^(-1|[1-5])([A-Z]{2})$').firstMatch(byDay);
        if (match == null || !_dayCodes.contains(match.group(2))) return null;
        final n = int.parse(match.group(1)!);
        return Recurrence(
          kind: RepeatKind.monthly,
          monthly: n == -1 ? MonthlyMode.lastWeekday : MonthlyMode.nthWeekday,
          end: end,
          until: until,
          count: count,
        );
      }
      return null;
    case 'YEARLY':
      if (interval != 1 || byDay != null || byMonthDay != null) return null;
      return Recurrence(
        kind: RepeatKind.yearly,
        end: end,
        until: until,
        count: count,
      );
    default:
      return null;
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
