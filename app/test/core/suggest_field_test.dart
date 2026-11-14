import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/text/suggest.dart';
import 'package:wuselwall/core/ui/suggest_field.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

const _entries = [
  TextSuggestion(text: 'Turnen', count: 4, location: 'Halle B'),
  TextSuggestion(text: 'Tennis', count: 2),
  TextSuggestion(text: 'Zahnarzt'),
];

class _Host extends StatefulWidget {
  const _Host({this.entries = _entries, this.picked, this.changed});

  final List<TextSuggestion> entries;
  final List<TextSuggestion>? picked;
  final List<String>? changed;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  final controller = TextEditingController();
  final other = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        TextField(
          controller: other,
          decoration: const InputDecoration(labelText: 'Anderes'),
        ),
        SuggestField(
          controller: controller,
          entries: widget.entries,
          decoration: const InputDecoration(labelText: 'Titel'),
          onChanged: widget.changed?.add,
          onPicked: widget.picked?.add,
        ),
      ],
    ),
  );
}

Future<void> _pump(WidgetTester t, Widget host) async {
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(UiRegister.adult, Shade.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: Scaffold(body: host),
    ),
  );
}

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(find.widgetWithText(TextField, 'Titel'), text);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('typing shows the matching entries, best first', (t) async {
    await _pump(t, const _Host());
    await _type(t, 't');

    final turnen = t.getTopLeft(find.text('Turnen')).dy;
    final tennis = t.getTopLeft(find.text('Tennis')).dy;
    expect(turnen, lessThan(tennis));
    expect(find.text('Zahnarzt'), findsNothing);
    // The place of an entry is its second line.
    expect(find.text('Halle B'), findsOneWidget);
  });

  testWidgets('the list is as wide as the field and rows are 48 high', (
    t,
  ) async {
    await _pump(t, const _Host());
    await _type(t, 't');

    final field = t.getRect(find.widgetWithText(TextField, 'Titel'));
    final card = t.getRect(
      find
          .ancestor(of: find.text('Tennis'), matching: find.byType(Material))
          .first,
    );
    expect(card.width, field.width);
    expect(
      t
          .getSize(
            find
                .ancestor(
                  of: find.text('Tennis'),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a tap takes the entry over, with the cursor at the end', (
    t,
  ) async {
    final picked = <TextSuggestion>[];
    final changed = <String>[];
    await _pump(t, _Host(picked: picked, changed: changed));
    await _type(t, 'tu');
    changed.clear();

    await t.tap(find.text('Turnen'));
    await t.pumpAndSettle();

    final field = t.widget<TextField>(find.widgetWithText(TextField, 'Titel'));
    expect(field.controller!.text, 'Turnen');
    expect(
      field.controller!.selection,
      const TextSelection.collapsed(offset: 6),
    );
    expect(picked.single.location, 'Halle B');
    expect(changed, ['Turnen']);
    // Nothing more to propose: the text equals the entry.
    expect(find.text('Halle B'), findsNothing);
  });

  testWidgets('nothing is shown for an empty field', (t) async {
    await _pump(t, const _Host());
    await t.tap(find.widgetWithText(TextField, 'Titel'));
    await t.pumpAndSettle();
    expect(find.text('Turnen'), findsNothing);
  });

  testWidgets('nothing is shown without entries', (t) async {
    await _pump(t, const _Host(entries: []));
    await _type(t, 't');
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('t'), findsOneWidget);
  });

  testWidgets('arrow down and Enter pick the first entry', (t) async {
    final picked = <TextSuggestion>[];
    await _pump(t, _Host(picked: picked));
    await _type(t, 't');

    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    final text = t
        .widget<TextField>(find.widgetWithText(TextField, 'Titel'))
        .controller!
        .text;
    expect(text, 'Turnen');
    expect(picked.single.text, 'Turnen');
  });

  testWidgets('a second arrow down moves to the second entry', (t) async {
    final picked = <TextSuggestion>[];
    await _pump(t, _Host(picked: picked));
    await _type(t, 't');

    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    expect(picked.single.text, 'Tennis');
  });

  testWidgets('Enter alone keeps what was typed', (t) async {
    final picked = <TextSuggestion>[];
    await _pump(t, _Host(picked: picked));
    await _type(t, 't');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(find.widgetWithText(TextField, 'Titel'))
          .controller!
          .text,
      't',
    );
    expect(picked, isEmpty);
  });

  testWidgets('typing on after an arrow key forgets the highlighted entry', (
    t,
  ) async {
    final picked = <TextSuggestion>[];
    await _pump(t, _Host(picked: picked));
    await _type(t, 't');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pumpAndSettle();
    await _type(t, 'te');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(picked, isEmpty);
  });

  testWidgets('the options vanish when the field loses focus', (t) async {
    await _pump(t, const _Host());
    await _type(t, 't');
    expect(find.text('Turnen'), findsOneWidget);

    await t.tap(find.widgetWithText(TextField, 'Anderes'));
    await t.pumpAndSettle();
    expect(find.text('Turnen'), findsNothing);
  });
}
