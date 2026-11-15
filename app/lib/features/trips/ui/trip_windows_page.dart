import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Zeitfenster (`Routes.tripWindows`): when the family could travel.
// placeholder: replaced by the UI build
class TripWindowsPage extends ConsumerWidget {
  const TripWindowsPage({this.tripId, super.key});

  /// The idea a chosen window is for (the `trip` query); null: a window to start a new
  /// trip from.
  final String? tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const Scaffold(body: SizedBox.shrink());
}
