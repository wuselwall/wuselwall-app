import 'package:flutter_test/flutter_test.dart';
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
      // In UTC: the clocks change between the two dates.
      DateTime utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);
      expect(
        utc(orthodoxEaster(2024)).difference(utc(westernEaster(2024))).inDays,
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
