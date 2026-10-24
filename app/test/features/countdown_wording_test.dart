import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/rituals/domain/countdown.dart';
import 'package:wuselwall/features/rituals/ui/countdown_widgets.dart';

void main() {
  final today = DateTime(2026, 10, 24);
  final de = lookupAppLocalizations(const Locale('de'));

  Countdown inDays(int days, {CountdownKind kind = CountdownKind.event}) =>
      Countdown(
        kind: kind,
        date: DateTime(today.year, today.month, today.day + days),
        title: 'Zoo',
      );

  group('countdownWhen (specs/27 "How it counts")', () {
    test('children and the wall count nights up to a week', () {
      expect(countdownWhen(de, inDays(2), today), 'noch 2× schlafen');
      expect(countdownWhen(de, inDays(7), today), 'noch 7× schlafen');
    });

    test('beyond a week they count days', () {
      expect(countdownWhen(de, inDays(8), today), 'noch 8 Tage');
      expect(countdownWhen(de, inDays(30), today), 'noch 30 Tage');
    });

    test('grown-ups always read "in N Tagen"', () {
      expect(countdownWhen(de, inDays(2), today, sleeps: false), 'in 2 Tagen');
      expect(countdownWhen(de, inDays(9), today, sleeps: false), 'in 9 Tagen');
    });

    test(
      'the day before is "Morgen!", the day itself "Heute!", for everyone',
      () {
        for (final sleeps in [true, false]) {
          expect(
            countdownWhen(de, inDays(1), today, sleeps: sleeps),
            'Morgen!',
          );
          expect(countdownWhen(de, inDays(0), today, sleeps: sleeps), 'Heute!');
        }
      },
    );
  });

  group('countdownTitle of a birthday', () {
    Countdown birthday({int? age}) => Countdown(
      kind: CountdownKind.birthday,
      date: DateTime(2026, 10, 27),
      title: 'Paul',
      age: age,
    );

    test('says the age the member turns, in all four languages', () {
      final expected = {
        'de': 'Paul wird 8',
        'en': 'Paul turns 8',
        'fr': 'Les 8 ans de Paul',
        'es': 'Paul cumple 8 años',
      };
      for (final MapEntry(key: lang, value: text) in expected.entries) {
        expect(
          countdownTitle(
            lookupAppLocalizations(Locale(lang)),
            birthday(age: 8),
          ),
          text,
          reason: lang,
        );
      }
    });

    test('one year old reads naturally', () {
      expect(
        countdownTitle(
          lookupAppLocalizations(const Locale('es')),
          birthday(age: 1),
        ),
        'Paul cumple 1 año',
      );
      expect(
        countdownTitle(
          lookupAppLocalizations(const Locale('fr')),
          birthday(age: 1),
        ),
        'Le premier anniversaire de Paul',
      );
    });

    test('without an age, whose birthday it is', () {
      expect(countdownTitle(de, birthday()), 'Geburtstag von Paul');
    });
  });
}
