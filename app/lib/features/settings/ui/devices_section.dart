import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/register_labels.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/ui/text_prompt.dart';
import 'package:wuselwall/features/calendar/ui/external_calendar_text.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/enrolment_qr.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/ui/action_tile.dart';
import 'package:wuselwall/features/system/ui/class_labels.dart';

/// All devices of the family (Geräte → Alle Geräte): connect another one, rename or
/// revoke the others. Every change is a guardian action.
class DevicesSection extends ConsumerWidget {
  const DevicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devices = ref.watch(devicesProvider);
    final thisDevice = ref.watch(deviceProvider).value;
    final canApprove = ref.watch(canApprovePairingProvider);
    final advanced = ref.watch(showAdvancedSettingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // J3: the new device shows the code, this phone approves it. The code the old
        // way stays for one release, for devices on an older app.
        if (canApprove) ...[
          FilledButton.icon(
            key: const ValueKey('connect-device'),
            onPressed: () => context.push<void>(Routes.devicePair),
            icon: const Icon(Icons.add_to_home_screen),
            label: Text(l10n.pairConnectAction),
          ),
          if (advanced)
            TextButton(
              onPressed: () => _addDevice(context, ref),
              child: Text(l10n.pairOldCodeAction),
            ),
          const SizedBox(height: Tokens.space2),
        ] else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _addDevice(context, ref),
              icon: const Icon(Icons.add_to_home_screen),
              label: Text(l10n.addDevice),
            ),
          ),
        AsyncValueView<List<DeviceEntry>>(
          value: devices,
          onRetry: () => ref.invalidate(devicesProvider),
          data: (list) => Column(
            children: [
              for (final d in list)
                _DeviceTile(
                  key: ValueKey('device-${d.id}'),
                  device: d,
                  isThis: d.id == thisDevice?.deviceId,
                  onRename: () => _renameDevice(context, ref, d),
                  onRevoke: () => _revoke(context, ref, d),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String? _actor(WidgetRef ref) => ref.read(actingProfileProvider);

  Future<void> _addDevice(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final spec = await showDialog<_NewDevice>(
      context: context,
      builder: (_) => const _NewDeviceDialog(),
    );
    if (spec == null || !context.mounted) return;

    final result = await ref
        .read(identityRepositoryProvider)
        .createEnrolmentCode(
          actor: _actor(ref),
          label: spec.label,
          deviceClass: spec.deviceClass,
          register: spec.register,
        );
    if (!context.mounted) return;
    switch (result) {
      case Ok(:final value):
        await showDialog<void>(
          context: context,
          builder: (_) => _CodeDialog(code: value),
        );
        ref.invalidate(devicesProvider);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  /// A guardian names any device; a device may rename itself without the PIN.
  Future<void> _renameDevice(
    BuildContext context,
    WidgetRef ref,
    DeviceEntry d,
  ) async {
    final isThis = d.id == ref.read(deviceProvider).value?.deviceId;
    if (!isThis && (!await ensureGuardian(context, ref) || !context.mounted)) {
      return;
    }
    final l10n = context.l10n;
    final label = await askText(
      context,
      title: l10n.deviceRename,
      label: l10n.deviceLabel,
      initial: d.label,
      maxLength: 60,
    );
    if (label == null || label == d.label || !context.mounted) return;
    final result = await ref
        .read(identityRepositoryProvider)
        .renameDevice(actor: _actor(ref), deviceId: d.id, label: label);
    if (!context.mounted) return;
    result.when(
      ok: (_) => ref
        ..invalidate(devicesProvider)
        ..invalidate(deviceProvider),
      err: context.showFailure,
    );
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    DeviceEntry d,
  ) async {
    final l10n = context.l10n;
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.revokeConfirm(d.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.revoke),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final result = await ref
        .read(identityRepositoryProvider)
        .revokeDevice(actor: _actor(ref), deviceId: d.id);
    if (!context.mounted) return;
    result.when(
      ok: (_) => ref.invalidate(devicesProvider),
      err: context.showFailure,
    );
  }
}

class _NewDevice {
  const _NewDevice(this.label, this.deviceClass, this.register);
  final String label;
  final DeviceClass deviceClass;
  final UiRegister register;
}

class _NewDeviceDialog extends StatefulWidget {
  const _NewDeviceDialog();

  @override
  State<_NewDeviceDialog> createState() => _NewDeviceDialogState();
}

class _NewDeviceDialogState extends State<_NewDeviceDialog> {
  final _label = TextEditingController();
  var _class = DeviceClass.shared;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addDevice),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.deviceLabel),
          ),
          const SizedBox(height: Tokens.space4),
          SegmentedButton<DeviceClass>(
            segments: [
              ButtonSegment(
                value: DeviceClass.shared,
                label: Text(DeviceClass.shared.label(l10n)),
              ),
              ButtonSegment(
                value: DeviceClass.kiosk,
                label: Text(DeviceClass.kiosk.label(l10n)),
              ),
            ],
            selected: {_class},
            onSelectionChanged: (s) => setState(() => _class = s.first),
          ),
          if (_class == DeviceClass.shared) ...[
            const SizedBox(height: Tokens.space2),
            Text(
              l10n.classSharedHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final label = _label.text.trim();
            if (label.isEmpty) return;
            // Shared devices are the children's: kid register. Kiosk is the wall.
            Navigator.pop(
              context,
              _NewDevice(
                label,
                _class,
                _class == DeviceClass.kiosk ? UiRegister.kiosk : UiRegister.kid,
              ),
            );
          },
          child: Text(l10n.createCode),
        ),
      ],
    );
  }
}

