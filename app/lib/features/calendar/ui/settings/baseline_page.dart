import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/domain/usual_week.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// Each member's usual week (specs/15 "The baseline", issue #81): where they usually
/// are on each weekday. Guardians may set everyone's; a member sets their own, and the
/// server refuses the rest, whose message is shown. Members come from the week board;
/// a server that does not send the usual week yet gets the single usual place.
class BaselinePage extends ConsumerWidget {
  const BaselinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snapshot = ref.watch(boardProvider);
    final acting = ref.watch(actingProfileProvider);
    final board = snapshot.board;

    final Widget body;
    if (board != null && board.days.first.usual == null) {
      body = _MemberList(
        board: board,
        card: (m) => _SinglePlaceCard(
          key: ValueKey('${m.id}-${m.baseline?.state.name}'),
          member: m,
          actingId: acting,
        ),
      );
    } else if (board != null) {
      body = AsyncValueView(
        value: ref.watch(usualWeeksProvider),
        onRetry: () => ref.invalidate(usualWeeksProvider),
        data: (weeks) => _MemberList(
          board: board,
          card: (m) => _UsualWeekCard(
            member: m,
            week:
                weeks.where((w) => w.profileId == m.id).firstOrNull ??
                UsualWeek(profileId: m.id),
            actingId: acting,
          ),
        ),
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

class _MemberList extends StatelessWidget {
  const _MemberList({required this.board, required this.card});

  final WeekBoard board;
  final Widget Function(BoardMember member) card;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(Tokens.space4),
    children: [
      Text(context.l10n.baselineHelp),
      const SizedBox(height: Tokens.space4),
      for (final m in board.members)
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.space4),
          child: card(m),
        ),
    ],
  );
}

/// The member's name and avatar over a card's content.
class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.member});

  final BoardMember member;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      MemberAvatar(member: member, size: 36),
      const SizedBox(width: Tokens.space3),
      Expanded(
        child: Text(
          member.displayName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ],
  );
}

/// A date of [weekday] (ISO, 1 = Monday), for naming it in the household's language.
DateTime _dayOfWeek(int weekday) => DateTime(2024, 1, weekday);

/// One member's week: a row per weekday with its usual places, tapped to change the
/// day. Saved as one `member_usual_week_set` call, which keeps week B and the anchor.
class _UsualWeekCard extends ConsumerStatefulWidget {
  const _UsualWeekCard({
    required this.member,
    required this.week,
    required this.actingId,
  });

  final BoardMember member;
  final UsualWeek week;
  final String? actingId;

  @override
  ConsumerState<_UsualWeekCard> createState() => _UsualWeekCardState();
}

class _UsualWeekCardState extends ConsumerState<_UsualWeekCard> {
  late UsualWeek _week = widget.week;
  bool _saving = false;

  @override
  void didUpdateWidget(_UsualWeekCard old) {
    super.didUpdateWidget(old);
    // The refetch after a save brings the server's week.
    if (!identical(old.week, widget.week) && !_saving) _week = widget.week;
  }

