import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/features/trips/domain/combination.dart';
import 'package:wuselwall/features/trips/domain/trip_dates.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// "19. Juli – 21. Juli": the nights [range] covers, from the first night's evening to the
/// last night's morning after, so two nights from the 19th read "19 – 21".
String tripNightsText(BuildContext context, NightRange range) =>
    context.l10n.tripCompareRange(
      formatTripDate(context, range.from),
      formatTripDate(context, addDays(range.to, 1)),
    );

/// What does not fit in [combination], one plain sentence each, in the order of the
/// domain's warnings (specs/30 "Comparing and combining").
List<String> tripWarningLines(BuildContext context, Combination combination) {
  final l10n = context.l10n;
  return [
    for (final w in combination.warnings)
      switch (w) {
        UncoveredNights(:final ranges, :final nights) =>
          l10n.tripComboWarnNights(
            nights,
            ranges.map((r) => tripNightsText(context, r)).join(', '),
          ),
        RentalOutsideTransport(:final rental, :final reason) =>
          switch (reason) {
            RentalMismatch.noTransport => l10n.tripComboWarnRentalNoTransport(
              rental.title,
            ),
            RentalMismatch.startsBeforeArrival =>
              l10n.tripComboWarnRentalBefore(rental.title),
            RentalMismatch.endsAfterDeparture => l10n.tripComboWarnRentalAfter(
              rental.title,
            ),
          },
        OverlappingStays(:final first, :final second, :final shared) =>
          l10n.tripComboWarnOverlap(
            first.title,
            second.title,
            tripNightsText(context, shared),
          ),
        PriceMissing(:final entries) => l10n.tripComboWarnPrice(entries.length),
      },
  ];
}

/// "12. Juli – 21. Juli 2027 · 9 Nächte"; "Noch keine Daten" for a combination without
/// dates.
String tripCombinationDates(BuildContext context, Combination combination) {
  final l10n = context.l10n;
  final from = combination.from;
  final to = combination.to;
  if (from == null || to == null) return l10n.tripComboNoDates;
  final dates = formatTripDates(context, from, to);
  return combination.nights == 0
      ? dates
      : l10n.tripComboDates(dates, l10n.tripComboNights(combination.nights));
}

/// The total of a combination: "Total CHF 1 240" or "Mindestens CHF 1 240".
String tripCombinationTotal(
  BuildContext context,
  Combination combination,
  String currency,
) {
  final amount = formatTripMoney(context, combination.total, currency);
  return combination.incomplete
      ? context.l10n.tripComboTotalAtLeast(amount)
      : context.l10n.tripComboTotal(amount);
}

/// The combination being tried, pinned to the bottom of the comparison page: its total,
/// its dates, what does not fit, and the button that keeps it (specs/30 "Try a
/// combination"). With several warnings it shows the first and expands to all of them.
class TripCombinationBar extends StatefulWidget {
  const TripCombinationBar({
    required this.combination,
    required this.currency,
    required this.onKeep,
    super.key,
  });

  final Combination combination;
  final String currency;
  final VoidCallback onKeep;

  @override
  State<TripCombinationBar> createState() => _TripCombinationBarState();
}

class _TripCombinationBarState extends State<TripCombinationBar> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final combination = widget.combination;
    final lines = tripWarningLines(context, combination);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.36;

    final Widget status;
    if (combination.isEmpty) {
      status = Text(
        l10n.tripCompareHint,
        style: TextStyle(color: context.ww.ink2),
      );
    } else if (lines.isEmpty) {
      status = Row(
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: context.ww.success),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              l10n.tripComboFits,
              key: const ValueKey('combo-fits'),
              style: TextStyle(color: context.ww.success),
            ),
          ),
        ],
      );
    } else {
      status = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lines.length > 1)
            InkWell(
              key: const ValueKey('combo-warnings-toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.tripComboWarningsCount(lines.length),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: context.ww.warning,
                        ),
                      ),
                    ),
                    Text(
                      _expanded
                          ? l10n.tripComboShowLess
                          : l10n.tripComboShowAll,
                      style: theme.textTheme.labelLarge,
                    ),
                    Icon(_expanded ? Icons.expand_more : Icons.expand_less),
                  ],
                ),
              ),
            ),
          for (final line
              in _expanded || lines.length == 1 ? lines : lines.take(1))
            _WarningLine(line),
        ],
      );
    }

    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 6,
      child: ContentWidth(
        maxWidth: 1240,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space4,
              Tokens.space2,
              Tokens.space4,
              Tokens.space2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!combination.isEmpty)
                  Wrap(
                    spacing: Tokens.space3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        tripCombinationTotal(
                          context,
                          combination,
                          widget.currency,
                        ),
                        key: const ValueKey('combo-total'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        tripCombinationDates(context, combination),
                        key: const ValueKey('combo-dates'),
                        style: TextStyle(color: context.ww.ink2),
                      ),
                    ],
                  ),
                const SizedBox(height: Tokens.space1),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(child: status),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.icon(
                    key: const ValueKey('combo-keep'),
                    onPressed: combination.isEmpty ? null : widget.onKeep,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(l10n.tripComboKeep),
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

class _WarningLine extends StatelessWidget {
  const _WarningLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: context.ww.warning,
          ),
        ),
        const SizedBox(width: Tokens.space2),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
