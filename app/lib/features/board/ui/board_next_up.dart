import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/motion.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_fit.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_primitives.dart';

/// The "als Nächstes" line in the header: the one piece of urgency the board carries
/// (specs/09). Shows the next timed thing today, or the meal if that comes first, with a
/// countdown, then the one after it when that fits too. At night, with nothing left today, tomorrow's first
/// appointment.
class BoardNextUp extends ConsumerStatefulWidget {
  const BoardNextUp({required this.frame, super.key});

  final BoardFrame frame;

  @override
  ConsumerState<BoardNextUp> createState() => _BoardNextUpState();
}

class _BoardNextUpState extends ConsumerState<BoardNextUp>
    with SingleTickerProviderStateMixin {
  /// Two pulses when the next thing changes, then a solid dot. The wall must not move
  /// all day (specs/26 "Protecting the wall": nothing moves at two metres but the clock
  /// and a moment that just happened), so the dot never pulses on its own.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
    value: 1,
  );

  /// The next thing the dot last pulsed for (see [_nextKey]).
  String? _pulsedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: the dot stays solid and nothing animates.
    if (!motionAllowed(context) && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Starts the two pulses after this frame when [key], the next thing, is new.
  void _pulseIfNew(String? key) {
    if (key == _pulsedFor) return;
    _pulsedFor = key;
    if (key == null || !motionAllowed(context)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pulse.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider);
    _pulseIfNew(_nextKey(now));
    return Row(
      children: [
        FadeTransition(
          opacity: _pulse.drive(const _TwoPulses()),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: _content(context, now)),
      ],
    );
  }

  /// What the line names as next: the first upcoming thing today, tomorrow's first
  /// appointment at night, or null for nothing. The countdown is left out, so the
  /// minute ticking on does not count as a change.
  String? _nextKey(DateTime now) {
    final frame = widget.frame;
    final today = frame.todayIndex;
    if (today == null) return null;
    final nowMinutes = now.hour * 60 + now.minute;
    final upcoming = _upcomingOf(
      frame.board,
      today,
    ).where((u) => minutesOf(u.start) > nowMinutes);
    if (upcoming.isNotEmpty) return 'today ${upcoming.first.key}';
    final tomorrow = today + 1;
    final next = frame.night && tomorrow < BoardGeometry.dayCount
        ? _firstTimedEvent(frame.board.days[tomorrow])
        : null;
    return next == null ? null : 'tomorrow ${next.key}';
  }

  Widget _content(BuildContext context, DateTime now) {
    final frame = widget.frame;
    final board = frame.board;
    final today = frame.todayIndex;
    final l10n = context.l10n;
    final ww = context.ww;
    final ink = Theme.of(context).colorScheme.onSurface;
    if (today == null) return const SizedBox.shrink();

    final nowMinutes = now.hour * 60 + now.minute;
    final upcoming = _upcomingOf(
      board,
      today,
    ).where((u) => minutesOf(u.start) > nowMinutes).toList();

    if (upcoming.isEmpty) {
      final tomorrow = today + 1;
      final next = frame.night && tomorrow < BoardGeometry.dayCount
          ? _firstTimedEvent(board.days[tomorrow])
          : null;
      if (next == null) {
        return _line(l10n.boardNothingMoreToday, ww.ink2);
      }
      return Row(
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${context.weekdayShort(board.days[tomorrow].date)} ',
                    style: boardUi(26, weight: FontWeight.w700, color: ww.ink2),
                  ),
                  TextSpan(
                    text: '${context.time(next.start)} ',
                    style: boardNum(28, weight: FontWeight.w700, color: ink),
                  ),
                  TextSpan(
                    text: next.title,
                    style: boardUi(26, weight: FontWeight.w700, color: ink),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      );
    }

    final first = upcoming[0];
    final inMinutes = minutesOf(first.start) - nowMinutes;
    final countdown = inMinutes >= 60
        ? l10n.boardInHours(inMinutes ~/ 60, inMinutes % 60)
        : l10n.boardInMinutes(inMinutes);
    final second = upcoming.length > 1 ? upcoming[1] : null;

    final firstText = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${context.time(first.start)} ',
            style: boardNum(28, weight: FontWeight.w700, color: ink),
          ),
          TextSpan(
            text: first.title,
            style: boardUi(26, weight: FontWeight.w700, color: ink),
          ),
          TextSpan(
            text: ' · $countdown',
            style: boardUi(26, weight: FontWeight.w500, color: ww.ink2),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
    final dots = MemberDots(
      dots: _dots(context, board, first.memberIds),
      size: 14,
    );

    // The first thing is the urgency and is shown whole; "danach …" only when it
    // fits beside it, never as two halves that both end in an ellipsis.
    return FirstThatFits(
      children: [
        if (second != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              firstText,
              const SizedBox(width: Tokens.space3),
              dots,
              const SizedBox(width: Tokens.space4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${l10n.boardThen} ',
                      style: boardUi(26, color: ww.ink2),
                    ),
                    TextSpan(
                      text: '${context.time(second.start)} ',
                      style: boardNum(26, color: ww.ink2),
                    ),
                    TextSpan(
                      text: second.title,
                      style: boardUi(26, color: ww.ink2),
                    ),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            firstText,
            const SizedBox(width: Tokens.space3),
            dots,
          ],
        ),
        // A title too long for the whole line: it ends in an ellipsis before the
        // dots (specs/09 "Degradation rules"). The dots and the gap need about 90 px,
        // which the header leaves the line at every text scale.
        Row(
          children: [
            Expanded(child: firstText),
            const SizedBox(width: Tokens.space3),
            dots,
          ],
        ),
      ],
    );
  }

  Widget _line(String text, Color color) => Text(
    text,
    style: boardUi(26, weight: FontWeight.w500, color: color),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    softWrap: false,
  );

  List<MemberDot> _dots(
    BuildContext context,
    WeekBoard board,
    List<String> ids,
  ) => [
    for (final id in ids)
      if (board.member(id) case final m?)
        MemberDot(
          memberColor: m.color,
          semanticLabel: context.memberName(board, m),
          size: 14,
        ),
  ];
}

