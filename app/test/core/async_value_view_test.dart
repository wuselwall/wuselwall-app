import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/core/ui/async_value_view.dart';

Widget _view(AsyncValue<String> value, {bool keepPrevious = false}) =>
    MaterialApp(
      home: Scaffold(
        body: AsyncValueView<String>(
          value: value,
          keepPrevious: keepPrevious,
          data: (s) => Text(s),
        ),
      ),
    );

/// The opacity the spinner is painted with: the product of its fades.
double _spinnerOpacity(WidgetTester t) {
  final spinner = find.byType(CircularProgressIndicator);
  if (spinner.evaluate().isEmpty) return 0;
  return t
      .widgetList<FadeTransition>(
        find.ancestor(of: spinner.first, matching: find.byType(FadeTransition)),
      )
      .fold(1.0, (o, f) => o * f.opacity.value);
}

void main() {
  testWidgets('a quick load never shows the spinner', (t) async {
    await t.pumpWidget(_view(const AsyncLoading()));
    await t.pump(const Duration(milliseconds: 150));
    expect(_spinnerOpacity(t), 0);

    await t.pumpWidget(_view(const AsyncData('Fertig')));
    expect(find.text('Fertig'), findsOneWidget);
    // Nothing fades out over the content, as nothing was shown.
    expect(_spinnerOpacity(t), 0);
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a slow load fades the spinner in, then the content over it', (
    t,
  ) async {
    await t.pumpWidget(_view(const AsyncLoading()));
    await t.pump(const Duration(milliseconds: 400));
    expect(_spinnerOpacity(t), 1);

    await t.pumpWidget(_view(const AsyncData('Fertig')));
    await t.pump(const Duration(milliseconds: 60));
    final content = t.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Fertig'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(content.opacity.value, inExclusiveRange(0, 1));
    expect(_spinnerOpacity(t), inExclusiveRange(0, 1));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(content.opacity.value, 1);
  });

  testWidgets('under reduced motion the content takes the spinner\'s place', (
    t,
  ) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(_view(const AsyncLoading()));
    await t.pump(const Duration(milliseconds: 100));
    expect(_spinnerOpacity(t), 0);
    await t.pump(const Duration(milliseconds: 150));
    expect(_spinnerOpacity(t), 1);

    await t.pumpWidget(_view(const AsyncData('Fertig')));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AsyncValueView<String>),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('keepPrevious dims the last content while the next loads', (
    t,
  ) async {
    await t.pumpWidget(_view(const AsyncData('Woche 1'), keepPrevious: true));
    await t.pumpWidget(_view(const AsyncLoading(), keepPrevious: true));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Woche 1'), findsOneWidget);
    final dim = t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(dim.opacity, 0.5);
    expect(
      t
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.byType(AnimatedOpacity),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );

    await t.pumpWidget(_view(const AsyncData('Woche 2'), keepPrevious: true));
    await t.pumpAndSettle();
    expect(find.text('Woche 2'), findsOneWidget);
    expect(t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity, 1);
  });
}
