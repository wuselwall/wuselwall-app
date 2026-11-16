import 'package:wuselwall/features/calendar/domain/calendar_models.dart'
    show dateOnly;

/// Calendar-day arithmetic for trips: local dates at midnight, never 24-hour
/// durations, so a clock change cannot move a day.

/// [d] moved by [days] calendar days.
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// The number of calendar days from [a] to [b] (negative when [b] is earlier).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Both dates as plain dates, for comparing ignoring any time of day.
DateTime dayOf(DateTime d) => dateOnly(d);

/// Whether [day] lies in `[from, to]`, both ends included.
bool dayWithin(DateTime day, DateTime from, DateTime to) =>
    daysBetween(from, day) >= 0 && daysBetween(day, to) >= 0;
