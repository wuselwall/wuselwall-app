import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/invitations/application/invitation_providers.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';

/// "18.10." for the local language, as the invitation lists write dates.
String inviteDate(BuildContext context, DateTime date) => DateFormat(
  'd.M.',
  Localizations.localeOf(context).languageCode,
).format(date);

/// What the guardian chose for a new adult: a name, a role and, optionally, an email address.
class AdultInvite {
  const AdultInvite({required this.name, required this.role, this.email});

  final String name;
  final InvitationRole role;
  final String? email;
}

/// Invites an adult. With [member] (an adult of the household without an account) the
/// invitation is for that profile; without it, the dialog creates the person first.
Future<void> inviteAdultFlow(
  BuildContext context,
  WidgetRef ref, {
  Member? member,
}) async {
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  final request = member == null
      ? await showDialog<AdultInvite>(
          context: context,
          builder: (_) => const _AdultInviteDialog(),
        )
      : AdultInvite(
          name: member.displayName,
          role: member.isGuardian
              ? InvitationRole.guardian
              : InvitationRole.member,
        );
  if (request == null || !context.mounted) return;
  final result = await ref
      .read(invitationRepositoryProvider)
      .create(
        profileId: member?.id,
        displayName: member == null ? request.name : null,
        role: request.role,
        email: request.email,
      );
  if (!context.mounted) return;
  await _showResult(context, ref, result, name: request.name);
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
            const SizedBox(height: Tokens.space4),
            QrCodeView(
              key: const ValueKey('invite-qr'),
              data: invitation.link,
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
          key: const ValueKey('invite-share'),
          onPressed: household.hasValue
              ? () => ref.read(inviteSharerProvider)(
                  l10n.inviteShareMessage(
                    household.value!,
                    invitation.link,
                    invitation.displayCode,
                  ),
                )
              : null,
          child: Text(l10n.inviteShare),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.inviteDone),
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
