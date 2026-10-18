import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/app/app.dart';
import 'package:wuselwall/app/theme/app_theme.dart';
import 'package:wuselwall/app/theme/night.dart';
import 'package:wuselwall/app/theme/palette.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/features/board/application/board_providers.dart';
import 'package:wuselwall/features/board/domain/week_board.dart';
import 'package:wuselwall/features/board/ui/details/board_details.dart';

// Kiosk detail views, actually rendered with the bundled fonts (t_10f0b348): DE/EN x
// light/dark/true night x 100/150/200 % text, for non-reference households of four, five
// and six members with long names, split care and a long meal. Checks, per text on
// screen: at least 24 px before the text scale, nothing clipped or cut short, no
// opacity over it, and at least 4.5:1 between its painted colour and its ground,
// measured on the rendered pixels.
//
// Week of Monday 12 October 2026; today is Wednesday 14 October, 14:05, so some of
// today's appointments and lessons are over and Monday and Tuesday are past.

final _now = DateTime(2026, 10, 14, 14, 5);
const _today = 2;

const _names = [
  ('k1', 'Maia-Leopoldine', '#7B3FE4', 'child'),
  ('k2', 'Kofi-Alexander', '#C2255C', 'child'),
  ('a1', 'Chloé-Alexandria', '#D9622B', 'adult'),
  ('a2', 'Sören-Mohammed', '#2F6FD6', 'adult'),
  ('a3', 'Alexandria-Nikodemus', '#08737F', 'adult'),
  ('a4', 'Bartholomäus-Konstantin', '#9A5300', 'adult'),
];

Map<String, Object?> _lesson(
  int period,
  String starts,
  String ends,
  String subject, {
  String? short,
  String? tint,
  String status = 'normal',
  String? note,
}) => {
  'period': period,
  'starts': starts,
  'ends': ends,
  'subject': subject,
  'short': short,
  'room': 'Raum 2.14',
  'teacher': 'Frau Wiesenthal-Brunner',
  'tint': tint,
  'status': status,
  'note': note,
};

List<Map<String, Object?>> _lessons() => [
  _lesson(1, '08:00', '08:45', 'Mathematik', short: 'Ma', tint: 'ocean'),
  _lesson(2, '08:50', '09:35', 'Deutsch', short: 'De', tint: 'raspberry'),
  _lesson(
    3,
    '09:55',
    '10:40',
    'Naturwissenschaften',
    short: 'NaWi',
    tint: 'petrol',
    status: 'substituted',
    note: 'Vertretung durch Herrn Oberhauser',
  ),
  _lesson(
    4,
    '10:45',
    '11:30',
    'Biologie',
    short: 'Bio',
    tint: 'mustard',
    status: 'cancelled',
    note: 'fällt aus',
  ),
  _lesson(5, '11:50', '12:35', 'Englisch', short: 'En', tint: 'violet'),
  _lesson(6, '13:30', '14:15', 'Sport', short: 'Sp', tint: 'amber'),
  {
    'starts': '14:25',
    'ends': '17:00',
    'subject': 'Nachmittagsbetreuung',
    'kind': 'care',
  },
];

Map<String, Object?> _event(
  String id,
  String title, {
  String? starts,
  String? ends,
  String? location,
  required List<String> who,
  bool tentative = false,
}) => {
  'id': id,
  'title': title,
  'location': location,
  'starts': starts,
  'ends': ends,
  'attendee_ids': who,
  'tentative': tentative,
  'key': true,
};

