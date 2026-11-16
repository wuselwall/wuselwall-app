import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/ui/row_peek.dart';

void main() {
  // Rows of 69 px with 8 px between them: the catalogue tiles of a phone.
  const tops = [0.0, 77.0, 154.0, 231.0];

  test('rows that fit are shown whole', () {
    expect(rowPeekHeight(rowTops: tops, content: 300, budget: 300), 300);
    expect(rowPeekHeight(rowTops: tops, content: 300, budget: 400), 300);
  });

  test(
    'the last row that can show its peek within the budget is the cut one',
    () {
      // 240 would leave 9 px of the fourth row: the third is cut instead.
      expect(rowPeekHeight(rowTops: tops, content: 300, budget: 240), 154 + 44);
      expect(rowPeekHeight(rowTops: tops, content: 300, budget: 275), 231 + 44);
      expect(rowPeekHeight(rowTops: tops, content: 300, budget: 274), 154 + 44);
      expect(
        rowPeekHeight(rowTops: tops, content: 300, budget: 240, peek: 20),
        154 + 20,
      );
    },
  );

  test('one row is whole, also where the budget is smaller', () {
    expect(rowPeekHeight(rowTops: tops, content: 300, budget: 112), 77 + 44);
    expect(rowPeekHeight(rowTops: tops, content: 300, budget: 10), 77 + 44);
  });

  test('a single row taller than the budget gets the budget', () {
    expect(rowPeekHeight(rowTops: const [0], content: 300, budget: 240), 240);
  });

  Widget rows(int count, {double tile = 60, double maxHeight = 200}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: RowPeek(
              maxHeight: maxHeight,
              runSpacing: 10,
              children: [
                for (var i = 0; i < count; i++)
                  SizedBox(key: ValueKey(i), width: 100, height: tile),
              ],
            ),
          ),
        ),
      );

  testWidgets('the strip is as tall as its rows, or ends in a cut row', (
    t,
  ) async {
    // Three tiles a row. Two rows (130) fit into 200.
    await t.pumpWidget(rows(6));
    expect(t.getSize(find.byType(RowPeek)).height, 130);

    // Four rows (270) do not: 200 would leave the third row whole and nothing of the
    // fourth; the third (at 140) is cut to its peek.
    await t.pumpWidget(rows(12));
    expect(t.getSize(find.byType(RowPeek)).height, 140 + kRowPeek);
    expect(t.getSize(find.byType(SingleChildScrollView)).height, 184);

    // And back: the rows changed below the scrollable, the strip follows.
    await t.pumpWidget(rows(3));
    expect(t.getSize(find.byType(RowPeek)).height, 60);
  });

  testWidgets('taller rows move the cut', (t) async {
    await t.pumpWidget(rows(12));
    expect(t.getSize(find.byType(RowPeek)).height, 184);
    // Large text: rows of 100 start at 0, 110, 220; only the second can show its
    // peek within 200.
    await t.pumpWidget(rows(12, tile: 100));
    expect(t.getSize(find.byType(RowPeek)).height, 110 + kRowPeek);
  });

  testWidgets('the cut rows scroll into sight', (t) async {
    await t.pumpWidget(rows(12));
    final last = find.byKey(const ValueKey(11));
    await t.ensureVisible(last);
    await t.pump();
    final strip = t.getRect(find.byType(RowPeek));
    expect(t.getRect(last).bottom, lessThanOrEqualTo(strip.bottom));
    expect(strip.height, 184);
  });
}
