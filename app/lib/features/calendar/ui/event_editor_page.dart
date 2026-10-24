import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';
import 'package:wuselwall/core/ui/ringed_avatar.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/application/calendar_providers.dart';
import 'package:wuselwall/features/calendar/data/calendar_repository.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/editor/event_draft.dart';
import 'package:wuselwall/features/calendar/ui/editor/presence_state_picker.dart';
import 'package:wuselwall/features/calendar/ui/editor/repeat_section.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/ui/event_ritual_fields.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';
import 'package:wuselwall/features/settings/domain/household_setting.dart';

/// The adult event editor (specs/05, specs/15, specs/21): a new event or an existing
/// one, loaded by id. A change to one occurrence of a series asks whether it applies to
/// that occurrence or to the whole series.
class EventEditorPage extends ConsumerWidget {
  const EventEditorPage({this.args, super.key});

  final EventEditArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = args?.eventId;
    if (id == null) return _EventEditorForm(args: args);
    final loaded = ref.watch(calendarEventProvider(id));
    return loaded.when(
      data: (event) => _EventEditorForm(args: args, initial: event),
      loading: () => _Frame(
        title: context.l10n.eventEditTitle,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _Frame(
        title: context.l10n.eventEditTitle,
        child: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(calendarEventProvider(id)),
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: child,
  );
}

enum _Scope { thisOccurrence, series }

class _EventEditorForm extends ConsumerStatefulWidget {
  const _EventEditorForm({this.args, this.initial});

  final EventEditArgs? args;

  /// Null for a new event.
  final CalendarEvent? initial;

  @override
  ConsumerState<_EventEditorForm> createState() => _EventEditorFormState();
}

class _EventEditorFormState extends ConsumerState<_EventEditorForm> {
  late final EventDraft _draft;
  late final TextEditingController _titleText;
  late final TextEditingController _notesText;
  late final TextEditingController _locationText;
  bool _submitted = false;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  /// The occurrence this editor was opened on, when it belongs to a series.
  Occurrence? get _seriesOccurrence {
    final occurrence = widget.args?.occurrence;
    if (occurrence == null || !occurrence.isRecurring) return null;
    return occurrence.recurrenceId == null ? null : occurrence;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _draft = EventDraft.fromEvent(initial);
    } else {
      final now = ref.read(nowProvider);
      final day = widget.args?.date ?? now;
      final actor = ref.read(actingProfileProvider);
      _draft = EventDraft.forNew(
        day: DateTime(day.year, day.month, day.day),
        startHour: math.min(now.hour + 1, 23),
        attendeeIds: {?actor},
      );
    }
    _titleText = TextEditingController(text: _draft.title);
    _notesText = TextEditingController(text: _draft.notes);
    _locationText = TextEditingController(text: _draft.location);
  }

  @override
  void dispose() {
    _titleText.dispose();
    _notesText.dispose();
    _locationText.dispose();
    super.dispose();
  }

  void _syncText() {
    _draft
      ..title = _titleText.text
      ..notes = _notesText.text
      ..location = _locationText.text;
  }

  /// Members in household order, the chosen attendees first in that order. Attendees
  /// the list does not know about are kept at the end.
  List<String> _orderedAttendees(List<Member> members) {
    final chosen = _draft.attendeeIds;
    final ordered = [
      for (final m in members)
        if (chosen.contains(m.id)) m.id,
    ];
    return [...ordered, ...chosen.where((id) => !ordered.contains(id))];
  }

  /// What `calendar.key_default` says about the current attendees.
  bool _defaultKey({
    required List<SettingEntry> settings,
    required List<Member> members,
    required String? actor,
    required String? deviceId,
  }) {
    final entry = resolveSetting(
      settings,
      'calendar.key_default',
      profileId: actor,
      deviceId: deviceId,
    );
    return defaultKeyFor(
      setting: (entry?.value ?? entry?.defaultValue) as String?,
      attendees: _draft.attendeeIds,
      activeMembers: members.where((m) => m.active).map((m) => m.id),
    );
  }

  CalendarEvent _eventNow(List<Member> members, bool key) =>
      _draft.toEvent(attendees: _orderedAttendees(members), key: key);

  Future<_Scope?> _askScope(String title) => showDialog<_Scope>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, _Scope.thisOccurrence),
          child: Text(context.l10n.eventScopeThis),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, _Scope.series),
          child: Text(context.l10n.eventScopeSeries),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    _syncText();
    setState(() => _submitted = true);
    if (_draft.validate() != null) return;

    final members = ref.read(membersProvider).value ?? const <Member>[];
    final key = _draft.effectiveKey(
      _defaultKey(
        settings: ref.read(householdSettingsProvider).value ?? const [],
        members: members,
        actor: ref.read(actingProfileProvider),
        deviceId: ref.read(deviceProvider).value?.deviceId,
      ),
    );
    final series = _seriesOccurrence;
    _Scope? scope;
    if (series != null) {
      scope = await _askScope(context.l10n.eventScopeTitle);
      if (scope == null || !mounted) return;
    }

    final actor = ref.read(actingProfileProvider);
    final repo = ref.read(calendarRepositoryProvider);
    setState(() => _saving = true);
    final Result<String> result = scope == _Scope.thisOccurrence
        ? await repo.saveOverride(
            actor: actor,
            eventId: series!.eventId,
            recurrenceId: series.recurrenceId!,
            patch: _draft.occurrencePatch(),
          )
        : await repo.save(actor: actor, event: _eventNow(members, key));
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(occurrencesProvider);
        context.pop();
      case Err(:final failure):
        setState(() => _saving = false);
        context.showFailure(failure);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final series = _seriesOccurrence;
    final actor = ref.read(actingProfileProvider);
    final repo = ref.read(calendarRepositoryProvider);
    final eventId = widget.initial?.id;
    if (eventId == null) return;

    final Result<void> result;
    if (series != null) {
      final scope = await _askScope(l10n.eventScopeDeleteTitle);
      if (scope == null || !mounted) return;
      setState(() => _saving = true);
      result = scope == _Scope.thisOccurrence
          ? (await repo.saveOverride(
              actor: actor,
              eventId: eventId,
              recurrenceId: series.recurrenceId!,
              cancelled: true,
            )).map((_) {})
          : await repo.delete(actor: actor, id: eventId);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.eventDeleteConfirm),
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
      if (confirmed != true || !mounted) return;
      setState(() => _saving = true);
      result = await repo.delete(actor: actor, id: eventId);
    }
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(occurrencesProvider);
        context.pop();
      case Err(:final failure):
        setState(() => _saving = false);
        context.showFailure(failure);
    }
  }

  Future<void> _pickDay({required bool isStart}) async {
    final current = isStart ? _draft.start : _draft.end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final day = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      );
      isStart ? _draft.moveStart(day) : _draft.setEnd(day);
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _draft.start : _draft.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final at = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
      isStart ? _draft.moveStart(at) : _draft.setEnd(at);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final settings = ref.watch(householdSettingsProvider).value ?? const [];
    final actor = ref.watch(actingProfileProvider);
    final deviceId = ref.watch(deviceProvider).value?.deviceId;
    final activeMembers = members.where((m) => m.active).toList();
    final key = _draft.effectiveKey(
      _defaultKey(
        settings: settings,
        members: members,
        actor: actor,
        deviceId: deviceId,
      ),
    );
    final error = _submitted ? _draft.validate() : null;
    final firstAttendee = [
      for (final m in members)
        if (_draft.attendeeIds.contains(m.id)) m,
    ].firstOrNull;
    final timed = !_draft.isAllDay;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.eventEditTitle : l10n.calendarNewEvent),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _titleText,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.eventTitleLabel,
              errorText: error == DraftError.titleRequired
                  ? l10n.eventTitleRequired
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<EventKind>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: EventKind.appointment,
                label: Text(l10n.eventKindAppointment),
              ),
              ButtonSegment(
                value: EventKind.presence,
                label: Text(l10n.eventKindPresence),
              ),
            ],
            selected: {_draft.kind},
            onSelectionChanged: (kinds) =>
                setState(() => _draft.kind = kinds.first),
          ),
          if (_draft.kind == EventKind.presence) ...[
            const SizedBox(height: 16),
            Text(
              l10n.eventPresenceState,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            PresenceStatePicker(
              selected: _draft.presenceState,
              memberColor: firstAttendee?.color ?? scheme.primary,
              errorText: error == DraftError.presenceStateRequired
                  ? l10n.eventPresenceStateRequired
                  : null,
              onChanged: (state) =>
                  setState(() => _draft.presenceState = state),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.eventAllDay),
            value: _draft.isAllDay,
            onChanged: (value) => setState(() => _draft.setAllDay(value)),
          ),
          _WhenRow(
            label: l10n.eventStarts,
            day: _draft.start,
            time: timed ? _draft.start : null,
            onDay: () => _pickDay(isStart: true),
            onTime: () => _pickTime(isStart: true),
          ),
          _WhenRow(
            label: l10n.eventEnds,
            day: _draft.end,
            time: timed ? _draft.end : null,
            onDay: () => _pickDay(isStart: false),
            onTime: () => _pickTime(isStart: false),
          ),
          if (error == DraftError.endBeforeStart)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.eventEndBeforeStart,
                style: TextStyle(color: scheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            l10n.eventAttendees,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in activeMembers)
                FilterChip(
                  showCheckmark: false,
                  avatar: RingedAvatar(
                    selected: _draft.attendeeIds.contains(m.id),
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
                  selected: _draft.attendeeIds.contains(m.id),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _draft.attendeeIds.add(m.id);
                    } else {
                      _draft.attendeeIds.remove(m.id);
                    }
                  }),
                ),
            ],
          ),
          if (_draft.attendeeIds.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.eventAttendeesWholeFamily),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationText,
            decoration: InputDecoration(labelText: l10n.eventLocation),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesText,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(labelText: l10n.eventNotes),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.eventTentative),
            value: _draft.tentative,
            onChanged: (value) => setState(() => _draft.tentative = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.eventKeyDisplay),
            value: key,
            // A tradition is always on the wall (specs/27).
            onChanged: _draft.tradition
                ? null
                : (value) => setState(() {
                    _draft
                      ..keyTouched = true
                      ..key = value;
                  }),
          ),
          const SizedBox(height: 16),
          RepeatSection(
            recurrence: _draft.recurrence,
            start: _draft.start,
            weekdaysError: error == DraftError.weekdaysRequired,
            onChanged: (recurrence) =>
                setState(() => _draft.recurrence = recurrence),
          ),
          // A picture, Vorfreude and traditions (specs/27), after the repeat.
          if (_draft.kind != EventKind.presence)
            EventRitualFields(draft: _draft, onChanged: () => setState(() {})),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}

/// One start or end row: a day button, and a time button for a timed event.
class _WhenRow extends StatelessWidget {
  const _WhenRow({
    required this.label,
    required this.day,
    required this.time,
    required this.onDay,
    required this.onTime,
  });

  final String label;
  final DateTime day;

  /// Null for an all-day event.
  final DateTime? time;
  final VoidCallback onDay;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: onDay,
            child: Text(
              '${context.weekdayShort(day)} ${context.dayMonth(day)}',
            ),
          ),
        ),
        if (time != null) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onTime,
            child: Text(
              context.time(TimeOfDay.fromDateTime(time!)),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
