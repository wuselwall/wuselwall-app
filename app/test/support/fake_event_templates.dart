import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/calendar/data/event_templates_repository.dart';
import 'package:wuselwall/features/calendar/domain/event_templates.dart';

/// Saved templates and suggestions in memory (specs/28); records what was saved,
/// deleted and hidden.
class FakeEventTemplatesRepository implements EventTemplatesRepository {
  FakeEventTemplatesRepository({
    List<EventTemplate> templates = const [],
    this.suggested = const [],
  }) : _templates = [...templates];

  final List<EventTemplate> _templates;
  final List<EventTemplate> suggested;
  final saved = <EventTemplate>[];
  final deleted = <String>[];
  final hidden = <String>[];
  final suggestionDays = <DateTime>[];

  @override
  Future<Result<List<EventTemplate>>> templates() async => Ok([..._templates]);

  @override
  Future<Result<String>> save({
    required String? actor,
    required EventTemplate template,
  }) async {
    saved.add(template);
    final id = template.id ?? 'tpl-${saved.length}';
    _templates
      ..removeWhere((t) => t.id == id)
      ..add(EventTemplate.fromJson({...template.toJson(), 'id': id}));
    return Ok(id);
  }

  @override
  Future<Result<void>> delete({
    required String? actor,
    required String id,
  }) async {
    deleted.add(id);
    _templates.removeWhere((t) => t.id == id);
    return const Ok(null);
  }

  @override
  Future<Result<List<EventTemplate>>> suggestions({
    required DateTime on,
    int limit = 4,
  }) async {
    suggestionDays.add(on);
    return Ok([
      for (final s in suggested)
        if (!hidden.contains(s.signature)) s,
    ]);
  }

  @override
  Future<Result<void>> hideSuggestion({
    required String? actor,
    required String signature,
    bool hidden = true,
  }) async {
    hidden ? this.hidden.add(signature) : this.hidden.remove(signature);
    return const Ok(null);
  }
}
