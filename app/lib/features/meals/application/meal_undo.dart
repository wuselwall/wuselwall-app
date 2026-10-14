import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/meals/application/meals_providers.dart';
import 'package:wuselwall/features/meals/data/meals_repository.dart';
import 'package:wuselwall/features/meals/domain/meal_models.dart';

/// Puts a cleared slot back as [previous] had it: the dish, then its eating overrides,
/// which a clear removes together with the row.
Future<Result<void>> restoreMeal(
  MealsRepository repo, {
  required String? actor,
  required MealEntry previous,
}) async {
  if (previous.recipeId != null || previous.freeText != null) {
    final set = await repo.setMeal(
      actor: actor,
      date: previous.onDate,
      slot: previous.slot,
      recipeId: previous.recipeId,
      freeText: previous.recipeId == null ? previous.freeText : null,
      servings: previous.servings,
      cookProfileId: previous.cookProfileId,
      time: previous.atTime,
      guests: previous.guests,
    );
    if (set case Err(:final failure)) return Err(failure);
  }
  for (final override in previous.eatingOverrides.entries) {
    final set = await repo.setEating(
      actor: actor,
      date: previous.onDate,
      slot: previous.slot,
      profileId: override.key,
      eating: override.value,
    );
    if (set case Err(:final failure)) return Err(failure);
  }
  return const Ok(null);
}

/// Offers "Rückgängig" for a meal that was just cleared. The container, not a widget ref,
/// is used, because the sheet that cleared the meal is gone by the time the user taps.
void offerMealUndo(
  ScaffoldMessengerState messenger,
  ProviderContainer container, {
  required AppLocalizations l10n,
  required String? actor,
  required MealEntry previous,
}) {
  showUndoSnack(
    messenger,
    message: l10n.mealsUxClearedSnack(previous.title ?? ''),
    actionLabel: l10n.mealsUxUndo,
    onAction: () => unawaited(
      _undo(messenger, container, l10n: l10n, actor: actor, previous: previous),
    ),
  );
}

Future<void> _undo(
  ScaffoldMessengerState messenger,
  ProviderContainer container, {
  required AppLocalizations l10n,
  required String? actor,
  required MealEntry previous,
}) async {
  final result = await restoreMeal(
    container.read(mealsRepositoryProvider),
    actor: actor,
    previous: previous,
  );
  container.invalidate(mealEntriesProvider(mondayOf(previous.onDate)));
  if (result case Err(:final failure)) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failure.message(l10n))));
  }
}