  Future<void> _editDay(int weekday) async {
    final places = await showModalBottomSheet<List<UsualPlace>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DaySheet(
        member: widget.member,
        weekday: weekday,
        places: _week.day(weekday),
      ),
    );
    if (places != null && mounted) {
      setState(() => _week = _week.withDay(weekday, places));
    }
  }

  void _copyMonday() {
    final monday = _week.day(DateTime.monday);
    setState(() {
      for (var d = DateTime.tuesday; d <= DateTime.friday; d++) {
        _week = _week.withDay(d, monday);
      }
    });
  }

  Future<void> _save() async {
    final member = widget.member;
    // Anyone else's week is a guardian action: the PIN gate comes first.
    if (member.id != widget.actingId) {
      final ok = await ensureGuardian(context, ref);
      if (!ok || !mounted) return;
    }
    setState(() => _saving = true);
    final result = await ref
        .read(calendarRepositoryProvider)
        .setUsualWeek(actor: widget.actingId, week: _week);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Ok():
        ref.invalidate(usualWeeksProvider);
        await ref.read(boardProvider.notifier).refresh();
        if (mounted) context.showMessage(context.l10n.baselineSaved);
      case Err(:final failure):
        context.showMessage(failure.message(context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MemberHeader(member: widget.member),
            const SizedBox(height: Tokens.space2),
            for (var d = DateTime.monday; d <= DateTime.sunday; d++)
              _DayRow(
                member: widget.member,
                weekday: d,
                places: _week.day(d),
                onTap: () => _editDay(d),
              ),
            const SizedBox(height: Tokens.space2),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                TextButton(
                  onPressed: _week.day(DateTime.monday).isEmpty
                      ? null
                      : _copyMonday,
                  child: Text(l10n.usualCopyMonday),
                ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A weekday and its places, or "nothing set"; tapping opens the day.
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.member,
    required this.weekday,
    required this.places,
    required this.onTap,
  });

  final BoardMember member;
  final int weekday;
  final List<UsualPlace> places;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontSize = theme.textTheme.bodyLarge?.fontSize ?? 16;
    final day = _dayOfWeek(weekday);
    return InkWell(
      borderRadius: BorderRadius.circular(Tokens.space2),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                context.weekdayShort(day),
                semanticsLabel: context.weekdayLong(day),
                style: theme.textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: places.isEmpty
                  ? Text(
                      context.l10n.baselineNone,
                      style: TextStyle(color: context.ww.ink3),
                    )
                  : Wrap(
                      spacing: Tokens.space1,
                      runSpacing: Tokens.space1,
                      children: [
                        for (final p in places)
                          PresenceBandView(
                            state: p.state,
                            memberColor: member.color,
                            label: context.usualLabel(p),
                            fontSize: fontSize,
                            dense: true,
                          ),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// One weekday: "nothing" or one of the six states, with an optional own label. Pops
/// the day's new places; closing it without "Apply" changes nothing.
class _DaySheet extends StatefulWidget {
  const _DaySheet({
    required this.member,
    required this.weekday,
    required this.places,
  });

  final BoardMember member;
  final int weekday;
  final List<UsualPlace> places;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late PresenceState? _state = widget.places.firstOrNull?.state;
  late final _label = TextEditingController(
    text: widget.places.firstOrNull?.label ?? '',
  );

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _apply() {
    final state = _state;
    final text = _label.text.trim();
    Navigator.pop<List<UsualPlace>>(context, [
      if (state != null)
        UsualPlace(state: state, label: text.isEmpty ? null : text),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final fontSize = theme.textTheme.bodyLarge?.fontSize ?? 16;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Tokens.space4,
          0,
          Tokens.space4,
          Tokens.space4 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.usualDayTitle(
                  widget.member.displayName,
                  context.weekdayLong(_dayOfWeek(widget.weekday)),
                ),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Tokens.space2),
              _PlaceChoice(
                member: widget.member,
                state: _state,
                fontSize: fontSize,
                onChanged: (s) => setState(() => _state = s),
              ),
              const SizedBox(height: Tokens.space2),
              _LabelField(controller: _label, enabled: _state != null),
              const SizedBox(height: Tokens.space2),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _apply,
                  child: Text(l10n.usualDayApply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Nothing" plus the six states, previewed as bands.
class _PlaceChoice extends StatelessWidget {
  const _PlaceChoice({
    required this.member,
    required this.state,
    required this.fontSize,
    required this.onChanged,
  });

  final BoardMember member;
  final PresenceState? state;
  final double fontSize;
  final ValueChanged<PresenceState?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Option(
        selected: state == null,
        onTap: () => onChanged(null),
        child: Text(context.l10n.baselineNone),
      ),
      for (final s in PresenceState.values)
        _Option(
          selected: state == s,
          onTap: () => onChanged(s),
          child: PresenceBandView(
            state: s,
            memberColor: member.color,
            label: context.presenceLabel(s),
            fontSize: fontSize,
            dense: true,
          ),
        ),
    ],
  );
}

/// The optional own label; the server takes at most 40 characters.
class _LabelField extends StatelessWidget {
  const _LabelField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: enabled,
    maxLength: 40,
    decoration: InputDecoration(
      labelText: context.l10n.baselineLabelField,
      hintText: context.l10n.baselineLabelHint,
    ),
  );
}

/// A server without the usual week: one place for every day, saved as one
/// `member_baseline_set` call.
class _SinglePlaceCard extends ConsumerStatefulWidget {
  const _SinglePlaceCard({
    required this.member,
    required this.actingId,
    super.key,
  });

  final BoardMember member;
  final String? actingId;

  @override
  ConsumerState<_SinglePlaceCard> createState() => _SinglePlaceCardState();
}

class _SinglePlaceCardState extends ConsumerState<_SinglePlaceCard> {
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
    final fontSize = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MemberHeader(member: widget.member),
            const SizedBox(height: Tokens.space2),
            _PlaceChoice(
              member: widget.member,
              state: _state,
              fontSize: fontSize,
              onChanged: (s) => setState(() => _state = s),
            ),
            const SizedBox(height: Tokens.space2),
            _LabelField(controller: _label, enabled: _state != null),
            const SizedBox(height: Tokens.space2),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(context.l10n.save),
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
