import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/config/config_providers.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/ringed_avatar.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/shortcuts/application/shortcut_providers.dart';
import 'package:wuselwall/features/shortcuts/data/shortcut_repository.dart';

/// Siri and Shortcuts (specs/12 "Part 1") and assistants over MCP ("Part 2"): one key per
/// person and device. A shortcut key reads and adds as that person; an assistant key, for
/// adults only, reads. A guardian sees and manages every key; everyone else sees and
/// manages their own. Never on the kitchen wall: a key is shown once, to the person who
/// pastes it into a shortcut or an assistant.
class ShortcutsPage extends ConsumerWidget {
  const ShortcutsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = ref.watch(shortcutTokensProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final acting = ref.watch(actingProfileProvider);
    final kiosk =
        ref.watch(deviceProvider).value?.deviceClass == DeviceClass.kiosk;
    final guardian = members.any((m) => m.id == acting && m.isGuardian);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shortcutTitle),
        leading: BackButton(onPressed: () => context.go(Routes.settings)),
      ),
      floatingActionButton: kiosk
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.shortcutNew),
            ),
      body: AsyncValueView<List<ShortcutToken>>(
        value: tokens,
        onRetry: () => ref.invalidate(shortcutTokensProvider),
        data: (list) {
          final visible = guardian
              ? list
              : list.where((t) => t.profileId == acting).toList();
          Widget tile(ShortcutToken t) => _KeyTile(
            token: t,
            owner: members
                .where((m) => m.id == t.profileId)
                .firstOrNull
                ?.displayName,
            onRevoke: guardian || t.profileId == acting
                ? () => _revoke(context, ref, t)
                : null,
          );
          final assistants = visible
              .where((t) => t.kind == KeyKind.assistant)
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Tokens.space4,
              Tokens.space4,
              Tokens.space4,
              96,
            ),
            children: [
              Text(l10n.shortcutIntro),
              const SizedBox(height: Tokens.space4),
              if (kiosk) Text(l10n.shortcutKioskNote),
              if (visible.isEmpty && !kiosk) Text(l10n.shortcutEmpty),
              for (final t in visible)
                if (t.kind == KeyKind.shortcut) tile(t),
              if (assistants.isNotEmpty) ...[
                const SizedBox(height: Tokens.space4),
                Text(
                  l10n.shortcutSectionAssistants,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: Tokens.space2),
                for (final t in assistants) tile(t),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final members = (await ref.read(membersProvider.future))
        .where((m) => m.active)
        .toList(growable: false);
    if (!context.mounted) return;
    final acting = ref.read(actingProfileProvider);
    final me = members.where((m) => m.id == acting).firstOrNull;
    if (me == null) return;
    final personal =
        ref.read(deviceProvider).value?.deviceClass == DeviceClass.personal;

    final spec = await showDialog<_NewKey>(
      context: context,
      builder: (_) =>
          _NewKeyDialog(me: me, members: me.isGuardian ? members : [me]),
    );
    if (spec == null || !context.mounted) return;
    // Someone else's key, or any key on a shared device, is a guardian action (PIN).
    if ((spec.profile.id != me.id || !personal) &&
        !await ensureGuardian(context, ref)) {
      return;
    }
    if (!context.mounted) return;

    final result = await ref
        .read(shortcutRepositoryProvider)
        .create(
          actor: acting,
          profileId: spec.profile.id,
          label: spec.label,
          kind: spec.kind,
        );
    if (!context.mounted) return;
    switch (result) {
      case Ok(:final value):
        ref.invalidate(shortcutTokensProvider);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _KeyDialog(
            name: spec.profile.displayName,
            token: value.token,
            kind: spec.kind,
            address: spec.kind == KeyKind.assistant
                ? mcpAddress(ref.read(appConfigProvider).supabaseUrl)
                : shortcutsAddress(ref.read(appConfigProvider).supabaseUrl),
          ),
        );
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    ShortcutToken t,
  ) async {
    final l10n = context.l10n;
    final acting = ref.read(actingProfileProvider);
    if (t.profileId != acting && !await ensureGuardian(context, ref)) return;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.shortcutRevokeConfirm(t.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.shortcutRevokeAction),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final result = await ref
        .read(shortcutRepositoryProvider)
        .revoke(actor: acting, id: t.id);
    if (!context.mounted) return;
    result.when(
      ok: (_) => ref.invalidate(shortcutTokensProvider),
      err: context.showFailure,
    );
  }
}

/// "Zuletzt benutzt: vor 3 Std.", from the server's last_used_at.
String _used(AppLocalizations l10n, ShortcutToken t) {
  final at = t.lastUsedAt;
  if (at == null) return l10n.shortcutNeverUsed;
  final d = DateTime.now().difference(at);
  // The relative times are the calendar subscriptions' wording ("vor 3 Std.").
  final ago = d.inMinutes < 1
      ? l10n.feedAgoJustNow
      : d.inMinutes < 60
      ? l10n.feedAgoMinutes(d.inMinutes)
      : d.inHours < 24
      ? l10n.feedAgoHours(d.inHours)
      : l10n.feedAgoDays(d.inDays);
  return l10n.shortcutLastUsed(ago);
}

class _KeyTile extends StatelessWidget {
  const _KeyTile({required this.token, required this.owner, this.onRevoke});

  final ShortcutToken token;
  final String? owner;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Opacity(
      opacity: token.revoked ? 0.5 : 1,
      child: Card(
        child: ListTile(
          leading: Icon(
            token.revoked
                ? Icons.key_off
                : token.kind == KeyKind.assistant
                ? Icons.smart_toy_outlined
                : Icons.key,
          ),
          title: Text(token.label),
          // "Thomas · 34 Abfragen", then when it was last used.
          subtitle: Text(
            [
              [
                ?owner,
                if (token.useCount > 0) l10n.shortcutUseCount(token.useCount),
              ].join(' · '),
              if (token.revoked) l10n.shortcutRevoked else _used(l10n, token),
            ].where((line) => line.isNotEmpty).join('\n'),
          ),
          isThreeLine: true,
          trailing: token.revoked || onRevoke == null
              ? null
              : TextButton(
                  onPressed: onRevoke,
                  child: Text(l10n.shortcutRevokeAction),
                ),
        ),
      ),
    );
  }
}

