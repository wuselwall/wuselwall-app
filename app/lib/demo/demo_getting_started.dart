import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/today/data/getting_started_repository.dart';
import 'package:wuselwall/features/today/domain/getting_started.dart';

/// The setup card for the screenshots: a household that has its tablet and PIN, with the
/// wall display and the calendar feed still to do (two of four). In memory only; a
/// dismissal removes the item until the card is restored.
class DemoGettingStartedRepository implements GettingStartedRepository {
  DemoGettingStartedRepository() : _items = List.of(_initial);

  static const _initial = [
    GettingStartedItem(item: StartItem.connectTablet, done: true),
    GettingStartedItem(item: StartItem.setPin, done: true),
    GettingStartedItem(item: StartItem.wallDisplay, done: false),
    GettingStartedItem(item: StartItem.subscribeFeed, done: false),
  ];

  List<GettingStartedItem> _items;

  @override
  Future<Result<List<GettingStartedItem>>> items({
    required String actor,
  }) async => Ok(List.of(_items));

  @override
  Future<Result<void>> dismiss({
    required String actor,
    required StartItem item,
  }) async {
    _items = [
      for (final i in _items)
        if (i.item != item) i,
    ];
    return const Ok(null);
  }

  @override
  Future<Result<void>> restore({required String actor}) async {
    _items = List.of(_initial);
    return const Ok(null);
  }
}