/// A household of [count] (4, 5 or 6) members with long names: no reference names,
/// two children, split care, a week-long trip and a long dish every day.
WeekBoard _household(int count) {
  final members = _names.take(count).toList();
  final ids = [for (final m in members) m.$1];
  return WeekBoard.fromJson({
    'week_start': '2026-10-12',
    'today': '2026-10-14',
    'generated_at': '2026-10-14T14:05:00',
    'settings': {
      'day_parts': ['12:00', '17:00'],
      'member_label': 'name',
    },
    'members': [
      for (final (id, name, color, kind) in members)
        {
          'id': id,
          'display_name': name,
          'color': color,
          'kind': kind,
          if (kind == 'adult')
            'baseline': {
              'state': 'home_office',
              'label': 'Heimarbeitsplatz am Hauptbahnhof',
            },
        },
    ],
    'presence': [
      {
        'id': 'trip',
        'member_id': 'a2',
        'state': 'travel',
        'label': 'Dienstreise nach Berlin-Schönefeld',
        'first_day': '2026-10-12',
        'last_day': '2026-10-15',
      },
      {
        'id': 'split-care',
        'member_id': 'k1',
        'state': 'childcare',
        'label': 'Nachmittagsbetreuung mit Schwimmen',
        'first_day': '2026-10-14',
        'last_day': '2026-10-14',
        'starts': '14:25',
        'ends': '17:00',
      },
    ],
    'timetables': [
      {
        'member_id': 'k1',
        'class_label': '5b',
        'school_name': 'Gesamtschule am Stadtpark',
        'periods': [
          {'index': 1, 'starts': '08:00', 'ends': '08:45', 'kind': 'lesson'},
          {'index': 2, 'starts': '08:50', 'ends': '09:35', 'kind': 'lesson'},
          {'index': 2, 'starts': '09:35', 'ends': '09:55', 'kind': 'break'},
          {'index': 3, 'starts': '09:55', 'ends': '10:40', 'kind': 'lesson'},
          {'index': 4, 'starts': '10:45', 'ends': '11:30', 'kind': 'lesson'},
          {'index': 4, 'starts': '11:30', 'ends': '11:50', 'kind': 'break'},
          {'index': 5, 'starts': '11:50', 'ends': '12:35', 'kind': 'lesson'},
          {'index': 6, 'starts': '13:30', 'ends': '14:15', 'kind': 'lesson'},
        ],
      },
    ],
    'days': [
      for (var i = 0; i < 7; i++)
        {
          'date': '2026-10-${12 + i}',
          'events': [
            if (i == 0)
              _event(
                'mon',
                'Elternsprechtag in der Gesamtschule',
                starts: '17:00',
                ends: '18:30',
                who: ['a1', 'k1'],
              ),
            if (i == _today) ...[
              _event('all', 'Geburtstag planen', who: ['a1']),
              _event(
                'heat',
                'Heizungswartung',
                starts: '10:00',
                ends: '11:00',
                location: 'Keller, Eingang über den Hof',
                who: ['a1'],
              ),
              _event(
                'dent',
                'Zahnarztkontrolle',
                starts: '13:00',
                ends: '13:30',
                location: 'Praxis Dr. Oberhauser-Lindqvist',
                who: ['k2', 'a1'],
              ),
              _event(
                'gym',
                'Turnen im Verein',
                starts: '14:30',
                ends: '15:15',
                who: ['k1'],
              ),
              _event(
                'bbq',
                'Grillen mit den Nachbarn',
                starts: '16:00',
                ends: '17:00',
                who: ids,
                tentative: true,
              ),
              _event(
                'eve',
                'Elternabend zur Klassenfahrt',
                starts: '19:30',
                who: ['a1', 'a2'],
              ),
            ],
          ],
          'busy_until': [
            if (i == _today) {'member_id': 'a1', 'until': '17:00'},
          ],
          'school': [
            if (i < 5)
              {
                'member_id': 'k1',
                'starts': '08:00',
                'ends': '14:15',
                'notable': ['Sport', 'Schwimmen'],
                'care_until': '17:00',
                'care_label': 'Nachmittagsbetreuung',
                'lessons': i == _today || i == 0 ? _lessons() : <Object>[],
              },
            if (i < 5)
              i == 1
                  ? {
                      'member_id': 'k2',
                      'free': 'holiday',
                      'holiday_name': 'Herbstferien',
                      'lessons': <Object>[],
                    }
                  : {
                      'member_id': 'k2',
                      'starts': '08:00',
                      'ends': '12:45',
                      'lessons': <Object>[],
                    },
          ],
          'meal': {
            'slot': 'dinner',
            'time': '18:30',
            'title':
                'Kartoffelgemüseauflauf mit Kräutersoße und Sonnenblumenkernen',
            'cook_id': 'a1',
            // Everyone but the last member, so both the eating and the
            // not-eating name are drawn.
            'eating': ids.take(ids.length - 1).toList(),
            'guests': 3,
          },
        },
    ],
    'open_tasks': <Object>[],
    'shopping_count': 0,
  });
}

