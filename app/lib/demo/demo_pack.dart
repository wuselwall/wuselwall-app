import 'package:wuselwall/demo/demo_clock.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

/// The demo's one-off things to bring (specs/15), in memory and shared by the demo's
/// school week and its board, so a thing noted in one shows in the other. Seeded with
/// one for the son tomorrow.
class DemoPackItems {
  DemoPackItems._();

  static final List<Map<String, String>> _rows = [];
  static bool _seeded = false;
  static var _next = 1;

  static List<Map<String, String>> get _all {
    if (!_seeded) {
      _seeded = true;
      final now = DemoClock.now();
      _rows.add({
        'id': 'demo-pack-0',
        'member_id': DemoData.son,
        'date': ymd(DateTime(now.year, now.month, now.day + 1)),
        'title': demoText('Bastelsachen'),
      });
    }
    return _rows;
  }

  /// The rows dated [from]..[to] (`YYYY-MM-DD`, inclusive), as the functions send them.
  static List<Map<String, String>> between(String from, String to) => [
    for (final r in _all)
      if (r['date']!.compareTo(from) >= 0 && r['date']!.compareTo(to) <= 0) r,
  ];

  /// As `api.pack_item_save`: the same title again for the child and day answers the
  /// row that is there.
  static String save({
    String? id,
    required String memberId,
    required DateTime date,
    required String title,
  }) {
    final day = ymd(date);
    final same = _all.where(
      (r) =>
          r['member_id'] == memberId &&
          r['date'] == day &&
          r['id'] != id &&
          r['title']!.toLowerCase() == title.trim().toLowerCase(),
    );
    if (same.isNotEmpty) {
      if (id != null) _all.removeWhere((r) => r['id'] == id);
      return same.first['id']!;
    }
    final row = {
      'id': id ?? 'demo-pack-${_next++}',
      'member_id': memberId,
      'date': day,
      'title': title.trim(),
    };
    final at = _all.indexWhere((r) => r['id'] == id);
    if (at < 0) {
      _all.add(row);
    } else {
      _all[at] = row;
    }
    return row['id']!;
  }

  static void delete(String id) => _all.removeWhere((r) => r['id'] == id);
}
