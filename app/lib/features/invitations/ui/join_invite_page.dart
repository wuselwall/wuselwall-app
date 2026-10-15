import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/household/domain/device_label.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/invitations/application/invitation_providers.dart';
import 'package:wuselwall/features/invitations/data/invitation_repository.dart';
import 'package:wuselwall/features/invitations/domain/invitation.dart';
import 'package:wuselwall/features/setup/ui/auth_form_scaffold.dart';

/// The join confirmation (specs/20, J2): "Du bist Sabine in Familie Huser", with the name and
/// colour the inviter chose, both editable. Shown for a kept invitation (its code) or for a
/// pending one from H0 (its id).
class JoinInvitePage extends ConsumerWidget {
  const JoinInvitePage({this.pending, super.key});

  /// The invitation H0 offered, when the person chose it there.
  final PendingInvitation? pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final invitation = pending;
    if (invitation != null) {
      return _JoinForm(
        source: _JoinSource(
          householdName: invitation.householdName,
          inviterFirstName: invitation.inviterFirstName,
          profileName: invitation.profileName,
          colorHex: invitation.profileColor,
          invitationId: invitation.id,
        ),
      );
    }
    final stored = ref.watch(storedInvitationProvider);
    return stored.when(
      data: (kept) => kept == null
          ? AuthFormScaffold(
              title: l10n.inviteCodeTitle,
              children: [Text(l10n.inviteNothingKept)],
            )
          : _JoinForm(
              source: _JoinSource(
                householdName: kept.householdName,
                inviterFirstName: kept.inviterFirstName,
                profileName: kept.profileName,
                colorHex: null,
                secret: kept.secret,
              ),
            ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => AuthFormScaffold(
        title: l10n.inviteCodeTitle,
        children: [Text(l10n.inviteNothingKept)],
      ),
    );
  }
}

/// Where the join's name, colour and household come from, whichever way the invitation came.
class _JoinSource {
  const _JoinSource({
    required this.householdName,
    required this.profileName,
    this.inviterFirstName,
    this.colorHex,
    this.secret,
    this.invitationId,
  });

  final String householdName;
  final String profileName;
  final String? inviterFirstName;

  /// The colour the inviter chose; null keeps it.
  final String? colorHex;
  final String? secret;
  final String? invitationId;
}

class _JoinForm extends ConsumerStatefulWidget {
  const _JoinForm({required this.source});

  final _JoinSource source;

  @override
  ConsumerState<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends ConsumerState<_JoinForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.source.profileName,
  );
  late String? _colorHex = widget.source.colorHex?.toUpperCase();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Forgets the kept invitation, if this join came from one.
  Future<void> _forget() async {
    if (widget.source.secret != null) {
      await ref.read(invitationStoreProvider).clear();
    }
  }

  Future<void> _join() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.fieldRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(invitationRepositoryProvider)
        .accept(
          secret: widget.source.secret,
          invitationId: widget.source.invitationId,
          displayName: name,
          colorHex: _colorHex,
          deviceLabel: deviceLabel(
            l10n: l10n,
            ownerName: name,
            host: currentDeviceHost(),
          ),
        );
    if (!mounted) return;
    switch (result) {
      case Ok(value: Accepted()):
        // This session is the device now; the session is read again and the router takes
        // the person to Today.
        await _forget();
        ref.invalidate(sessionStateProvider);
      case Ok(value: AcceptRefused(:final reason)):
        setState(() {
          _busy = false;
          _error = reason == 'rate_limited'
              ? l10n.inviteRateLimited
              : l10n.inviteNoLonger;
        });
        if (reason != 'rate_limited') {
          await _forget();
          ref.invalidate(sessionStateProvider);
        }
      case Err(:final failure) when failure.code == 'already_in_household':
        await _forget();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = l10n.inviteAlreadyIn(widget.source.householdName);
        });
      case Err(:final failure):
        setState(() => _busy = false);
        context.showFailure(failure);
    }
  }

  Future<void> _decline() async {
    if (widget.source.secret == null) {
      context.go(Routes.invitePending);
      return;
    }
    await _forget();
    ref.invalidate(sessionStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final shown = _name.text.trim().isEmpty
        ? widget.source.profileName
        : _name.text.trim();
    return AuthFormScaffold(
      title: l10n.inviteCodeTitle,
      children: [
        Text(
          l10n.inviteJoinTitle(shown, widget.source.householdName),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: Tokens.space2),
        Text(l10n.inviteJoinHint),
        const SizedBox(height: Tokens.space6),
        TextField(
          controller: _name,
          enabled: !_busy,
          maxLength: 40,
          decoration: InputDecoration(labelText: l10n.householdNewYourName),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Tokens.space4),
        Text(l10n.householdNewColour, style: theme.textTheme.labelLarge),
        const SizedBox(height: Tokens.space2),
        Wrap(
          spacing: Tokens.space2,
          runSpacing: Tokens.space2,
          children: [
            for (final swatch in MemberPalette.swatches)
              _SwatchChoice(
                color: swatch.light,
                selected: _colorHex == toHex(swatch.light),
                onTap: _busy
                    ? null
                    : () => setState(() => _colorHex = toHex(swatch.light)),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: Tokens.space4),
          Text(
            _error!,
            key: const ValueKey('join-error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: Tokens.space6),
        FilledButton(
          key: const ValueKey('join-confirm'),
          onPressed: _busy ? null : _join,
          child: Text(l10n.inviteJoin),
        ),
        const SizedBox(height: Tokens.space2),
        TextButton(
          onPressed: _busy ? null : _decline,
          child: Text(l10n.inviteJoinDecline),
        ),
      ],
    );
  }
}

/// One colour of the member palette, round and labelled.
class _SwatchChoice extends StatelessWidget {
  const _SwatchChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
      ),
    ),
  );
}
