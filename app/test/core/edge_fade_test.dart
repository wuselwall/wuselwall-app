import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/ui/edge_fade.dart';

/// Where a row of [count] chips 100 px wide in a 300 px box fades, after [scroll]
/// pixels.
Future<({bool start, bool end})> _fades(
  WidgetTester t, {
  required int count,
  double scroll = 0,
}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await t.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 300,
          height: 40,
          child: EdgeFade(
            child: ListView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < count; i++)
                  SizedBox(width: 100, child: Text('chip $i')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await t.pump();
  if (scroll > 0) {
    controller.jumpTo(scroll);
    await t.pump();
  }
  final mask = t.widget<ShaderMask>(find.byType(ShaderMask));
  expect(mask.shaderCallback(const Rect.fromLTWH(0, 0, 300, 40)), isNotNull);
  final state = t.state(find.byType(EdgeFade)) as dynamic;
  return state.fades as ({bool start, bool end});
}

void main() {
  testWidgets('a row that fits does not fade', (t) async {
    expect(await _fades(t, count: 2), (start: false, end: false));
  });

  testWidgets('a row with more beyond fades at its end only', (t) async {
    expect(await _fades(t, count: 6), (start: false, end: true));
  });

  testWidgets('scrolled to the end, it fades at its start only', (t) async {
    expect(await _fades(t, count: 6, scroll: 300), (start: true, end: false));
  });

  testWidgets('keeps the row and its position while the fade changes', (
    t,
  ) async {
    expect(await _fades(t, count: 6, scroll: 120), (start: true, end: true));
    final position = t.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, 120);
  });
}
