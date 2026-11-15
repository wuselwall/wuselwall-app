import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wohin? (`Routes.tripDiscover`): where it is warm and dry in a window.
// placeholder: replaced by the UI build
class TripDiscoverPage extends ConsumerWidget {
  const TripDiscoverPage({this.range, super.key});

  /// The window to look at (the route's `extra`); null: the page asks.
  final DateTimeRange? range;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const Scaffold(body: SizedBox.shrink());
}
