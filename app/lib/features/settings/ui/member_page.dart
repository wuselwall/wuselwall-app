import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/account/ui/mfa_reset_button.dart';
import 'package:wuselwall/features/account/ui/password_reset_button.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/data/identity_repository.dart';
import 'package:wuselwall/features/identity/domain/avatars.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/identity/ui/member_circle.dart';
import 'package:wuselwall/features/invitations/ui/members_invitations.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/ui/settings_view_switch.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';

/// One person of the family (specs/16 step 10.1): name, colour, picture, child or adult,
/// and under Advanced the role and "no longer with us". A member changes their own name,
/// colour and picture; everything else is a guardian action (the PIN on shared devices).
/// Every control applies at once; the server decides in the end and its message is shown.
class MemberPage extends ConsumerStatefulWidget {
  const MemberPage({required this.profileId, super.key});

  final String profileId;

  @override
  ConsumerState<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends ConsumerState<MemberPage> {
  final _name = TextEditingController();
  var _nameSeeded = false;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _actor => ref.read(actingProfileProvider);
  IdentityRepository get _repo => ref.read(identityRepositoryProvider);

  void _refresh() => ref
    ..invalidate(allMembersProvider)
    ..invalidate(membersProvider);

  /// Runs a write; [guardian] asks for the PIN first where the server will insist on it.
  Future<void> _pickBirthday(Member m, bool isSelf) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: m.birthday ?? DateTime(now.year - 8, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !mounted) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    await _run(
      () => _repo.updateMember(actor: _actor, profileId: m.id, birthday: iso),
      guardian: !isSelf,
    );
  }

