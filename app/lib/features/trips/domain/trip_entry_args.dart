import 'package:flutter/foundation.dart' show immutable;
import 'package:uuid/uuid.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// What the entry page (`Routes.tripEntryPath`, `GoRouterState.extra`) opens: an entry to
/// change, or a seed for a new one. Without it (a restored route) the page makes a plain
/// activity seed itself.
@immutable
class TripEntryArgs {
  /// Opens [entry], which exists on the server.
  const TripEntryArgs.edit(this.entry) : isNew = false;

  /// Opens [seed] as a new entry: its id is the one the first save will use.
  const TripEntryArgs.create(TripEntry seed) : entry = seed, isNew = true;

  /// A new entry of [kind] for [tripId] with a fresh id, in state `option`; the seed may
  /// carry a first [title], a pasted [url] or a [price] in cents.
  factory TripEntryArgs.seed(
    String tripId,
    EntryKind kind, {
    TransportMode? mode,
    String title = '',
    String? url,
    int? priceCents,
    EntryState state = EntryState.option,
  }) => TripEntryArgs.create(
    TripEntry(
      id: const Uuid().v4(),
      tripId: tripId,
      kind: kind,
      mode: kind == EntryKind.transport ? mode ?? TransportMode.flight : null,
      title: title,
      state: state,
      url: url,
      priceCents: priceCents,
    ),
  );

  final TripEntry entry;

  /// True for a seed that has not been saved.
  final bool isNew;
}
