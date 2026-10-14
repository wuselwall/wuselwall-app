import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/application/external_calendar_providers.dart';
import 'package:wuselwall/features/calendar/data/external_calendars_repository.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';
import 'package:wuselwall/features/calendar/ui/external_calendar_text.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';

/// Subscribed calendars (FR-1.9, specs/05). Guardians add, change, pause, refresh and
/// remove them; everyone else sees the list read-only.
class ExternalCalendarsPage extends ConsumerStatefulWidget {
  const ExternalCalendarsPage({super.key});

  @override
  ConsumerState<ExternalCalendarsPage> createState() =>
      _ExternalCalendarsPageState();
}

class _ExternalCalendarsPageState extends ConsumerState<ExternalCalendarsPage> {
  /// Calendars whose refresh is running.
  final _refreshing = <String>{};

  /// Whoever acts on this device is a guardian. The server decides in the end.
  bool get _canManage {
    final acting = ref.watch(actingProfileProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    return members.any((m) => m.id == acting && m.isGuardian);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final calendars = ref.watch(externalCalendarsProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final canManage = _canManage;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.extCalTitle),
        leading: BackButton(onPressed: () => context.go(Routes.settings)),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(l10n.extCalNew),
            )
          : null,
      body: AsyncValueView<List<ExternalCalendar>>(
        value: calendars,
        onRetry: () => ref.invalidate(externalCalendarsProvider),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space4,
            Tokens.space4,
            Tokens.space4,
            96,
          ),
          children: [
            if (!canManage) ...[
              Text(l10n.extCalReadOnlyHint),
              const SizedBox(height: Tokens.space3),
            ],
            if (list.isEmpty)
              Text(l10n.extCalEmpty)
            else
              for (final c in list)
                _CalendarCard(
                  calendar: c,
                  membersLabel: _membersLabel(l10n, c, members),
                  statusText: calendarStatusText(l10n, c, now),
                  canManage: canManage,
                  refreshing: _refreshing.contains(c.id),
                  onRefresh: () => _refresh(c),
                  onEdit: () => _edit(c),
                  onDelete: () => _delete(c),
                  onActiveChanged: (on) => _setActive(c, on),
                ),
            const SizedBox(height: Tokens.space3),
            Text(
              l10n.extCalSettingsRefreshHint,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.ww.ink2),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (!await ensureGuardian(context, ref) || !mounted) return;
    await context.push(Routes.externalCalendarNew);
  }

  Future<void> _edit(ExternalCalendar c) async {
    if (!await ensureGuardian(context, ref) || !mounted) return;
    await context.push(Routes.externalCalendarEdit, extra: c);
  }

  Future<void> _setActive(ExternalCalendar c, bool active) async {
    if (!await ensureGuardian(context, ref) || !mounted) return;
    final result = await ref
        .read(externalCalendarsRepositoryProvider)
        .save(
          actor: ref.read(actingProfileProvider),
          draft: ExternalCalendarDraft(id: c.id, active: active),
        );
    if (!mounted) return;
    switch (result) {
      case Ok():
        _invalidate();
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _refresh(ExternalCalendar c) async {
    if (!await ensureGuardian(context, ref) || !mounted) return;
    setState(() => _refreshing.add(c.id));
    final result = await ref
        .read(externalCalendarsRepositoryProvider)
        .refresh(actor: ref.read(actingProfileProvider), calendarId: c.id);
    if (!mounted) return;
    setState(() => _refreshing.remove(c.id));
    _invalidate();
    switch (result) {
      case Ok(:final value):
        context.showMessage(refreshResultText(context.l10n, value));
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  Future<void> _delete(ExternalCalendar c) async {
    final l10n = context.l10n;
    if (!await ensureGuardian(context, ref) || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.extCalDeleteConfirm(c.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await ref
        .read(externalCalendarsRepositoryProvider)
        .delete(actor: ref.read(actingProfileProvider), id: c.id);
    if (!mounted) return;
    switch (result) {
      case Ok():
        _invalidate();
        context.showMessage(l10n.extCalDeleted);
      case Err(:final failure):
        context.showFailure(failure);
    }
  }

  void _invalidate() {
    ref
      ..invalidate(externalCalendarsProvider)
      ..invalidate(occurrencesProvider);
  }
}

/// "Lukas, Sabine" or "Ganze Familie": who the calendar is for.
String _membersLabel(
  AppLocalizations l10n,
  ExternalCalendar c,
  List<Member> members,
) {
  if (c.wholeFamily) return l10n.extCalMembersWhole;
  return members
      .where((m) => c.memberIds.contains(m.id))
      .map((m) => m.displayName)
      .join(', ');
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.calendar,
    required this.membersLabel,
    required this.statusText,
    required this.canManage,
    required this.refreshing,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onActiveChanged,
  });

  final ExternalCalendar calendar;
  final String membersLabel;
  final String statusText;
  final bool canManage;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ww = context.ww;
    final text = Theme.of(context).textTheme;
    final colour = calendar.colour;
    final failed = calendar.active && calendar.lastError != null;

    return Opacity(
      opacity: calendar.active ? 1 : 0.6,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space4,
            Tokens.space3,
            Tokens.space2,
            Tokens.space1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colour == null
                          ? cs.primary
                          : ww.member(colour).ink,
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(calendar.name, style: text.titleMedium),
                        Text(
                          membersLabel,
                          style: text.bodySmall?.copyWith(color: ww.ink2),
                        ),
                        const SizedBox(height: Tokens.space1),
                        Row(
                          children: [
                            if (failed) ...[
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: cs.error,
                              ),
                              const SizedBox(width: Tokens.space1),
                            ],
                            Expanded(
                              child: Text(
                                statusText,
                                style: text.bodySmall?.copyWith(
                                  color: failed ? cs.error : ww.ink2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    Semantics(
                      label: l10n.extCalActive,
                      child: Switch(
                        value: calendar.active,
                        onChanged: onActiveChanged,
                      ),
                    ),
                ],
              ),
              if (refreshing) const LinearProgressIndicator(),
              if (canManage)
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: refreshing ? null : onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.extCalRefreshNow),
                    ),
                    TextButton(onPressed: onEdit, child: Text(l10n.extCalEdit)),
                    TextButton(onPressed: onDelete, child: Text(l10n.delete)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
