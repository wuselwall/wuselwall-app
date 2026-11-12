import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/content_width.dart';
import 'package:wuselwall/core/ui/ringed_avatar.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/application/event_import_providers.dart';
import 'package:wuselwall/features/calendar/application/event_share_providers.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/ics_import.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';

/// "Termin übernehmen" (specs/05 "Sharing one event", the receiving side): shows the one
/// event of a calendar file somebody sent, and adds it to the family calendar as the
/// family's own event once a guardian says so. Nothing is saved before that.
///
/// When the family already took this event (the server knows the file's UID), the file
/// replaces that copy instead of adding a second one.
class ImportEventPage extends ConsumerStatefulWidget {
  const ImportEventPage({required this.bytes, super.key});

  /// The file as it arrived.
  final Uint8List bytes;

  @override
  ConsumerState<ImportEventPage> createState() => _ImportEventPageState();
}

class _ImportEventPageState extends ConsumerState<ImportEventPage> {
  ImportedEvent? _event;
  IcsImportProblem? _problem;
  Object? _loadError;

  /// The copy the family already has, if the server knows one.
  ImportedCopy? _copy;
  final _attendees = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _problem = null;
    });
    try {
      final household = await ref.read(householdInfoProvider.future);
      final ImportedEvent event;
      try {
        event = parseSharedEvent(
          widget.bytes,
          zoneOf: eventZone,
          // A family zone the database does not know is unheard of; UTC then.
          familyZone: eventZone(household.timezone) ?? tz.UTC,
        );
      } on IcsImportException catch (e) {
        if (mounted) setState(() => _problem = e.problem);
        return;
      }
      ImportedCopy? copy;
      final uid = event.uid;
      if (uid != null && ref.read(eventImportSupportedProvider)) {
        final repo = ref.read(calendarRepositoryProvider);
        final actor = ref.read(actingProfileProvider);
        copy = (await repo.importLookup(actor: actor, uid: uid)).unwrap();
        if (copy != null && !copy.own) {
          // An update keeps the people the family chose for its copy.
          final existing = (await repo.event(copy.eventId)).unwrap();
          _attendees.addAll(existing.attendeeIds);
        }
      }
      if (!mounted) return;
      setState(() {
        _event = event;
        _copy = copy;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  String _when(BuildContext context, ImportedEvent e) {
    if (e.isAllDay) {
      final start = e.startDate!;
      final end = e.endDate ?? start;
      return start == end
          ? context.fullDate(start)
          : '${context.fullDate(start)} – ${context.fullDate(end)}';
    }
    final start = e.startsAt!.toLocal();
    final end = e.endsAt!.toLocal();
    final from =
        '${context.fullDate(start)}, ${context.time(TimeOfDay.fromDateTime(start))}';
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final to = context.time(TimeOfDay.fromDateTime(end));
    return sameDay ? '$from – $to' : '$from – ${context.fullDate(end)}, $to';
  }

  Future<void> _save() async {
    final imported = _event;
    if (imported == null || _saving) return;
    final l10n = context.l10n;
    final members = ref.read(membersProvider).value ?? const <Member>[];
    final copy = _copy;
    final event = imported.toEvent(
      fallbackTitle: l10n.eventKindAppointment,
      // Household order, as the editor saves it.
      attendeeIds: [
        for (final m in members)
          if (_attendees.contains(m.id)) m.id,
      ],
      id: copy?.eventId,
    );
    final repo = ref.read(calendarRepositoryProvider);
    final actor = ref.read(actingProfileProvider);
    final uid = imported.uid;
    setState(() => _saving = true);
    final result = uid != null && ref.read(eventImportSupportedProvider)
        ? await repo.importEvent(
            actor: actor,
            event: event,
            uid: uid,
            sequence: imported.sequence,
          )
        : await repo.save(actor: actor, event: event);
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(occurrencesProvider);
        context.showMessage(
          copy == null ? l10n.eventImportAdded : l10n.eventImportUpdated,
        );
        context.pop(true);
      case Err(:final failure):
        setState(() => _saving = false);
        context.showFailure(failure);
    }
  }

  String _problemText(BuildContext context, IcsImportProblem problem) {
    final l10n = context.l10n;
    return switch (problem) {
      IcsImportProblem.tooLarge => l10n.eventImportTooLarge,
      IcsImportProblem.notAnEvent => l10n.eventImportNotAnEvent,
      IcsImportProblem.severalEvents => l10n.eventImportSeveral,
      IcsImportProblem.cancelled => l10n.eventImportCancelled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final event = _event;
    final problem = _problem;
    final copy = _copy;

    Widget body;
    final known =
        ref.watch(deviceProvider).hasValue &&
        ref.watch(membersProvider).hasValue;
    if (!known) {
      // Right after the app was opened with a file: who is acting is not loaded yet.
      body = const Center(child: CircularProgressIndicator());
    } else if (!ref.watch(canImportEventProvider)) {
      body = _Note(text: l10n.eventImportParentsOnly);
    } else if (problem != null) {
      body = _Note(text: _problemText(context, problem));
    } else if (_loadError != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.eventImportUnreadable),
            const SizedBox(height: Tokens.space2),
            OutlinedButton(
              onPressed: () => unawaited(_load()),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    } else if (event == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final members = (ref.watch(membersProvider).value ?? const <Member>[])
          .where((m) => m.active)
          .toList();
      final repeats = event.rrule != null || event.rdates.isNotEmpty;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            copy == null
                ? l10n.eventImportIntro
                : copy.own
                ? l10n.eventImportOwn
                : l10n.eventImportExisting,
          ),
          const SizedBox(height: Tokens.space3),
          DecoratedBox(
            key: const ValueKey('import-event-preview'),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(Tokens.space2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Tokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title.isEmpty
                        ? l10n.eventKindAppointment
                        : event.title,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(_when(context, event)),
                  if (repeats) Text(l10n.eventImportRepeats),
                  if (event.location != null) Text(event.location!),
                  if (event.description != null) ...[
                    const SizedBox(height: Tokens.space1),
                    Text(
                      event.description!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (event.repeatDropped) ...[
            const SizedBox(height: Tokens.space1),
            Text(
              l10n.eventImportRepeatDropped,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (copy != null && copy.own) ...[
            const SizedBox(height: Tokens.space4),
            FilledButton(
              key: const ValueKey('import-event-open'),
              onPressed: () => context.pushReplacement(
                Routes.eventEdit,
                extra: EventEditArgs(eventId: copy.eventId),
              ),
              child: Text(l10n.eventImportOpen),
            ),
          ] else ...[
            const SizedBox(height: Tokens.space4),
            Text(l10n.eventAttendees, style: theme.textTheme.titleSmall),
            const SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                for (final m in members)
                  FilterChip(
                    showCheckmark: false,
                    avatar: RingedAvatar(
                      selected: _attendees.contains(m.id),
                      child: MemberAvatar(
                        member: BoardMember(
                          id: m.id,
                          displayName: m.displayName,
                          color: m.color,
                          kind: MemberKind.adult,
                        ),
                        size: 24,
                      ),
                    ),
                    label: Text(m.displayName),
                    selected: _attendees.contains(m.id),
                    onSelected: (on) => setState(() {
                      on ? _attendees.add(m.id) : _attendees.remove(m.id);
                    }),
                  ),
              ],
            ),
            if (_attendees.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space1),
                child: Text(l10n.eventAttendeesWholeFamily),
              ),
            const SizedBox(height: Tokens.space6),
            FilledButton(
              key: const ValueKey('import-event-save'),
              onPressed: _saving ? null : _save,
              child: Text(
                copy == null ? l10n.eventImportAdd : l10n.eventImportUpdate,
              ),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.eventImportTitle)),
      body: ContentWidth(maxWidth: 640, child: body),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Tokens.space6),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
