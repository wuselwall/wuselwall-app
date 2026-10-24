import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/wusel/wusel.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/wusel/ui/family_wusel.dart';

/// Wusel peeking over an empty state (specs/25): small on a phone, larger where
/// children and the wall look. A quiet Wusel still shows here, held still.
class EmptyWusel extends ConsumerWidget {
  const EmptyWusel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = switch (ref.watch(uiRegisterProvider)) {
      UiRegister.adult => 72.0,
      UiRegister.kid || UiRegister.kiosk => 112.0,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space2),
      child: FamilyWusel(pose: WuselPose.peek, size: size, quietAllowed: true),
    );
  }
}
