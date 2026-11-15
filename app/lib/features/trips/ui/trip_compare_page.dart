import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// Comparing and combining the options of a trip (`Routes.tripComparePath`).
// placeholder: replaced by the UI build
class TripComparePage extends ConsumerWidget {
  const TripComparePage({required this.tripId, this.kind, super.key});

  final String tripId;

  /// The kind to start on (the `kind` query: `transport`, `stay` or `rental`); null: the
  /// first kind with options.
  final EntryKind? kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const Scaffold(body: SizedBox.shrink());
}
