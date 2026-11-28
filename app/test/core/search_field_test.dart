import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/ui/search_field.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

const _clear = ValueKey('search-clear');

Future<void> _pump(WidgetTester t, Widget field) async {
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(UiRegister.adult, Shade.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('de'),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: field),
      ),
    ),
  );
}

String _text(WidgetTester t) =>
    t.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('an empty field shows its hint and no clear button', (t) async {
    await _pump(t, SearchField(hint: 'Wonach suchst du?', onChanged: (_) {}));

    expect(find.text('Wonach suchst du?'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byKey(_clear), findsNothing);
  });

  testWidgets('typing tells the caller the text as typed', (t) async {
    final typed = <String>[];
    await _pump(t, SearchField(hint: 'Suche', onChanged: typed.add));

    await t.enterText(find.byType(TextField), 'Käse');
    await t.pump();

    expect(typed, ['Käse']);
  });

  testWidgets('the clear button shows with text and only then', (t) async {
    await _pump(t, SearchField(hint: 'Suche', onChanged: (_) {}));

    await t.enterText(find.byType(TextField), 'Käse');
    await t.pump();
    expect(find.byKey(_clear), findsOneWidget);
    expect(find.byTooltip('Leeren'), findsOneWidget);

    await t.enterText(find.byType(TextField), '');
    await t.pump();
    expect(find.byKey(_clear), findsNothing);
  });

  testWidgets('the clear button empties the field and reports an empty text', (
    t,
  ) async {
    final typed = <String>[];
    await _pump(t, SearchField(hint: 'Suche', onChanged: typed.add));
    await t.enterText(find.byType(TextField), 'Käse');
    await t.pump();

    await t.tap(find.byKey(_clear));
    await t.pump();

    expect(_text(t), isEmpty);
    expect(typed, ['Käse', '']);
    expect(find.byKey(_clear), findsNothing);
    expect(find.text('Suche'), findsOneWidget);
  });

  testWidgets('an external controller is used, and stays the caller\'s', (
    t,
  ) async {
    final controller = TextEditingController(text: 'Brot');
    addTearDown(controller.dispose);
    final typed = <String>[];
    await _pump(
      t,
      SearchField(hint: 'Suche', controller: controller, onChanged: typed.add),
    );

    // Text that is already there shows the clear button.
    expect(find.byKey(_clear), findsOneWidget);
    expect(find.text('Brot'), findsOneWidget);

    // Text set from outside is followed.
    controller.text = 'Milch';
    await t.pump();
    expect(find.text('Milch'), findsOneWidget);

    await t.tap(find.byKey(_clear));
    await t.pump();
    expect(controller.text, isEmpty);
    expect(typed, ['']);

    // The field did not dispose a controller it does not own.
    await t.pumpWidget(const SizedBox());
    controller.text = 'still usable';
    expect(controller.text, 'still usable');
  });

  testWidgets('a new controller is followed after the widget is rebuilt', (
    t,
  ) async {
    final first = TextEditingController();
    final second = TextEditingController(text: 'Eier');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await _pump(
      t,
      SearchField(hint: 'Suche', controller: first, onChanged: (_) {}),
    );
    expect(find.byKey(_clear), findsNothing);

    await _pump(
      t,
      SearchField(hint: 'Suche', controller: second, onChanged: (_) {}),
    );
    expect(find.byKey(_clear), findsOneWidget);

    first.text = 'ignored';
    await t.pump();
    second.clear();
    await t.pump();
    expect(find.byKey(_clear), findsNothing);
  });

  testWidgets('submitting hands the text to onSubmitted', (t) async {
    final submitted = <String>[];
    await _pump(
      t,
      SearchField(hint: 'Suche', onChanged: (_) {}, onSubmitted: submitted.add),
    );
    await t.enterText(find.byType(TextField), 'Käse');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump();

    expect(submitted, ['Käse']);
  });
}
