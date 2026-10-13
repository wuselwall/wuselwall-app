import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// Each member's usual place (specs/15 "The baseline"). Guardians may set everyone's;
/// a member sets their own, and the server refuses the rest, whose message is shown.
/// Members come from the week board, which carries the baseline.
class BaselinePage extends ConsumerWidget {
  const BaselinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(boardProvider);
    final acting = ref.watch(actingProfileProvider);
    final board = snapshot.board;

    final Widget body;
    if (board != null) {
      body = ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          Text(l10n.baselineHelp),
          const SizedBox(height: Tokens.space4),
          for (final m in board.members)
            Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space4),
              child: _BaselineCard(
                key: ValueKey('${m.id}-${m.baseline?.state.name}'),
                member: m,
                actingId: acting,
              ),
            ),
        ],
      );
    } else if (snapshot.failure != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space4),
          child: Text(snapshot.failure!.message(l10n)),
        ),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.baselineTitle),
        leading: BackButton(onPressed: () => context.go(Routes.settings)),
      ),
      body: body,
    );
  }
}

/// One member: the seven choices ("nothing" plus the six states, previewed as bands)
/// and the optional own label. Saved as one `member_baseline_set` call.
class _BaselineCard extends ConsumerStatefulWidget {
  const _BaselineCard({
    required this.member,
    required this.actingId,
    super.key,
  });

  final BoardMember member;
  final String? actingId;

  @override
  ConsumerState<_BaselineCard> createState() => _BaselineCardState();
}

class _BaselineCardState extends ConsumerState<_BaselineCard> {
  late PresenceState? _state = widget.member.baseline?.state;
  late final _label = TextEditingController(
    text: widget.member.baseline?.label ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final member = widget.member;
    // Anyone else's baseline is a guardian action: the PIN gate comes first.
    if (member.id != widget.actingId) {
      final ok = await ensureGuardian(context, ref);
      if (!ok || !mounted) return;
    }
    setState(() => _saving = true);
    final text = _label.text.trim();
    final result = await ref
        .read(calendarRepositoryProvider)
        .setBaseline(
          actor: widget.actingId,
          profileId: member.id,
          state: _state,
          label: _state == null || text.isEmpty ? null : text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Ok():
        await ref.read(boardProvider.notifier).refresh();
        if (mounted) context.showMessage(context.l10n.baselineSaved);
      case Err(:final failure):
        context.showMessage(failure.message(context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final member = widget.member;
    final theme = Theme.of(context);
    final fontSize = theme.textTheme.bodyLarge?.fontSize ?? 16;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MemberAvatar(member: member, size: 36),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: Text(
                    member.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space2),
            _Option(
              selected: _state == null,
              onTap: () => setState(() => _state = null),
              child: Text(l10n.baselineNone),
            ),
            for (final state in PresenceState.values)
              _Option(
                selected: _state == state,
                onTap: () => setState(() => _state = state),
                child: PresenceBandView(
                  state: state,
                  memberColor: member.color,
                  label: context.presenceLabel(state),
                  fontSize: fontSize,
                  dense: true,
                ),
              ),
            const SizedBox(height: Tokens.space2),
            TextField(
              controller: _label,
              enabled: _state != null,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: l10n.baselineLabelField,
                hintText: l10n.baselineLabelHint,
              ),
            ),
            const SizedBox(height: Tokens.space2),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A selectable row: a radio mark and the child, tappable as a whole.
class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(Tokens.space2),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: Tokens.space2),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
