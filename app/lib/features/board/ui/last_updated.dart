import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/tokens.dart';
import 'package:wuselwall/app/theme/ww_colors.dart';
import 'package:wuselwall/core/cache/read_cache.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/time/clock.dart';
import 'package:wuselwall/features/board/ui/board_format.dart';

/// "last updated 17:05", and with its day once that is not today: "last updated
/// Fr 7.11., 17:05". A plan stored before a restart can be days old, and a bare time
/// would pass it off as today's (FR-8.10).
String lastUpdatedText(BuildContext context, DateTime fetchedAt, DateTime now) {
  final time = context.time(TimeOfDay.fromDateTime(fetchedAt));
  final sameDay = DateUtils.isSameDay(fetchedAt, now);
  return context.l10n.boardLastUpdatedAt(
    sameDay
        ? time
        : '${context.weekdayShort(fetchedAt)} ${context.dayMonth(fetchedAt)}, $time',
  );
}

/// The strip above a phone's or a child's pages while something on them comes from the
/// device's store, not from the server (a restart without network): it says since when.
/// Nothing while everything is live. The wall says the same in its header.
class StaleStrip extends ConsumerWidget {
  const StaleStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final since = ref.watch(staleSinceProvider);
    if (since == null) return const SizedBox.shrink();
    final now = ref.watch(
      nowProvider.select((n) => DateTime(n.year, n.month, n.day)),
    );
    final ww = context.ww;
    return Semantics(
      container: true,
      liveRegion: true,
      child: ColoredBox(
        key: const ValueKey('stale-strip'),
        color: ww.warningContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space4,
            vertical: Tokens.space2,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.cloud_off,
                  size: 20,
                  color: ww.onWarningContainer,
                ),
              ),
              const SizedBox(width: Tokens.space2),
              Expanded(
                child: Text(
                  lastUpdatedText(context, since, now),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: ww.onWarningContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
