import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/ui/empty_view.dart';

Widget _app(Widget body) => MaterialApp(
  theme: AppTheme.build(UiRegister.adult, Shade.light),
  home: Scaffold(body: body),
);

void main() {
  testWidgets('the message sits in the middle of the space it is given', (
    t,
  ) async {
    await t.pumpWidget(_app(const EmptyView(message: 'Nothing here')));
    final screen = t.getCenter(find.byType(Scaffold));
    final message = t.getCenter(find.text('Nothing here'));
    expect(message.dy, moreOrLessEquals(screen.dy, epsilon: 1));
    expect(message.dx, moreOrLessEquals(screen.dx, epsilon: 1));
  });

  testWidgets('without the scroll view it centres in a remaining sliver', (
    t,
  ) async {
    await t.pumpWidget(
      _app(
        const CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: 100)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(message: 'Nothing here', scrolls: false),
            ),
          ],
        ),
      ),
    );
    final scaffold = t.getRect(find.byType(Scaffold));
    final message = t.getCenter(find.text('Nothing here'));
    expect(
      message.dy,
      moreOrLessEquals((scaffold.top + 100 + scaffold.bottom) / 2, epsilon: 1),
    );
  });

  testWidgets('the call to action is offered and pressed', (t) async {
    var pressed = 0;
    await t.pumpWidget(
      _app(
        EmptyView(
          title: 'No chores yet.',
          message: 'Start with these.',
          actions: [
            FilledButton(onPressed: () => pressed++, child: const Text('Add')),
          ],
        ),
      ),
    );
    expect(find.text('No chores yet.'), findsOneWidget);
    await t.tap(find.text('Add'));
    expect(pressed, 1);
  });

  testWidgets('a surrounding RefreshIndicator still pulls', (t) async {
    var refreshed = 0;
    await t.pumpWidget(
      _app(
        RefreshIndicator(
          onRefresh: () async => refreshed++,
          child: const EmptyView(message: 'Nothing here'),
        ),
      ),
    );
    await t.fling(find.text('Nothing here'), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect(refreshed, 1);
  });
}
