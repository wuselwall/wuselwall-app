import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/server/server_address.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/invitations/application/invitation_providers.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

/// An invitation's expiry date for the local language: "Oct 22" in English, "22. Okt." in German.
String inviteDate(BuildContext context, DateTime date) =>
    formatInviteDate(Localizations.localeOf(context).languageCode, date);

/// [inviteDate] for a language code, without a context.
String formatInviteDate(String languageCode, DateTime date) =>
    DateFormat.MMMd(languageCode).format(date);

/// What the guardian chose for a new adult: a name, a role and, optionally, an email address.
class AdultInvite {
  const AdultInvite({required this.name, required this.role, this.email});

  final String name;
  final InvitationRole role;
  final String? email;
}

/// Invites an adult. With [member] (an adult of the household without an account) the
/// invitation is for that profile; without it, the dialog creates the person first. With
/// [offerExisting] (the getting-started card's "Partner:in einladen") the adults the family
/// already has without an account are offered first, so the partner added at the start (H2)
/// is invited as themselves instead of a second time.
Future<void> inviteAdultFlow(
  BuildContext context,
  WidgetRef ref, {
  Member? member,
  bool offerExisting = false,
}) async {
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  var chosen = member;
  if (chosen == null && offerExisting) {
    final candidates = await _adultsWithoutAccount(ref);
    if (!context.mounted) return;
    if (candidates.isNotEmpty) {
      final pick = await showDialog<_AdultChoice>(
        context: context,
        builder: (_) => _PickAdultDialog(candidates: candidates),
      );
      if (pick == null || !context.mounted) return;
      chosen = pick.member;
    }
  }
  final existing = chosen;
  final request = existing == null
      ? await showDialog<AdultInvite>(
          context: context,
          builder: (_) => const _AdultInviteDialog(),
        )
      : AdultInvite(
          name: existing.displayName,
          role: existing.isGuardian
              ? InvitationRole.guardian
              : InvitationRole.member,
        );
  if (request == null || !context.mounted) return;
  final result = await ref
      .read(invitationRepositoryProvider)
      .create(
        profileId: existing?.id,
        displayName: existing == null ? request.name : null,
        role: request.role,
        email: request.email,
      );
  if (!context.mounted) return;
  await _showResult(context, ref, result, name: request.name);
}

/// The household's adults who have not signed in yet: the ones an invitation can be for.
/// Empty when the members cannot be read; the person is then created as before.
Future<List<Member>> _adultsWithoutAccount(WidgetRef ref) async {
  try {
    final members = await ref.read(membersProvider.future);
    return [
      for (final m in members)
        if (m.active && !m.isChild && !m.hasAccount) m,
    ];
  } on Object {
    return const [];
  }
}

/// What the guardian picked: one of the family's adults, or someone new ([member] null).
class _AdultChoice {
  const _AdultChoice(this.member);
  final Member? member;
}

/// "Wen möchtest du einladen?": an adult the family already has, or someone else.
class _PickAdultDialog extends StatelessWidget {
  const _PickAdultDialog({required this.candidates});

