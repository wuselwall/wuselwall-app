import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/calendar/application/event_share_providers.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';
import 'package:wuselwall/features/trips/application/trip_actions.dart';
import 'package:wuselwall/features/trips/application/trip_providers.dart';
import 'package:wuselwall/features/trips/domain/trip_import.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// What the sheet reports when entries were added.
typedef TripImported = ({String tripId, EntriesImported done});

/// "Zur Reise hinzufügen" (specs/30 "A booking's calendar file"): choose one of the
/// upcoming trips, see what the file's events would become, and add them. Opens the trip
/// afterwards, with a line saying how many were added and updated.
///
/// Returns true when the entries were added (the caller is then on the trip's page).
Future<bool> addCalendarFileToTrip(
  BuildContext context,
  Uint8List bytes,
) async {
  final result = await showModalBottomSheet<TripImported>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TripImportSheet(bytes: bytes),
  );
  if (result == null || !context.mounted) return false;
  context.showMessage(
    context.l10n.tripImportDone(result.done.added, result.done.updated),
  );
  context.pushReplacement(Routes.tripPath(result.tripId));
  return true;
}

/// The sheet itself; see [addCalendarFileToTrip].
class TripImportSheet extends ConsumerStatefulWidget {
  const TripImportSheet({required this.bytes, super.key});

  final Uint8List bytes;

  @override
  ConsumerState<TripImportSheet> createState() => _TripImportSheetState();
}

class _TripImportSheetState extends ConsumerState<TripImportSheet> {
  Trip? _trip;
  TripFileImport? _import;
  bool _busy = false;

  void _choose(Trip trip) {
    final l10n = context.l10n;
    setState(() {
      _trip = trip;
      _import = tripEntriesFromCalendarFile(
        widget.bytes,
        tripId: trip.id,
        zoneOf: eventZone,
        fallbackTitle: l10n.tripImportFallbackTitle,
      );
    });
  }

  Future<void> _add() async {
    final trip = _trip;
    final file = _import;
    if (trip == null || file == null || file.entries.isEmpty || _busy) return;
    setState(() => _busy = true);
    final result = await ref
        .read(tripActionsProvider)
        .importEntries(trip.id, file.entries);
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop<TripImported>((tripId: trip.id, done: value));
      case Err(:final failure):
        setState(() => _busy = false);
        context.showFailure(failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trips = ref.watch(upcomingTripsProvider);
    // One trip to choose from needs no choosing.
    if (_trip == null && trips.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _trip == null) _choose(trips.single);
      });
    }
    final trip = _trip;
    final file = _import;
    return Padding(
      padding: EdgeInsets.only(
        left: Tokens.space4,
        right: Tokens.space4,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Tokens.space4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            trip == null ? l10n.tripImportTitle : trip.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Tokens.space2),
          if (trip == null || file == null) ...[
            Text(l10n.tripImportIntro),
            const SizedBox(height: Tokens.space2),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in trips)
                    _TripTile(trip: t, onTap: () => _choose(t)),
                ],
              ),
            ),
          ] else
            ..._preview(context, trips.length > 1, file),
        ],
      ),
    );
  }

  List<Widget> _preview(
    BuildContext context,
    bool canChooseAgain,
    TripFileImport file,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return [
      Text(
        file.entries.isEmpty
            ? l10n.tripImportNothing
            : l10n.tripImportEntries(file.entries.length),
      ),
      const SizedBox(height: Tokens.space2),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in file.entries) _EntryTile(entry: e),
            if (file.skipped > 0)
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space2),
                child: Text(
                  l10n.tripImportSkipped(file.skipped),
                  key: const ValueKey('trip-import-skipped'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: Tokens.space3),
      OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: Tokens.space2,
        overflowSpacing: Tokens.space1,
        children: [
          TextButton(
            onPressed: _busy
                ? null
                : canChooseAgain
                ? () => setState(() {
                    _trip = null;
                    _import = null;
                  })
                : () => Navigator.of(context).pop(),
            child: Text(canChooseAgain ? l10n.tripImportTitle : l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('trip-import-confirm'),
            onPressed: _busy || file.entries.isEmpty ? null : _add,
            child: Text(l10n.tripImportConfirm),
          ),
        ],
      ),
    ];
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip, required this.onTap});

  final Trip trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = eventIconAsset(trip.iconKey);
    return ListTile(
      key: ValueKey('trip-import-${trip.id}'),
      contentPadding: EdgeInsets.zero,
      leading: asset != null
          ? EmojiPicture(asset, size: 32)
          : const Icon(Icons.luggage_outlined),
      title: Text(trip.title),
      subtitle: Text(formatTripDates(context, trip.startsOn!, trip.endsOn!)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// One entry the file would add: its picture of the kind, title, day and time, and the
/// kind it was taken for.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final TripEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final day = entry.startsOn;
    final time = entry.startsTime;
    final kind = entry.mode != null && entry.kind == EntryKind.transport
        ? transportModeLabel(l10n, entry.mode!)
        : entryKindLabel(l10n, entry.kind);
    final when = [
      if (day != null) formatTripDay(context, day),
      if (time != null) formatTripTime(context, time),
    ].join(', ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(entryIcon(entry)),
      title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(when.isEmpty ? kind : '$when · $kind'),
    );
  }
}
