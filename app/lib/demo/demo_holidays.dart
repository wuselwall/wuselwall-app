import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart'
    show westernEaster;

/// Holidays for the demo build's calendar month (specs/05 "Views"): the public holidays
/// a server would name for the household's region, and one stretch of Ferien in the
/// month on screen.

/// The demo's public holidays from [from] to [to] (inclusive local dates), by date, in
/// the demo's language: the dates most of the demo's countries share, and a national day
/// of the language's country. A real server names its region's own (`holidays` of the
/// `occurrences` function).
Map<DateTime, String> demoPublicHolidays(DateTime from, DateTime to) {
  final first = DateTime(from.year, from.month, from.day);
  final last = DateTime(to.year, to.month, to.day);
  final out = <DateTime, String>{};
  for (var year = first.year; year <= last.year; year++) {
    final easter = westernEaster(year);
    DateTime afterEaster(int days) =>
        DateTime(easter.year, easter.month, easter.day + days);
    final days = <DateTime, String?>{
      DateTime(year): DemoData.tr4(
        'Neujahr',
        "New Year's Day",
        'Jour de l’an',
        'Año Nuevo',
      ),
      afterEaster(-2): DemoData.tr4(
        'Karfreitag',
        'Good Friday',
        'Vendredi saint',
        'Viernes Santo',
      ),
      afterEaster(1): DemoData.tr4(
        'Ostermontag',
        'Easter Monday',
        'Lundi de Pâques',
        'Lunes de Pascua',
      ),
      DateTime(year, 5): DemoData.tr4(
        'Tag der Arbeit',
        'Labour Day',
        'Fête du Travail',
        'Día del Trabajo',
      ),
      afterEaster(39): DemoData.tr4(
        'Christi Himmelfahrt',
        'Ascension Day',
        'Ascension',
        'Ascensión',
      ),
      afterEaster(50): DemoData.tr4(
        'Pfingstmontag',
        'Whit Monday',
        'Lundi de Pentecôte',
        'Lunes de Pentecostés',
      ),
      DateTime(year, 8, 15): DemoData.tr(const {
        'fr': 'Assomption',
        'es': 'Asunción de la Virgen',
        'de': '',
      }),
      DateTime(year, 10, 3): DemoData.tr(const {
        'de': 'Tag der Deutschen Einheit',
        'en': '',
        'fr': '',
        'es': '',
      }),
      DateTime(year, 10, 12): DemoData.tr(const {
        'es': 'Fiesta Nacional de España',
        'de': '',
      }),
      DateTime(year, 11): DemoData.tr(const {
        'de': 'Allerheiligen',
        'en': '',
        'fr': 'Toussaint',
        'es': 'Todos los Santos',
      }),
      DateTime(year, 12, 25): DemoData.tr4(
        '1. Weihnachtstag',
        'Christmas Day',
        'Noël',
        'Navidad',
      ),
      DateTime(year, 12, 26): DemoData.tr4(
        '2. Weihnachtstag',
        'Boxing Day',
        'Saint-Étienne',
        'San Esteban',
      ),
    };
    for (final MapEntry(key: day, value: name) in days.entries) {
      if (name == null || name.isEmpty) continue;
      if (day.isBefore(first) || day.isAfter(last)) continue;
      out[day] = name;
    }
  }
  return out;
}

/// One stretch of Ferien in the month of [today], so the month view shows its band, and
/// never near enough to start a countdown or hang the sky's ribbon: in the second half
/// of a month the twelve days that ended three days ago, in the first half the twelve
/// days from fifteen days ahead (after the two weeks Vorfreude looks ahead).
List<HolidayRecord> demoSchoolHolidays(DateTime today) {
  final t = DateTime(today.year, today.month, today.day);
  final starts = t.day >= 15
      ? DateTime(t.year, t.month, t.day - 14)
      : DateTime(t.year, t.month, t.day + 15);
  return [
    HolidayRecord(
      id: 'demo-ferien',
      name: DemoData.tr4(
        'Schulferien',
        'School holidays',
        'Vacances scolaires',
        'Vacaciones escolares',
      ),
      startsOn: starts,
      endsOn: DateTime(starts.year, starts.month, starts.day + 11),
    ),
  ];
}
