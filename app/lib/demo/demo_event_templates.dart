import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';
import 'package:wuselwall/features/calendar/data/event_templates_repository.dart';
import 'package:wuselwall/features/calendar/domain/event_templates.dart';

/// The demo family's templates (specs/28): the son's football tournaments are a saved
/// template, and the grandparents' visits and the dentist come up often enough to be
/// suggested. Changes last for the session.
class DemoEventTemplatesRepository implements EventTemplatesRepository {
  var _next = 2;
  final _hidden = <String>{};

  late final _templates = <EventTemplate>[
    EventTemplate(
      id: 't-1',
      title: demoText('Fußballturnier'),
      iconKey: 'football',
      startMinute: 9 * 60,
      durationMinutes: 300,
      attendeeIds: const {DemoData.son, DemoData.papa},
      location: demoText('Sportplatz Ost'),
      createdBy: DemoData.papa,
    ),
  ];

  List<EventTemplate> get _suggestions => [
    EventTemplate(
      signature: 'oma & opa kommen',
      count: 6,
      title: demoText('Oma & Opa kommen'),
      iconKey: 'house',
      startMinute: 15 * 60,
      durationMinutes: 180,
      attendeeIds: const {
        DemoData.papa,
        DemoData.mama,
        DemoData.daughter,
        DemoData.son,
      },
    ),
    EventTemplate(
      signature: 'zahnarzt',
      count: 4,
      title: demoText('Zahnarzt'),
      startMinute: 15 * 60 + 30,
      durationMinutes: 60,
      attendeeIds: const {DemoData.mama, DemoData.daughter},
    ),
  ];

  @override
  Future<Result<List<EventTemplate>>> templates() async => Ok([..._templates]);

  @override
  Future<Result<String>> save({
    required String? actor,
    required EventTemplate template,
  }) async {
    final id = template.id ?? 't-${_next++}';
    final saved = EventTemplate.fromJson({
      ...template.toJson(),
      'id': id,
      'created_by_profile_id': actor,
    });
    _templates
      ..removeWhere((t) => t.id == id)
      ..add(saved);
    return Ok(id);
  }

  @override
  Future<Result<void>> delete({
    required String? actor,
    required String id,
  }) async {
    _templates.removeWhere((t) => t.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<List<EventTemplate>>> suggestions({
    required DateTime on,
    int limit = 4,
  }) async {
    // A suggestion kept as a template is no longer suggested, as on a server.
    final saved = {for (final t in _templates) t.title.toLowerCase()};
    return Ok(
      [
        for (final s in _suggestions)
          if (!_hidden.contains(s.signature) &&
              !saved.contains(s.title.toLowerCase()))
            s,
      ].take(limit).toList(),
    );
  }

  @override
  Future<Result<void>> hideSuggestion({
    required String? actor,
    required String signature,
    bool hidden = true,
  }) async {
    hidden ? _hidden.add(signature) : _hidden.remove(signature);
    return const Ok(null);
  }
}