class _NewKey {
  const _NewKey({
    required this.label,
    required this.profile,
    required this.kind,
  });

  final String label;
  final Member profile;
  final KeyKind kind;
}

/// What the key is for, its name, and for a guardian whose it is (the guardian's own by
/// default). An assistant reads the whole family's week, so only adults are offered for it.
class _NewKeyDialog extends StatefulWidget {
  const _NewKeyDialog({required this.me, required this.members});

  final Member me;
  final List<Member> members;

  @override
  State<_NewKeyDialog> createState() => _NewKeyDialogState();
}

class _NewKeyDialogState extends State<_NewKeyDialog> {
  final _label = TextEditingController();
  late Member _profile = widget.me;
  var _kind = KeyKind.shortcut;

  List<Member> get _people => _kind == KeyKind.assistant
      ? widget.members.where((m) => !m.isChild).toList()
      : widget.members;

  void _setKind(KeyKind kind) => setState(() {
    _kind = kind;
    if (!_people.any((m) => m.id == _profile.id)) _profile = widget.me;
  });

  @override
  void initState() {
    super.initState();
    _label.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.shortcutNew),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A child has no assistant key, so a child's own dialog offers shortcuts only.
          if (!widget.me.isChild) ...[
            SegmentedButton<KeyKind>(
              segments: [
                ButtonSegment(
                  value: KeyKind.shortcut,
                  icon: const Icon(Icons.key),
                  label: Text(l10n.shortcutKindShortcut),
                ),
                ButtonSegment(
                  value: KeyKind.assistant,
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: Text(l10n.shortcutKindAssistant),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => _setKind(s.single),
            ),
            const SizedBox(height: Tokens.space1),
            Text(
              _kind == KeyKind.assistant
                  ? l10n.shortcutKindAssistantHelp
                  : l10n.shortcutKindShortcutHelp,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Tokens.space2),
          ],
          TextField(
            controller: _label,
            autofocus: true,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: l10n.shortcutLabelField,
              hintText: _kind == KeyKind.assistant
                  ? l10n.shortcutAssistantLabelHint
                  : l10n.shortcutLabelHint,
            ),
          ),
          if (_people.length > 1) ...[
            const SizedBox(height: Tokens.space2),
            Text(l10n.shortcutForWhom, style: theme.textTheme.labelLarge),
            Text(l10n.shortcutForWhomHelp, style: theme.textTheme.bodySmall),
            const SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                for (final m in _people)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: RingedAvatar(
                      selected: _profile.id == m.id,
                      child: MemberDot(
                        memberColor: m.color,
                        semanticLabel: m.displayName,
                        size: 16,
                      ),
                    ),
                    label: Text(m.displayName),
                    selected: _profile.id == m.id,
                    onSelected: (_) => setState(() => _profile = m),
                  ),
              ],
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
          onPressed: _label.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _NewKey(
                    label: _label.text.trim(),
                    profile: _profile,
                    kind: _kind,
                  ),
                ),
          child: Text(l10n.shortcutCreate),
        ),
      ],
    );
  }
}

/// The key, once, with the address and the first steps in the Shortcuts app, or for an
/// assistant the connection and what it means for the family's data.
class _KeyDialog extends StatelessWidget {
  const _KeyDialog({
    required this.name,
    required this.token,
    required this.kind,
    required this.address,
  });

  final String name;
  final String token;
  final KeyKind kind;
  final String address;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.shortcutKeyTitle(name)),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kind == KeyKind.assistant
                ? l10n.shortcutAssistantKeyOnce(name)
                : l10n.shortcutKeyOnce(name),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Tokens.space2),
          SelectableText(token),
          const SizedBox(height: Tokens.space1),
          FilledButton.tonalIcon(
            onPressed: () => _copy(context, token),
            icon: const Icon(Icons.copy),
            label: Text(l10n.shortcutCopyKey),
          ),
          const SizedBox(height: Tokens.space3),
          Text(l10n.shortcutAddressLabel, style: theme.textTheme.labelLarge),
          SelectableText(address, style: theme.textTheme.bodySmall),
          const SizedBox(height: Tokens.space1),
          OutlinedButton.icon(
            onPressed: () => _copy(context, address),
            icon: const Icon(Icons.link),
            label: Text(l10n.shortcutCopyAddress),
          ),
          const SizedBox(height: Tokens.space4),
          Text(l10n.shortcutHowTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: Tokens.space1),
          Text(
            kind == KeyKind.assistant
                ? l10n.shortcutAssistantHowSteps
                : l10n.shortcutHowSteps,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) context.showMessage(context.l10n.shortcutCopied);
  }
}
