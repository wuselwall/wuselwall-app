import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart' show minutesOf;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart';

/// The time grid's span. Earlier or later appointments are not drawn on the grid; the
/// day detail (a later screen) lists everything.
const gridStartHour = 6;
const gridEndHour = 22;
const _gridStart = gridStartHour * 60;
const _gridEnd = gridEndHour * 60;

/// A timed appointment placed on one day's column, in minutes from midnight, clipped to
/// the grid. [lane] of [lanes] splits the column when appointments overlap.
class DayBlock {
  DayBlock(this.occurrence, this.start, this.end);

  final Occurrence occurrence;
  final int start;
  final int end;
  int lane = 0;
  int lanes = 1;
}

/// The timed, non-presence occurrences that touch [day], placed and laid out side by
/// side where they overlap. Presence is drawn as bands, all-day ones as chips.
List<DayBlock> timedBlocksOn(
  DateTime day,
  Iterable<Occurrence> occurrences, {
  int minimumDisplayMinutes = 0,
}) {
  final d = dateOnly(day);
  final blocks = <DayBlock>[];
  for (final o in occurrences) {
    if (o.allDay || o.isPresence || !o.coversDay(d)) continue;
    final startHere = dateOnly(o.localStartDate) == d;
    final endHere = dateOnly(o.localEndDate) == d;
    final from = startHere && o.localStarts != null
        ? _minutes(o.localStarts!)
        : 0;
    // A zero or negative span still gets a half hour, so it can be tapped.
    var to = endHere && o.localEnds != null ? _minutes(o.localEnds!) : 24 * 60;
    if (to <= from) to = from + 30;
    if (to <= _gridStart || from >= _gridEnd) continue;
    blocks.add(DayBlock(o, _within(from), _within(to)));
  }
  _layOut(blocks, minimumDisplayMinutes);
  return blocks;
}

/// Groups blocks that overlap (directly or through a chain) and gives each a lane, so
/// a cluster of n overlapping blocks shares the column n ways.
void _layOut(List<DayBlock> blocks, int minimumDisplayMinutes) {
  blocks.sort(
    (a, b) => a.start != b.start
        ? a.start.compareTo(b.start)
        : a.end.compareTo(b.end),
  );
  final cluster = <DayBlock>[];
  final laneEnds = <int>[];
  var clusterEnd = -1;

  void closeCluster() {
    if (cluster.isEmpty) return;
    final lanes =
        cluster.map((b) => b.lane).reduce((a, b) => a > b ? a : b) + 1;
    for (final b in cluster) {
      b.lanes = lanes;
    }
    cluster.clear();
    laneEnds.clear();
  }

  for (final b in blocks) {
    // Short appointments have a larger touch target. Reserve its footprint too,
    // so the next appointment cannot cover it even when their times do not overlap.
    final displayEnd = b.end > b.start + minimumDisplayMinutes
        ? b.end
        : b.start + minimumDisplayMinutes;
    if (b.start >= clusterEnd) closeCluster();
    var lane = laneEnds.indexWhere((end) => end <= b.start);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(displayEnd);
    } else {
      laneEnds[lane] = displayEnd;
    }
    b.lane = lane;
    cluster.add(b);
    if (displayEnd > clusterEnd) clusterEnd = displayEnd;
  }
  closeCluster();
}

int _minutes(TimeOfDay t) => minutesOf(t);

int _within(int minute) =>
    minute < _gridStart ? _gridStart : (minute > _gridEnd ? _gridEnd : minute);
