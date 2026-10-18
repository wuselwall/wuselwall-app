import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/tasks/application/tasks_providers.dart';
import 'package:wuselwall/features/tasks/domain/tasks_models.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';
import 'package:wuselwall/features/tasks/ui/tasks_today_tab.dart';
import 'package:wuselwall/l10n/generated/app_localizations.dart';

/// Two members with one chore each and one chore open for anyone.
const _emma = Member(
  id: 'm-emma',
  displayName: 'Emma',
  color: Color(0xFFFF8800),
  role: Role.member,
  active: true,
  isChild: true,
);
const _paul = Member(
  id: 'm-paul',
  displayName: 'Paul',
  color: Color(0xFF2E7D6B),
  role: Role.guardian,
  active: true,
);

TaskInstance _chore(String id, String title, String? assignee) => TaskInstance(
  id: id,
  title: title,
  kind: TaskKind.duty,
  points: 1,
  dueOn: DateTime(2026, 10, 18),
  opensOn: DateTime(2026, 10, 18),
  closesOn: DateTime(2026, 10, 18),
  status: InstanceStatus.open,
  completionCount: 0,
  requiresVerification: false,
  assignedProfileId: assignee,
);

Widget _app(Locale locale, Widget home) => ProviderScope(
  overrides: [
    membersProvider.overrideWith((ref) async => const [_emma, _paul]),
    tasksTodayProvider.overrideWith(
      (ref) async => [
        _chore('t1', 'Tisch decken', 'm-emma'),
        _chore('t2', 'Müll rausbringen', 'm-paul'),
        _chore('t3', 'Blumen gießen', null),
      ],
    ),
    streaksProvider.overrideWith((ref) async => const []),
  ],
  child: MaterialApp(
    theme: AppTheme.build(UiRegister.adult, Shade.light),
    localizationsDelegates: localizationsDelegates,
    supportedLocales: supportedLocales,
    locale: locale,
    home: home,
  ),
);

/// Every semantics label in [node]'s subtree, depth first, including [node] itself.
List<String> _labelsBelow(SemanticsNode node) {
  final labels = <String>[];
  void visit(SemanticsNode n) {
    if (n.label.isNotEmpty) labels.add(n.label);
    n.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(node);
  return labels;
}

/// Labels of every node below [node], not counting [node]'s own label.
List<String> _descendantLabels(SemanticsNode node) {
  final labels = <String>[];
  node.visitChildren((child) {
    labels.addAll(_labelsBelow(child));
    return true;
  });
  return labels;
}

/// The heading node whose subtree shows [name]: the group header of that member.
SemanticsNode _headerNode(WidgetTester t, String name) {
  final headers = find
      .byWidgetPredicate((w) => w is Semantics && w.properties.header == true)
      .evaluate()
      .map((e) => e.widget)
      .toList();
  final matches = [
    for (final w in headers)
      if (_labelsBelow(t.getSemantics(find.byWidget(w)))
          .any((l) => l.contains(name)))
        t.getSemantics(find.byWidget(w)),
  ];
  expect(matches, hasLength(1), reason: 'one heading for $name');
  return matches.single;
}

void main() {
  for (final locale in const [Locale('de'), Locale('en')]) {
    final code = locale.languageCode.toUpperCase();
    final l10n = lookupAppLocalizations(locale);

    testWidgets('$code: each member name is read once in its section heading', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(_app(locale, const Scaffold(body: TasksTodayTab())));
      await t.pumpAndSettle();

      for (final name in ['Emma', 'Paul']) {
        final header = _headerNode(t, name);
        expect(header.flagsCollection.isHeader, isTrue, reason: name);
        expect(header.label, name, reason: 'heading name of $name');
        // The avatar must not add a second label for the same name.
        expect(
          _descendantLabels(header),
          isNot(contains(name)),
          reason: 'no child of the $name heading repeats the name',
        );
      }
      expect(
        _labelsBelow(_headerNode(t, 'Paul')),
        isNot(contains('Emma')),
        reason: 'headings do not leak another member name',
      );
      handle.dispose();
    });

    testWidgets('$code: the open-for-anyone heading is read once', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(_app(locale, const Scaffold(body: TasksTodayTab())));
      await t.pumpAndSettle();

      final header = _headerNode(t, l10n.tasksOpenForAnyone);
      expect(header.flagsCollection.isHeader, isTrue);
      expect(header.label, l10n.tasksOpenForAnyone);
      handle.dispose();
    });

    testWidgets('$code: a standalone TaskAvatar keeps its member label', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        _app(
          locale,
          const Scaffold(
            body: Center(
              child: TaskAvatar(name: 'Emma', color: Color(0xFFFF8800)),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.bySemanticsLabel('Emma'), findsOneWidget);
      handle.dispose();
    });
  }
}
