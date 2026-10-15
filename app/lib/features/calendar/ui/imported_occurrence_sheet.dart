import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/calendar/application/external_calendar_providers.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';

/// Opens an imported occurrence read-only. It never opens the event editor: the source
/// owns the appointment (specs/05, FR-1.9).
Future<void> showImportedOccurrenceSheet(
  BuildContext context,
  Occurrence occurrence,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (_) => ImportedOccurrenceSheet(occurrence: occurrence),
);

class ImportedOccurrenceSheet extends ConsumerWidget {
  const ImportedOccurrenceSheet({required this.occurrence, super.key});

  final Occurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ww = context.ww;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final calendars = ref.watch(externalCalendarsProvider).value ?? const [];
    final calendar = calendars
        .where((c) => c.id == occurrence.calendarId)
        .firstOrNull;
    final colour = colourFromHex(occurrence.colourHex) ?? cs.primary;

    final day = context.fullDate(occurrence.localStartDate);
    final start = occurrence.localStarts;
    final end = occurrence.localEnds;
    final when = start == null
        ? '$day · ${l10n.extCalAllDay}'
        : end == null
        ? '$day · ${context.time(start)}'
        : '$day · ${context.span(start, end)}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Tokens.space4,
          0,
          Tokens.space4,
          Tokens.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.extCalSheetTitle,
              style: text.labelMedium?.copyWith(color: ww.ink2),
            ),
            const SizedBox(height: Tokens.space1),
            Text(occurrence.title, style: text.headlineSmall),
            const SizedBox(height: Tokens.space2),
            Text(when, style: text.bodyLarge),
            if (occurrence.location != null) ...[
              const SizedBox(height: Tokens.space2),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 18, color: ww.ink2),
                  const SizedBox(width: Tokens.space1),
                  Expanded(
                    child: Text(occurrence.location!, style: text.bodyMedium),
                  ),
                ],
              ),
            ],
            if (calendar != null) ...[
              const SizedBox(height: Tokens.space2),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colour,
                    ),
                  ),
                  const SizedBox(width: Tokens.space2),
                  Expanded(
                    child: Text(
                      l10n.extCalFromCalendar(calendar.name),
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Tokens.space4),
            DecoratedBox(
              decoration: BoxDecoration(
                color: ww.sunken,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Tokens.space3),
                child: Row(
                  children: [
                    Icon(Icons.rss_feed, size: 20, color: ww.ink2),
                    const SizedBox(width: Tokens.space2),
                    Expanded(
                      child: Text(
                        l10n.extCalImportedNote,
                        style: text.bodyMedium?.copyWith(color: ww.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
