import 'dart:math' as math;

import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/board_geometry.dart';

/// One band drawn once across a run of consecutive days where the same band is the
/// longest deviation of the member's day.
class BandRun {
  const BandRun({
    required this.band,
    required this.first,
    required this.last,
    required this.extra,
  });

  final PresenceBand band;

  /// Column indexes, inclusive.
  final int first;
  final int last;

  /// The most other bands that any day of the run also has.
  final int extra;
}

/// The bands of [memberId] to draw, as runs over the week. Consecutive days share a
/// run, so a two-day trip is one band and one label.
List<BandRun> bandRuns(WeekBoard board, String memberId) {
  final primary = <PresenceBand?>[
    for (var i = 0; i < BoardGeometry.dayCount; i++)
      board.presenceOn(memberId, i).firstOrNull,
  ];
  final runs = <BandRun>[];
  var i = 0;
  while (i < BoardGeometry.dayCount) {
    final band = primary[i];
    if (band == null) {
      i++;
      continue;
    }
    var j = i;
    while (j + 1 < BoardGeometry.dayCount && primary[j + 1]?.id == band.id) {
      j++;
    }
    var extra = 0;
    for (var k = i; k <= j; k++) {
      extra = math.max(extra, board.presenceOn(memberId, k).length - 1);
    }
    runs.add(BandRun(band: band, first: i, last: j, extra: extra));
    i = j + 1;
  }
  return runs;
}
