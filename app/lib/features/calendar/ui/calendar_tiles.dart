import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/emoji_picture.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/ui/event_edit_args.dart';
import 'package:wuselwall/features/calendar/ui/imported_occurrence_sheet.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/rituals/domain/event_icons.dart';

/// Below this column width an appointment shows no words: a timed block its picture
/// or its first attendee's initial, an all-day chip its picture or mark, a presence
/// band its colour. A word would break mid-syllable or end in "…" otherwise (specs/09,
/// "never break"); the tooltip and the screen reader keep the title.
const narrowColumn = 60.0;

/// Below this width a title stays on one line: two lines of a narrow column break
/// inside long words.
const _oneTitleLineBelow = 90.0;

/// Blocks shorter than this show the time and title on one line ("16:00 Klavier").
const _oneLineBelow = 44.0;

/// An appointment as the calendar draws it: a block on the time grid ([compact] false,
/// with its [width] and [height]) or a one-line chip in the all-day row ([compact]).
/// The first attendee's tint is the ground and their ink the bar; with nobody attending
/// it is brand-coloured. Tentative ones are dashed and faded; ones already over too.
class OccurrenceTile extends StatelessWidget {
  const OccurrenceTile({
    required this.occurrence,
    required this.members,
    required this.now,
    this.compact = false,
    this.width,
    this.height,
    super.key,
  });

  final Occurrence occurrence;

  /// Household members; the occurrence's attendees are looked up here.
  final List<Member> members;
  final DateTime now;

  /// One line: a chip in the all-day row.
  final bool compact;

  /// The block's size on the grid; for a chip only its width, when known.
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ww = context.ww;
    final text = Theme.of(context).textTheme;
    final attendees = [
      for (final id in occurrence.attendeeIds)
        for (final m in members)
          if (m.id == id) m,
    ];
    // An imported calendar's appointments take that calendar's colour, not a member's.
    final imported = occurrence.isImported;
    final lead = imported
        ? ww.member(colourFromHex(occurrence.colourHex) ?? cs.primary)
        : attendees.isEmpty
        ? null
        : ww.member(attendees.first.color);
    final ground = lead?.tint ?? cs.surfaceContainerHigh;
    final bar = lead?.ink ?? cs.primary;
    final past = occurrence.end.isBefore(now);
    final opacity = (occurrence.isTentative ? 0.6 : 1.0) * (past ? 0.5 : 1.0);

    final start = occurrence.localStarts;
    final end = occurrence.localEnds;
    final startText = start == null ? null : context.time(start);
    final spanText = start == null
        ? null
        : end == null
        ? startText
        : context.span(start, end);

    final titleStyle = text.labelMedium?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w600,
    );
    final timeStyle = text.labelSmall?.copyWith(
      color: ww.ink2,
      fontFamily: Tokens.fontNumeric,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // The subscription mark: the non-colour cue for an imported appointment (NFR-13).
    Widget titleText({required int maxLines, required bool softWrap}) =>
        imported
        ? Text.rich(
            TextSpan(
              style: titleStyle,
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(Icons.rss_feed, size: 11, color: ww.ink2),
                  ),
                ),
                TextSpan(text: occurrence.title),
              ],
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: softWrap,
          )
        : Text(
            occurrence.title,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: softWrap,
            style: titleStyle,
          );
    final dots = MemberDots(
      size: 8,
      dots: [
        for (final m in attendees)
          MemberDot(
            memberColor: m.color,
            size: 8,
            semanticLabel: m.displayName,
          ),
      ],
    );

    // A narrow tile's picture, when the appointment has one.
    final asset = eventIconAsset(occurrence.iconKey);
    final narrow = (width ?? double.infinity) < narrowColumn;
    final Widget content;
    if (compact && narrow) {
      content = Center(
        child: asset != null
            ? EmojiPicture(asset, size: 14)
            : imported
            ? Icon(Icons.rss_feed, size: 12, color: ww.ink2)
            : Text(
                _initial(occurrence.title),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: titleStyle,
              ),
      );
    } else if (compact) {
      content = Row(
        children: [
          Expanded(child: titleText(maxLines: 1, softWrap: false)),
          if (attendees.isNotEmpty) ...[const SizedBox(width: 4), dots],
        ],
      );
    } else {
      final w = width ?? double.infinity;
      final h = height ?? double.infinity;
      if (w < narrowColumn) {
        final initial = Text(
          attendees.isEmpty ? '' : _initial(attendees.first.displayName),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: titleStyle,
        );
        content = Center(
          child: asset == null
              ? initial
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmojiPicture(asset, size: 16),
                    if (h >= 40 && attendees.isNotEmpty) initial,
                  ],
                ),
        );
      } else if (h < _oneLineBelow) {
        content = Text.rich(
          TextSpan(
            children: [
              if (startText != null)
                TextSpan(text: '$startText ', style: timeStyle),
              if (imported)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(Icons.rss_feed, size: 11, color: ww.ink2),
                  ),
                ),
              TextSpan(text: occurrence.title, style: titleStyle),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        );
      } else {
        final titleLines = w < _oneTitleLineBelow || h < 60 ? 1 : 2;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleText(maxLines: titleLines, softWrap: titleLines > 1),
            if (spanText != null)
              Text(
                spanText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: timeStyle,
              ),
            if (h >= 80 && occurrence.location != null)
              Text(
                occurrence.location!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: text.labelSmall?.copyWith(color: ww.ink2),
              ),
            if (h >= 96 && attendees.isNotEmpty) ...[
              const SizedBox(height: 2),
              dots,
            ],
          ],
        );
      }
    }

    final label = [
      occurrence.title,
      ?spanText,
      if (narrow) ...[for (final m in attendees) m.displayName],
      if (occurrence.isTentative) l10n.boardTentative,
      if (imported) l10n.extCalSheetTitle,
    ].join(', ');

    final tile = Opacity(
      opacity: opacity,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            // Imported appointments are read-only: they open the source's details, never
            // the editor.
            onTap: imported
                ? () => showImportedOccurrenceSheet(context, occurrence)
                : () => context.push(
                    Routes.eventEdit,
                    extra: EventEditArgs(
                      eventId: occurrence.eventId,
                      occurrence: occurrence,
                    ),
                  ),
            child: CustomPaint(
              foregroundPainter: occurrence.isTentative
                  ? _DashedOutlinePainter(color: bar, radius: 6)
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ground,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ColoredBox(color: bar, child: const SizedBox(width: 3)),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 5 : 4,
                              vertical: compact ? 2 : 3,
                            ),
                            child: content,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Without its words, a narrow tile names itself on hover and long press: the
    // title, when, and who (its letter is the first attendee's initial).
    return narrow
        ? Tooltip(
            message: [
              occurrence.title,
              ?spanText,
              for (final m in attendees) m.displayName,
            ].join(' · '),
            child: tile,
          )
        : tile;
  }
}

/// The first letter of a name, upper-cased; by code point, so no half characters.
String initialOf(String name) => _initial(name);

String _initial(String name) {
  if (name.isEmpty) return '';
  return String.fromCharCode(name.runes.first).toUpperCase();
}

/// A dashed outline for a tentative appointment (specs/05: "dashed, at 60 % opacity").
class _DashedOutlinePainter extends CustomPainter {
  const _DashedOutlinePainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.75),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + 4 < metric.length ? distance + 4 : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedOutlinePainter old) =>
      old.color != color || old.radius != radius;
}
