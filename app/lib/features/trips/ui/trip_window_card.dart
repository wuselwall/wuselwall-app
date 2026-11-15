import 'package:flutter/material.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/domain/week_board.dart'
    show PresenceState;
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';
import 'package:wuselwall/features/trips/ui/trip_labels.dart';

/// One proposed time window (specs/30 "Time windows"): its dates, length, the Ferien or
/// holiday it lies in, the leave days, who is free earlier or longer, and what is in the
/// way, by day. Which of the actions shows depends on whether the page is choosing dates
/// for a trip ([onTake]) or looking for a window to start from ([onWhere], [onNewTrip]).
class TripWindowCard extends StatelessWidget {
  const TripWindowCard({
    required this.window,
    required this.members,
    this.onTake,
    this.onWhere,
    this.onNewTrip,
    super.key,
  });

  final TripWindow window;
  final List<Member> members;
  final VoidCallback? onTake;
  final VoidCallback? onWhere;
  final VoidCallback? onNewTrip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ww = context.ww;
    final w = window;
    final name = w.name?.trim() ?? '';
    final title = name.isNotEmpty
        ? name
        : (w.kind == WindowKind.holidays
              ? l10n.tripWindowHolidaysFallback
              : '');
    final byId = {for (final m in members) m.id: m};
    final conflicts = groupWindowConflicts(context, w.conflicts);

    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.space3),
      child: Padding(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatTripDates(context, w.from, w.to),
              style: theme.textTheme.titleMedium,
            ),
            Text(
              [
                l10n.tripWindowDays(w.days),
                if (title.isNotEmpty) title,
              ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(color: ww.ink2),
            ),
            const SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (w.kind == WindowKind.longWeekend)
                  Chip(
                    label: Text(l10n.tripWindowKindLongWeekend),
                    visualDensity: VisualDensity.compact,
                  ),
                Chip(
                  label: Text(l10n.tripWindowLeave(w.leaveDays)),
                  visualDensity: VisualDensity.compact,
                ),
                if (!w.hasConflicts)
                  Chip(
                    avatar: Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: ww.success,
                    ),
                    label: Text(l10n.tripWindowFree),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            for (final p in w.partial)
              _partialLine(context, p, byId[p.profileId]),
            if (w.hasConflicts) ...[
              const SizedBox(height: Tokens.space2),
              Text(l10n.tripWindowConflicts, style: theme.textTheme.titleSmall),
              const SizedBox(height: Tokens.space1),
              for (final c in conflicts) _ConflictRow(line: c, byId: byId),
            ],
            if (onTake != null || onWhere != null || onNewTrip != null) ...[
              const SizedBox(height: Tokens.space2),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space1,
                children: [
                  if (onTake != null)
                    FilledButton(
                      onPressed: onTake,
                      child: Text(l10n.tripWindowTake),
                    ),
                  if (onWhere != null)
                    OutlinedButton(
                      onPressed: onWhere,
                      child: Text(l10n.tripWindowWhere),
                    ),
                  if (onNewTrip != null)
                    FilledButton.tonal(
                      onPressed: onNewTrip,
                      child: Text(l10n.tripWindowNewTrip),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "Lotta is free from 3 July already": days of the window's edge only some children
  /// have off.
  Widget _partialLine(BuildContext context, WindowPartial p, Member? who) {
    final l10n = context.l10n;
    final name = who?.displayName ?? '';
    final text = p.from.isBefore(window.from)
        ? l10n.tripWindowPartialBefore(name, formatTripDate(context, p.from))
        : l10n.tripWindowPartialAfter(name, formatTripDate(context, p.to));
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (who != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ExcludeSemantics(
                child: MemberDot(
                  memberColor: who.color,
                  semanticLabel: who.displayName,
                ),
              ),
            ),
            const SizedBox(width: Tokens.space2),
          ],
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// What is in the way, one line per appointment or presence entry with its days.
class WindowConflictLine {
  const WindowConflictLine({
    required this.title,
    required this.from,
    required this.to,
    required this.profileIds,
  });

  final String title;
  final DateTime from;
  final DateTime to;
  final List<String> profileIds;
}

/// The conflicts of a window by entry: the server names one per day, the page one line
/// per appointment. A presence entry reads as the household's label of its state (such as
/// "Dienstreise"), an appointment by its title.
List<WindowConflictLine> groupWindowConflicts(
  BuildContext context,
  List<WindowConflict> conflicts,
) {
  final lines = <String, WindowConflictLine>{};
  for (final c in conflicts) {
    final state = _presence(c.presenceState);
    final title = c.kind == 'presence' && state != null
        ? context.presenceLabel(state)
        : c.title;
    final key = '${c.eventId}|$title|${c.kind}';
    final old = lines[key];
    lines[key] = old == null
        ? WindowConflictLine(
            title: title,
            from: c.date,
            to: c.date,
            profileIds: c.profileIds,
          )
        : WindowConflictLine(
            title: title,
            from: c.date.isBefore(old.from) ? c.date : old.from,
            to: c.date.isAfter(old.to) ? c.date : old.to,
            profileIds: {...old.profileIds, ...c.profileIds}.toList(),
          );
  }
  return lines.values.toList()..sort((a, b) => a.from.compareTo(b.from));
}

PresenceState? _presence(String? wire) {
  if (wire == null) return null;
  try {
    return PresenceState.parse(wire);
  } on FormatException {
    return null;
  }
}

class _ConflictRow extends StatelessWidget {
  const _ConflictRow({required this.line, required this.byId});

  final WindowConflictLine line;
  final Map<String, Member> byId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ww = context.ww;
    final who = [for (final id in line.profileIds) ?byId[id]];
    final single = DateUtils.isSameDay(line.from, line.to);
    final dates = single
        ? formatTripDay(context, line.from)
        : '${formatTripDate(context, line.from)} – '
              '${formatTripDate(context, line.to)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.event_busy_outlined, size: 18, color: ww.ink2),
          ),
          const SizedBox(width: Tokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.title),
                Wrap(
                  spacing: Tokens.space2,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dates,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ww.ink2,
                      ),
                    ),
                    if (who.isNotEmpty)
                      MemberDots(
                        dots: [
                          for (final m in who)
                            MemberDot(
                              memberColor: m.color,
                              semanticLabel: m.displayName,
                              size: 12,
                            ),
                        ],
                        size: 12,
                      ),
                    if (who.isNotEmpty)
                      Text(
                        who.map((m) => m.displayName).join(', '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ww.ink2,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