/// The detail views a wall opens, each through its real entry point.
final _details = <String, Future<void> Function(BuildContext, WeekBoard)>{
  'day-today': (c, b) => openDayDetail(c, b, _today),
  'day-past': (c, b) => openDayDetail(c, b, 0),
  'member-week': (c, b) => openMemberWeek(c, b, 'a1'),
  'travel-week': (c, b) => openMemberWeek(c, b, 'a2'),
  'child-week': (c, b) => openChildWeek(c, b, 'k1'),
  'school-today': (c, b) => openSchoolDay(c, b, 'k1', _today),
  'school-past': (c, b) => openSchoolDay(c, b, 'k1', 0),
  'meal-week': (c, b) => openMealWeek(c, b),
};

class _FixedNight extends NightNotifier {
  _FixedNight(this.night);

  final bool night;

  @override
  bool build() => night;
}

final _frame = GlobalKey();

Future<BuildContext> _pumpHost(
  WidgetTester t, {
  required Size size,
  required Shade shade,
  required Locale locale,
  required double scale,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  late BuildContext host;
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        nowProvider.overrideWithValue(_now),
        nightProvider.overrideWith(() => _FixedNight(shade == Shade.night)),
      ],
      child: MaterialApp(
        theme: AppTheme.build(UiRegister.kiosk, shade),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        locale: locale,
        // The boundary holds the navigator, so the detail dialog is in the image.
        builder: (context, child) => RepaintBoundary(
          key: _frame,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    ),
  );
  return host;
}

Future<void> _open(
  WidgetTester t,
  BuildContext host,
  WeekBoard board,
  String detail,
) async {
  unawaited(_details[detail]!(host, board));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  expect(t.takeException(), isNull, reason: '$detail: layout exception');
  // Exactly one detail is open.
  expect(find.byType(FilledButton), findsOneWidget, reason: detail);
}

Future<void> _close(WidgetTester t) async {
  await t.tap(find.byType(FilledButton));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
  expect(find.byType(FilledButton), findsNothing);
}

/// The detail's paragraphs: everything on screen while it is open but icon glyphs.
List<RenderParagraph> _paragraphs(WidgetTester t) => [
  for (final e in find.byType(RichText).evaluate())
    if (e.renderObject case final RenderParagraph p
        when !p.text.toPlainText().runes.every(
          (r) => r >= 0xe000 && r <= 0xf8ff,
        ))
      p,
];

