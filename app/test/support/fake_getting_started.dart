import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';

/// In-memory getting-started card. Applies dismissals and restores to its items, and
/// records each call with its actor, so tests can assert what the card asked for.
class FakeGettingStartedRepository implements GettingStartedRepository {
  FakeGettingStartedRepository([List<GettingStartedItem> items = const []])
    : _items = [...items];

  final List<GettingStartedItem> _items;

  /// Every dismissal, in order, with the actor that sent it.
  final dismissed = <({String actor, StartItem item})>[];

  /// The actors that restored the card, in order.
  final restored = <String>[];

  @override
  Future<Result<List<GettingStartedItem>>> items({
    required String actor,
  }) async => Ok(List.of(_items));

  @override
  Future<Result<void>> dismiss({
    required String actor,
    required StartItem item,
  }) async {
    dismissed.add((actor: actor, item: item));
    _items.removeWhere((i) => i.item == item);
    return const Ok(null);
  }

  @override
  Future<Result<void>> restore({required String actor}) async {
    restored.add(actor);
    return const Ok(null);
  }
}
