import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/proposals_repository.dart';
import 'package:wuselwall/features/school/domain/proposal_models.dart';
import 'package:wuselwall/features/school/ui/timetable_import_page.dart';

/// The open proposals (specs/24): one card each, for guardians, on Today and above the
/// Stundenplan. "Prüfen" opens the preview; "Verwerfen" rejects without looking.
class ProposalCards extends ConsumerWidget {
  const ProposalCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposals =
        ref.watch(openProposalsProvider).value ?? const <ProposalRecord>[];
    if (proposals.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [for (final p in proposals) _ProposalCard(proposal: p)],
    );
  }
}

class _ProposalCard extends ConsumerWidget {
  const _ProposalCard({required this.proposal});

  final ProposalRecord proposal;

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final import = proposal.timetable;
    if (import == null) {
      context.showMessage(context.l10n.schoolProposalUnreadable);
      return;
    }
    unawaited(
      context.push(
        Routes.timetableImport,
        extra: TimetableImportArgs(
          import: import,
          proposalId: proposal.id,
          assistantLabel: proposal.assistantLabel,
        ),
      ),
    );
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final result = await ref
        .read(proposalsRepositoryProvider)
        .resolve(
          actor: ref.read(actingProfileProvider),
          id: proposal.id,
          applied: false,
        );
    if (!context.mounted) return;
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok():
        ref.invalidate(openProposalsProvider);
        context.showMessage(context.l10n.schoolImportDiscarded);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final import = proposal.timetable;
    final body =
        proposal.summary ??
        (import == null
            ? l10n.schoolProposalUnreadable
            : l10n.schoolProposalSummary(
                import.member ?? '?',
                import.lessons.length,
              ));
    return Card(
      key: ValueKey('proposal-${proposal.id}'),
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: Tokens.space2),
                Expanded(
                  child: Text(
                    l10n.schoolProposalTitle(
                      proposal.assistantLabel ?? l10n.shortcutSectionAssistants,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space1),
            Text(body),
            const SizedBox(height: Tokens.space2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _discard(context, ref),
                  child: Text(l10n.schoolImportDiscard),
                ),
                const SizedBox(width: Tokens.space2),
                FilledButton(
                  onPressed: import == null
                      ? null
                      : () => _review(context, ref),
                  child: Text(l10n.schoolProposalReview),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
