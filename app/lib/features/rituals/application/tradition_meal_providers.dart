import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';

/// A tradition's meal, offered on the tradition's day (specs/27 "Familientraditionen":
/// the planner's one-tap suggestion). Never planned by itself.
@immutable
class TraditionMealSuggestion {
  const TraditionMealSuggestion({
    required this.date,
    required this.slot,
    required this.title,
    required this.tradition,
    this.recipeId,
    this.iconKey,
  });

  /// The tradition's day (local).
  final DateTime date;
  final PlanSlot slot;

  /// The meal's words or its recipe's title ("Pizza").
  final String title;

  /// The tradition's name ("Pizza-Freitag").
  final String tradition;

  /// The recipe, when the meal is one; else [title] is planned as words.
  final String? recipeId;

  /// The tradition's content icon.
  final String? iconKey;
}

/// The tradition meals of the week starting on [weekStart], by day. Empty on a server
/// without traditions, and while anything loads or fails: a suggestion is a nicety,
/// never an error in the planner.
final traditionMealSuggestionsProvider = Provider.autoDispose
    .family<List<TraditionMealSuggestion>, DateTime>((ref, weekStart) {
      final window = (
        from: weekStart,
        to: DateTime(weekStart.year, weekStart.month, weekStart.day + 6),
      );
      final occurrences =
          ref.watch(occurrencesProvider(window)).value?.occurrences ??
          const <Occurrence>[];
      final out = <TraditionMealSuggestion>[];
      for (final o in occurrences) {
        if (!o.tradition ||
            o.isPresence ||
            o.isImported ||
            o.status == EventStatus.cancelled ||
            o.localStartDate.isBefore(window.from) ||
            o.localStartDate.isAfter(window.to)) {
          continue;
        }
        // The occurrences carry the flag; the meal is on the event (api.events).
        final meal = ref
            .watch(calendarEventProvider(o.eventId))
            .value
            ?.traditionMeal;
        final title = meal?.title ?? meal?.freeText;
        if (meal == null || title == null || title.trim().isEmpty) continue;
        final PlanSlot slot;
        try {
          slot = PlanSlot.parse(meal.slot);
        } on FormatException {
          continue;
        }
        out.add(
          TraditionMealSuggestion(
            date: o.localStartDate,
            slot: slot,
            title: title.trim(),
            tradition: o.title,
            recipeId: meal.recipeId,
            iconKey: o.iconKey,
          ),
        );
      }
      return out;
    });