class _CodeDialog extends ConsumerWidget {
  const _CodeDialog({required this.code});

  final EnrolmentCode code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.enrolmentCodeTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // One line whatever the width: a code broken over two lines gets misread.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                code.code,
                key: const ValueKey('enrolment-code'),
                maxLines: 1,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  letterSpacing: 6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: Tokens.space4),
            EnrolmentQr(
              key: const ValueKey('enrolment-qr'),
              code: code.code,
              server: ref.watch(appConfigProvider).supabaseUrl,
            ),
            const SizedBox(height: Tokens.space3),
            Text(l10n.enrolmentCodeHint),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// One device: tap to rename, "Sperren" to revoke. "zuletzt aktiv vor 3 Tagen" makes
/// the revoke of J4 an informed choice.
class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({
    required this.device,
    required this.isThis,
    required this.onRename,
    required this.onRevoke,
    super.key,
  });

  final DeviceEntry device;
  final bool isThis;
  final VoidCallback onRename;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = device;
    final seen = d.lastSeenAt;
    final lastSeen = d.revoked
        ? l10n.deviceRevoked
        : seen == null
        ? l10n.deviceNeverSeen
        : l10n.deviceLastSeen(agoText(l10n, seen, DateTime.now()));
    final kind = d.deviceClass.label(l10n);
    final register = d.register.label(l10n);
    final scheme = Theme.of(context).colorScheme;
    return SettingsActionTile(
      leading: Icon(switch (d.deviceClass) {
        DeviceClass.personal => Icons.smartphone,
        DeviceClass.shared => Icons.tablet_android,
        DeviceClass.kiosk => Icons.tv,
      }),
      title: Text(isThis ? '${d.label} (${l10n.thisDevice})' : d.label),
      // A wall is a "Wandanzeige" twice over (class and register): say it once.
      subtitle: Text(
        '${kind == register ? kind : '$kind · $register'}\n$lastSeen',
      ),
      // Revoking is a row action like "Passwort ändern", outlined in the error colour,
      // not a link.
      action: d.revoked
          ? null
          : OutlinedButton(
              key: ValueKey('revoke-${d.id}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
              ),
              onPressed: onRevoke,
              child: Text(l10n.revoke),
            ),
      onTap: d.revoked ? null : onRename,
    );
  }
}
