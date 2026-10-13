import 'package:flutter/material.dart';
import 'package:wuselwall/features/home/application/home_section.dart';
import 'package:wuselwall/features/meals/ui/meals_page.dart';

/// The adult home's meals destination: the week grid, with its navigation in the bar.
final mealsSection = HomeSection(
  icon: Icons.restaurant_menu,
  label: (l10n) => l10n.mealsTitle,
  body: const MealsWeekBody(),
  bottom: const MealsToolbar(),
);