Rect _globalRect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// Size, clipping and opacity checks on every paragraph of the open detail. Every
/// problem is returned, so one run names all of them.
List<String> _checkLayout(WidgetTester t, String label, double scale) {
  final back = find.byType(FilledButton);
  final backSize = t.getSize(back);
  expect(backSize.width, greaterThanOrEqualTo(56), reason: '$label back');
  expect(backSize.height, greaterThanOrEqualTo(56), reason: '$label back');

  final problems = <String>[];
  final paragraphs = _paragraphs(t);
  expect(paragraphs, isNotEmpty);
  final width = t.view.physicalSize.width;
  for (final p in paragraphs) {
    final why = '"${p.text.toPlainText()}"';
    void checkSpan(InlineSpan span) {
      if (span.style?.fontSize case final size?) {
        // At least 24 px before the text scale, actually drawn scaled.
        final drawn = p.textScaler.scale(size);
        if (drawn < 24 * scale - 0.01) problems.add('$why drawn at $drawn px');
      }
      if (span is TextSpan) {
        for (final child in span.children ?? const <InlineSpan>[]) {
          checkSpan(child);
        }
      }
    }

    checkSpan(p.text);
    // Nothing cut short: no line limit or ellipsis hit, every laid-out line no wider
    // than the paragraph's box (a word too wide for it would be clipped there) and all
    // lines inside its height.
    if (p.didExceedMaxLines) problems.add('$why exceeds its line limit');
    final painter = TextPainter(
      text: p.text,
      textDirection: p.textDirection,
      textAlign: p.textAlign,
      textScaler: p.textScaler,
      maxLines: p.maxLines,
      locale: p.locale,
      strutStyle: p.strutStyle,
      textWidthBasis: p.textWidthBasis,
      textHeightBehavior: p.textHeightBehavior,
    )..layout(maxWidth: p.size.width);
    for (final line in painter.computeLineMetrics()) {
      if (line.width > p.size.width + 0.5) {
        problems.add('$why has a ${line.width} px line in ${p.size.width}');
        break;
      }
    }
    if (painter.height > p.size.height + 0.5) {
      problems.add(
        '$why needs ${painter.height} px high, has ${p.size.height}',
      );
    }
    painter.dispose();
    // A compound word wider than its column (Kartoffelgemüseauflauf at 200 %) wraps
    // inside the word; all of it stays on screen, so that is not counted here.
    // Inside the screen and every clip above it, left to right (top to bottom is
    // scrolling).
    final rect = _globalRect(p);
    if (rect.left < -0.1 || rect.right > width + 0.1) {
      problems.add('$why off screen at $rect');
    }
    for (RenderObject? o = p.parent; o != null; o = o.parent) {
      if (o is RenderClipRect || o is RenderClipRRect || o is RenderClipPath) {
        final clip = _globalRect(o as RenderBox);
        if (rect.left < clip.left - 0.1 || rect.right > clip.right + 0.1) {
          problems.add('$why clipped horizontally by $clip');
        }
      }
      // No fixed opacity over a text: the past and the cancelled recede through
      // their ground, so the text keeps its contrast-checked colour.
      if (o is RenderOpacity && o.opacity < 1) {
        problems.add('$why under opacity ${o.opacity}');
      }
      if (o is RenderAnimatedOpacity && o.opacity.value < 1) {
        problems.add('$why under opacity ${o.opacity.value}');
      }
    }
  }
  return [for (final p in problems) '$label: $p'];
}

double _channel(int v) {
  final s = v / 255;
  return s <= 0.04045
      ? s / 12.92
      : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(int argb) =>
    0.2126 * _channel((argb >> 16) & 0xff) +
    0.7152 * _channel((argb >> 8) & 0xff) +
    0.0722 * _channel(argb & 0xff);

double _ratio(int a, int b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

int _composite(Color c, int ground) {
  int mix(double fg, int bg) =>
      (fg * 255 * c.a + bg * (1 - c.a)).round().clamp(0, 255);
  return 0xff000000 |
      mix(c.r, (ground >> 16) & 0xff) << 16 |
      mix(c.g, (ground >> 8) & 0xff) << 8 |
      mix(c.b, ground & 0xff);
}

/// The text colours a paragraph paints, one per non-blank run.
Set<Color> _inks(RenderParagraph p) {
  final inks = <Color>{};
  void visit(InlineSpan span, Color? inherited) {
    final color = span.style?.color ?? inherited;
    if (span is TextSpan) {
      if ((span.text ?? '').trim().isNotEmpty && color != null) {
        inks.add(color);
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        visit(child, color);
      }
    }
  }

  visit(p.text, null);
  return inks;
}

/// Renders the open detail and measures every text against the pixels: its ground
/// is the rect's commonest colour; its declared colour must actually be painted there
/// (so nothing faded it) and must reach 4.5:1 against that ground.
Future<List<Map<String, Object?>>> _checkContrast(
  WidgetTester t,
  String label,
  List<String> problems,
) async {
  final boundary =
      _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final (bytes, width, height) = (await t.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    final result = (data!, image.width, image.height);
    image.dispose();
    return result;
  }))!;
  int pixel(int x, int y) {
    final i = (y * width + x) * 4;
    return 0xff000000 |
        bytes.getUint8(i) << 16 |
        bytes.getUint8(i + 1) << 8 |
        bytes.getUint8(i + 2);
  }

  final rows = <Map<String, Object?>>[];
  for (final p in _paragraphs(t)) {
    final text = p.text.toPlainText();
    final rect = _globalRect(p);
    final visible = rect.intersect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    // Rendered inside the image: the contrast run uses a tall view, so nothing scrolls.
    if ((visible.height - rect.height).abs() > 0.5) {
      problems.add('$label "$text" is outside the rendered image');
      continue;
    }
    final counts = <int, int>{};
    final left = rect.left.ceil(), right = rect.right.floor();
    final top = rect.top.ceil(), bottom = rect.bottom.floor();
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final c = pixel(x, y);
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    final ground = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    for (final ink in _inks(p)) {
      final expected = _composite(ink, ground);
      // The declared colour is really painted (a stem pixel within rounding).
      var nearest = 1 << 30;
      for (final c in counts.keys) {
        var d = 0;
        for (final shift in const [16, 8, 0]) {
          d = math.max(
            d,
            (((c >> shift) & 0xff) - ((expected >> shift) & 0xff)).abs(),
          );
        }
        nearest = math.min(nearest, d);
      }
      final ratio = _ratio(expected, ground);
      final painted = nearest <= 8;
      final pass = painted && ratio >= 4.5;
      rows.add({
        'text': text,
        'ink': expected.toRadixString(16),
        'ground': ground.toRadixString(16),
        'ratio': double.parse(ratio.toStringAsFixed(3)),
        'painted_delta': nearest,
        'pass': pass,
      });
      if (!pass) {
        problems.add(
          '$label "$text": ${expected.toRadixString(16)} on '
          '${ground.toRadixString(16)} = ${ratio.toStringAsFixed(2)}'
          '${painted ? '' : ', not painted (nearest $nearest)'}',
        );
      }
    }
  }
  return rows;
}

