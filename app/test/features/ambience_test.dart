import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
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

  group('the evening sun sets in the hour before night (specs/26)', () {
    DateTime at(int h, int m) => DateTime(2026, 10, 24, h, m);

    test('still up until an hour before, then down in five-minute steps', () {
      expect(sunsetAt(at(19, 59)), 0);
      expect(sunsetAt(at(20, 0)), 0);
      expect(sunsetAt(at(20, 4)), 0);
      expect(sunsetAt(at(20, 5)), 1 / 12);
      expect(sunsetAt(at(20, 30)), 6 / 12);
      expect(sunsetAt(at(20, 59)), 11 / 12);
      // The night has begun: the night sky takes over.
      expect(sunsetAt(at(21, 0)), 0);
    });

    test('follows the device\'s night hours, across midnight too', () {
      final late = NightHours.parse(const {'from': '00:30', 'to': '06:00'});
      expect(sunsetAt(at(23, 0), hours: late), 0);
      expect(sunsetAt(at(23, 45), hours: late), 3 / 12);
      expect(sunsetAt(at(0, 15), hours: late), 9 / 12);
    });

    test('a device without a night never sees the sun set', () {
      const none = NightHours(start: 0, end: 0);
      expect(sunsetAt(at(23, 30), hours: none), 0);
    });

    test('the ambience carries it, so the sky repaints with each step', () {
      const day = LighterDay();
      expect(ambienceFor(at(20, 30), night: false, day: day).sunset, 0.5);
      expect(
        ambienceFor(at(20, 30), night: false, day: day),
        isNot(ambienceFor(at(20, 40), night: false, day: day)),
      );
      expect(
        ambienceFor(at(20, 31), night: false, day: day),
        ambienceFor(at(20, 34), night: false, day: day),
      );
    });
  });

  group('the Ferien ribbon\'s days', () {
    HolidayRecord ferien(
      DateTime from,
      DateTime to, {
      String kind = 'holiday',
    }) => HolidayRecord(
      id: '$from',
      name: 'Herbstferien',
      startsOn: from,
      endsOn: to,
      kind: kind,
    );
    final autumn = ferien(DateTime(2026, 10, 10), DateTime(2026, 10, 25));

    test('the first and the last day, nothing before, between or after', () {
      expect(ferienEdgeOn([autumn], DateTime(2026, 10, 9, 12)), isNull);
      expect(
        ferienEdgeOn([autumn], DateTime(2026, 10, 10, 7)),
        FerienEdge.first,
      );
      expect(ferienEdgeOn([autumn], DateTime(2026, 10, 17)), isNull);
      expect(
        ferienEdgeOn([autumn], DateTime(2026, 10, 25, 20)),
        FerienEdge.last,
      );
      expect(ferienEdgeOn([autumn], DateTime(2026, 10, 26)), isNull);
    });

    test('back-to-back holidays are one stretch', () {
      final bridge = ferien(DateTime(2026, 10, 26), DateTime(2026, 10, 26));
      expect(ferienEdgeOn([autumn, bridge], DateTime(2026, 10, 25)), isNull);
      expect(
        ferienEdgeOn([autumn, bridge], DateTime(2026, 10, 26)),
        FerienEdge.last,
      );
    });

    test('the weekends around weekday Ferien belong to them', () {
      // Monday 12 to Friday 23 October: school ends Friday the 9th and starts again
      // Monday the 26th.
      final weekdays = ferien(DateTime(2026, 10, 12), DateTime(2026, 10, 23));
      expect(ferienEdgeOn([weekdays], DateTime(2026, 10, 9)), isNull);
      expect(
        ferienEdgeOn([weekdays], DateTime(2026, 10, 10)),
        FerienEdge.first,
      );
      expect(ferienEdgeOn([weekdays], DateTime(2026, 10, 12)), isNull);
      expect(ferienEdgeOn([weekdays], DateTime(2026, 10, 23)), isNull);
      expect(ferienEdgeOn([weekdays], DateTime(2026, 10, 25)), FerienEdge.last);
      expect(ferienEdgeOn([weekdays], DateTime(2026, 10, 26)), isNull);
    });

    test('a public holiday after the Ferien moves the last day', () {
      // Osterferien until Friday 3 April 2026, Ostermontag on the 6th.
      final easter = ferien(DateTime(2026, 3, 23), DateTime(2026, 4, 3));
      final monday = ferien(
        DateTime(2026, 4, 6),
        DateTime(2026, 4, 6),
        kind: 'public_holiday',
      );
      expect(ferienEdgeOn([easter, monday], DateTime(2026, 4, 5)), isNull);
      expect(
        ferienEdgeOn([easter, monday], DateTime(2026, 4, 6)),
        FerienEdge.last,
      );
    });

    test('a long weekend without Ferien is no stretch', () {
      final monday = ferien(
        DateTime(2026, 4, 6),
        DateTime(2026, 4, 6),
        kind: 'public_holiday',
      );
      expect(ferienEdgeOn([monday], DateTime(2026, 4, 4)), isNull);
      expect(ferienEdgeOn([monday], DateTime(2026, 4, 6)), isNull);
      expect(ferienEdgeOn(const [], DateTime(2026, 4, 4)), isNull);
    });

    test('one Ferien day joins its weekend; other kinds are no Ferien', () {
      // Monday 2 November 2026: the weekend before it starts the stretch.
      final day = ferien(DateTime(2026, 11, 2), DateTime(2026, 11, 2));
      expect(ferienEdgeOn([day], DateTime(2026, 10, 31)), FerienEdge.first);
      expect(ferienEdgeOn([day], DateTime(2026, 11, 2)), FerienEdge.last);
      final closure = ferien(
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 2),
        kind: 'closure',
      );
      expect(ferienEdgeOn([closure], DateTime(2026, 11, 2)), isNull);
    });

    test('the household\'s switch turns the ribbon off', () {
      const off = LighterDay(occasionSwitches: {'ambience.ferien': false});
      expect(
        ambienceFor(
          DateTime(2026, 10, 10),
          night: false,
          day: const LighterDay(),
          ferien: FerienEdge.first,
        ).ferien,
        FerienEdge.first,
      );
      expect(
        ambienceFor(
          DateTime(2026, 10, 10),
          night: false,
          day: off,
          ferien: FerienEdge.first,
        ).ferien,
        isNull,
      );
    });
  });
}
