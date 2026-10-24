import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/rituals/application/ritual_providers.dart';
import 'package:wuselwall/features/rituals/ui/countdown_widgets.dart';
import 'package:wuselwall/features/rituals/ui/meal_wish_widgets.dart';
import 'package:wuselwall/features/rituals/ui/table_question_widgets.dart';
import 'package:wuselwall/features/rituals/ui/week_review_widgets.dart';
import 'package:wuselwall/features/wusel/application/ambience.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

/// The rituals on Today (specs/27): a birthday, the Sunday look-back, the table
/// question during the meal, the nearest countdown and new meal wishes. Each shows
/// only when it has something to say; none of them is a notification.
class RitualCards extends StatelessWidget {
  const RitualCards({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: Tokens.space2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BirthdayCard(),
        WeekReviewCard(),
        TableQuestionCard(),
        TodayCountdown(),
        TodayWishCard(),
      ],
    ),
  );
}

/// A special day on Today: Wusel in the party hat, even when it is quiet for this
/// grown-up (specs/25 "Where Wusel appears"). A household that switched the birthday
/// ambience off gets none of it; the birthday itself is still on the calendar.
class _BirthdayCard extends ConsumerWidget {
  const _BirthdayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = [
      for (final m in ref.watch(birthdaysTodayMembersProvider)) m.displayName,
    ];
    if (names.isEmpty) return const SizedBox.shrink();
    final on = ref.watch(
      ambienceProvider.select((a) => a.birthdays.isNotEmpty),
    );
    if (!on) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: WuselSays(
          line: context.l10n.wuselFactBirthday(names.join(' & ')),
          pose: WuselPose.cheer,
          outfit: WuselOutfit.party,
          size: 72,
          quietAllowed: true,
        ),
      ),
    );
  }
}
