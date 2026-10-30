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
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/empty_view.dart';
import 'package:wuselwall/core/ui/qr_code_view.dart';
import 'package:wuselwall/core/ui/ringed_avatar.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/application/feed_providers.dart';
import 'package:wuselwall/features/calendar/data/feed_repository.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// Calendar subscriptions (specs/05 "The ICS feed"). Each token is one subscriber with
/// its own filter; revoking one leaves the others alone. Guardian-only, PIN included.
class FeedTokensPage extends ConsumerWidget {
  const FeedTokensPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = ref.watch(feedTokensProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.feedTitle),
        leading: BackButton(
          onPressed: () => context.go(Routes.settingsCalendar),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.feedNew),
      ),
      body: ContentWidth(
        child: AsyncValueView<List<FeedToken>>(
          value: tokens,
          onRetry: () => ref.invalidate(feedTokensProvider),
          data: (list) => list.isEmpty
              ? EmptyView(
                  // A settings page: no Wusel (specs/25 "Where Wusel never appears").
                  illustrated: false,
                  message: l10n.feedEmpty,
                  actions: [
                    FilledButton.icon(
                      onPressed: () => _create(context, ref),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.feedNew),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.space4,
                    Tokens.space4,
                    Tokens.space4,
                    96,
                  ),
                  children: [
                    for (final t in list)
                      _FeedTile(
                        token: t,
                        summary: _summary(l10n, t.filter, members),
                        onRevoke: () => _revoke(context, ref, t),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final members = (await ref.read(membersProvider.future))
        .where((m) => m.active)
        .toList(growable: false);
    if (!context.mounted) return;
    final spec = await showDialog<_NewFeed>(
      context: context,
      builder: (_) => _NewFeedDialog(members: members),
    );
    if (spec == null || !context.mounted) return;

    final result = await ref
        .read(feedRepositoryProvider)
        .create(
          actor: ref.read(actingProfileProvider),
          label: spec.label,
          filter: spec.filter,
        );
    if (!context.mounted) return;
    switch (result) {
      case Ok(:final value):
        ref.invalidate(feedTokensProvider);
        final url = feedAddress(
          ref.read(appConfigProvider).supabaseUrl,
          value.token,
        );
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _TokenDialog(url: url),
        );
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, FeedToken t) async {
    final l10n = context.l10n;
    if (!await ensureGuardian(context, ref) || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.feedRevokeConfirm(t.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.feedRevokeAction),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final result = await ref
        .read(feedRepositoryProvider)
        .revoke(actor: ref.read(actingProfileProvider), id: t.id);
    if (!context.mounted) return;
    result.when(
      ok: (_) => ref.invalidate(feedTokensProvider),
      err: context.showFailure,
    );
  }
}

/// "Termine · Thomas, Julia · Schultag": what a subscription carries, in words.
String _summary(AppLocalizations l10n, FeedFilter f, List<Member> members) {
  final kinds = [
    if (f.kinds.contains('appointment')) l10n.feedSummaryAppointments,
    if (f.kinds.contains('presence')) l10n.feedSummaryPresence,
  ];
  final people = f.profileIds.isEmpty
      ? l10n.feedSummaryEveryone
      : members
            .where((m) => f.profileIds.contains(m.id))
            .map((m) => m.displayName)
            .join(', ');
  final school = switch (f.school) {
    FeedSchool.off => null,
    FeedSchool.day => l10n.feedSummarySchoolDay,
    FeedSchool.lessons => l10n.feedSummarySchoolLessons,
  };
  return [
    kinds.join(' + '),
    people,
    ?school,
    if (f.subscribed) l10n.feedSubSummary,
  ].join(' · ');
}

/// "vor 3 Std." and the fetch count, from the server's last_fetched_at.
String _fetched(AppLocalizations l10n, FeedToken t) {
  final at = t.lastFetchedAt;
  if (at == null) return '${l10n.feedNeverFetched} · ${l10n.feedFetchCount(0)}';
  final d = DateTime.now().difference(at);
  final ago = d.inMinutes < 1
      ? l10n.feedAgoJustNow
      : d.inMinutes < 60
      ? l10n.feedAgoMinutes(d.inMinutes)
      : d.inHours < 24
      ? l10n.feedAgoHours(d.inHours)
      : l10n.feedAgoDays(d.inDays);
  return '${l10n.feedLastFetched(ago)} · ${l10n.feedFetchCount(t.fetchCount)}';
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.token,
    required this.summary,
    required this.onRevoke,
  });

  final FeedToken token;
  final String summary;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Opacity(
      opacity: token.revoked ? 0.5 : 1,
      child: Card(
        child: ListTile(
          leading: Icon(token.revoked ? Icons.event_busy : Icons.rss_feed),
          title: Text(token.label),
          subtitle: Text(
            [
              summary,
              if (token.revoked) l10n.feedRevoked else _fetched(l10n, token),
            ].join('\n'),
          ),
          isThreeLine: true,
          trailing: token.revoked
              ? null
              : TextButton(
                  onPressed: onRevoke,
                  child: Text(l10n.feedRevokeAction),
                ),
        ),
      ),
    );
  }
}

class _NewFeed {
  const _NewFeed({required this.label, required this.filter});

  final String label;
  final FeedFilter filter;
}

/// Name, whose events, which kinds, school. Presence and school default to off: a
/// child's whereabouts and a shift pattern are the things most worth not sharing by
/// accident (specs/05).
class _NewFeedDialog extends StatefulWidget {
  const _NewFeedDialog({required this.members});

  final List<Member> members;

  @override
  State<_NewFeedDialog> createState() => _NewFeedDialogState();
}

class _NewFeedDialogState extends State<_NewFeedDialog> {
  final _label = TextEditingController();
  final _people = <String>{};
  bool _presence = false;
  FeedSchool _school = FeedSchool.off;
  bool _subscribed = false;

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

  void _submit() {
    Navigator.pop(
      context,
      _NewFeed(
        label: _label.text.trim(),
        filter: FeedFilter(
          profileIds: _people.toList(),
          kinds: {'appointment', if (_presence) 'presence'},
          school: _school,
          subscribed: _subscribed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.feedNew),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _label,
            autofocus: true,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: l10n.feedLabelField,
              hintText: l10n.feedLabelHint,
            ),
          ),
          const SizedBox(height: Tokens.space2),
          Text(l10n.feedWhoseTitle, style: theme.textTheme.labelLarge),
          Text(l10n.feedWhoseHelp, style: theme.textTheme.bodySmall),
          const SizedBox(height: Tokens.space2),
          Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              for (final m in widget.members)
                FilterChip(
                  showCheckmark: false,
                  avatar: RingedAvatar(
                    selected: _people.contains(m.id),
                    child: MemberDot(
                      memberColor: m.color,
                      semanticLabel: m.displayName,
                      size: 16,
                    ),
                  ),
                  label: Text(m.displayName),
                  selected: _people.contains(m.id),
                  onSelected: (on) => setState(
                    () => on ? _people.add(m.id) : _people.remove(m.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          Text(l10n.feedWhatTitle, style: theme.textTheme.labelLarge),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: true,
            onChanged: null,
            title: Text(l10n.feedSummaryAppointments),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _presence,
            onChanged: (v) => setState(() => _presence = v ?? false),
            title: Text(l10n.feedKindPresenceTitle),
            subtitle: Text(l10n.feedPresenceHint),
          ),
          const SizedBox(height: Tokens.space2),
          Text(l10n.feedSchoolTitle, style: theme.textTheme.labelLarge),
          Text(l10n.feedSchoolHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: Tokens.space2),
          Wrap(
            spacing: Tokens.space2,
            children: [
              for (final (value, label) in [
                (FeedSchool.off, l10n.feedSchoolOff),
                (FeedSchool.day, l10n.feedSummarySchoolDay),
                (FeedSchool.lessons, l10n.feedSummarySchoolLessons),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _school == value,
                  onSelected: (_) => setState(() => _school = value),
                ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _subscribed,
            onChanged: (v) => setState(() => _subscribed = v),
            title: Text(l10n.feedSubTitle),
            subtitle: Text(l10n.feedSubHelp),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _label.text.trim().isEmpty ? null : _submit,
          child: Text(l10n.feedCreate),
        ),
      ],
    );
  }
}

/// The address, once: copy as https or webcal, a QR code for a phone, and the two
/// subscribe steps (specs/05 "Subscribing").
class _TokenDialog extends StatelessWidget {
  const _TokenDialog({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final webcal = webcalAddress(url);
    return AlertDialog(
      title: Text(l10n.feedUrlTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.feedUrlOnce, style: theme.textTheme.bodySmall),
          const SizedBox(height: Tokens.space2),
          SelectableText(url),
          const SizedBox(height: Tokens.space1),
          FilledButton.tonalIcon(
            onPressed: () => _copy(context, url),
            icon: const Icon(Icons.copy),
            label: Text(l10n.feedCopyUrl),
          ),
          const SizedBox(height: Tokens.space3),
          SelectableText(webcal, style: theme.textTheme.bodySmall),
          const SizedBox(height: Tokens.space1),
          OutlinedButton.icon(
            onPressed: () => _copy(context, webcal),
            icon: const Icon(Icons.link),
            label: Text(l10n.feedCopyWebcal),
          ),
          const SizedBox(height: Tokens.space4),
          Center(
            child: QrCodeView(
              data: url,
              semanticsLabel: l10n.feedQrLabel,
              size: 200,
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Text(l10n.feedHowTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: Tokens.space1),
          Text(l10n.feedHowOutlook),
          const SizedBox(height: Tokens.space2),
          Text(l10n.feedHowIphone),
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
    if (context.mounted) context.showMessage(context.l10n.feedCopied);
  }
}
