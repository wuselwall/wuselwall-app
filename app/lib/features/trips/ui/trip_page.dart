import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One trip (`Routes.tripPath`): header, options and plan, packing, forecast.
// placeholder: replaced by the UI build
class TripPage extends ConsumerWidget {
  const TripPage({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const Scaffold(body: SizedBox.shrink());
}
