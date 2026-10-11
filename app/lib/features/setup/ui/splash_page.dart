import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// Shown while the device record is read, and when that fails (for example offline).
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(sessionStateProvider);
    return Scaffold(
      body: device.hasError
          ? ErrorView(
              error: device.error!,
              onRetry: () => ref.invalidate(sessionStateProvider),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
