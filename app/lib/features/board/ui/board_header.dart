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
import 'package:wuselwall/features/wusel/ui/ambience_sky.dart';
import 'package:wuselwall/features/wusel/ui/board_wusel.dart';

/// The top line: the clock, the date and calendar week, the "als Nächstes" line, the
/// way to settings and, once the connection is lost, the time of the last good board.
/// Ticks with the clock.
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
    final compact = MediaQuery.textScalerOf(context).scale(24) > 32;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ww.line)),
      ),
      // The sky changes with the time of day and the occasions (specs/26).
      child: AmbienceSky(
        fallback: scheme.surface,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsets.only(left: 20, right: 8),
          // IntrinsicHeight gives the row a finite height to stretch every item to
          // (its loose Column slot alone would allow unbounded height); stretching
          // keeps the header's items full height so it can still grow past `height`
          // at larger text scales, instead of clipping or overflowing the clock and
          // date (specs/09: preserve system text scaling).
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The clock is the one thing read from across the room.
                Center(
                  child: Text(
                    context.time(TimeOfDay.fromDateTime(now)),
                    style: boardNum(
                      50,
                      weight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 18),
                // The date keeps its full length; the next-up line gives way instead.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
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
                      if (!compact)
                        Text(
                          context.l10n.boardWeekNumber(board.isoWeek),
                          style: boardNum(
                            24,
                            weight: FontWeight.w600,
                            color: ww.ink3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                    ],
                  ),
                ),
                Center(
                  child: Container(
                    width: 1,
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 22),
                    color: ww.line,
                  ),
                ),
                Expanded(
                  child: Center(
                    // On a nearly opaque pill, so the member dots never sit on the sky.
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow.withValues(
                          alpha: 0.92,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: BoardNextUp(frame: frame),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Center(child: BoardWusel(stale: snapshot.isStale)),
                if (_isOutdated(snapshot, now)) ...[
                  const SizedBox(width: 16),
                  Flexible(child: _LastUpdated(snapshot: snapshot)),
                ],
                Center(
                  child: IconButton(
                    tooltip: context.l10n.settingsTitle,
                    constraints: const BoxConstraints.tightFor(
                      width: 56,
                      height: 56,
                    ),
                    iconSize: 30,
                    color: ww.ink3,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.go(Routes.settings),
                  ),
                ),
              ],
            ),
          ),
        ),
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

/// Twice the full refetch interval: a board this old has stopped updating even when no
/// refresh has failed.
final _outdatedAfter = BoardNotifier.refetchEvery * 2;

bool _isOutdated(BoardSnapshot snapshot, DateTime now) {
  final fetchedAt = snapshot.fetchedAt;
  if (fetchedAt == null) return false;
  return snapshot.isStale || now.difference(fetchedAt) > _outdatedAfter;
}

/// While the connection is lost, or the board has not been refreshed for a while: the warning and the time of the last good board
/// (specs/09 "Freshness and failure"). A live board says nothing about its freshness:
/// "updated 4 s ago" on a board that is always current is only noise.
class _LastUpdated extends StatelessWidget {
  const _LastUpdated({required this.snapshot});

  final BoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final fetchedAt = snapshot.fetchedAt;
    if (fetchedAt == null) return const SizedBox.shrink();
    final color = context.ww.warning;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off, size: 26, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            context.l10n.boardLastUpdatedAt(
              context.time(TimeOfDay.fromDateTime(fetchedAt)),
            ),
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
