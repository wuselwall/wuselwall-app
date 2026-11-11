import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/application/event_share_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/event_ics.dart';
import 'package:wuselwall/features/settings/application/household_export_providers.dart';

/// "Termin teilen" (specs/05 "Sharing one event"): shows what would leave the household,
/// then hands one `.ics` file to the platform's share sheet. [event] is the saved event;
/// [occurrence] is the date of a series the editor was opened on, if any.
Future<void> showShareEventSheet(
  BuildContext context, {
  required CalendarEvent event,
  Occurrence? occurrence,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ShareEventSheet(event: event, occurrence: occurrence),
);

class _ShareEventSheet extends ConsumerStatefulWidget {
  const _ShareEventSheet({required this.event, this.occurrence});

  final CalendarEvent event;
  final Occurrence? occurrence;

  @override
  ConsumerState<_ShareEventSheet> createState() => _ShareEventSheetState();
}

class _ShareEventSheetState extends ConsumerState<_ShareEventSheet> {
  /// Only the tapped date of a series, the likelier wish ("this Spieleabend").
  late bool _onlyThis = widget.occurrence != null;
  bool _includeNote = false;
  ShareReminder _reminder = ShareReminder.none;
  bool _busy = false;

  Occurrence? get _occurrence => _onlyThis ? widget.occurrence : null;

  String get _title => _occurrence?.title ?? widget.event.title;

  String? get _location {
    final v = (_occurrence?.location ?? widget.event.location)?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  String? get _note {
    final v = (_occurrence?.description ?? widget.event.description)?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  bool get _allDay => _occurrence?.allDay ?? widget.event.isAllDay;

  /// The time as the event's own zone has it, which is what the file says.
  String _when(BuildContext context) {
    final occurrence = _occurrence;
    final event = widget.event;
    if (_allDay) {
      final start = occurrence?.localStartDate ?? event.startDate!;
      final end = occurrence?.localEndDate ?? event.endDate ?? start;
      return start == end
          ? context.fullDate(start)
          : '${context.fullDate(start)} – ${context.fullDate(end)}';
    }
    final zone = eventZone(event.timezone);
    DateTime wall(DateTime at) =>
        zone == null ? at.toLocal() : tz.TZDateTime.from(at, zone);
    final start = wall(occurrence?.start ?? event.startsAt!);
    final endAt = occurrence?.end ?? event.endsAt;
    final end = endAt == null ? null : wall(endAt);
    final from =
        '${context.fullDate(start)}, ${context.time(TimeOfDay.fromDateTime(start))}';
    if (end == null) return from;
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final to = context.time(TimeOfDay.fromDateTime(end));
    return sameDay ? '$from – $to' : '$from – ${context.fullDate(end)}, $to';
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final text = renderSharedEvent(
      event: widget.event,
      now: ref.read(nowProvider),
      zone: eventZone(widget.event.timezone),
      occurrence: _occurrence,
      includeNote: _includeNote,
      reminder: _reminder,
    );
    await ref.read(shareExportProvider)(
      fileName: sharedEventFileName(_title),
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: 'text/calendar',
      origin: origin,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canChooseScope =
        widget.occurrence != null && widget.event.isRecurring;
    final note = _note;
    final location = _location;
    final sendsSeries = _occurrence == null && widget.event.isRecurring;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          0,
          Tokens.space4,
          Tokens.space4,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.eventShare, style: theme.textTheme.titleLarge),
              const SizedBox(height: Tokens.space1),
              Text(l10n.eventShareHelp, style: theme.textTheme.bodySmall),
              if (canChooseScope) ...[
                const SizedBox(height: Tokens.space3),
                SegmentedButton<bool>(
                  key: const ValueKey('share-event-scope'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.eventScopeThis),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.eventScopeSeries),
                    ),
                  ],
                  selected: {_onlyThis},
                  onSelectionChanged: (v) =>
                      setState(() => _onlyThis = v.first),
                ),
              ],
              const SizedBox(height: Tokens.space3),
              Text(l10n.eventShareSent, style: theme.textTheme.labelLarge),
              const SizedBox(height: Tokens.space1),
              DecoratedBox(
                key: const ValueKey('share-event-preview'),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(Tokens.space2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Tokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title, style: theme.textTheme.titleMedium),
                      Text(_when(context)),
                      if (location != null) Text(location),
                      if (_includeNote && note != null) ...[
                        const SizedBox(height: Tokens.space1),
                        Text(note, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space1),
              Text(l10n.eventShareNotSent, style: theme.textTheme.bodySmall),
              if (sendsSeries) ...[
                const SizedBox(height: Tokens.space1),
                Text(
                  l10n.eventShareSeriesNote,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (note != null)
                SwitchListTile(
                  key: const ValueKey('share-event-note'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.eventShareIncludeNote),
                  value: _includeNote,
                  onChanged: (v) => setState(() => _includeNote = v),
                ),
              const SizedBox(height: Tokens.space2),
              Text(l10n.eventShareReminder, style: theme.textTheme.labelLarge),
              const SizedBox(height: Tokens.space1),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final (value, label) in [
                    (ShareReminder.none, l10n.eventShareReminderNone),
                    if (!_allDay)
                      (ShareReminder.hourBefore, l10n.eventShareReminderHour),
                    (ShareReminder.dayBefore, l10n.eventShareReminderDay),
                  ])
                    ChoiceChip(
                      key: ValueKey('share-event-reminder-${value.name}'),
                      label: Text(label),
                      selected: _reminder == value,
                      onSelected: (_) => setState(() => _reminder = value),
                    ),
                ],
              ),
              const SizedBox(height: Tokens.space1),
              Text(
                l10n.eventShareReminderHelp,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: Tokens.space4),
              FilledButton.icon(
                key: const ValueKey('share-event-send'),
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: Text(l10n.eventShareSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
