import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/server_session.dart';
import 'package:wuselwall/app/theme/register_labels.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/notifications/notification_scheduler_provider.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/account/ui/delete_account_tile.dart';
import 'package:wuselwall/features/account/ui/mfa_reset_button.dart';
import 'package:wuselwall/features/home/application/home_tab.dart';
import 'package:wuselwall/features/household/application/household_leave_providers.dart';
import 'package:wuselwall/features/household/ui/leave_family_tiles.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/application/pairing_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/enrolment_qr.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/identity/ui/set_password_dialog.dart';
import 'package:wuselwall/features/invitations/ui/members_invitations.dart';
import 'package:wuselwall/features/settings/application/household_export_providers.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_export_repository.dart';
import 'package:wuselwall/features/settings/ui/appearance_tile.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/system/ui/class_labels.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';

/// Members and devices. Reading is open to the household; every change is a guardian
/// action and goes through [ensureGuardian] (PIN step-up on shared devices).
///
/// Basic shows what a family needs to get going; Advanced adds the rest. Hiding a row
/// changes nothing it controls.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final members = ref.watch(membersProvider);
    final devices = ref.watch(devicesProvider);
    final thisDevice = ref.watch(deviceProvider).value;
    final canApprove = ref.watch(canApprovePairingProvider);
    final advanced = ref.watch(showAdvancedSettingsProvider);
    // Reminders exist only on a personal phone that can show notifications.
    final reminders =
        thisDevice?.deviceClass == DeviceClass.personal &&
        ref.watch(notificationSchedulerProvider).available;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: BackButton(onPressed: () => context.go(Routes.home)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Tokens.space4),
        children: [
          const SettingsViewSwitch(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.householdSettingsTitle),
            subtitle: Text(l10n.householdSettingsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.householdSettings),
          ),
          if (advanced) ...[
            ListTile(
              leading: const Icon(Icons.rss_feed),
              title: Text(l10n.feedTitle),
              subtitle: Text(l10n.feedSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.feedTokens),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: Text(l10n.extCalTitle),
              subtitle: Text(l10n.extCalSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.externalCalendars),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(l10n.baselineTitle),
            subtitle: Text(l10n.baselineSettingsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.baselines),
          ),
          if (reminders)
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.reminderSettingsTitle),
              subtitle: Text(l10n.reminderSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.reminders),
            ),
          const AppearanceTile(),
          if (advanced && thisDevice?.deviceClass != DeviceClass.kiosk)
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(l10n.shortcutTitle),
              subtitle: Text(l10n.shortcutSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.shortcuts),
            ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.settingsGettingStarted),
            subtitle: Text(l10n.settingsGettingStartedSubtitle),
            onTap: () => _showGettingStarted(context, ref),
          ),
          const SizedBox(height: Tokens.space6),
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.isGuardian ? l10n.roleGuardian : l10n.roleMember,
                        ),
                        // Below the role, not beside it: at phone width a trailing
                        // action squeezes the role into a sliver (as #29 did).
                        Wrap(
                          spacing: Tokens.space1,
                          children: [
                            MfaResetButton(member: m),
                            InviteMemberButton(member: m),
                          ],
                        ),
                      ],
                    ),
                  ),
                const OpenInvitationRows(),
                const InviteAdultTile(),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space6),
          _Header(
            title: l10n.settingsDevices,
            action: canApprove
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.addDevice,
                    icon: const Icon(Icons.add_to_home_screen),
                    onPressed: () => _addDevice(context, ref),
                  ),
          ),
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
          ],
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
          if (advanced) ...[
            const _ServerSection(),
            if (thisDevice?.deviceClass == DeviceClass.personal) ...[
              const _FamilySection(),
              const SizedBox(height: Tokens.space6),
              const _SignInMethodsSection(),
              const LeaveFamilyTile(),
              const DeleteAccountTile(),
              const SizedBox(height: Tokens.space6),
              const _SecuritySection(),
            ],
          ] else ...[
            // Account deletion stays easy to find (App Store guideline 5.1.1(v)).
            if (thisDevice?.deviceClass == DeviceClass.personal)
              const DeleteAccountTile(),
            const MoreSettingsHint(),
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

  /// Brings the setup card back and shows it on the Today tab.
  Future<void> _showGettingStarted(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context);
    final repository = ref.read(gettingStartedRepositoryProvider);
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final actor = container.read(actingProfileProvider);
    if (actor == null) return;
    final result = await repository.restore(actor: actor);
    container
      ..invalidate(gettingStartedProvider)
      ..read(homeTabProvider.notifier).select(HomeTab.today);
    if (!context.mounted) return;
    if (result case Err(:final failure)) {
      context.showFailure(failure);
      return;
    }
    context.go(Routes.home);
  }

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
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
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

/// Family-wide actions. Only a guardian on their own phone sees the export (GDPR Art. 20);
/// the server refuses everyone else too.
class _FamilySection extends ConsumerStatefulWidget {
  const _FamilySection();

  @override
  ConsumerState<_FamilySection> createState() => _FamilySectionState();
}