  final List<Member> candidates;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.invitePartnerPickTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: Tokens.space3),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in candidates)
              ListTile(
                key: ValueKey('invite-pick-${m.id}'),
                leading: CircleAvatar(
                  backgroundColor: context.ww.member(m.color).ink,
                  foregroundColor: context.ww.member(m.color).onInk,
                  child: Text(m.initial),
                ),
                title: Text(m.displayName),
                subtitle: Text(l10n.invitePartnerExisting),
                onTap: () => Navigator.pop(context, _AdultChoice(m)),
              ),
            ListTile(
              key: const ValueKey('invite-pick-new'),
              leading: const Icon(Icons.person_add_alt_1),
              title: Text(l10n.invitePartnerSomeoneElse),
              subtitle: Text(l10n.invitePartnerSomeoneElseHint),
              onTap: () => Navigator.pop(context, const _AdultChoice(null)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

/// "Erneut teilen": the token is shown only once, so a new invitation replaces the open one
/// (the server revokes the earlier one in the same call).
Future<void> reshareInvitation(
  BuildContext context,
  WidgetRef ref,
  OpenInvitation invitation,
) async {
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  final result = await ref
      .read(invitationRepositoryProvider)
      .create(
        profileId: invitation.profileId,
        role: invitation.role,
        email: invitation.email,
      );
  if (!context.mounted) return;
  await _showResult(context, ref, result, name: invitation.profileName);
}

/// "Zurückziehen".
Future<void> withdrawInvitation(
  BuildContext context,
  WidgetRef ref,
  OpenInvitation invitation,
) async {
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  final result = await ref
      .read(invitationRepositoryProvider)
      .revoke(invitation.id);
  ref
    ..invalidate(openInvitationsProvider)
    ..invalidate(membersProvider);
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      context.showMessage(context.l10n.inviteWithdrawn);
    case Err(:final failure):
      context.showFailure(failure);
  }
}

Future<void> _showResult(
  BuildContext context,
  WidgetRef ref,
  Result<CreatedInvitation> result, {
  required String name,
}) async {
  ref
    ..invalidate(openInvitationsProvider)
    ..invalidate(membersProvider);
  if (!context.mounted) return;
  switch (result) {
    case Ok(:final value):
      await showDialog<void>(
        context: context,
        builder: (_) => _InviteResultDialog(invitation: value, name: name),
      );
    case Err(:final failure):
      context.showFailure(failure);
  }
}

/// The code, the QR code of the link, and "Teilen" with the message of specs/20.
class _InviteResultDialog extends ConsumerWidget {
  const _InviteResultDialog({required this.invitation, required this.name});

  final CreatedInvitation invitation;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final household = ref.watch(householdNameProvider);
    final server = ref.watch(currentServerProvider);
    return AlertDialog(
      title: Text(l10n.inviteResultTitle(name)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // One line whatever the width: a code broken over two lines gets misread.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                invitation.displayCode,
                key: const ValueKey('invite-code'),
                maxLines: 1,
                style: theme.textTheme.displaySmall?.copyWith(
                  letterSpacing: 4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (server != null) ...[
              const SizedBox(height: Tokens.space2),
              Text(
                l10n.inviteResultServer(displayServerAddress(server)),
                key: const ValueKey('invite-server'),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: Tokens.space4),
            QrCodeView(
              key: const ValueKey('invite-qr'),
              data: invitation.linkOn(server),
              semanticsLabel: l10n.inviteQrLabel,
              size: 200,
            ),
            const SizedBox(height: Tokens.space3),
            Text(l10n.inviteResultHint, textAlign: TextAlign.center),
            const SizedBox(height: Tokens.space2),
            Text(
              l10n.inviteValidUntil(inviteDate(context, invitation.expiresAt)),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('invite-done'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.inviteDone),
        ),
        // Sharing is what the guardian came for; "Fertig" only closes.
        FilledButton.icon(
          key: const ValueKey('invite-share'),
          onPressed: household.hasValue
              ? () => ref.read(inviteSharerProvider)(
                  l10n.inviteShareMessage(
                    household.value!,
                    invitation.linkOn(server),
                    invitation.displayCode,
                    server == null ? '' : displayServerAddress(server),
                  ),
                )
              : null,
          icon: const Icon(Icons.ios_share),
          label: Text(l10n.inviteShare),
        ),
      ],
    );
  }
}

/// Name, role and an optional email for a new adult.
class _AdultInviteDialog extends StatefulWidget {
  const _AdultInviteDialog();

  @override
  State<_AdultInviteDialog> createState() => _AdultInviteDialogState();
}

class _AdultInviteDialogState extends State<_AdultInviteDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  var _role = InvitationRole.guardian;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    Navigator.pop(
      context,
      AdultInvite(
        name: _name.text.trim(),
        role: _role,
        email: email.isEmpty ? null : email.toLowerCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.inviteAdultTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 40,
                decoration: InputDecoration(labelText: l10n.inviteAdultName),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: Tokens.space3),
              Text(l10n.inviteAdultRole, style: theme.textTheme.labelLarge),
              const SizedBox(height: Tokens.space2),
              SegmentedButton<InvitationRole>(
                segments: [
                  ButtonSegment(
                    value: InvitationRole.guardian,
                    label: Text(l10n.inviteRoleGuardian),
                  ),
                  ButtonSegment(
                    value: InvitationRole.member,
                    label: Text(l10n.inviteRoleMember),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: Tokens.space2),
              Text(
                _role == InvitationRole.guardian
                    ? l10n.inviteRoleGuardianHelp
                    : l10n.inviteRoleMemberHelp,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: Tokens.space4),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.inviteAdultEmail,
                  helperText: l10n.inviteAdultEmailHelp,
                  helperMaxLines: 3,
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  return value.isEmpty ||
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
                      ? null
                      : l10n.inviteEmailInvalid;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.inviteCreate)),
      ],
    );
  }
}