  Future<bool> _run(
    Future<Result<void>> Function() action, {
    required bool guardian,
  }) async {
    if (guardian && (!await ensureGuardian(context, ref) || !mounted)) {
      return false;
    }
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return false;
    setState(() => _busy = false);
    return result.when(
      ok: (_) {
        _refresh();
        return true;
      },
      err: (failure) {
        context.showFailure(failure);
        return false;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final members = ref.watch(allMembersProvider);
    final member = members.value
        ?.where((m) => m.id == widget.profileId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(member?.displayName ?? l10n.settingsMembers),
        leading: BackButton(
          onPressed: () => context.go(Routes.settingsMembers),
        ),
        actions: const [SettingsViewSwitch()],
      ),
      body: AsyncValueView<List<Member>>(
        value: members,
        onRetry: _refresh,
        data: (list) {
          final m = list.where((x) => x.id == widget.profileId).firstOrNull;
          if (m == null) {
            return Center(child: Text(l10n.errorNotFound));
          }
          if (!_nameSeeded) {
            _name.text = m.displayName;
            _nameSeeded = true;
          }
          return _body(context, m, list);
        },
      ),
    );
  }

  Widget _body(BuildContext context, Member m, List<Member> all) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final acting = ref.watch(actingProfileProvider);
    final viewer = all.where((x) => x.id == acting).firstOrNull;
    final isGuardian = viewer?.isGuardian ?? false;
    final isSelf = acting == m.id;
    // The wall edits no one: the server refuses a kiosk (20261025100000).
    final kiosk =
        ref.watch(deviceProvider).value?.deviceClass == DeviceClass.kiosk;
    final canEditBasics = !kiosk && (isGuardian || isSelf);
    final advanced = ref.watch(showAdvancedSettingsProvider);
    final nameChanged = _name.text.trim() != m.displayName;

    return ListView(
      padding: const EdgeInsets.all(Tokens.space4),
      children: [
        Center(child: MemberCircle(member: m, size: 96)),
        const SizedBox(height: Tokens.space4),
        if (!m.active)
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: Text(l10n.memberInactive),
              subtitle: Text(l10n.memberInactiveBody),
            ),
          ),
        if (!canEditBasics)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space4),
            child: Text(
              kiosk ? l10n.memberKioskReadOnly : l10n.memberReadOnlyHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
        TextField(
          key: const ValueKey('member-name'),
          controller: _name,
          enabled: canEditBasics && !_busy,
          maxLength: 40,
          decoration: InputDecoration(labelText: l10n.memberName),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _saveName(m, isSelf),
        ),
        if (nameChanged)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('member-save-name'),
              onPressed: _busy ? null : () => _saveName(m, isSelf),
              child: Text(l10n.save),
            ),
          ),
        const SizedBox(height: Tokens.space4),
        Text(l10n.memberColour, style: theme.textTheme.labelLarge),
        const SizedBox(height: Tokens.space2),
        Wrap(
          spacing: Tokens.space2,
          runSpacing: Tokens.space2,
          children: [
            for (final (i, swatch) in MemberPalette.swatches.indexed)
              SwatchChoice(
                key: ValueKey('member-colour-${swatch.key}'),
                color: swatch.light,
                label: l10n.householdNewColourOption('${i + 1}'),
                selected: MemberPalette.resolve(m.color).key == swatch.key,
                onTap: !canEditBasics || _busy
                    ? null
                    : () => _run(
                        () => _repo.updateMember(
                          actor: _actor,
                          profileId: m.id,
                          colorHex: toHex(swatch.light),
                        ),
                        guardian: !isSelf,
                      ),
              ),
          ],
        ),
        const SizedBox(height: Tokens.space4),
        Text(l10n.memberAvatar, style: theme.textTheme.labelLarge),
        const SizedBox(height: Tokens.space2),
        Wrap(
          spacing: Tokens.space2,
          runSpacing: Tokens.space2,
          children: [
            _AvatarChoice(
              key: const ValueKey('member-avatar-initial'),
              member: m,
              avatarKey: null,
              label: l10n.memberAvatarInitial,
              selected: avatarAsset(m.avatarKey) == null,
              onTap: !canEditBasics || _busy
                  ? null
                  : () => _run(
                      () => _repo.updateMember(
                        actor: _actor,
                        profileId: m.id,
                        avatarKey: '',
                      ),
                      guardian: !isSelf,
                    ),
            ),
            for (final key in avatarKeys)
              _AvatarChoice(
                key: ValueKey('member-avatar-$key'),
                member: m,
                avatarKey: key,
                label: key,
                selected: m.avatarKey == key,
                onTap: !canEditBasics || _busy
                    ? null
                    : () => _run(
                        () => _repo.updateMember(
                          actor: _actor,
                          profileId: m.id,
                          avatarKey: key,
                        ),
                        guardian: !isSelf,
                      ),
              ),
          ],
        ),
        // The birthday counts down on the wall and dresses Wusel up (specs/27); only on a
        // server that knows it.
        if (ref.watch(lighterDaySupportedProvider)) ...[
          const SizedBox(height: Tokens.space4),
          Text(l10n.memberBirthday, style: theme.textTheme.labelLarge),
          const SizedBox(height: Tokens.space1),
          Text(l10n.memberBirthdayHelp, style: theme.textTheme.bodySmall),
          const SizedBox(height: Tokens.space2),
          Row(
            children: [
              OutlinedButton.icon(
                key: const ValueKey('member-birthday'),
                icon: const Icon(Icons.cake_outlined),
                label: Text(
                  m.birthday == null
                      ? l10n.memberBirthdayPick
                      : MaterialLocalizations.of(context)
                            .formatMediumDate(m.birthday!),
                ),
                onPressed: !canEditBasics || _busy
                    ? null
                    : () => _pickBirthday(m, isSelf),
              ),
              if (m.birthday != null)
                IconButton(
                  key: const ValueKey('member-birthday-clear'),
                  tooltip: l10n.memberBirthdayClear,
                  icon: const Icon(Icons.close),
                  onPressed: !canEditBasics || _busy
                      ? null
                      : () => _run(
                          () => _repo.updateMember(
                            actor: _actor,
                            profileId: m.id,
                            birthday: '',
                          ),
                          guardian: !isSelf,
                        ),
                ),
            ],
          ),
        ],
        const SizedBox(height: Tokens.space6),
        // Child or adult: starter chores, the kid register and the timetable follow it.
        Text(l10n.memberKind, style: theme.textTheme.labelLarge),
        const SizedBox(height: Tokens.space2),
        SegmentedButton<bool>(
          key: const ValueKey('member-kind'),
          segments: [
            ButtonSegment(value: true, label: Text(l10n.householdKindChild)),
            ButtonSegment(value: false, label: Text(l10n.householdKindAdult)),
          ],
          selected: {m.isChild},
          onSelectionChanged:
              !isGuardian || _busy || m.hasAccount || m.isGuardian
              ? null
              : (s) => _run(
                  () => _repo.updateMember(
                    actor: _actor,
                    profileId: m.id,
                    isChild: s.first,
                  ),
                  guardian: true,
                ),
        ),
        if (m.hasAccount || m.isGuardian)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space1),
            child: Text(
              l10n.memberErrKindAdult,
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: Tokens.space4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.home_outlined),
          title: Text(l10n.baselineTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.baselines),
        ),
        MemberInvitationDetails(member: m),
        Wrap(
          spacing: Tokens.space1,
          children: [
            MfaResetButton(member: m),
            PasswordResetButton(member: m),
            InviteMemberButton(member: m),
          ],
        ),
        if (advanced) ...[
          const SizedBox(height: Tokens.space6),
          Text(l10n.memberRole, style: theme.textTheme.labelLarge),
          const SizedBox(height: Tokens.space2),
          SegmentedButton<Role>(
            key: const ValueKey('member-role'),
            segments: [
              ButtonSegment(
                value: Role.guardian,
                label: Text(l10n.roleGuardian),
              ),
              ButtonSegment(value: Role.member, label: Text(l10n.roleMember)),
            ],
            selected: {m.role},
            onSelectionChanged: !isGuardian || _busy || m.isChild
                ? null
                : (s) => _run(
                    () => _repo.setMemberRole(
                      actor: _actor,
                      profileId: m.id,
                      role: s.first,
                    ),
                    guardian: true,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space1),
            child: Text(
              m.isChild ? l10n.memberErrRoleChild : l10n.memberRoleHelp,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (isGuardian && !isSelf) ...[
            const SizedBox(height: Tokens.space6),
            if (m.hasAccount)
              Text(
                l10n.memberHasAccountHint(m.displayName),
                style: theme.textTheme.bodySmall,
              )
            else if (m.active)
              ListTile(
                key: const ValueKey('member-deactivate'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_off_outlined),
                title: Text(l10n.memberDeactivate),
                subtitle: Text(l10n.memberDeactivateBody(m.displayName)),
                onTap: _busy ? null : () => _deactivate(m),
              )
            else
              ListTile(
                key: const ValueKey('member-reactivate'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_add_alt_1),
                title: Text(l10n.memberReactivate),
                onTap: _busy
                    ? null
                    : () => _run(
                        () => _repo.setMemberActive(
                          actor: _actor,
                          profileId: m.id,
                          active: true,
                        ),
                        guardian: true,
                      ),
              ),
          ],
        ] else
          const MoreSettingsHint(),
      ],
    );
  }

  Future<void> _saveName(Member m, bool isSelf) async {
    final name = _name.text.trim();
    if (name.isEmpty || name == m.displayName) return;
    final ok = await _run(
      () => _repo.updateMember(actor: _actor, profileId: m.id, name: name),
      guardian: !isSelf,
    );
    if (ok && mounted) context.showMessage(context.l10n.savedMessage);
  }

  Future<void> _deactivate(Member m) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.memberDeactivate),
        content: Text(l10n.memberDeactivateConfirm(m.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.memberDeactivate),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await _run(
      () =>
          _repo.setMemberActive(actor: _actor, profileId: m.id, active: false),
      guardian: true,
    );
    if (done && mounted) context.go(Routes.settingsMembers);
  }
}

/// One choice in the picture picker: the member's circle as it would look.
class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.member,
    required this.avatarKey,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Member member;
  final String? avatarKey;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: MemberCircle(
        member: Member(
          id: member.id,
          displayName: member.displayName,
          color: member.color,
          role: member.role,
          active: member.active,
          avatarKey: avatarKey,
        ),
        size: 48,
        selected: selected,
      ),
    ),
  );
}
