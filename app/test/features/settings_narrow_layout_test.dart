import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/demo/demo_repositories.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/settings/application/settings_groups.dart';
import 'package:wuselwall/features/settings/application/settings_view.dart';
import 'package:wuselwall/features/settings/data/household_settings_repository.dart';
import 'package:wuselwall/features/settings/ui/settings_group_text.dart';

import '../support/fakes.dart';

final _de = lookupAppLocalizations(const Locale('de'));

/// Round 3 UI findings B, C-5, D and I (Einstellungen on narrow phones, at text scale 1.3
/// and on a tablet): labels stay whole, titles fit beside the Advanced chip, one way to
/// Advanced, nothing said twice.
void main() {
  // The app's own fonts, so widths are the real ones and not the test font's squares.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in {
      'AtkinsonHyperlegibleNext': ['Regular', 'SemiBold', 'Bold', 'ExtraBold'],
      'BarlowSemiCondensed': ['Medium', 'SemiBold', 'Bold'],
    }.entries) {
      final loader = FontLoader(family.key);
      for (final weight in family.value) {
        loader.addFont(
          rootBundle.load('assets/fonts/${family.key}-$weight.ttf'),
        );
      }
      await loader.load();
    }
  });

  Future<ProviderContainer> open(
    WidgetTester t,
    String route, {
    double width = 390,
    double height = 844,
    double textScale = 1,
    SettingsView view = SettingsView.basic,
    Locale locale = const Locale('de'),
    FakeIdentityRepository? identity,
  }) async {
    if (textScale != 1) {
      t.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final container = await pumpApp(
      t,
      size: Size(width, height),
      locale: locale,
      overrides: [
        ...baseOverrides(
          identity: identity ?? FakeIdentityRepository(current: device()),
          settingsViewStore: MemorySettingsViewStore(view),
        ),
        householdSettingsRepositoryProvider.overrideWithValue(
          DemoHouseholdSettingsRepository(),
        ),
      ],
    );
    container.read(routerProvider).go(route);
    await t.pumpAndSettle();
    return container;
  }

  /// Another page of the same app (one app per test: a second pump leaves timers).
  Future<void> go(WidgetTester t, ProviderContainer c, String route) async {
    c.read(routerProvider).go(route);
    await t.pumpAndSettle();
  }

  /// [finder]'s paragraph is one line: no larger than the same text laid out unbounded.
  void expectOneLine(WidgetTester t, Finder finder) {
    for (final element in finder.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final single = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout();
      expect(
        paragraph.size.height,
        lessThanOrEqualTo(single.height + 0.5),
        reason: '"${paragraph.text.toPlainText()}" wraps',
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      single.dispose();
    }
  }

  final wusel = find.byKey(const ValueKey('setting-member.wusel'));

  group('D: an enum setting never breaks a label inside a word', () {
    for (final (width, scale) in [(360.0, 1.0), (390.0, 1.0), (390.0, 1.3)]) {
      testWidgets('Wusel at $width px, text scale $scale', (t) async {
        await open(t, Routes.settingsPersonal, width: width, textScale: scale);
        expect(wusel, findsOneWidget);
        final auto = find.descendant(
          of: wusel,
          matching: find.text(_de.settingValueAuto),
        );
        expect(auto, findsOneWidget);
        expectOneLine(t, auto);
        // Four labels do not fit four equal segments here: chips instead.
        expect(
          find.descendant(of: wusel, matching: find.byType(ChoiceChip)),
          findsNWidgets(4),
        );
      });
    }

    testWidgets('a tablet keeps the segments', (t) async {
      await open(t, Routes.settingsPersonal, width: 1024, height: 768);
      expect(
        find.descendant(
          of: wusel,
          matching: find.byType(SegmentedButton<String>),
        ),
        findsOneWidget,
      );
      expectOneLine(
        t,
        find.descendant(of: wusel, matching: find.text(_de.settingValueAuto)),
      );
    });

    testWidgets('a chip writes its value', (t) async {
      await open(t, Routes.settingsPersonal, width: 360);
      await t.tap(
        find.descendant(of: wusel, matching: find.text(_de.settingValueOff)),
      );
      await t.pumpAndSettle();
      final chip = t.widget<ChoiceChip>(
        find.ancestor(
          of: find.descendant(
            of: wusel,
            matching: find.text(_de.settingValueOff),
          ),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(chip.selected, isTrue);
    });
  });

  group('B: a group title fits beside the Advanced chip', () {
    Finder barTitle() =>
        find.descendant(of: find.byType(AppBar), matching: find.byType(Text));

    for (final locale in const [Locale('de'), Locale('fr'), Locale('es')]) {
      testWidgets('no group title is cut at 360 px (${locale.languageCode})', (
        t,
      ) async {
        final c = await open(
          t,
          Routes.settings,
          width: 360,
          height: 640,
          view: SettingsView.advanced,
          locale: locale,
        );
        for (final group in SettingsGroup.values) {
          if (group == SettingsGroup.server) continue;
          await go(t, c, group.route);
          for (final element in barTitle().evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '${group.name}: "${paragraph.text.toPlainText()}"',
            );
          }
        }
      });
    }

    testWidgets('the short title on a phone, the full one on a tablet', (
      t,
    ) async {
      await open(
        t,
        Routes.settingsTasks,
        width: 390,
        view: SettingsView.advanced,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(_de.settingsGroupTasksShortTitle),
        ),
        findsOneWidget,
      );

      t.view.physicalSize = const Size(1024, 768);
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(_de.settingsGroupTasksTitle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the family profile is titled as its row', (t) async {
      await open(t, Routes.familyProfile);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(_de.familyProfileTitle),
        ),
        findsOneWidget,
      );
    });
  });

  group('C-5: account rows on a phone', () {
    testWidgets('the button sits under the text at 390, beside it at 1024', (
      t,
    ) async {
      await open(t, Routes.settingsAccount);
      final title = find.text(_de.pinChangeTitle);
      await t.scrollUntilVisible(
        title,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expectOneLine(t, title);
      final action = find.text(_de.pinChangeAction);
      expect(t.getTopLeft(action).dy, greaterThan(t.getBottomLeft(title).dy));
      // The explanation keeps the row's width: three lines at most, not four.
      final body = find.text(_de.pinChangeBody);
      final lineHeight = t.getSize(title).height;
      expect(t.getSize(body).height, lessThan(lineHeight * 4));

      t.view.physicalSize = const Size(1024, 768);
      await t.pumpAndSettle();
      expect(
        t.getTopLeft(find.text(_de.pinChangeAction)).dy,
        lessThan(t.getBottomLeft(find.text(_de.pinChangeBody)).dy),
      );
    });
  });

  group('I: one way to each thing, nothing said twice', () {
    testWidgets('the hint is one quiet line without a second switch', (
      t,
    ) async {
      await open(t, Routes.settingsMeals);
      final hint = find.byKey(const ValueKey('settings-more-hint'));
      await t.scrollUntilVisible(
        hint,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.descendant(of: hint, matching: find.byType(ButtonStyleButton)),
        findsNothing,
      );
      expectOneLine(t, find.text(_de.settingsViewMoreHint));
    });

    testWidgets('no heading repeats the row under it', (t) async {
      final c = await open(t, Routes.settingsPersonal);
      // "Wusel" is the setting's title, not a heading above it as well.
      expect(find.text(_de.settingsSectionWusel), findsOneWidget);
      await go(t, c, Routes.settingsRituals);
      expect(find.text(_de.settingsSectionTableQuestion), findsOneWidget);
    });

    testWidgets('the region row does not label its field "Region" again', (
      t,
    ) async {
      await open(t, Routes.settingsFamily);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('setting-household.region')),
          matching: find.text(_de.regionFieldLabel),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a wall says Wandanzeige once and offers an outlined Sperren', (
      t,
    ) async {
      final identity = FakeIdentityRepository(current: device())
        ..devices_ = const [
          DeviceEntry(
            id: 'wall',
            label: 'Küche (Wand)',
            deviceClass: DeviceClass.kiosk,
            register: UiRegister.kiosk,
            revoked: false,
            lastSeenAt: null,
          ),
        ];
      await open(t, Routes.settingsDevices, identity: identity);
      final revoke = find.byKey(const ValueKey('revoke-wall'));
      await t.scrollUntilVisible(
        revoke,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Device class and register are both "Wandanzeige" for a wall.
      expect(_de.classKiosk, _de.registerKiosk);
      expect(
        find.textContaining('${_de.classKiosk} · ${_de.registerKiosk}'),
        findsNothing,
      );
      expect(find.textContaining(_de.classKiosk), findsOneWidget);
      expect(t.widget(revoke), isA<OutlinedButton>());
    });

    testWidgets('members: one row to add a person, one to invite', (t) async {
      await open(t, Routes.settingsMembers);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.person_add_alt_1),
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('add-member')), findsOneWidget);
      expect(find.text(_de.addMemberSubtitle), findsOneWidget);
    });
  });
}
