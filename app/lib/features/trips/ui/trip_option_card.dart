import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_card_parts.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// "12. Juli, 10:40": a date as the ticket writes it, with its time when there is one.
String tripWhen(BuildContext context, DateTime? date, TimeOfDay? time) {
  if (date == null) return '';
  final day = formatTripDate(context, date);
  return time == null ? day : '$day, ${formatTripTime(context, time)}';
}

/// "12. Juli, 10:40 – 12. Juli, 12:05"; null for an entry without a start.
String? tripEntryWhen(BuildContext context, TripEntry e) {
  if (e.startsOn == null) return null;
  final start = tripWhen(context, e.startsOn, e.startsTime);
  if (e.endsOn == null) return start;
  return context.l10n.tripCompareRange(
    start,
    tripWhen(context, e.endsOn, e.endsTime),
  );
}

/// One option of a kind on the comparison page. Every card of a kind has the same rows in
/// the same order, so the eye can run across them: title, price, derived price, from and
/// to, start and end, details, free cancellation, the price's date.
class TripOptionCard extends StatelessWidget {
  const TripOptionCard({
    required this.entry,
    required this.currency,
    required this.today,
    required this.ticked,
    required this.cheapest,
    required this.onTick,
    required this.onEdit,
    required this.onCopy,
    this.onOpenLink,
    super.key,
  });

  final TripEntry entry;
  final String currency;
  final DateTime today;
  final bool ticked;
  final bool cheapest;
  final VoidCallback onTick;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = entry;

    final price = e.priceCents == null
        ? null
        : formatTripMoney(context, e.priceCents!, currency);
    final derived = switch (e.kind) {
      EntryKind.stay when e.pricePerNight != null => l10n.tripComparePerNight(
        formatTripMoney(context, e.pricePerNight!, currency),
      ),
      EntryKind.rental when e.pricePerDay != null => l10n.tripComparePerDay(
        formatTripMoney(context, e.pricePerDay!, currency),
      ),
      _ => null,
    };
    final hasDerived = e.kind == EntryKind.stay || e.kind == EntryKind.rental;
    final route = switch ((e.fromPlace, e.toPlace)) {
      (final f?, final t?) when f.isNotEmpty && t.isNotEmpty =>
        l10n.tripCompareFromTo(f, t),
      (final f?, _) when f.isNotEmpty => f,
      (_, final t?) when t.isNotEmpty => t,
      _ => null,
    };
    final hasRoute =
        e.kind == EntryKind.transport || e.kind == EntryKind.rental;
    final details = (e.details ?? '').trim();
    final passed = e.cancellationPassed(today);

    return TripCardFrame(
      highlighted: ticked,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space1,
          0,
          Tokens.space3,
          Tokens.space1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              checked: ticked,
              label: l10n.tripCompareTick(e.title),
              onTap: onTick,
              child: ExcludeSemantics(
                child: InkWell(
                  key: ValueKey('tick-${e.id}'),
                  onTap: onTick,
                  borderRadius: BorderRadius.circular(Tokens.space2),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: kMinInteractiveDimension,
                    ),
                    child: Row(
                      children: [
                        IgnorePointer(
                          child: Checkbox(value: ticked, onChanged: (_) {}),
                        ),
                        Icon(entryIcon(e), size: 20, color: context.ww.ink2),
                        const SizedBox(width: Tokens.space2),
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: Tokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TripCardTags(
                    children: [
                      if (e.state.inPlan)
                        TripCardTag(
                          label: context.entryState(e.state),
                          icon: e.state == EntryState.booked
                              ? Icons.verified_outlined
                              : Icons.check_circle_outline,
                          background: e.state == EntryState.booked
                              ? scheme.primaryContainer
                              : scheme.secondaryContainer,
                          foreground: e.state == EntryState.booked
                              ? scheme.onPrimaryContainer
                              : scheme.onSecondaryContainer,
                        ),
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
                    price ?? l10n.tripCompareNoPrice,
                    style: price == null
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: context.ww.ink3,
                          )
                        : theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                  ),
                  if (hasDerived)
                    TripCardRow(icon: Icons.calculate_outlined, text: derived),
                  if (hasRoute)
                    TripCardRow(icon: Icons.place_outlined, text: route),
                  TripCardRow(
                    icon: Icons.event_outlined,
                    text: tripEntryWhen(context, e),
                  ),
                  TripCardRow(
                    icon: Icons.info_outline,
                    text: details.isEmpty ? null : details,
                  ),
                  TripCardRow(
                    icon: passed
                        ? Icons.event_busy_outlined
                        : Icons.event_available_outlined,
                    text: e.cancelUntil == null
                        ? null
                        : passed
                        ? l10n.tripCompareCancelPassed
                        : l10n.tripCompareFreeCancel(
                            formatTripDate(context, e.cancelUntil!),
                          ),
                    color: passed ? scheme.error : null,
                  ),
                  TripCardRow(
                    icon: Icons.update,
                    text: e.priceCheckedOn == null || e.priceCents == null
                        ? null
                        : l10n.tripEntryPriceFrom(
                            formatTripDate(context, e.priceCheckedOn!),
                          ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onOpenLink != null)
                  IconButton(
                    tooltip: l10n.tripEntryOpenLink,
                    icon: const Icon(Icons.open_in_new),
                    onPressed: onOpenLink,
                  ),
                IconButton(
                  key: ValueKey('edit-${e.id}'),
                  tooltip: l10n.tripCompareEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
                IconButton(
                  key: ValueKey('copy-${e.id}'),
                  tooltip: l10n.tripEntryCopy,
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: onCopy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