/// When set, the contrast measurements are written there as JSON (evidence for QA).
final _evidenceDir = Platform.environment['WW_DETAIL_A11Y_OUT'];

void main() {
  setUpAll(() async {
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

  const locales = [Locale('de'), Locale('en')];
  const scales = [1.0, 1.5, 2.0];

  group('kiosk details at 1280x800: size, clipping, opacity (t_10f0b348)', () {
    for (final locale in locales) {
      for (final shade in Shade.values) {
        for (final scale in scales) {
          for (final count in [4, 5, 6]) {
            final key =
                '${locale.languageCode}-${shade.name}-${scale}x-$count members';
            testWidgets(key, (t) async {
              final board = _household(count);
              final host = await _pumpHost(
                t,
                size: const Size(1280, 800),
                shade: shade,
                locale: locale,
                scale: scale,
              );
              final problems = <String>[];
              for (final detail in _details.keys) {
                await _open(t, host, board, detail);
                problems.addAll(_checkLayout(t, detail, scale));
                await _close(t);
              }
              expect(problems, isEmpty);
            });
          }
        }
      }
    }
  });

  group('kiosk details: painted text contrast >= 4.5:1 (t_10f0b348)', () {
    for (final locale in locales) {
      for (final shade in Shade.values) {
        for (final scale in scales) {
          final key = '${locale.languageCode}-${shade.name}-${scale}x';
          testWidgets(key, (t) async {
            final board = _household(6);
            // Tall enough that no detail scrolls, so every text is in the image.
            final host = await _pumpHost(
              t,
              size: const Size(1280, 8000),
              shade: shade,
              locale: locale,
              scale: scale,
            );
            final evidence = <String, Object?>{};
            final problems = <String>[];
            for (final detail in _details.keys) {
              await _open(t, host, board, detail);
              evidence[detail] = await _checkContrast(t, detail, problems);
              await _close(t);
            }
            if (_evidenceDir case final dir?) {
              Directory(dir).createSync(recursive: true);
              File('$dir/contrast-$key.json')
                  .writeAsStringSync(jsonEncode(evidence));
            }
            expect(problems, isEmpty);
          });
        }
      }
    }
  });

  testWidgets('a scaled avatar initial is 24 px before the scale and fits', (
    t,
  ) async {
    for (final scale in scales) {
      final host = await _pumpHost(
        t,
        size: const Size(1280, 800),
        shade: Shade.light,
        locale: const Locale('de'),
        scale: scale,
      );
      await _open(t, host, _household(6), 'day-today');
      final initials = [
        for (final p in _paragraphs(t))
          if (p.text.toPlainText().length == 1) p,
      ];
      expect(initials, hasLength(6));
      for (final p in initials) {
        expect(p.textScaler.scale(p.text.style!.fontSize!), 24 * scale);
        expect(
          p.getMaxIntrinsicHeight(p.size.width),
          lessThanOrEqualTo(p.size.height),
        );
      }
      await _close(t);
    }
  });
}
