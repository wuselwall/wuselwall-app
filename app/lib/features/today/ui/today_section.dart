import 'package:flutter/material.dart';
import 'package:wuselwall/features/home/application/home_section.dart';
import 'package:wuselwall/features/today/ui/today_page.dart';

/// The adult home's first destination: today at a glance, and the setup card.
final todaySection = HomeSection(
  icon: Icons.today,
  label: (l10n) => l10n.todayTitle,
  body: const TodayPage(),
);
