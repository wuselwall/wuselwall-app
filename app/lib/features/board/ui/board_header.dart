import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';
import 'package:wuselwall/features/board/ui/board_grid.dart';
import 'package:wuselwall/features/board/ui/board_next_up.dart';

/// The top line: the clock, the date and calendar week, the "als Nächstes" line, the
/// freshness marker and the way to settings. Ticks with the clock.
class BoardHeader extends ConsumerWidget {
  const BoardHeader({required this.frame, required this.snapshot, super.key});

  static const height = 72.0;

  final BoardFrame frame;
  final BoardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = snapshot.board!;
    final now = ref.watch(nowProvider);
    final ww = context.ww;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ww.line)),
      ),
      child: Row(
        children: [
          // The clock is the one thing read from across the room.
          Text(
            context.time(TimeOfDay.fromDateTime(now)),
            style: boardNum(
              50,
              weight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            maxLines: 1,
            softWrap: false,
          ),
          const SizedBox(width: 18),
          Flexible(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.fullDate(board.today),
                  style: boardUi(
                    26,
                    weight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
                Text(
                  context.l10n.boardWeekNumber(board.isoWeek),
                  style: boardNum(24, weight: FontWeight.w600, color: ww.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 22),
            color: ww.line,
          ),
          Expanded(flex: 4, child: BoardNextUp(frame: frame)),
          const SizedBox(width: 16),
          Flexible(
            child: _Freshness(snapshot: snapshot, now: now),
          ),
          IconButton(
            tooltip: context.l10n.settingsTitle,
            constraints: const BoxConstraints.tightFor(width: 56, height: 56),
            iconSize: 30,
            color: ww.ink3,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
    );
  }
}

/// The muted banner under the header while the connection is lost: the last good board
/// stays on screen below it (specs/09 "Freshness and failure", FR-8.10).
class BoardOfflineBanner extends StatelessWidget {
  const BoardOfflineBanner({super.key});

  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final ww = context.ww;
    return Container(
      height: height,
      color: ww.warningContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 26, color: ww.onWarningContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.boardOffline,
              style: boardUi(
                24,
                weight: FontWeight.w600,
                color: ww.onWarningContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// "aktualisiert vor 4 s", or, when the connection is lost, the warning and the time of
/// the last good board (specs/09 "Freshness and failure").
class _Freshness extends StatelessWidget {
  const _Freshness({required this.snapshot, required this.now});

  final BoardSnapshot snapshot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ww = context.ww;
    final fetchedAt = snapshot.fetchedAt;
    if (fetchedAt == null) return const SizedBox.shrink();

    final String text;
    final Color color;
    if (snapshot.isStale) {
      text = l10n.boardLastUpdatedAt(
        context.time(TimeOfDay.fromDateTime(fetchedAt)),
      );
      color = ww.warning;
    } else {
      final seconds = now.difference(fetchedAt).inSeconds.clamp(0, 1 << 30);
      text = seconds < 60
          ? l10n.boardUpdatedSecondsAgo(seconds)
          : l10n.boardUpdatedMinutesAgo(seconds ~/ 60);
      color = ww.ink3;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (snapshot.isStale) ...[
          Icon(Icons.cloud_off, size: 26, color: color),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            text,
            style: boardUi(24, weight: FontWeight.w500, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}
