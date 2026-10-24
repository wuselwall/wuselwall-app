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
import 'package:wuselwall/core/server/server_compat.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/core/ui/text_prompt.dart';
import 'package:wuselwall/features/account/ui/delete_account_tile.dart';
import 'package:wuselwall/features/account/ui/mfa_reset_button.dart';
import 'package:wuselwall/features/calendar/ui/external_calendar_text.dart';
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
import 'package:wuselwall/features/identity/ui/member_circle.dart';
import 'package:wuselwall/features/identity/ui/set_password_dialog.dart';
import 'package:wuselwall/features/invitations/ui/members_invitations.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/ui/appearance_tile.dart';
import 'package:wuselwall/features/settings/ui/language_tile.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/system/ui/class_labels.dart';
import 'package:wuselwall/features/today/application/today_providers.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';

/// Einstellungen: the family (its settings, its name, the usual week, members and
/// devices), then this device, then under Advanced the connections, the server and the
/// account. Reading is open to the household; every change is a guardian action and goes
/// through [ensureGuardian] (PIN step-up on shared devices).
///
/// Basic shows what a family needs to get going; Advanced adds the rest. Hiding a row
/// changes nothing it controls.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
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
        actions: const [SettingsViewSwitch()],
      ),
      // One scrollable: the member rows are a sliver reorderable list in the middle, so
      // dragging works without a nested list of its own.
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space4,
              Tokens.space4,
              Tokens.space4,
              0,
            ),
            sliver: SliverList.list(
              children: [
                _Header(
                  title: l10n.settingsSectionFamily,
                  action: const SizedBox.shrink(),
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(l10n.householdSettingsTitle),
                  subtitle: Text(l10n.householdSettingsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.householdSettings),
                ),
                ListTile(
                  key: const ValueKey('settings-family'),
                  leading: const Icon(Icons.family_restroom_outlined),
                  title: Text(l10n.familyTitle),
                  subtitle: Text(l10n.familySettingsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.family),
                ),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: Text(l10n.baselineTitle),
                  subtitle: Text(l10n.baselineSettingsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.baselines),
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
                Text(
                  l10n.settingsMembersHint,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            sliver: _MembersList(),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space4,
              0,
              Tokens.space4,
              Tokens.space4,
            ),
            sliver: SliverList.list(
              children: [
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
                const SizedBox(height: Tokens.space6),
                _Header(
                  title: l10n.settingsSectionThisDevice,
                  action: const SizedBox.shrink(),
                ),
                if (reminders)
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text(l10n.reminderSettingsTitle),
                    subtitle: Text(l10n.reminderSettingsSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(Routes.reminders),
                  ),
                const LanguageTile(),
                const AppearanceTile(),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l10n.settingsGettingStarted),
                  subtitle: Text(l10n.settingsGettingStartedSubtitle),
                  onTap: () => _showGettingStarted(context, ref),
                ),
                const _VersionsTile(),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(l10n.settingsLicenses),
                  subtitle: Text(l10n.settingsLicensesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'WuselWall',
                    applicationLegalese:
                        'Copyright 2026 Daniel Huser and the WuselWall contributors.\n'
                        'Licensed under the Apache License, Version 2.0.',
                  ),
                ),
                if (advanced) ...[
                  const SizedBox(height: Tokens.space6),
                  _Header(
                    title: l10n.settingsSectionConnect,
                    action: const SizedBox.shrink(),
                  ),
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
                  if (thisDevice?.deviceClass != DeviceClass.kiosk)
                    ListTile(
                      leading: const Icon(Icons.hub_outlined),
                      title: Text(l10n.shortcutTitle),
                      subtitle: Text(l10n.shortcutSettingsSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(Routes.shortcuts),
                    ),
                  const _ServerSection(),
                  if (thisDevice?.deviceClass == DeviceClass.personal) ...[
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
                  onPressed: () =>
                      thisDevice?.deviceClass == DeviceClass.personal
                      ? ref.read(identityRepositoryProvider).signOutDevice()
                      : ref.read(identityRepositoryProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.signOutDevice),
                ),
              ],
            ),
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
    final name = await askText(
      context,
      title: l10n.addMember,
      label: l10n.memberName,
    );
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
      ok: (_) => ref
        ..invalidate(membersProvider)
        ..invalidate(allMembersProvider),
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

/// The people of the family, in the board's order, each a row that opens the member
/// page. Guardians drag the handle to reorder; the server keeps the new order for every
/// screen. People who are no longer with the family sit at the end, greyed. A sliver, so
/// the settings page stays one scrollable.
class _MembersList extends ConsumerStatefulWidget {
  const _MembersList();

  @override
  ConsumerState<_MembersList> createState() => _MembersListState();
}

class _MembersListState extends ConsumerState<_MembersList> {
  /// The order on screen while a drag's write is in flight.
  List<Member>? _dragged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final members = ref.watch(allMembersProvider);
    final acting = ref.watch(actingProfileProvider);
    final list = members.value;
    if (list == null) {
      return SliverToBoxAdapter(
        child: AsyncValueView<List<Member>>(
          value: members,
          onRetry: () => ref.invalidate(allMembersProvider),
          data: (_) => const SizedBox.shrink(),
        ),
      );
    }
    final active = _dragged ?? list.where((m) => m.active).toList();
    final retired = list.where((m) => !m.active).toList();
    final isGuardian = list.any((m) => m.id == acting && m.isGuardian);
    return SliverMainAxisGroup(
      slivers: [
        SliverReorderableList(
          key: const ValueKey('members-list'),
          itemCount: active.length,
          onReorderItem: (from, to) => _reorder(active, from, to),
          // The row in flight is drawn in the overlay: give it the Material its tile needs.
          proxyDecorator: (child, _, _) => Material(elevation: 2, child: child),
          itemBuilder: (context, i) {
            final m = active[i];
            return _MemberTile(
              key: ValueKey('member-${m.id}'),
              member: m,
              handle: isGuardian && active.length > 1
                  ? ReorderableDragStartListener(
                      index: i,
                      child: Tooltip(
                        message: l10n.memberReorderHandle,
                        child: const Padding(
                          padding: EdgeInsets.all(Tokens.space2),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    )
                  : null,
            );
          },
        ),
        SliverList.list(
          children: [
            for (final m in retired)
              _MemberTile(key: ValueKey('member-${m.id}'), member: m),
            const InviteAdultTile(),
          ],
        ),
      ],
    );
  }

  Future<void> _reorder(List<Member> current, int from, int to) async {
    final next = List.of(current);
    final moved = next.removeAt(from);
    next.insert(to, moved);
    setState(() => _dragged = next);
    if (!await ensureGuardian(context, ref) || !mounted) {
      setState(() => _dragged = null);
      return;
    }
    final result = await ref
        .read(identityRepositoryProvider)
        .reorderMembers(
          actor: ref.read(actingProfileProvider),
          profileIds: [for (final m in next) m.id],
        );
    if (!mounted) return;
    ref
      ..invalidate(allMembersProvider)
      ..invalidate(membersProvider);
    setState(() => _dragged = null);
    result.when(ok: (_) {}, err: context.showFailure);
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, this.handle, super.key});

  final Member member;
  final Widget? handle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final role = member.isGuardian ? l10n.roleGuardian : l10n.roleMember;
    return ListTile(
      leading: Opacity(
        opacity: member.active ? 1 : 0.5,
        child: MemberCircle(member: member),
      ),
      title: Text(member.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.active
                ? (member.isChild ? l10n.householdKindChild : role)
                : l10n.memberInactive,
          ),
          MemberInvitationDetails(member: member),
          // Below the role, not beside it: at phone width a trailing action
          // squeezes the role into a sliver (as #29 did).
          Wrap(
            spacing: Tokens.space1,
            children: [
              MfaResetButton(member: member),
              InviteMemberButton(member: member),
            ],
          ),
        ],
      ),
      // The handle is the affordance when there is one: a chevron beside it would
      // squeeze the role into a sliver at phone width.
      trailing: handle ?? const Icon(Icons.chevron_right),
      onTap: () => context.go(Routes.member, extra: member.id),
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
    return ListTile(
      leading: Icon(switch (d.deviceClass) {
        DeviceClass.personal => Icons.smartphone,
        DeviceClass.shared => Icons.tablet_android,
        DeviceClass.kiosk => Icons.tv,
      }),
      title: Text(isThis ? '${d.label} (${l10n.thisDevice})' : d.label),
      subtitle: Text(
        '${d.deviceClass.label(l10n)} · ${d.register.label(l10n)}\n$lastSeen',
      ),
      isThreeLine: true,
      trailing: d.revoked
          ? null
          : TextButton(onPressed: onRevoke, child: Text(l10n.revoke)),
      onTap: d.revoked ? null : onRename,
    );
  }
}

/// "App 1.1.0 · Server 0.3.0 · API 1": which pair runs here, the first thing support asks.
/// The app only runs on a server it fits (server_compat.dart), so the line needs no
/// verdict of its own.
class _VersionsTile extends ConsumerWidget {
  const _VersionsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final server = ref.watch(appConfigProvider).server;
    final app =
        ref.watch(appVersionProvider).value ?? l10n.settingsVersionUnknown;
    return ListTile(
      key: const ValueKey('settings-versions'),
      leading: const Icon(Icons.info_outline),
      title: Text(l10n.settingsVersions),
      subtitle: Text(
        l10n.settingsVersionsLine(
          app,
          server?.serverVersion ?? l10n.settingsVersionUnknown,
          (server?.apiVersion ?? appApiVersion).toString(),
        ),
      ),
    );
  }
}
