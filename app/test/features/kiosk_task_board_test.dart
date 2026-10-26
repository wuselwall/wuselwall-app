import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/details/task_board_detail.dart';
import 'package:wuselwall/features/identity/domain/models.dart';
import 'package:wuselwall/features/identity/ui/acting_profile_bar.dart';
import 'package:wuselwall/features/tasks/ui/task_widgets.dart';

import '../support/fake_tasks.dart';
import '../support/fakes.dart';

// Review round 3, F and NEW-2: the wall's family task board at the reference
// viewport. Spec 09: the tap-through details never truncate.

const _mama = 'mama-1';
const _emil = 'emil-1';

final _family = [
  ...testMembers,
  const Member(
    id: _mama,
    displayName: 'Mama',
    color: Color(0xFF7B3FE4),
    role: Role.guardian,
    active: true,
  ),
  const Member(
    id: _emil,
    displayName: 'Emil',
    color: Color(0xFF08737F),
    role: Role.member,
    active: true,
    isChild: true,
    hasAccount: false,
  ),
];

WeekBoard _board() {
  final today = DateTime.now();
  final monday = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(Duration(days: today.weekday - 1));
  String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return WeekBoard.fromJson({
    'week_start': ymd(monday),
    'today': ymd(today),
    'generated_at': today.toUtc().toIso8601String(),
    'members': [
      for (final m in _family)
        {
          'id': m.id,
          'display_name': m.displayName,
          'color': '#7B3FE4',
          'kind': m.isChild ? 'child' : 'adult',
        },
    ],
    'presence': <Map<String, dynamic>>[],
    'timetables': <Map<String, dynamic>>[],
    'days': [
      for (var i = 0; i < 7; i++)
        {
          'date': ymd(monday.add(Duration(days: i))),
          'events': <Map<String, dynamic>>[],
          'busy_until': <Map<String, dynamic>>[],
          'school': <Map<String, dynamic>>[],
        },
    ],
    'open_tasks': [
      {'member_id': kidId, 'count': 2},
    ],
    'shopping_count': 0,
  });
}

void main() {
  testWidgets(
    'five columns at 1280x800 wrap into rows and nothing on them is cut (F)',
    (t) async {
      final api = FakeTasksApi(
        tables: {
          'task_instances': [
            instanceRow(
              id: 'i-1',
              title: 'Spülmaschine ausräumen',
              assignee: kidId,
              points: 2,
            ),
            instanceRow(
              id: 'i-2',
              title: 'Zimmer aufräumen',
              assignee: kidId,
              points: 2,
              status: 'awaiting_approval',
              verification: true,
            ),
            instanceRow(id: 'i-3', title: 'Brot holen', assignee: guardianId),
            instanceRow(id: 'i-4', title: 'Blumen gießen', assignee: _emil),
            instanceRow(id: 'i-5', title: 'Müll rausbringen', points: 5),
          ],
          'streaks': [
            {
              'profile_id': kidId,
              'definition_id': 'd-1',
              'current_length': 12,
              'longest_length': 12,
            },
          ],
        },
      );
      final container = await pumpApp(
        t,
        size: const Size(1280, 800),
        overrides: baseOverrides(
          identity: FakeIdentityRepository(
            current: device(
              deviceClass: DeviceClass.kiosk,
              register: UiRegister.kiosk,
            ),
            members: _family,
          ),
        ),
        board: FakeBoardRepository(_board()),
        tasks: api,
      );

      await t.tap(find.text('Heute offen'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final body = find.byType(TaskBoardDetailBody);
      expect(body, findsOneWidget);
      final bounds = t.getRect(body);

      // Every column header is inside the dialog: no sideways scroll, no column
      // cut at the edge. Four members and "Offen für alle" make five.
      final names = ['Papa', 'Anna', 'Mama', 'Emil', 'Offen für alle'];
      final tops = <double>{};
      for (final name in names) {
        // The first: the acting profile bar under the board names them too.
        final header = find
            .descendant(of: body, matching: find.text(name))
            .first;
        final rect = t.getRect(header);
        expect(rect.left, greaterThanOrEqualTo(bounds.left), reason: name);
        expect(rect.right, lessThanOrEqualTo(bounds.right), reason: name);
        tops.add(rect.top.roundToDouble());
      }
      // Five columns do not fit side by side at 1280: they take two rows.
      expect(tops.length, greaterThan(1));
      // The board itself never scrolls sideways (the avatar bar may).
      final sideways = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      );
      expect(
        find.descendant(of: body, matching: sideways).evaluate().length,
        find
            .descendant(of: find.byType(ActingProfileBar), matching: sideways)
            .evaluate()
            .length,
      );

      // NEW-2: the name comes first and whole; the streak follows it.
      final anna = t.getRect(
        find.descendant(of: body, matching: find.text('Anna')).first,
      );
      final streak = t.getRect(
        find.descendant(of: body, matching: find.byType(StreakBadge)),
      );
      expect(
        streak.left >= anna.right || streak.top >= anna.bottom,
        isTrue,
        reason: 'streak $streak before name $anna',
      );

      // Nothing on the board ends in an ellipsis or a line limit (the acting
      // profile bar under it is not part of the board).
      final bar = find.byType(ActingProfileBar);
      for (final e
          in find
              .descendant(of: body, matching: find.byType(RichText))
              .evaluate()) {
        if (find
            .descendant(of: bar, matching: find.byWidget(e.widget))
            .evaluate()
            .isNotEmpty) {
          continue;
        }
        final paragraph = e.renderObject! as RenderParagraph;
        final text = paragraph.text.toPlainText();
        // A count (the streak, the points) is one line by nature.
        if (!RegExp(r'^\d+$').hasMatch(text)) {
          expect(paragraph.maxLines, isNull, reason: text);
        }
        expect(paragraph.overflow, isNot(TextOverflow.ellipsis), reason: text);
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
      }
      expect(
        find.descendant(
          of: body,
          matching: find.text('Spülmaschine ausräumen'),
        ),
        findsOneWidget,
      );
      await unmountApp(t, container);
    },
  );
}
