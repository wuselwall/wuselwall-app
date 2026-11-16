import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/trips/domain/combination.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_card_parts.dart';
import 'package:wuselwall/features/trips/ui/trip_combination_bar.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// One kept combination, a card with the same kind of rows as an option: name, total, dates,
/// the transport, the stay, the rental and how many things do not fit.
class TripComboCard extends StatelessWidget {
  const TripComboCard({
    required this.combo,
    required this.combination,
    required this.currency,
    required this.cheapest,
    required this.loaded,
    required this.onLoad,
    required this.onRename,
    required this.onDelete,
    required this.onTake,
    super.key,
  });

  final TripCombo combo;
  final Combination combination;
  final String currency;

  /// The cheapest complete total of the kept combinations.
  final bool cheapest;

  /// The ticks were loaded from this combination and still stand for it.
  final bool loaded;
  final VoidCallback onLoad;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onTake;

  String? _titles(EntryKind kind) {
    final titles = [for (final e in combination.ofKind(kind)) e.title];
    return titles.isEmpty ? null : titles.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final warnings = combination.warnings.length;
    return TripCardFrame(
      highlighted: loaded,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space3,
          Tokens.space3,
          Tokens.space3,
          Tokens.space1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark_outline, size: 20, color: context.ww.ink2),
                const SizedBox(width: Tokens.space2),
                Expanded(
                  child: Text(
                    combo.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space1),
            TripCardTags(
              children: [
                if (cheapest)
                  TripCardTag(
                    label: l10n.tripCompareCheapest,
                    icon: Icons.savings_outlined,
                    background: context.ww.successContainer,
                    foreground: context.ww.success,
                  ),
              ],
            ),
            const SizedBox(height: Tokens.space1),
            Text(
              tripCombinationTotal(context, combination, currency),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TripCardRow(
              icon: Icons.event_outlined,
              text: combination.from == null
                  ? null
                  : tripCombinationDates(context, combination),
            ),
            TripCardRow(
              icon: entryKindIcon(EntryKind.transport),
              text: _titles(EntryKind.transport),
            ),
            TripCardRow(
              icon: entryKindIcon(EntryKind.stay),
              text: _titles(EntryKind.stay),
            ),
            TripCardRow(
              icon: entryKindIcon(EntryKind.rental),
              text: _titles(EntryKind.rental),
            ),
            TripCardRow(
              icon: warnings == 0
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_rounded,
              color: warnings == 0 ? context.ww.success : context.ww.warning,
              text: warnings == 0
                  ? l10n.tripComboFits
                  : l10n.tripComboWarningsCount(warnings),
            ),
            const SizedBox(height: Tokens.space2),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                key: ValueKey('take-${combo.id}'),
                onPressed: onTake,
                child: Text(l10n.tripComboTake),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: ValueKey('load-${combo.id}'),
                  tooltip: l10n.tripComboLoad,
                  icon: const Icon(Icons.checklist_rtl),
                  onPressed: onLoad,
                ),
                IconButton(
                  key: ValueKey('rename-${combo.id}'),
                  tooltip: l10n.tripComboRename,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onRename,
                ),
                IconButton(
                  key: ValueKey('delete-${combo.id}'),
                  tooltip: l10n.tripComboDelete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before a combination is taken (specs/30 "Take one"): says what happens and, when
/// the combination has dates, offers to set the trip's dates to them. Resolves to whether
/// the dates are to be set, or null when cancelled.
Future<bool?> askTakeCombo(
  BuildContext context, {
  required String name,
  required Combination combination,
  required bool tripHasDates,
}) {
  final l10n = context.l10n;
  final from = combination.from;
  final to = combination.to;
  final dates = from != null && to != null
      ? formatTripDates(context, from, to)
      : null;
  var setDates = !tripHasDates;
  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.tripComboTakeTitle(name)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.tripComboTakeBody),
              if (dates != null)
                SwitchListTile(
                  key: const ValueKey('take-dates'),
                  contentPadding: EdgeInsets.zero,
                  value: setDates,
                  onChanged: (v) => setState(() => setDates = v),
                  title: Text(l10n.tripComboSetDates(dates)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('take-confirm'),
            onPressed: () => Navigator.pop(context, dates != null && setDates),
            child: Text(l10n.tripComboTake),
          ),
        ],
      ),
    ),
  );
}
