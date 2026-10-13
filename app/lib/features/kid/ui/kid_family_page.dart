import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/kid/application/kid_logic.dart';
import 'package:wuselwall/features/kid/ui/kid_widgets.dart';

/// "Familie": who is doing what today. One row per member, their presence and how many
/// chores are open. No points, no comparison: that is deliberate (specs/06).
class KidFamilyPage extends ConsumerWidget {
  const KidFamilyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(boardProvider);
    final board = snapshot.board;
    if (board == null) {
      final failure = snapshot.failure;
      return Center(
        child: failure == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(Tokens.space4),
                child: Text(failure.message(l10n), textAlign: TextAlign.center),
              ),
      );
    }
    final index = board.todayIndex;
    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        KidSectionTitle(l10n.kidFamilyTitle),
        for (final m in board.members)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space2),
            child: _FamilyRow(board: board, member: m, index: index),
          ),
      ],
    );
  }
}

class _FamilyRow extends StatelessWidget {
  const _FamilyRow({
    required this.board,
    required this.member,
    required this.index,
  });

  final WeekBoard board;
  final BoardMember member;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final presence = kidPresenceOf(board, member, index);
    final open = board.openTasks[member.id] ?? 0;
    return KidCard(
      child: Row(
        children: [
          MemberAvatar(member: member, size: 56),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  presence == null
                      ? l10n.kidNoPlanToday
                      : context.presenceLabel(presence.state, presence.label),
                  style: theme.textTheme.bodyLarge,
                ),
                Text(l10n.kidOpenTasks(open), style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
