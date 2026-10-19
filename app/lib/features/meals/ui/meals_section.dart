import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/home/application/home_section.dart';
import 'package:wuselwall/features/meals/ui/meals_page.dart';

/// The adult home's meals destination: the week grid, with its navigation in the bar.
final mealsSection = HomeSection(
  icon: Icons.restaurant_menu,
  label: (l10n) => l10n.mealsTitle,
  body: const MealsWeekBody(),
  appBar: (context, actions) {
    final wide = homeBarIsWide(context);
    return AppBar(
      centerTitle: false,
      titleSpacing: 12,
      title: Row(
        children: [
          if (wide) ...[
            Text(context.l10n.mealsTitle),
            const SizedBox(width: 24),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: const MealsToolbar(),
              ),
            ),
          ] else
            const Expanded(child: MealsToolbar()),
        ],
      ),
      actions: actions,
    );
  },
);
