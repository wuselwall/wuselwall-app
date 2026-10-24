import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// The seasons of the northern hemisphere, by month (specs/26 "Seasons and occasions").
enum Season { spring, summer, autumn, winter }

Season seasonOf(DateTime date) => switch (date.month) {
  3 || 4 || 5 => Season.spring,
  6 || 7 || 8 => Season.summer,
  9 || 10 || 11 => Season.autumn,
  _ => Season.winter,
};

/// The occasions that can decorate the wall and the Today header. Each is one
/// household switch (`ambience.*`).
enum Occasion {
  season,
  birthday,
  ferien,
  advent,
  easterWestern,
  easterOrthodox,
  newYear,
}

/// The phase of the day the sky shows (specs/26 "Day phases"): morning from the end of
/// the night until 10, day until 17, evening until the night begins.
SkyPhase skyPhaseAt(DateTime now, {required bool night}) {
  if (night) return SkyPhase.night;
  if (now.hour < 10) return SkyPhase.morning;
  if (now.hour < 17) return SkyPhase.day;
  return SkyPhase.evening;
}

/// Western Easter Sunday, by the Gregorian computus (the "anonymous" algorithm).
DateTime westernEaster(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

/// Orthodox Easter Sunday: the Julian computus (Meeus), converted to the Gregorian
/// calendar. The Julian calendar runs 13 days behind from 1900 to 2099.
DateTime orthodoxEaster(int year) {
  final a = year % 4;
  final b = year % 7;
  final c = year % 19;
  final d = (19 * c + 15) % 30;
  final e = (2 * a + 4 * b - d + 34) % 7;
  final month = (d + e + 114) ~/ 31;
  final day = ((d + e + 114) % 31) + 1;
  final offset = year < 2100 ? 13 : 14;
  return DateTime(year, month, day + offset);
}

/// How many Advent candles burn on [date]: one from the first Sunday of Advent, one
/// more each Sunday, four from the fourth until Christmas Eve; 0 outside Advent.
int adventCandles(DateTime date) {
  final d = DateUtils.dateOnly(date);
  final christmas = DateTime(d.year, 12, 25);
  // The fourth Sunday of Advent is the last Sunday before Christmas Day.
  final back = christmas.weekday == DateTime.sunday ? 7 : christmas.weekday;
  final fourth = DateTime(d.year, 12, 25 - back);
  if (d.isAfter(DateTime(d.year, 12, 24))) return 0;
  for (var n = 4; n >= 1; n--) {
    final sunday = DateTime(
      fourth.year,
      fourth.month,
      fourth.day - 7 * (4 - n),
    );
    if (!d.isBefore(sunday)) return n;
  }
  return 0;
}

/// Countries whose public Easter holiday falls on the Orthodox date (specs/26
/// "Defaults per country"). Everyone else defaults to the Western date and Advent.
const _orthodoxCountries = {
  'GR',
  'CY',
  'RO',
  'BG',
  'RS',
  'ME',
  'MK',
  'MD',
  'UA',
  'GE',
  'BY',
  'RU',
};

/// Countries with a default for the church-year occasions. A region outside both
/// lists has only the occasions every country has.
const _westernCountries = {
  'DE',
  'AT',
  'CH',
  'LI',
  'LU',
  'BE',
  'NL',
  'FR',
  'ES',
  'PT',
  'IT',
  'SM',
  'VA',
  'MT',
  'IE',
  'GB',
  'DK',
  'NO',
  'SE',
  'FI',
  'IS',
  'EE',
  'LV',
  'LT',
  'PL',
  'CZ',
  'SK',
  'HU',
  'SI',
  'HR',
  'BA',
  'AL',
  'AD',
  'MC',
};

/// Whether [occasion] is on for a household in [country] whose switch says [stored]
/// (true, false, 'on', 'off' or 'auto').
@visibleForTesting
bool occasionOn(Occasion occasion, Object? stored, String? country) {
  switch (stored) {
    case true || 'on':
      return true;
    case false || 'off':
      return false;
  }
  return switch (occasion) {
    Occasion.season || Occasion.birthday || Occasion.ferien => true,
    Occasion.newYear => false,
    Occasion.advent ||
    Occasion.easterWestern => _westernCountries.contains(country),
    Occasion.easterOrthodox => _orthodoxCountries.contains(country),
  };
}

String _key(Occasion o) => switch (o) {
  Occasion.season => 'ambience.season',
  Occasion.birthday => 'ambience.birthdays',
  Occasion.ferien => 'ambience.ferien',
  Occasion.advent => 'ambience.advent',
  Occasion.easterWestern => 'ambience.easter_western',
  Occasion.easterOrthodox => 'ambience.easter_orthodox',
  Occasion.newYear => 'ambience.new_year',
};

/// What the sky shows today: the phase, the season and today's occasions.
@immutable
class Ambience {
  const Ambience({
    required this.phase,
    this.season,
    this.advent = 0,
    this.easter = false,
    this.newYear = false,
    this.ferien,
    this.birthdays = const [],
  });

  final SkyPhase phase;

  /// Null when the household switched the seasons off.
  final Season? season;

  /// Advent candles burning, 0 outside Advent.
  final int advent;

  /// Eggs in the hills.
  final bool easter;
  final bool newYear;

  /// The holidays' first or last day: the ribbon's text comes from the screen.
  final FerienEdge? ferien;

  /// The stored colours of the members whose birthday is today.
  final List<Color> birthdays;
}

/// The first or the last day of the school holidays.
enum FerienEdge { first, last }

/// Computes today's [Ambience] from the date and the household's switches.
@visibleForTesting
Ambience ambienceFor(
  DateTime now, {
  required bool night,
  required LighterDay day,
  FerienEdge? ferien,
  List<Color> birthdays = const [],
}) {
  bool on(Occasion o) =>
      occasionOn(o, day.occasionSwitches[_key(o)], day.country);
  final today = DateUtils.dateOnly(now);
  bool aroundEaster(DateTime easter) =>
      today.difference(easter).inDays.abs() <= 2;
  return Ambience(
    phase: skyPhaseAt(now, night: night),
    season: on(Occasion.season) ? seasonOf(now) : null,
    advent: on(Occasion.advent) ? adventCandles(now) : 0,
    easter:
        (on(Occasion.easterWestern) && aroundEaster(westernEaster(now.year))) ||
        (on(Occasion.easterOrthodox) && aroundEaster(orthodoxEaster(now.year))),
    newYear:
        on(Occasion.newYear) &&
        ((now.month == 12 && now.day == 31) ||
            (now.month == 1 && now.day == 1)),
    ferien: on(Occasion.ferien) ? ferien : null,
    birthdays: on(Occasion.birthday) ? birthdays : const [],
  );
}

/// Today's ambience for this household. Rebuilds with the board's clock.
final ambienceProvider = Provider.autoDispose<Ambience>((ref) {
  final now = ref.watch(nowProvider);
  final night = ref.watch(nightProvider);
  final day = ref.watch(lighterDayProvider);
  return ambienceFor(
    now,
    night: night,
    day: day,
    ferien: ref.watch(ferienEdgeTodayProvider),
    birthdays: [
      for (final m in ref.watch(birthdaysTodayMembersProvider)) m.color,
    ],
  );
});
