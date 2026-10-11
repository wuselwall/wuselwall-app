import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/register_labels.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/enrolment_qr.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/system/ui/class_labels.dart';

/// Members and devices. Reading is open to the household; every change is a guardian
/// action and goes through [ensureGuardian] (PIN step-up on shared devices).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider);
    final devices = ref.watch(devicesProvider);
    final thisDevice = ref.watch(deviceProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: BackButton(onPressed: () => context.go(Routes.home)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          _Header(
            title: l10n.settingsMembers,
            action: IconButton(
              tooltip: l10n.addMember,
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => _addMember(context, ref),
            ),
          ),
          AsyncValueView<List<Member>>(
            value: members,
            onRetry: () => ref.invalidate(membersProvider),
            data: (list) => Column(
              children: [
                for (final m in list)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: m.color,
                      child: Text(m.initial),
                    ),
                    title: Text(m.displayName),
                    subtitle: Text(
                      m.isGuardian ? l10n.roleGuardian : l10n.roleMember,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space6),
          _Header(
            title: l10n.settingsDevices,
            action: IconButton(
              tooltip: l10n.addDevice,
              icon: const Icon(Icons.add_to_home_screen),
              onPressed: () => _addDevice(context, ref),
            ),
          ),
          AsyncValueView<List<DeviceEntry>>(
            value: devices,
            onRetry: () => ref.invalidate(devicesProvider),
            data: (list) => Column(
              children: [
                for (final d in list)
                  ListTile(
                    leading: const Icon(Icons.devices),
                    title: Text(
                      d.id == thisDevice?.deviceId
                          ? '${d.label} (${l10n.thisDevice})'
                          : d.label,
                    ),
                    subtitle: Text(
                      '${d.deviceClass.label(l10n)} · ${d.register.label(l10n)}'
                      '${d.revoked ? ' · ${l10n.deviceRevoked}' : ''}',
                    ),
                    trailing: d.revoked
                        ? null
                        : TextButton(
                            onPressed: () => _revoke(context, ref, d),
                            child: Text(l10n.revoke),
                          ),
                  ),
              ],
            ),
          ),
          if (thisDevice?.deviceClass == DeviceClass.personal) ...[
            const SizedBox(height: Tokens.space6),
            const _SecuritySection(),
          ],
          const SizedBox(height: Tokens.space6),
          OutlinedButton.icon(
            onPressed: () => thisDevice?.deviceClass == DeviceClass.personal
                ? ref.read(identityRepositoryProvider).signOutDevice()
                : ref.read(identityRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: Text(l10n.signOutDevice),
          ),
        ],
      ),
    );
  }

  String? _actor(WidgetRef ref) => ref.read(actingProfileProvider);

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final l10n = context.l10n;
    final name = await _askText(context, l10n.addMember, l10n.memberName);
    if (name == null || !context.mounted) return;

    final colors = [0xFFE57373, 0xFFFFB74D, 0xFF64B5F6, 0xFFBA68C8, 0xFF81C784];
    final taken = ref.read(membersProvider).value?.length ?? 0;
    final result = await ref
        .read(identityRepositoryProvider)
        .addMember(
          actor: _actor(ref),
          name: name,
          colorHex: toHex(Color(colors[taken % colors.length])),
        );
    if (!context.mounted) return;
    result.when(
      ok: (_) => ref.invalidate(membersProvider),
      err: context.showFailure,
    );
  }

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

Future<String?> _askText(BuildContext context, String title, String label) {
  final controller = TextEditingController();
  final l10n = context.l10n;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            controller.text.trim().isEmpty ? null : controller.text.trim(),
          ),
          child: Text(l10n.save),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      action,
    ],
  );
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

class _CodeDialog extends StatelessWidget {
  const _CodeDialog({required this.code});

  final EnrolmentCode code;

