import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// The combination being tried on the comparison page (specs/30 "Comparing and
/// combining"): the ticked entries of one trip and the stored combination they were loaded
/// from. Pure page state: nothing is written while ticking.
class TripCompareState {
  const TripCompareState({this.ticks, this.loadedComboId});

  /// The ticked entry ids; null while nobody has touched a tick, which means the entries
  /// that are chosen or booked ([defaultTicks]).
  final Set<String>? ticks;

  /// The stored combination the ticks were loaded from, so keeping them again under the
  /// same name updates it.
  final String? loadedComboId;
}

/// The entries ticked before anyone ticks anything: the ones in the plan (chosen or booked).
Set<String> defaultTicks(Iterable<TripEntry> entries) => {
  for (final e in entries)
    if (e.state.inPlan && e.kind != EntryKind.note) e.id,
};

/// The ticks of one trip's comparison page. The page passes the ticks it shows, because the
/// default ones depend on the entries, which load asynchronously.
class TripCompareNotifier extends Notifier<TripCompareState> {
  TripCompareNotifier(this.tripId);

  final String tripId;

  @override
  TripCompareState build() => const TripCompareState();

  /// Ticks or unticks [id], starting from [current] (what the page shows).
  void toggle(String id, Set<String> current) {
    final next = {...current};
    if (!next.remove(id)) next.add(id);
    state = TripCompareState(ticks: next, loadedComboId: state.loadedComboId);
  }

  /// Replaces the ticks with the entries of a stored combination.
  void load(String comboId, Iterable<String> entryIds) {
    state = TripCompareState(ticks: {...entryIds}, loadedComboId: comboId);
  }

  /// After keeping the ticks as [comboId], so a further change updates that one.
  void kept(String comboId) {
    state = TripCompareState(ticks: state.ticks, loadedComboId: comboId);
  }

  /// Back to the default ticks (the chosen and booked entries).
  void reset() => state = const TripCompareState();
}

final tripCompareProvider = NotifierProvider.autoDispose
    .family<TripCompareNotifier, TripCompareState, String>(
      TripCompareNotifier.new,
    );
