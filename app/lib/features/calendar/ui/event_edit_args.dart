import 'package:wuselwall/features/calendar/domain/calendar_models.dart';
import 'package:wuselwall/features/calendar/domain/tradition_starters.dart';

/// What the editor receives. An existing appointment is opened with its [eventId] and
/// the occurrence it was tapped on (its title shows at once, and its original start
/// identifies the occurrence when only this one changes). A new event may name the
/// tapped [date]; without one it starts today. A new tradition starts from its
/// [tradition] template (Kalender → *Neue Tradition*). Null: a new event starting today.
class EventEditArgs {
  const EventEditArgs({
    this.eventId,
    this.occurrence,
    this.date,
    this.tradition,
  });

  final String? eventId;
  final Occurrence? occurrence;

  /// The local day a new event starts on.
  final DateTime? date;

  /// A new tradition's starting point; null for anything else.
  final TraditionTemplate? tradition;
}
