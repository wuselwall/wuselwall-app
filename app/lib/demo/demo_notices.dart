import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/today/data/notices_repository.dart';
import 'package:wuselwall/features/today/domain/notice.dart';

/// One join notice for the screenshots: the mother has just joined. In memory only; "Gesehen"
/// removes it until the demo is reloaded.
class DemoNoticesRepository implements NoticesRepository {
  DemoNoticesRepository()
    : _notices = [
        AppNotice(
          key: 'join:1',
          kind: NoticeKind.join,
          name: DemoData.name(DemoData.mama),
          at: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

  final List<AppNotice> _notices;

  @override
  Future<Result<List<AppNotice>>> notices({required String actor}) async =>
      Ok(List.of(_notices));

  @override
  Future<Result<void>> dismiss({
    required String actor,
    required String key,
  }) async {
    _notices.removeWhere((n) => n.key == key);
    return const Ok(null);
  }
}
