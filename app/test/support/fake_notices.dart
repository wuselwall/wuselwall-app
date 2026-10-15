import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/today/data/notices_repository.dart';
import 'package:wuselwall/features/today/domain/notice.dart';

/// In-memory notices. Records each dismissal with its actor and removes the notice.
class FakeNoticesRepository implements NoticesRepository {
  FakeNoticesRepository([List<AppNotice> notices = const []])
    : _notices = [...notices];

  final List<AppNotice> _notices;

  /// Every dismissal, in order, with the actor that sent it.
  final dismissed = <({String actor, String key})>[];

  @override
  Future<Result<List<AppNotice>>> notices({required String actor}) async =>
      Ok(List.of(_notices));

  @override
  Future<Result<void>> dismiss({
    required String actor,
    required String key,
  }) async {
    dismissed.add((actor: actor, key: key));
    _notices.removeWhere((n) => n.key == key);
    return const Ok(null);
  }
}
