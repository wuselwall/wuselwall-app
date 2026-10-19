import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/setup/ui/server_choice_page.dart';
import 'package:wuselwall/features/shopping/application/shopping_providers.dart';
import 'package:wuselwall/features/shopping/data/shopping_repository.dart';
import 'package:wuselwall/features/shopping/data/shopping_store.dart';
import 'package:wuselwall/features/shopping/domain/shopping_item.dart';
import 'package:wuselwall/features/shopping/domain/shopping_sync_model.dart';
import 'package:wuselwall/features/shopping/ui/shopping_page.dart';
import 'package:wuselwall/features/tasks/application/task_defaults.dart';
import 'package:wuselwall/features/tasks/ui/task_editor.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

import '../support/fakes.dart';

/// A German app shell around [home], as the store build shows it.
Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.build(UiRegister.adult, Shade.light),
    localizationsDelegates: localizationsDelegates,
    supportedLocales: supportedLocales,
    locale: const Locale('de'),
    home: home,
  ),
);

/// Records every screen-reader announcement the app sends during a test.
List<String> _recordAnnouncements(WidgetTester t) {
  final messages = <String>[];
  t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        messages.add((message['data'] as Map)['message'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () =>
        t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return messages;
}

bool _hasFocus(WidgetTester t, Finder field) => t
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .focusNode
    .hasFocus;

void main() {
  final de = lookupAppLocalizations(const Locale('de'));

  group('A8: errors are announced and the field takes the focus', () {
    testWidgets('an address that is not one is announced on the server page', (
      t,
    ) async {
      final messages = _recordAnnouncements(t);
      await t.pumpWidget(
        _app(
          ServerChoicePage(
            onAddress: (_) async => null,
            onDemo: () {},
            canScan: false,
          ),
        ),
      );
      final field = find.byKey(const ValueKey('server-address'));
      await t.enterText(field, 'a b c');
      await t.tap(find.byKey(const ValueKey('server-connect')));
      await t.pump();

      expect(messages, [de.serverInvalid]);
      expect(find.text(de.serverInvalid), findsOneWidget);
      expect(_hasFocus(t, field), isTrue);
    });

    testWidgets('a server that cannot be reached is announced too', (t) async {
      final messages = _recordAnnouncements(t);
      await t.pumpWidget(
        _app(
          ServerChoicePage(
            onAddress: (_) async => ServerProblem.unreachable,
            onDemo: () {},
            canScan: false,
          ),
        ),
      );
      final field = find.byKey(const ValueKey('server-address'));
      await t.enterText(field, 'family.example.org');
      await t.tap(find.byKey(const ValueKey('server-connect')));
      await t.pumpAndSettle();

      expect(messages, [de.serverUnreachable]);
      expect(_hasFocus(t, field), isTrue);
      // The field itself is flagged invalid for assistive technology.
      final handle = t.ensureSemantics();
      final node = t.getSemantics(field);
      expect(node.validationResult, SemanticsValidationResult.invalid);
      handle.dispose();
    });

    testWidgets('an empty task title is announced and the title takes focus', (
      t,
    ) async {
      final messages = _recordAnnouncements(t);
      await t.pumpWidget(
        _app(
          TaskEditorDialog(
            members: const [],
            defaults: const TaskDefaults.curated(),
          ),
        ),
      );
      await t.pumpAndSettle();
      // The title is focused on open; move the focus away so the test shows it returns.
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, de.save));
      await t.pump();

      expect(messages, [de.tasksTitleRequired]);
      expect(find.text(de.tasksTitleRequired), findsOneWidget);
      expect(
        _hasFocus(t, find.widgetWithText(TextField, de.tasksFieldTitle)),
        isTrue,
      );
    });
  });

  testWidgets('A11: the added-by mark is a letter as well as a colour', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          uiRegisterProvider.overrideWithValue(UiRegister.kiosk),
          membersProvider.overrideWith(
            (ref) async => [
              const Member(
                id: 'emma',
                displayName: 'Emma',
                color: Color(0xFFB5306B),
                role: Role.member,
                active: true,
                isChild: true,
              ),
            ],
          ),
          shoppingViewProvider.overrideWithValue(
            AsyncData(
              ShoppingView(
                items: [
                  ShoppingItem(
                    id: '1',
                    name: 'Milch',
                    quantity: null,
                    checked: false,
                    createdAt: DateTime(2026, 10, 11),
                    listId: 'l1',
                    addedBy: 'emma',
                  ),
                ],
                lists: const [
                  ShoppingList(
                    id: 'l1',
                    name: 'Supermarkt',
                    isDefault: true,
                    openCount: 1,
                  ),
                ],
                categories: const [],
                catalog: const [],
                pendingCount: 0,
              ),
            ),
          ),
          shoppingStoreProvider.overrideWith((ref) => MemoryShoppingStore()),
          shoppingRepositoryProvider.overrideWithValue(
            FakeShoppingRepository([]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(UiRegister.kiosk, Shade.light),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: supportedLocales,
          locale: const Locale('de'),
          home: const Scaffold(body: ShoppingBody()),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('E'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Hinzugefügt von Emma')), findsWidgets);
    handle.dispose();
  });

  testWidgets('A9: the picked task picture is exposed as selected', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      _app(
        TaskEditorDialog(
          members: const [],
          defaults: const TaskDefaults.curated(),
        ),
      ),
    );
    await t.pumpAndSettle();

    bool selected(String label) =>
        t
            .getSemantics(find.bySemanticsLabel(label))
            .flagsCollection
            .isSelected ==
        Tristate.isTrue;

    final none = de.tasksNoIcon;
    final table = taskIconName(de, 'table');
    expect(selected(none), isTrue);
    expect(selected(table), isFalse);

    await t.tap(find.byTooltip(table));
    await t.pumpAndSettle();
    expect(selected(table), isTrue);
    expect(selected(none), isFalse);
    handle.dispose();
  });
}
