import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/step_up_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/pin_pad.dart';

/// Guarantees the next guardian-only call will be accepted, asking for the PIN if
/// needed. Returns false if the user is not a guardian or cancels.
///
/// The server decides in the end (`app.require_guardian`); this only avoids sending a
/// request that is certain to be refused.
Future<bool> ensureGuardian(BuildContext context, WidgetRef ref) async {
  final device = ref.read(deviceProvider).value;
  final actingId = ref.read(actingProfileProvider);
  if (device == null) return false;

  final members = await ref.read(membersProvider.future);
  if (!context.mounted) return false;
  final acting = members.where((m) => m.id == actingId).firstOrNull;
  if (acting == null || !acting.isGuardian) {
    context.showMessage(context.l10n.errGuardianRequired);
    return false;
  }
  if (device.deviceClass == DeviceClass.personal) return true;
  if (ref.read(guardianVerifiedProvider.notifier).isActive) return true;

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => PinPadDialog(guardian: acting),
  );
  return ok ?? false;
}

/// Ends the PIN step-up of this device early (specs/08 "Guardian PIN step-up"): when the
/// acting profile changes, when the wall reverts to nobody, and when the person leaves
/// the settings. The server forgets the window too (`api.guardian_step_down`), so a child
/// who taps the parent's avatar afterwards is asked for the PIN, whatever the clock says.
///
/// Nothing happens on a personal device (the PIN is never asked there) or while no window
/// is open. The call is fire-and-forget: a failed request leaves the server's own, short
/// window to run out, and the client already forgot it.
void guardianStepDown(WidgetRef ref) {
  final device = ref.read(deviceProvider).value;
  if (device == null || !device.deviceClass.isTapToSwitch) return;
  if (ref.read(guardianVerifiedProvider) == null) return;
  ref.read(guardianVerifiedProvider.notifier).set(null);
  // ignore: discarded_futures
  ref.read(stepUpRepositoryProvider).stepDown();
}

/// Steps down when the person leaves the settings area: the settings are where guardian
/// actions happen on a shared device, and the window should not outlive the visit.
///
/// Wrap it around something that stays mounted while the settings are open above it
/// (the acting profile bar on the home of a shared device or the wall). It follows the
/// router's location; without a router (a test, a preview) it does nothing.
class GuardianStepDownOnLeave extends ConsumerStatefulWidget {
  const GuardianStepDownOnLeave({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GuardianStepDownOnLeave> createState() =>
      _GuardianStepDownOnLeaveState();
}

class _GuardianStepDownOnLeaveState
    extends ConsumerState<GuardianStepDownOnLeave> {
  GoRouter? _router;
  bool _inSettings = false;

  String get _path => _router!.routerDelegate.currentConfiguration.uri.path;

  void _onRoute() {
    final now = isSettingsPath(_path);
    if (_inSettings && !now) guardianStepDown(ref);
    _inSettings = now;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.maybeOf(context);
    if (identical(router, _router)) return;
    _router?.routerDelegate.removeListener(_onRoute);
    _router = router;
    if (router == null) return;
    _inSettings = isSettingsPath(_path);
    router.routerDelegate.addListener(_onRoute);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
