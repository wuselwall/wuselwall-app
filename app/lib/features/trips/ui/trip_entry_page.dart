import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/trips/domain/trip_entry_args.dart';

/// Adding or changing one entry of a trip (`Routes.tripEntryPath`).
// placeholder: replaced by the UI build
class TripEntryPage extends ConsumerWidget {
  const TripEntryPage({required this.tripId, this.args, super.key});

  final String tripId;

  /// The entry to change or the seed of a new one (the route's `extra`); null for a
  /// restored route.
  final TripEntryArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const Scaffold(body: SizedBox.shrink());
}
