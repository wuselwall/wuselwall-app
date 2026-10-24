import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/wusel/application/wusel_settings.dart';
import 'package:wuselwall/features/wusel/ui/pixel_shift.dart';

class _Shift extends Notifier<bool> {
  _Shift(this.initial);

  final bool initial;

  @override
  bool build() => initial;

  void set(bool on) => state = on;
}

void main() {
  late NotifierProvider<_Shift, bool> shift;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required bool on,
  }) async {
    shift = NotifierProvider<_Shift, bool>(() => _Shift(on));
    final container = ProviderContainer(
      overrides: [
        lighterDayProvider.overrideWith(
          (ref) => LighterDay(pixelShift: ref.watch(shift)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: PixelShift(child: SizedBox.expand()),
        ),
      ),
    );
    return container;
  }

  Offset offset(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(PixelShift),
        matching: find.byType(Transform),
      ),
    );
    final t = transform.transform.getTranslation();
    return Offset(t.x, t.y);
  }

  testWidgets('walks the circuit one step every ten minutes', (tester) async {
    await pump(tester, on: true);
    for (var i = 0; i < PixelShift.offsets.length + 2; i++) {
      expect(
        offset(tester),
        PixelShift.offsets[i % PixelShift.offsets.length],
        reason: 'step $i',
      );
      await tester.pump(PixelShift.every);
    }
    // Never more than 2 px from where the screen belongs.
    for (final o in PixelShift.offsets) {
      expect(o.dx.abs() <= 2 && o.dy.abs() <= 2, isTrue);
    }
  });

  testWidgets('stays put while off, and stops when switched off', (
    tester,
  ) async {
    final container = await pump(tester, on: false);
    await tester.pump(PixelShift.every * 3);
    expect(offset(tester), Offset.zero);

    container.read(shift.notifier).set(true);
    await tester.pump();
    await tester.pump(PixelShift.every);
    expect(offset(tester), PixelShift.offsets[1]);

    container.read(shift.notifier).set(false);
    await tester.pump();
    expect(offset(tester), Offset.zero);
    await tester.pump(PixelShift.every * 2);
    expect(offset(tester), Offset.zero);
  });

  testWidgets('cancels its timer when it goes away', (tester) async {
    await pump(tester, on: true);
    await tester.pumpWidget(const SizedBox());
    // testWidgets fails a test that ends with a timer still pending, so reaching the
    // end without that failure is the check.
    await tester.pump(PixelShift.every);
  });
}
