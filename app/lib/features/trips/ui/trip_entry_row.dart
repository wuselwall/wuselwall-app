import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/domain/trip_plan.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';
import 'package:wuselwall/features/trips/ui/trip_links.dart';

/// The word for how an entry shows on a day of the plan: check-in, pick-up, departure and
/// so on; null for an entry that is only there that day or runs through it.
String? tripRoleWord(AppLocalizations l10n, TripEntry entry, PlanRole role) =>
    switch (role) {
      PlanRole.start => switch (entry.kind) {
        EntryKind.stay => l10n.tripPlanRoleCheckIn,
        EntryKind.rental => l10n.tripPlanRolePickUp,
        EntryKind.transport => l10n.tripPlanRoleDeparture,
        _ => l10n.tripPlanRoleStart,
      },
      PlanRole.end => switch (entry.kind) {
        EntryKind.stay => l10n.tripPlanRoleCheckOut,
        EntryKind.rental => l10n.tripPlanRoleReturn,
        EntryKind.transport => l10n.tripPlanRoleArrival,
        _ => l10n.tripPlanRoleEnd,
      },
      PlanRole.single || PlanRole.during => null,
    };

/// A small pill with the entry's state; an option is quiet, a booking is the strongest.
class EntryStateChip extends StatelessWidget {
  const EntryStateChip(this.state, {super.key});

  final EntryState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (state) {
      EntryState.option => (context.ww.sunken, context.ww.ink2),
      EntryState.chosen => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      EntryState.booked => (scheme.primaryContainer, scheme.onPrimaryContainer),
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
          context.entryState(state),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

/// One entry of a trip: its icon, title, what is known about it, its price, its state and
/// small ways to open its link, phone number and address in the phone's own apps.
class TripEntryRow extends StatelessWidget {
  const TripEntryRow({
    required this.entry,
    required this.currency,
    required this.onTap,
    this.role,
    this.showChecked = false,
    super.key,
  });

  final TripEntry entry;
  final String currency;
  final VoidCallback onTap;

  /// How it shows on the plan day this row stands in; null outside the days.
  final PlanRole? role;

  /// Say when the price was entered ("Preis vom 12.11."), as the options do.
  final bool showChecked;

  Future<void> _open(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final opened = await action();
    if (!opened && context.mounted) {
      context.showMessage(context.l10n.tripPlanOpenFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = TextStyle(color: context.ww.ink2);

    final times = switch (role) {
      PlanRole.single => [entry.startsTime, entry.endsTime],
      PlanRole.start => [entry.startsTime],
      PlanRole.end => [entry.endsTime],
      _ => const <TimeOfDay?>[],
    };
    final clock = [
      for (final t in times)
        if (t != null) formatTripTime(context, t),
    ].join('–');
    final word = role == null ? null : tripRoleWord(l10n, entry, role!);
    final lead = [?word, if (clock.isNotEmpty) clock].join(' · ');

    final route = [
      for (final p in [entry.fromPlace, entry.toPlace])
        if (p?.isNotEmpty ?? false) p!,
    ].join(' – ');
    final details = entry.details?.trim() ?? '';
    final price = entry.priceCents == null
        ? null
        : [
            formatTripMoney(context, entry.priceCents!, currency),
            if (showChecked && entry.priceCheckedOn != null)
              l10n.tripPlanPriceChecked(
                formatTripDate(context, entry.priceCheckedOn!),
              ),
          ].join(' · ');
    final ref = entry.bookingRef?.trim() ?? '';

    final url = entry.url?.trim() ?? '';
    final phone = entry.phone?.trim() ?? '';
    final address = entry.address?.trim() ?? '';
    final hasPlace =
        address.isNotEmpty || (entry.lat != null && entry.lon != null);

    return InkWell(
      key: ValueKey('trip-entry-${entry.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space3,
          vertical: Tokens.space2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Tokens.space1),
              child: Icon(entryIcon(entry), color: theme.colorScheme.primary),
            ),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lead.isNotEmpty)
                    Text(
                      lead,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  Text(entry.title, style: theme.textTheme.titleSmall),
                  if (route.isNotEmpty) Text(route, style: muted),
                  if (details.isNotEmpty) Text(details, style: muted),
                  if (price != null)
                    Text(price, style: theme.textTheme.bodyMedium),
                  if (ref.isNotEmpty)
                    Text(l10n.tripPlanBookingRef(ref), style: muted),
                  if (url.isNotEmpty || phone.isNotEmpty || hasPlace)
                    Wrap(
                      children: [
                        if (url.isNotEmpty)
                          IconButton(
                            tooltip: l10n.tripPlanOpenLink,
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () =>
                                _open(context, () => openTripLink(url)),
                          ),
                        if (phone.isNotEmpty)
                          IconButton(
                            tooltip: l10n.tripPlanCall,
                            icon: const Icon(Icons.call_outlined),
                            onPressed: () =>
                                _open(context, () => callTripPhone(phone)),
                          ),
                        if (hasPlace)
                          IconButton(
                            tooltip: l10n.tripPlanOpenMap,
                            icon: const Icon(Icons.map_outlined),
                            onPressed: () => _open(
                              context,
                              () => openTripPlace(
                                address: address,
                                lat: entry.lat,
                                lon: entry.lon,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: Tokens.space2),
            EntryStateChip(entry.state),
          ],
        ),
      ),
    );
  }
}
