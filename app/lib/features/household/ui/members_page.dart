import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/household/application/household_providers.dart';
import 'package:wuselwall/features/household/data/household_onboarding_repository.dart';
import 'package:wuselwall/features/household/domain/household_models.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// H2 "Wer gehört noch zu euch?" (specs/20, J1): the rest of the family, shown once after
/// H1. Children are members, adults guardians without an account yet. The examples were
/// chosen on H1; their child chores follow the people added here.
class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

/// One person being added. A child by default.
class _Row {
  _Row() : controller = TextEditingController();

  final TextEditingController controller;
  bool isChild = true;

  void dispose() => controller.dispose();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  final _rows = <_Row>[_Row()];
  var _busy = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _add() => setState(() => _rows.add(_Row()));

  void _remove(_Row row) => setState(() {
    _rows.remove(row);
    row.dispose();
  });

  /// Adds the named people, completes the examples if asked, and leaves for Today.
  Future<void> _finish() async {
    final members = [
      for (final r in _rows)
        if (r.controller.text.trim().isNotEmpty)
          NewMember(displayName: r.controller.text, isChild: r.isChild),
    ];
    final repo = ref.read(householdOnboardingRepositoryProvider);
    final seedExamples =
        ref.read(onboardingPlanProvider)?.seedExamples ?? false;

    setState(() => _busy = true);
    if (members.isNotEmpty) {
      final added = await repo.addMembers(members);
      if (!mounted) return;
      if (added case Err(:final failure)) {
        setState(() => _busy = false);
        context.showFailure(failure);
        return;
      }
    }
    if (seedExamples && members.any((m) => m.isChild)) {
      final seeded = await repo.completeExamples();
      if (!mounted) return;
      if (seeded case Err(:final failure)) context.showFailure(failure);
    }
    _leave();
  }

  /// Skipping keeps the household as H1 made it.
  void _leave() {
    ref.read(onboardingPlanProvider.notifier).clear();
    ref.invalidate(membersProvider);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final founderId = ref.watch(deviceProvider).value?.profileId;
    final founder = ref
        .watch(membersProvider)
        .value
        ?.where((m) => m.id == founderId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.householdMembersTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(Tokens.space6),
              children: [
                if (founder != null) ...[
                  Row(
                    children: [
                      MemberDot(
                        memberColor: founder.color,
                        semanticLabel: founder.displayName,
                        size: 16,
                      ),
                      const SizedBox(width: Tokens.space3),
                      Expanded(
                        child: Text(
                          l10n.householdMembersYou(founder.displayName),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Tokens.space4),
                ],
                for (final (i, row) in _rows.indexed) ...[
                  _PersonRow(
                    row: row,
                    // A preview only: the household gets the next free colour itself.
                    color: MemberPalette
                        .swatches[(i + 1) % MemberPalette.swatches.length]
                        .light,
                    enabled: !_busy,
                    onRemove: _rows.length > 1 ? () => _remove(row) : null,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: Tokens.space4),
                ],
                TextButton.icon(
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.householdMembersAdd),
                ),
                const SizedBox(height: Tokens.space2),
                Text(l10n.householdMembersHelp),
                const SizedBox(height: Tokens.space6),
                FilledButton(
                  onPressed: _busy ? null : _finish,
                  child: Text(l10n.householdMembersDone),
                ),
                const SizedBox(height: Tokens.space2),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: _busy ? null : _leave,
                    child: Text(l10n.householdMembersSkip),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A name, a Kind/Erwachsen choice and a remove button for one person.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.row,
    required this.color,
    required this.enabled,
    required this.onRemove,
    required this.onChanged,
  });

  final _Row row;
  final Color color;
  final bool enabled;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MemberDot(memberColor: color, semanticLabel: '', size: 16),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: TextField(
                controller: row.controller,
                enabled: enabled,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l10n.householdMembersName,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            if (onRemove != null)
              IconButton(
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close),
                tooltip: l10n.householdMembersRemove,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, top: Tokens.space2),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l10n.householdKindChild)),
              ButtonSegment(value: false, label: Text(l10n.householdKindAdult)),
            ],
            selected: {row.isChild},
            onSelectionChanged: enabled
                ? (s) {
                    row.isChild = s.first;
                    onChanged();
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
