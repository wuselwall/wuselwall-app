import 'package:flutter/foundation.dart';

/// The starter traditions of Kalender → *Neue Tradition* (specs/27
/// "Familientraditionen"): Spieleabend, Pizza-Freitag, Filmabend, Sonntagsfrühstück,
/// Vorlesezeit and Ausflugstag. Each language names them itself (the ARB keys
/// `traditionStarter*`); this is what they start as. Every value is only a suggestion
/// the editor shows before anything is saved.
enum TraditionStarter {
  gameNight(
    iconKey: 'game_die',
    weekday: DateTime.friday,
    hour: 19,
    minutes: 90,
  ),
  pizzaFriday(
    iconKey: 'pizza',
    weekday: DateTime.friday,
    hour: 18,
    minutes: 60,
    meal: true,
  ),
  filmNight(
    iconKey: 'cinema',
    weekday: DateTime.saturday,
    hour: 19,
    minutes: 120,
  ),
  sundayBreakfast(
    iconKey: 'croissant',
    weekday: DateTime.sunday,
    hour: 9,
    minutes: 90,
  ),
  storyTime(
    iconKey: 'book',
    weekday: DateTime.wednesday,
    hour: 19,
    minutes: 30,
  ),
  dayOut(iconKey: 'hiking', weekday: DateTime.sunday);

  const TraditionStarter({
    required this.iconKey,
    required this.weekday,
    this.hour,
    this.minutes = 60,
    this.meal = false,
  });

  /// One of `eventIconKeys`.
  final String iconKey;

  /// ISO weekday (1 = Monday) it repeats on.
  final int weekday;

  /// The start hour; null for an all-day tradition.
  final int? hour;

  /// How long it lasts, for a timed one.
  final int minutes;

  /// Whether it carries a dinner (Pizza-Freitag), offered by the meal planner.
  final bool meal;

  bool get allDay => hour == null;

  /// The first day on or after [from] that falls on [weekday].
  DateTime firstDay(DateTime from) {
    final day = DateTime(from.year, from.month, from.day);
    return DateTime(day.year, day.month, day.day + (weekday - day.weekday) % 7);
  }

  /// The editor's starting point from [from] on: [title] and, for a meal tradition,
  /// [mealWords] are in the household's language.
  TraditionTemplate template({
    required String title,
    required DateTime from,
    String mealWords = '',
  }) {
    final day = firstDay(from);
    final start = allDay ? day : DateTime(day.year, day.month, day.day, hour!);
    return TraditionTemplate(
      title: title,
      start: start,
      end: allDay ? day : start.add(Duration(minutes: minutes)),
      allDay: allDay,
      iconKey: iconKey,
      meal: meal ? mealWords : '',
    );
  }
}

/// A new tradition as the editor opens it: weekly on [start]'s weekday, the whole
/// family, always on the wall. [title] empty for the family's own.
@immutable
class TraditionTemplate {
  const TraditionTemplate({
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.iconKey,
    this.meal = '',
    this.mealSlot = 'dinner',
  });

  /// The family's own tradition: no name or picture yet, an hour from [start].
  factory TraditionTemplate.own(DateTime start) => TraditionTemplate(
    title: '',
    start: start,
    end: start.add(const Duration(hours: 1)),
  );

  final String title;

  /// Timed: the instants; all-day: the dates (inclusive).
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? iconKey;

  /// The meal in a few words; empty for none.
  final String meal;
  final String mealSlot;
}
