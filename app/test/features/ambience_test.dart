import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

void main() {
  group('Easter is computed for every year (specs/26, Q52)', () {
    test('Western dates', () {
      expect(westernEaster(2000), DateTime(2000, 4, 23));
      expect(westernEaster(2019), DateTime(2019, 4, 21));
      expect(westernEaster(2024), DateTime(2024, 3, 31));
      expect(westernEaster(2025), DateTime(2025, 4, 20));
      expect(westernEaster(2026), DateTime(2026, 4, 5));
      expect(westernEaster(2027), DateTime(2027, 3, 28));
      expect(westernEaster(2038), DateTime(2038, 4, 25));
      expect(westernEaster(2050), DateTime(2050, 4, 10));
    });

    test('Orthodox dates, on the Gregorian calendar', () {
      expect(orthodoxEaster(2000), DateTime(2000, 4, 30));
      expect(orthodoxEaster(2019), DateTime(2019, 4, 28));
      expect(orthodoxEaster(2024), DateTime(2024, 5, 5));
      expect(orthodoxEaster(2025), DateTime(2025, 4, 20));
      expect(orthodoxEaster(2026), DateTime(2026, 4, 12));
      expect(orthodoxEaster(2027), DateTime(2027, 5, 2));
      expect(orthodoxEaster(2050), DateTime(2050, 4, 17));
    });

    test('the two coincide in some years and are weeks apart in others', () {
      expect(westernEaster(2025), orthodoxEaster(2025));
      // Counted in calendar days: the clocks change between the two dates.
      expect(
        calendarDaysBetween(westernEaster(2024), orthodoxEaster(2024)),
        35,
      );
    });
  });

  group('Advent candles', () {
    test('one more each Sunday, four until Christmas Eve', () {
      // 2026: Christmas is a Friday; Advent Sundays 29 Nov, 6, 13, 20 Dec.
      expect(adventCandles(DateTime(2026, 11, 28)), 0);
      expect(adventCandles(DateTime(2026, 11, 29)), 1);
      expect(adventCandles(DateTime(2026, 12, 5)), 1);
      expect(adventCandles(DateTime(2026, 12, 6)), 2);
      expect(adventCandles(DateTime(2026, 12, 13)), 3);
      expect(adventCandles(DateTime(2026, 12, 20)), 4);
      expect(adventCandles(DateTime(2026, 12, 24)), 4);
      expect(adventCandles(DateTime(2026, 12, 25)), 0);
    });

    test('when Christmas is a Sunday, the fourth Advent is the 18th', () {
      // 2022: Christmas on a Sunday.
      expect(adventCandles(DateTime(2022, 11, 27)), 1);
      expect(adventCandles(DateTime(2022, 12, 18)), 4);
      expect(adventCandles(DateTime(2022, 12, 17)), 3);
    });
  });

  group('defaults per country', () {
    test('season, birthdays and Ferien everywhere; New Year off', () {
      for (final country in ['DE', 'GR', 'JP', null]) {
        expect(occasionOn(Occasion.season, 'auto', country), isTrue);
        expect(occasionOn(Occasion.birthday, 'auto', country), isTrue);
        expect(occasionOn(Occasion.ferien, 'auto', country), isTrue);
        expect(occasionOn(Occasion.newYear, 'auto', country), isFalse);
      }
    });

    test('the church year follows the region, a switch overrides it', () {
      expect(occasionOn(Occasion.advent, 'auto', 'DE'), isTrue);
      expect(occasionOn(Occasion.easterWestern, 'auto', 'CH'), isTrue);
      expect(occasionOn(Occasion.easterOrthodox, 'auto', 'DE'), isFalse);
      expect(occasionOn(Occasion.easterOrthodox, 'auto', 'GR'), isTrue);
      expect(occasionOn(Occasion.easterWestern, 'auto', 'GR'), isFalse);
      expect(occasionOn(Occasion.advent, 'auto', null), isFalse);
      expect(occasionOn(Occasion.easterOrthodox, 'on', 'DE'), isTrue);
      expect(occasionOn(Occasion.advent, 'off', 'DE'), isFalse);
      expect(occasionOn(Occasion.season, false, 'DE'), isFalse);
    });
  });

  test('a household can keep both Easters', () {
    const day = LighterDay(
      country: 'DE',
      occasionSwitches: {'ambience.easter_orthodox': 'on'},
    );
    expect(
      ambienceFor(DateTime(2024, 3, 31, 9), night: false, day: day).easter,
      isTrue,
    );
    expect(
      ambienceFor(DateTime(2024, 5, 5, 9), night: false, day: day).easter,
      isTrue,
    );
    expect(
      ambienceFor(DateTime(2024, 4, 15, 9), night: false, day: day).easter,
      isFalse,
    );
  });

  group('Easter ± 2 days, across a clock change', () {
    // In 2024 and 2016 Western Easter fell on the night the clocks went forward in
    // central Europe, so local midnights after it are a multiple of 24 h minus one
    // hour away. These hold in every time zone; under a DST zone (TZ=Europe/Zurich)
    // they also catch a day count taken from Duration.inDays.
    const day = LighterDay(country: 'DE');
    bool eggs(DateTime d) => ambienceFor(d, night: false, day: day).easter;

    test('2024: Easter 31 March', () {
      expect(eggs(DateTime(2024, 3, 28)), isFalse);
      expect(eggs(DateTime(2024, 3, 29)), isTrue);
      expect(eggs(DateTime(2024, 4, 2)), isTrue);
      expect(eggs(DateTime(2024, 4, 3)), isFalse);
    });

    test('2016: Easter 27 March', () {
      expect(westernEaster(2016), DateTime(2016, 3, 27));
      expect(eggs(DateTime(2016, 3, 29)), isTrue);
      expect(eggs(DateTime(2016, 3, 30)), isFalse);
    });

    test('days are counted on the calendar, not in hours', () {
      expect(
        calendarDaysBetween(
          DateTime(2024, 3, 31, 23, 30),
          DateTime(2024, 4, 3),
        ),
        3,
      );
      expect(
        calendarDaysBetween(DateTime(2024, 3, 31), DateTime(2024, 4, 3, 0, 30)),
        3,
      );
      expect(
        calendarDaysBetween(DateTime(2024, 4, 3), DateTime(2024, 3, 31)),
        -3,
      );
    });
  });

  test('the sky follows the night hours and board.day_parts', () {
    final hours = NightHours.parse(const {'from': '22:00', 'to': '07:00'});
    DateTime at(int h, int m) => DateTime(2026, 10, 24, h, m);
    SkyPhase phase(DateTime t) => skyPhaseAt(
      t,
      night: hours.contains(t),
      hours: hours,
      eveningStart: 18 * 60 + 30,
    );
    expect(phase(at(6, 59)), SkyPhase.night);
    expect(phase(at(7, 0)), SkyPhase.morning);
    expect(phase(at(10, 0)), SkyPhase.day);
    expect(phase(at(18, 29)), SkyPhase.day);
    expect(phase(at(18, 30)), SkyPhase.evening);
    expect(phase(at(21, 59)), SkyPhase.evening);
    expect(phase(at(22, 0)), SkyPhase.night);
    // A night that begins after midnight keeps the evening's sky until then.
    final late = NightHours.parse(const {'from': '01:00', 'to': '06:00'});
    expect(
      skyPhaseAt(at(0, 30), night: late.contains(at(0, 30)), hours: late),
      SkyPhase.evening,
    );
  });

  test('the sky follows the day: morning, day, evening, night', () {
    expect(
      skyPhaseAt(DateTime(2026, 10, 24, 7), night: false),
      SkyPhase.morning,
    );
    expect(skyPhaseAt(DateTime(2026, 10, 24, 13), night: false), SkyPhase.day);
    expect(
      skyPhaseAt(DateTime(2026, 10, 24, 18), night: false),
      SkyPhase.evening,
    );
    expect(skyPhaseAt(DateTime(2026, 10, 24, 22), night: true), SkyPhase.night);
  });
}