class _FamilySectionState extends ConsumerState<_FamilySection> {
  var _exporting = false;

  bool get _canExport {
    final device = ref.watch(deviceProvider).value;
    if (device?.deviceClass != DeviceClass.personal) return false;
    final acting = ref.watch(actingProfileProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return members.any((m) => m.id == acting && m.isGuardian);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canExport) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Tokens.space6),
        Text(
          l10n.exportFamilyTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ListTile(
          key: const ValueKey('export-data'),
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.exportAction),
          subtitle: Text(l10n.exportExplanation),
          trailing: _exporting
              ? Semantics(
                  label: l10n.exportInProgress,
                  child: const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          onTap: _exporting ? null : _export,
        ),
        const DeleteFamilyTile(),
      ],
    );
  }

  Future<void> _export() async {
    if (!await ensureGuardian(context, ref) || !mounted) return;
    // Read before the first await: the share sheet is anchored to this tile on iPad.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final actor = ref.read(actingProfileProvider);

    setState(() => _exporting = true);
    try {
      final result = await ref
          .read(householdExportRepositoryProvider)
          .export(actor: actor);
      if (!mounted) return;
      switch (result) {
        case Err(:final failure):
          context.showFailure(failure);
        case Ok(:final value):
          final shared = await Result.guard(
            () => ref.read(shareExportProvider)(
              fileName: householdExportFileName(
                DateTime.now(),
                value.extension,
              ),
              bytes: value.bytes,
              mimeType: value.mimeType,
              origin: origin,
            ),
          );
          if (!mounted) return;
          shared.when(ok: (_) {}, err: context.showFailure);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

/// How this account signs in (specs/20, "Several ways into one account") — for the
/// adult's own phone: the email code, always, and an optional password.
class _SignInMethodsSection extends ConsumerStatefulWidget {
  const _SignInMethodsSection();

  @override
  ConsumerState<_SignInMethodsSection> createState() =>
      _SignInMethodsSectionState();
}

class _SignInMethodsSectionState extends ConsumerState<_SignInMethodsSection> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = ref.watch(myAccountProvider).value?.email;
    final hasPassword = ref.read(identityRepositoryProvider).hasPassword();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.signInMethodsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ListTile(
          leading: const Icon(Icons.mail_outline),
          title: Text(l10n.signInMethodEmail),
          // The e-mail code is always there for an account with an address.
          subtitle: Text(
            email == null
                ? l10n.signInMethodAlwaysAvailable
                : l10n.signInMethodEmailSubtitle(email),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.settingsPasswordTitle),
          subtitle: Text(
            hasPassword
                ? l10n.settingsPasswordSet
                : l10n.settingsPasswordNotSet,
          ),
          trailing: OutlinedButton(
            onPressed: _setPassword,
            child: Text(
              hasPassword ? l10n.passwordChangeAction : l10n.passwordSetAction,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setPassword() async {
    final saved = await showSetPasswordDialog(context);
    if (!saved || !mounted) return;
    setState(() {});
    context.showMessage(context.l10n.passwordSaved);
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
        // Not on the web until the passkeys SDK is self-hosted (web/index.html), and
        // only in a build that names its own server (ADR-018).
        if (!kIsWeb && ref.watch(appConfigProvider).passkeys)
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
              QrCodeView(
                data: widget.enrolment.uri,
                semanticsLabel: l10n.totpQrLabel,
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

/// The server this app talks to (ADR-018): its address and QR code, so another device
/// joins it with one scan, and the way to another server. Only for a store build, which
/// chose its server; a development build names its own.
class _ServerSection extends ConsumerWidget {
  const _ServerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(serverSessionProvider);
    if (config.server == null) return const SizedBox.shrink();
    final server = Uri.parse(config.supabaseUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Tokens.space6),
        Text(
          l10n.settingsServer,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: SelectableText(displayServerAddress(server)),
          subtitle: Text(l10n.settingsServerBody(displayServerAddress(server))),
        ),
        Center(
          child: QrCodeView(
            key: const ValueKey('server-qr'),
            data: serverQrPayload(server),
            semanticsLabel: l10n.settingsServer,
          ),
        ),
        if (session.leave != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _switch(context, ref, session),
              icon: const Icon(Icons.swap_horiz),
              label: Text(l10n.settingsServerSwitch),
            ),
          ),
      ],
    );
  }

  /// Leaving a server empties the device: its outbox belongs to that server's household.
  /// A guardian decision, so a child cannot move the family tablet elsewhere.
  Future<void> _switch(
    BuildContext context,
    WidgetRef ref,
    ServerSession session,
  ) async {
    final l10n = context.l10n;
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsServerSwitch),
        content: Text(l10n.settingsServerSwitchConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.settingsServerSwitch),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final identity = ref.read(identityRepositoryProvider);
    final personal =
        ref.read(deviceProvider).value?.deviceClass == DeviceClass.personal;
    await ref.read(shoppingStoreProvider).clear();
    // Like "Sign out": a personal phone also gives up its device record.
    await (personal ? identity.signOutDevice() : identity.signOut());
    await session.leave?.call();
  }
}