/// A timed thing that can be "next": an appointment, or today's meal when it is planned.
class _Upcoming {
  const _Upcoming({
    required this.start,
    required this.title,
    required this.memberIds,
  });

  final TimeOfDay start;
  final String title;
  final List<String> memberIds;

  /// Identifies this thing for [_BoardNextUpState._nextKey].
  String get key => '${minutesOf(start)} $title';
}

/// The dot's opacity over the controller's run: full, dimmed and back, twice, ending
/// full, so the controller at rest (0 or 1) shows a solid dot.
class _TwoPulses extends Animatable<double> {
  const _TwoPulses();

  @override
  double transform(double t) => 1 - 0.65 * (1 - math.cos(4 * math.pi * t)) / 2;
}

List<_Upcoming> _upcomingOf(WeekBoard board, int dayIndex) {
  final day = board.days[dayIndex];
  final items = <_Upcoming>[
    for (final e in day.events)
      if (e.starts case final start?)
        _Upcoming(start: start, title: e.title, memberIds: e.attendeeIds),
  ];
  final meal = day.meal;
  if (meal != null && meal.isPlanned && meal.time != null) {
    items.add(
      _Upcoming(
        start: meal.time!,
        title: meal.title!,
        memberIds: [?meal.cookId],
      ),
    );
  }
  items.sort((a, b) => minutesOf(a.start).compareTo(minutesOf(b.start)));
  return items;
}

_Upcoming? _firstTimedEvent(BoardDay day) {
  for (final e in day.events) {
    if (e.starts case final start?) {
      return _Upcoming(start: start, title: e.title, memberIds: e.attendeeIds);
    }
  }
  return null;
}
