import 'package:flutter/material.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/features/home/application/home_section.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';

/// The adult home's shopping destination.
final shoppingSection = HomeSection(
  icon: Icons.shopping_basket,
  label: (l10n) => l10n.shoppingTitle,
  navLabel: (l10n) => l10n.shoppingNavLabel,
  body: const ContentWidth(child: ShoppingBody()),
);
