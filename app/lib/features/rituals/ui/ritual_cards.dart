import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/features/rituals/ui/countdown_widgets.dart';
import 'package:wuselwall/features/rituals/ui/meal_wish_widgets.dart';

/// The rituals on Today (specs/27): the nearest countdown, the table question during
/// the meal, the Sunday look-back and new meal wishes. Each shows only when it has
/// something to say; none of them is a notification.
class RitualCards extends StatelessWidget {
  const RitualCards({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: Tokens.space2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [TodayCountdown(), TodayWishCard()],
    ),
  );
}
