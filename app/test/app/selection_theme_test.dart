import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';

import 'theme_test.dart' show contrast;

/// A selected segment or chip must be visible against the page in every shade
/// (specs/17, "Selected state"). Material 3 paints it `secondaryContainer`, which this
/// palette maps to `sunken`, 1.02-1.08 : 1 against the page. The theme paints it
/// `primaryContainer` instead.
void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'a', label: Text('Alpha')),
                  ButtonSegment(value: 'b', label: Text('Beta')),
                ],
                selected: const {'b'},
                onSelectionChanged: (_) {},
              ),
              FilterChip(
                label: const Text('Chip on'),
                selected: true,
                onSelected: (_) {},
              ),
              FilterChip(
                label: const Text('Chip off'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// The fill the segment containing [text] is painted with.
  Color? segmentFill(WidgetTester tester, String text) {
    final materials = tester.widgetList<Material>(
      find.descendant(
        of: find.ancestor(
          of: find.text(text),
          matching: find.byType(TextButton),
        ),
        matching: find.byType(Material),
      ),
    );
    return materials.map((m) => m.color).whereType<Color>().firstOrNull;
  }

  /// A chip paints its own fill (no `Material.color` to read), so check the
  /// theme it resolves; the web demo screenshots show the painted result.
  ChipThemeData chipTheme(WidgetTester tester) =>
      ChipTheme.of(tester.element(find.text('Chip on')));

  for (final register in UiRegister.values) {
    for (final shade in Shade.values) {
      final c = Palette.of(shade);

      testWidgets('${register.name} ${shade.name}: selection shows', (
        tester,
      ) async {
        final theme = AppTheme.build(register, shade);
        await pump(tester, theme);

        final selected = segmentFill(tester, 'Beta');
        expect(selected, theme.colorScheme.primaryContainer);
        expect(selected, c.brandTint);
        expect(selected, isNot(theme.scaffoldBackgroundColor));
        expect(selected, isNot(c.sunken));
        // Unselected segments stay on the page.
        expect(segmentFill(tester, 'Alpha'), isNot(selected));
        expect(segmentFill(tester, 'Alpha')?.a ?? 0, 0);

        expect(chipTheme(tester).selectedColor, c.brandTint);

        // The label on the selected fill stays readable.
        expect(contrast(c.onBrandTint, c.brandTint), greaterThanOrEqualTo(4.5));

        // Segments keep the register's touch target, not the 40 px default.
        final height = tester
            .getSize(
              find.ancestor(
                of: find.text('Beta'),
                matching: find.byType(TextButton),
              ),
            )
            .height;
        expect(height, greaterThanOrEqualTo(register.touchTarget));
      });

      testWidgets('${register.name} ${shade.name}: selection follows the '
          'acting member', (tester) async {
        final member = MemberPalette.swatches.first;
        final base = AppTheme.build(register, shade);
        final theme = AppTheme.forMember(base, member.light);
        await pump(tester, theme);

        final tint = member.tint(shade);
        expect(theme.colorScheme.primaryContainer, tint);
        expect(segmentFill(tester, 'Beta'), tint);
        expect(
          segmentFill(tester, 'Beta'),
          isNot(base.scaffoldBackgroundColor),
        );
        expect(chipTheme(tester).selectedColor, tint);
        // forMember keeps the label colour and the touch target of the base.
        expect(
          theme.segmentedButtonTheme.style!.minimumSize!.resolve({}),
          base.segmentedButtonTheme.style!.minimumSize!.resolve({}),
        );
        expect(
          contrast(theme.colorScheme.onPrimaryContainer, tint),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  }
}
