import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/settings/application/household_settings_providers.dart';

/// `08:30` or `08:30:00` as minutes after midnight; null for anything else, so a value
/// this app cannot read falls back to the default instead of failing.
int? clockMinutes(Object? value) {
  if (value is! String) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return h * 60 + m;
}

/// The kiosk's night (`device.night_hours`, specs/09 and 21): from [start] until [end],
/// in minutes after local midnight. The night usually runs over midnight.
@immutable
class NightHours {
  const NightHours({required this.start, required this.end});

  /// 21:00 to 06:00: the setting's default, and what a device without the setting (an
  /// older server, or settings still loading) uses.
  static const standard = NightHours(start: 21 * 60, end: 6 * 60);

  /// Reads the stored `{"from": "21:00", "to": "06:00"}`; [standard] if it is missing
  /// or malformed.
  factory NightHours.parse(Object? stored) {
    if (stored is! Map) return standard;
    final start = clockMinutes(stored['from']);
    final end = clockMinutes(stored['to']);
    if (start == null || end == null) return standard;
    return NightHours(start: start, end: end);
  }

  final int start;
  final int end;

  /// Whether [time] falls in the night. Equal ends mean no night at all.
  bool contains(DateTime time) {
    final m = time.hour * 60 + time.minute;
    if (start == end) return false;
    return start < end ? m >= start && m < end : m >= start || m < end;
  }

  /// The next start or end strictly after [time].
  DateTime nextBoundary(DateTime time) {
    DateTime? best;
    for (var day = 0; day < 2; day++) {
      for (final minutes in [start, end]) {
        // DateTime normalises the minutes into hours.
        final candidate = DateTime(
          time.year,
          time.month,
          time.day + day,
          0,
          minutes,
        );
        if (candidate.isAfter(time) &&
            (best == null || candidate.isBefore(best))) {
          best = candidate;
        }
      }
    }
    return best!;
  }

  @override
  bool operator ==(Object other) =>
      other is NightHours && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Whether [time] is in the night of [hours] (by default 21:00 to 06:00).
bool isNightAt(DateTime time, [NightHours hours = NightHours.standard]) =>
    hours.contains(time);

/// The next night boundary strictly after [time].
DateTime nextNightBoundary(
  DateTime time, [
  NightHours hours = NightHours.standard,
]) => hours.nextBoundary(time);

/// Whether [time] is in the first half hour after the night: Wusel waves good morning
/// on the wall then (specs/25).
bool isMorningWaveAt(DateTime time, [NightHours hours = NightHours.standard]) {
  if (hours.contains(time)) return false;
  final m = time.hour * 60 + time.minute;
  final since = (m - hours.end) % (24 * 60);
  return since < 30;
}

/// This device's night hours: its own `device.night_hours`, or the household's, or
/// [NightHours.standard] while the settings load and against a server without them.
final nightHoursProvider = Provider.autoDispose<NightHours>((ref) {
  final entries = ref.watch(householdSettingsProvider).value;
  if (entries == null) return NightHours.standard;
  final deviceId = ref.watch(deviceProvider).value?.deviceId;
  return NightHours.parse(
    resolveSetting(entries, 'device.night_hours', deviceId: deviceId)?.value,
  );
});

/// Whether it is night now. Rebuilds itself at the next boundary rather than polling,
/// and when the night hours change.
class NightNotifier extends Notifier<bool> {
  @override
  bool build() {
    final hours = ref.watch(nightHoursProvider);
    final now = DateTime.now();
    final timer = Timer(
      hours.nextBoundary(now).difference(now),
      ref.invalidateSelf,
    );
    ref.onDispose(timer.cancel);
    return hours.contains(now);
  }
}

final nightProvider = NotifierProvider<NightNotifier, bool>(NightNotifier.new);
