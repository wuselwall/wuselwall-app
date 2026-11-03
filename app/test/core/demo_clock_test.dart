import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/demo/demo_clock.dart';
import 'package:wuselwall/demo/demo_repositories.dart';

void main() {
  tearDown(() => DemoClock.fixedNow = null);

  test('the store demo keeps real time unless a test explicitly fixes it', () {
    final before = DateTime.now();
    final now = DemoClock.now();
    final after = DateTime.now();
    expect(now.isBefore(before), isFalse);
    expect(now.isAfter(after), isFalse);
  });

  test(
    'default demo repositories use the fixed clock for their data',
    () async {
      final fixed = DateTime(2026, 10, 14, 14, 5);
      DemoClock.fixedNow = fixed;
      expect(DemoClock.now(), fixed);
      final repo = DemoShoppingRepository();
      await repo.add(actor: null, name: 'Clock probe');
      final items = (await repo.items()).valueOrNull!;
      expect(
        items.singleWhere((item) => item.name == 'Clock probe').createdAt,
        fixed,
      );
    },
  );
}
