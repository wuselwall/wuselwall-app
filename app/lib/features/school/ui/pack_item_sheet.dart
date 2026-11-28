import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';

/// The children a thing to bring can be noted for by [actor]: every active child for an
/// adult, only itself for a child (the server's rule, `api.pack_item_save`), none while
/// nobody acts at a shared device or the wall.
List<Member> packChildrenFor(List<Member> members, String? actor) {
  final me = members.where((m) => m.id == actor).firstOrNull;
  if (me == null) return const [];
  if (me.isChild) return me.active ? [me] : const [];
  return [
    for (final m in members)
      if (m.active && m.isChild) m,
  ];
}

/// Whether this device can note a thing to bring now: the server keeps them and someone
/// who may is acting.
final canNotePackItemProvider = Provider<bool>((ref) {
  // Nobody acting (the wall at rest) is the common case: decided before the server is
  // asked about.
  final actor = ref.watch(actingProfileProvider);
  if (actor == null) return false;
  if (!ref.watch(packItemsSupportedProvider)) return false;
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  return packChildrenFor(members, actor).isNotEmpty;
});

/// Notes a one-off thing a child has to bring on a day (specs/15 "One-off things to
/// bring"): who, which day ([date], tomorrow when not given) and what. [childId]
/// preselects the child. Answers whether one was noted.
Future<bool> showPackItemSheet(
  BuildContext context, {
  String? childId,
  DateTime? date,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PackItemSheet(childId: childId, date: date),
  );
  return saved ?? false;
}

/// Removes [item] and says so. The packing lists reload through the `school` topic as
/// well; this refreshes them at once.
Future<void> removePackItem(
  BuildContext context,
  WidgetRef ref,
  PackItem item,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final result = await ref
      .read(schoolRepositoryProvider)
      .deletePackItem(actor: ref.read(actingProfileProvider), id: item.id);
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      _refresh(container);
      context.showMessage(context.l10n.packItemRemoved(item.title));
    case Err(:final failure):
      context.showFailure(failure);
  }
}

/// Reloads the packing lists at once: the school weeks, and the board where it is in use
/// (the wall, a child's Today). A phone that shows no board does not start one.
void _refresh(ProviderContainer container) {
  container.invalidate(schoolWeekProvider);
  if (container.read(boardProvider.exists)) {
    unawaited(container.read(boardProvider.notifier).refresh());
  }
}

class _PackItemSheet extends ConsumerStatefulWidget {
  const _PackItemSheet({this.childId, this.date});

  final String? childId;
  final DateTime? date;

  @override
  ConsumerState<_PackItemSheet> createState() => _PackItemSheetState();
}

class _PackItemSheetState extends ConsumerState<_PackItemSheet> {
  final _title = TextEditingController();
  String? _child;
  late DateTime _day;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(nowProvider);
    _day = _dateOnly(widget.date ?? DateTime(now.year, now.month, now.day + 1));
    _child = widget.childId;
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pickDay(DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(today) ? today : _day,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _day = _dateOnly(picked));
  }

  Future<void> _save(List<Member> children) async {
    final child = children.where((m) => m.id == _child).firstOrNull;
    final title = _title.text.trim();
    if (child == null || title.isEmpty || _busy) return;
    setState(() => _busy = true);
    final container = ProviderScope.containerOf(context, listen: false);
    final result = await ref
        .read(schoolRepositoryProvider)
        .savePackItem(
          actor: ref.read(actingProfileProvider),
          profileId: child.id,
          date: _day,
          title: title,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        _refresh(container);
        // Taken before the sheet closes: the page below says it.
        final messenger = ScaffoldMessenger.maybeOf(context);
        final message = context.l10n.packItemSaved(child.displayName, title);
        Navigator.of(context).pop(true);
        messenger?.showSnackBar(SnackBar(content: Text(message)));
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider);
    final today = _dateOnly(now);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final children = packChildrenFor(members, ref.watch(actingProfileProvider));
    // One child to choose from: chosen.
    if (_child == null && children.length == 1) _child = children.single.id;
    final quick = [
      (label: l10n.packItemToday, day: today),
      (label: l10n.packItemTomorrow, day: today.add(const Duration(days: 1))),
      (label: l10n.packItemDayAfter, day: today.add(const Duration(days: 2))),
    ];
    final other = !quick.any((q) => q.day == _day);
    final canSave =
        !_busy &&
        _title.text.trim().isNotEmpty &&
        children.any((m) => m.id == _child);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: Tokens.space4, bottom: Tokens.space2),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.space4,
        right: Tokens.space4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.space4,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.backpack_outlined),
                const SizedBox(width: Tokens.space2),
                Expanded(
                  child: Text(
                    l10n.packItemAdd,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            label(l10n.packItemWhat),
            TextField(
              key: const ValueKey('pack-item-title'),
              controller: _title,
              autofocus: true,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: l10n.packItemWhatHint,
                border: const OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => unawaited(_save(children)),
            ),
            if (children.length > 1) ...[
              label(l10n.packItemWho),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final m in children)
                    ChoiceChip(
                      key: ValueKey('pack-item-child-${m.id}'),
                      label: Text(m.displayName),
                      selected: _child == m.id,
                      onSelected: (_) => setState(() => _child = m.id),
                    ),
                ],
              ),
            ],
            label(l10n.packItemWhen),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                for (final q in quick)
                  ChoiceChip(
                    label: Text(q.label),
                    selected: _day == q.day,
                    onSelected: (_) => setState(() => _day = q.day),
                  ),
                ChoiceChip(
                  key: const ValueKey('pack-item-other-day'),
                  avatar: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    other
                        ? '${context.weekdayShort(_day)} ${context.dayMonth(_day)}'
                        : l10n.packItemOtherDay,
                  ),
                  selected: other,
                  onSelected: (_) => unawaited(_pickDay(today)),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space6),
            FilledButton.icon(
              key: const ValueKey('pack-item-save'),
              onPressed: canSave ? () => unawaited(_save(children)) : null,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(l10n.packItemSave),
            ),
          ],
        ),
      ),
    );
  }
}

/// The things noted for [childId] on [date] as chips to remove, and a chip to note one
/// more (specs/15). Nothing at all on a server without them or when nobody who may is
/// acting; the noted things then still show in the packing line above.
class PackItemChips extends ConsumerWidget {
  const PackItemChips({
    required this.childId,
    required this.date,
    required this.items,
    super.key,
  });

  final String childId;
  final DateTime date;
  final List<PackItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canNotePackItemProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final mine = packChildrenFor(
      members,
      ref.watch(actingProfileProvider),
    ).any((m) => m.id == childId);
    if (!mine) return const SizedBox.shrink();
    return Wrap(
      spacing: Tokens.space2,
      runSpacing: Tokens.space2,
      children: [
        for (final item in items)
          InputChip(
            key: ValueKey('pack-item-${item.id}'),
            avatar: const Icon(Icons.backpack_outlined, size: 18),
            label: Text(item.title),
            onDeleted: () => unawaited(removePackItem(context, ref, item)),
            deleteButtonTooltipMessage: l10n.packItemRemove(item.title),
          ),
        ActionChip(
          key: ValueKey('pack-item-add-$childId'),
          avatar: const Icon(Icons.add, size: 18),
          label: Text(l10n.packItemAdd),
          onPressed: () => unawaited(
            showPackItemSheet(context, childId: childId, date: date),
          ),
        ),
      ],
    );
  }
}
