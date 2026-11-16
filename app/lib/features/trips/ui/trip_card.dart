import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// "Tag 3 von 10" while the trip runs, "in 12 Tagen" before it; null for a trip without
/// dates and after it.
String? tripWhenText(AppLocalizations l10n, Trip trip, DateTime today) {
  final day = trip.dayNumber(today);
  if (day != null) return l10n.tripListDayOf(day, trip.days);
  final until = trip.daysUntil(today);
  if (until == null || until < 0) return null;
  return l10n.tripListInDays(until);
}

/// The trip's picture, the way an event shows its icon; a suitcase when it has none.
class TripPicture extends StatelessWidget {
  const TripPicture(this.iconKey, {this.size = 44, super.key});

  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = eventIconAsset(iconKey);
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: asset != null
            ? EmojiPicture(asset, size: size * 0.9)
            : Icon(
                Icons.luggage_outlined,
                size: size * 0.7,
                color: context.ww.ink2,
              ),
      ),
    );
  }
}

/// A small pill with the stage: an idea is quiet, a planned trip is pencilled, a fixed one
/// is decided. Colour and the word both say it.
class TripStageChip extends StatelessWidget {
  const TripStageChip(this.stage, {super.key});

  final TripStage stage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (stage) {
      TripStage.idea => (context.ww.sunken, context.ww.ink2),
      TripStage.planned => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      TripStage.fixed => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space2,
          vertical: Tokens.space1,
        ),
        child: Text(
          context.tripStage(stage),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

/// One trip of the list: picture, name, destination, dates, stage and how near it is.
class TripCard extends StatelessWidget {
  const TripCard({
    required this.trip,
    required this.today,
    required this.onTap,
    super.key,
  });

  final Trip trip;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final destination = trip.destinationName?.trim() ?? '';
    final when = tripWhenText(l10n, trip, today);
    final dates = trip.hasDates
        ? formatTripDates(context, trip.startsOn!, trip.endsOn!)
        : l10n.tripListNoDates;
    return Card(
      key: ValueKey('trip-card-${trip.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TripPicture(trip.iconKey),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.title, style: theme.textTheme.titleMedium),
                    if (destination.isNotEmpty)
                      Text(
                        destination,
                        style: TextStyle(color: context.ww.ink2),
                      ),
                    Text(dates, style: TextStyle(color: context.ww.ink2)),
                    const SizedBox(height: Tokens.space2),
                    Wrap(
                      spacing: Tokens.space2,
                      runSpacing: Tokens.space1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TripStageChip(trip.stage),
                        if (when != null)
                          Text(when, style: theme.textTheme.labelLarge),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.ww.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