  @override
  Widget build(BuildContext context) {
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
            EnrolmentQr(key: const ValueKey('enrolment-qr'), code: code.code),
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

/// Second factor and passkeys — for the guardian's own phone.
class _SecuritySection extends ConsumerWidget {
  const _SecuritySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final factor = ref.watch(totpFactorProvider);
    final repo = ref.read(identityRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsSecurity,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        factor.when(
          loading: () => const ListTile(title: LinearProgressIndicator()),
          error: (_, _) => ListTile(title: Text(l10n.errorUnknown)),
          data: (id) => ListTile(
            leading: const Icon(Icons.security),
            title: Text(l10n.totpTitle),
            subtitle: Text(id == null ? l10n.totpOff : l10n.totpOn),
            trailing: id == null
                ? FilledButton(
                    onPressed: () => _enableTotp(context, ref),
                    child: Text(l10n.totpEnable),
                  )
                : TextButton(
                    onPressed: () async {
                      final result = await repo.totpDisable(id);
                      if (!context.mounted) return;
                      result.when(
                        ok: (_) => ref.invalidate(totpFactorProvider),
                        err: context.showFailure,
                      );
                    },
                    child: Text(l10n.totpDisable),
                  ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.pin_outlined),
          title: Text(l10n.pinChangeTitle),
          subtitle: Text(l10n.pinChangeBody),
          trailing: OutlinedButton(
            onPressed: () => _changePin(context, repo),
            child: Text(l10n.pinChangeAction),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.fingerprint),
          title: Text(l10n.passkeyTitle),
          subtitle: Text(l10n.passkeyBody),
          trailing: OutlinedButton(
            onPressed: () async {
              final result = await repo.registerPasskey(l10n.appTitle);
              if (!context.mounted) return;
              result.when(
                ok: (_) => context.showMessage(l10n.passkeyAdded),
                err: context.showFailure,
              );
            },
            child: Text(l10n.passkeyAdd),
          ),
        ),
      ],
    );
  }

  Future<void> _changePin(BuildContext context, IdentityRepository repo) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pinChangeTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: l10n.pinChangeField),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.pinChangeAction),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || !context.mounted) return;
    final result = await repo.setPin(pin: pin);
    if (!context.mounted) return;
    result.when(
      ok: (_) => context.showMessage(l10n.pinChanged),
      err: context.showFailure,
    );
  }

  Future<void> _enableTotp(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(identityRepositoryProvider);
    final enrolment = await repo.totpEnrol();
    if (!context.mounted) return;
    switch (enrolment) {
      case Err(:final failure):
        context.showFailure(failure);
      case Ok(:final value):
        final done = await showDialog<bool>(
          context: context,
          builder: (_) => _TotpEnrolDialog(enrolment: value),
        );
        if (done ?? false) ref.invalidate(totpFactorProvider);
    }
  }
}

class _TotpEnrolDialog extends ConsumerStatefulWidget {
  const _TotpEnrolDialog({required this.enrolment});

  final TotpEnrolment enrolment;

  @override
  ConsumerState<_TotpEnrolDialog> createState() => _TotpEnrolDialogState();
}

class _TotpEnrolDialogState extends ConsumerState<_TotpEnrolDialog> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final result = await ref
        .read(identityRepositoryProvider)
        .totpVerify(widget.enrolment.factorId, _code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      ok: (_) => Navigator.pop(context, true),
      err: context.showFailure,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.totpTitle),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.totpScanBody),
              const SizedBox(height: Tokens.space3),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(Tokens.space3),
                child: QrImageView(data: widget.enrolment.uri, size: 200),
              ),
              const SizedBox(height: Tokens.space3),
              SelectableText(
                widget.enrolment.secret,
                style: const TextStyle(letterSpacing: 2),
              ),
              const SizedBox(height: Tokens.space3),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(labelText: l10n.mfaCodeLabel),
                onSubmitted: (_) => _verify(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: Text(l10n.mfaVerify),
        ),
      ],
    );
  }
}
