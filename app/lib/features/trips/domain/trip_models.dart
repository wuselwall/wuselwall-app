import 'package:flutter/material.dart' show TimeOfDay;
import 'package:wuselwall/features/board/domain/week_board.dart'
    show parseDate, parseTime;
import 'package:wuselwall/features/calendar/domain/calendar_models.dart'
    show clockOf, isoDate;
import 'package:wuselwall/features/trips/domain/trip_dates.dart';

/// Trips, their entries, stored combinations, checks and the home place, shaped by the
/// contract of `api.trips`, `api.trip_entries`, `api.trip_combos`, `api.trip_checks`,
/// `api.trip_home` and the `api.trip_*` write functions (specs/30 "Data and contract").
///
/// Dates are local dates at midnight ([parseDate]); the times of an entry are the
/// place's own wall clock, with no zone and no conversion (specs/30 "Times are the
/// place's own"), read and written as `HH:MM`.

/// Marks "keep the old value" in the `copyWith` of a class whose fields can be null.
const Object _keep = Object();

T? _pick<T>(Object? value, T? old) =>
    identical(value, _keep) ? old : value as T?;

DateTime? _date(Object? v) => v == null ? null : parseDate(v as String);

TimeOfDay? _clock(Object? v) => v == null ? null : parseTime(v as String);

String? _isoOrNull(DateTime? d) => d == null ? null : isoDate(d);

String? _clockOrNull(TimeOfDay? t) => t == null ? null : clockOf(t);

double? _double(Object? v) => (v as num?)?.toDouble();

List<String> _strings(Object? v) =>
    ((v as List?) ?? const []).cast<String>().toList(growable: false);

/// Where a trip stands (specs/30 "The journey").
enum TripStage {
  /// A wish: no dates needed, nothing in the calendar.
  idea,

  /// Pencilled into dates; one tentative all-day entry in the calendar.
  planned,

  /// Decided; the calendar entry is confirmed and counts down.
  fixed;

  static TripStage parse(String? v) => switch (v) {
    'planned' => planned,
    'fixed' => fixed,
    _ => idea,
  };

  String get wire => name;
}

/// An `api.trips` row.
class Trip {
  const Trip({
    required this.id,
    required this.title,
    this.iconKey,
    this.stage = TripStage.idea,
    this.destinationName,
    this.destinationKey,
    this.country,
    this.lat,
    this.lon,
    this.startsOn,
    this.endsOn,
    this.note = '',
    this.currency = '',
    this.memberIds = const [],
    this.eventId,
    this.createdAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    iconKey: json['icon_key'] as String?,
    stage: TripStage.parse(json['stage'] as String?),
    destinationName: json['destination_name'] as String?,
    destinationKey: json['destination_key'] as String?,
    country: json['country'] as String?,
    lat: _double(json['lat']),
    lon: _double(json['lon']),
    startsOn: _date(json['starts_on']),
    endsOn: _date(json['ends_on']),
    note: json['note'] as String? ?? '',
    currency: json['currency'] as String? ?? '',
    memberIds: _strings(json['member_ids']),
    eventId: json['event_id'] as String?,
    createdAt: json['created_at'] == null
        ? null
        : DateTime.parse(json['created_at'] as String),
  );

  /// Client-chosen on create (a UUID), which makes saving idempotent.
  final String id;

  /// 1–120 characters.
  final String title;

  /// One of the event icons (`eventIconKeys`); null for none.
  final String? iconKey;
  final TripStage stage;
  final String? destinationName;

  /// The key of the destination in the server's catalogue, when it came from there.
  final String? destinationKey;

  /// ISO 3166-1 alpha-2, upper case.
  final String? country;
  final double? lat;
  final double? lon;

  /// Both or neither; required unless [stage] is [TripStage.idea]; at most 366 days.
  final DateTime? startsOn;
  final DateTime? endsOn;

  /// At most 4000 characters.
  final String note;

  /// Three letters; the currency of every price of the trip's entries. Empty for a trip
  /// not saved yet: the key is then left out and the server takes the household's habit
  /// (the last trip's currency, else CHF for CH and LI, else EUR).
  final String currency;

  /// Who travels; empty means the whole family.
  final List<String> memberIds;

  /// The trip's calendar entry (`app.event.trip_id`); null for an idea.
  final String? eventId;
  final DateTime? createdAt;

  bool get hasDates => startsOn != null && endsOn != null;
  bool get hasCoordinates => lat != null && lon != null;

  /// Everybody travels.
  bool get wholeFamily => memberIds.isEmpty;

  /// Nights from the first to the last day; 0 for a trip without dates.
  int get nights => hasDates ? daysBetween(startsOn!, endsOn!) : 0;

  /// The days from [startsOn] to [endsOn], both included; 0 without dates.
  int get days => hasDates ? nights + 1 : 0;

  /// A trip is running from its first to its last day, by date, whatever its stage.
  bool isRunning(DateTime today) =>
      hasDates && dayWithin(dayOf(today), startsOn!, endsOn!);

  /// After the last day.
  bool isPast(DateTime today) =>
      hasDates && daysBetween(endsOn!, dayOf(today)) > 0;

  /// Days until the first day: 0 on it, negative after it; null without dates.
  int? daysUntil(DateTime today) =>
      hasDates ? daysBetween(dayOf(today), startsOn!) : null;

  /// "Tag 3 von 10": 1 on the first day; null when the trip is not running today.
  int? dayNumber(DateTime today) =>
      isRunning(today) ? daysBetween(startsOn!, dayOf(today)) + 1 : null;

  /// The `p_trip` of `api.trip_save`: every key, a cleared value as JSON null (the
  /// server keeps a value only for an omitted key). [eventId] and [createdAt] belong to
  /// the server.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title.trim(),
    'icon_key': iconKey,
    'stage': stage.wire,
    'destination_name': destinationName,
    'destination_key': destinationKey,
    'country': country,
    'lat': lat,
    'lon': lon,
    'starts_on': _isoOrNull(startsOn),
    'ends_on': _isoOrNull(endsOn),
    'note': note,
    if (currency.isNotEmpty) 'currency': currency,
    'member_ids': memberIds,
  };

  /// A copy with the given fields changed. A nullable field passed as null becomes null;
  /// one not passed keeps its value.
  Trip copyWith({
    String? title,
    Object? iconKey = _keep,
    TripStage? stage,
    Object? destinationName = _keep,
    Object? destinationKey = _keep,
    Object? country = _keep,
    Object? lat = _keep,
    Object? lon = _keep,
    Object? startsOn = _keep,
    Object? endsOn = _keep,
    String? note,
    String? currency,
    List<String>? memberIds,
  }) => Trip(
    id: id,
    title: title ?? this.title,
    iconKey: _pick(iconKey, this.iconKey),
    stage: stage ?? this.stage,
    destinationName: _pick(destinationName, this.destinationName),
    destinationKey: _pick(destinationKey, this.destinationKey),
    country: _pick(country, this.country),
    lat: _pick(lat, this.lat),
    lon: _pick(lon, this.lon),
    startsOn: _pick(startsOn, this.startsOn),
    endsOn: _pick(endsOn, this.endsOn),
    note: note ?? this.note,
    currency: currency ?? this.currency,
    memberIds: memberIds ?? this.memberIds,
    eventId: eventId,
    createdAt: createdAt,
  );
}

/// What an entry of a trip is (specs/30 "Options and the plan").
enum EntryKind {
  transport,
  stay,
  rental,
  activity,
  note;

  static EntryKind parse(String? v) => switch (v) {
    'transport' => transport,
    'stay' => stay,
    'rental' => rental,
    'note' => note,
    _ => activity,
  };

  String get wire => name;

  /// The kinds that are compared and combined (specs/30 "Comparing and combining").
  bool get comparable => this == transport || this == stay || this == rental;
}

/// How a transport entry travels; only for [EntryKind.transport].
enum TransportMode {
  flight,
  train,
  car,
  ferry,
  bus,
  other;

  static TransportMode? parse(String? v) => switch (v) {
    null => null,
    'flight' => flight,
    'train' => train,
    'car' => car,
    'ferry' => ferry,
    'bus' => bus,
    _ => other,
  };

  String get wire => name;
}

/// Where an entry stands: found, this one, or booked.
enum EntryState {
  /// Found, not decided.
  option,

  /// This one: it belongs to the plan.
  chosen,

  /// Chosen and booked; the reference is filled in.
  booked;

  static EntryState parse(String? v) => switch (v) {
    'chosen' => chosen,
    'booked' => booked,
    _ => option,
  };

  String get wire => name;

  /// Chosen or booked: part of the plan.
  bool get inPlan => this != option;
}

/// An `api.trip_entries` row: an option, a decision or a booking of one trip.
class TripEntry {
  const TripEntry({
    required this.id,
    required this.tripId,
    required this.kind,
    required this.title,
    this.mode,
    this.state = EntryState.option,
    this.url,
    this.priceCents,
    this.priceCheckedOn,
    this.details,
    this.note = '',
    this.fromPlace,
    this.toPlace,
    this.bookingRef,
    this.cancelUntil,
    this.address,
    this.phone,
    this.lat,
    this.lon,
    this.startsOn,
    this.startsTime,
    this.endsOn,
    this.endsTime,
    this.position = 0,
    this.sourceUid,
  });

  factory TripEntry.fromJson(Map<String, dynamic> json) => TripEntry(
    id: json['id'] as String,
    tripId: json['trip_id'] as String,
    kind: EntryKind.parse(json['kind'] as String?),
    mode: TransportMode.parse(json['mode'] as String?),
    title: json['title'] as String? ?? '',
    state: EntryState.parse(json['state'] as String?),
    url: json['url'] as String?,
    priceCents: (json['price_cents'] as num?)?.toInt(),
    priceCheckedOn: _date(json['price_checked_on']),
    details: json['details'] as String?,
    note: json['note'] as String? ?? '',
    fromPlace: json['from_place'] as String?,
    toPlace: json['to_place'] as String?,
    bookingRef: json['booking_ref'] as String?,
    cancelUntil: _date(json['cancel_until']),
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    lat: _double(json['lat']),
    lon: _double(json['lon']),
    startsOn: _date(json['starts_on']),
    startsTime: _clock(json['starts_time']),
    endsOn: _date(json['ends_on']),
    endsTime: _clock(json['ends_time']),
    position: (json['position'] as num?)?.toInt() ?? 0,
    sourceUid: json['source_uid'] as String?,
  );

  /// Client-chosen on create (a UUID), which makes saving idempotent.
  final String id;
  final String tripId;
  final EntryKind kind;

  /// Only for [EntryKind.transport].
  final TransportMode? mode;

  /// 1–200 characters.
  final String title;
  final EntryState state;

  /// An http or https link, at most 2000 characters; opened in the phone's own browser.
  final String? url;

  /// The price in the trip's currency, in hundredths; null for none yet.
  final int? priceCents;

  /// The day the price was entered or last changed; set by the server.
  final DateTime? priceCheckedOn;

  /// A short line ("1 Stopp, Gepäck inklusive"), at most 200 characters.
  final String? details;
  final String note;

  /// Transport and rental: where from and to (at most 80 characters each).
  final String? fromPlace;
  final String? toPlace;
  final String? bookingRef;

  /// The last day on which the booking can be cancelled free of charge.
  final DateTime? cancelUntil;

  /// Stay and activity (at most 300 characters); opened in the phone's maps app.
  final String? address;

  /// Stay and activity; opened in the phone's dialler.
  final String? phone;
  final double? lat;
  final double? lon;

  /// The ticket's own date and wall-clock time. A time needs its date; an end is not
  /// before its start.
  final DateTime? startsOn;
  final TimeOfDay? startsTime;
  final DateTime? endsOn;
  final TimeOfDay? endsTime;

  /// Order within the trip; the server places a copy after its original.
  final int position;

  /// The calendar file's UID when the entry came from one.
  final String? sourceUid;

  bool get hasDates => startsOn != null;
  bool get hasPrice => priceCents != null;

  /// The last day, [endsOn] or else the first day.
  DateTime? get lastDay => endsOn ?? startsOn;

  /// Nights from [startsOn] to [endsOn] (a stay's check-in to check-out); null without
  /// both dates.
  int? get nights => startsOn == null || endsOn == null
      ? null
      : daysBetween(startsOn!, endsOn!);

  /// Days from [startsOn] to [endsOn], both included (a rental's days); null without
  /// both dates.
  int? get days => nights == null ? null : nights! + 1;

  /// A stay's price per night; null without a price or at least one night.
  int? get pricePerNight {
    final n = nights;
    return priceCents == null || n == null || n < 1
        ? null
        : (priceCents! / n).round();
  }

  /// A rental's price per day (both end days count); null without a price or both dates.
  int? get pricePerDay {
    final d = days;
    return priceCents == null || d == null || d < 1
        ? null
        : (priceCents! / d).round();
  }

  /// Free cancellation is over: [cancelUntil] lies before [today].
  bool cancellationPassed(DateTime today) =>
      cancelUntil != null && daysBetween(cancelUntil!, dayOf(today)) > 0;

  /// The `p_entry` of `api.trip_entry_save`: every key, a cleared value as JSON null.
  /// `price_checked_on`, `position` and the audit columns belong to the server.
  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'kind': kind.wire,
    'mode': kind == EntryKind.transport ? mode?.wire : null,
    'title': title.trim(),
    'state': state.wire,
    'url': url,
    'price_cents': priceCents,
    'details': details,
    'note': note,
    'from_place': fromPlace,
    'to_place': toPlace,
    'booking_ref': bookingRef,
    'cancel_until': _isoOrNull(cancelUntil),
    'address': address,
    'phone': phone,
    'lat': lat,
    'lon': lon,
    'starts_on': _isoOrNull(startsOn),
    'starts_time': _clockOrNull(startsTime),
    'ends_on': _isoOrNull(endsOn),
    'ends_time': _clockOrNull(endsTime),
    if (sourceUid != null) 'source_uid': sourceUid,
  };

  /// One element of `p_entries` of `api.trip_entries_import`: [toJson] without the id
  /// and the trip, which the call names itself. [sourceUid] identifies the entry.
  Map<String, dynamic> toImportJson() => toJson()
    ..remove('id')
    ..remove('trip_id');

  /// A copy with the given fields changed. A nullable field passed as null becomes null;
  /// one not passed keeps its value.
  TripEntry copyWith({
    String? id,
    EntryKind? kind,
    Object? mode = _keep,
    String? title,
    EntryState? state,
    Object? url = _keep,
    Object? priceCents = _keep,
    Object? priceCheckedOn = _keep,
    Object? details = _keep,
    String? note,
    Object? fromPlace = _keep,
    Object? toPlace = _keep,
    Object? bookingRef = _keep,
    Object? cancelUntil = _keep,
    Object? address = _keep,
    Object? phone = _keep,
    Object? lat = _keep,
    Object? lon = _keep,
    Object? startsOn = _keep,
    Object? startsTime = _keep,
    Object? endsOn = _keep,
    Object? endsTime = _keep,
    int? position,
    Object? sourceUid = _keep,
  }) => TripEntry(
    id: id ?? this.id,
    tripId: tripId,
    kind: kind ?? this.kind,
    mode: _pick(mode, this.mode),
    title: title ?? this.title,
    state: state ?? this.state,
    url: _pick(url, this.url),
    priceCents: _pick(priceCents, this.priceCents),
    priceCheckedOn: _pick(priceCheckedOn, this.priceCheckedOn),
    details: _pick(details, this.details),
    note: note ?? this.note,
    fromPlace: _pick(fromPlace, this.fromPlace),
    toPlace: _pick(toPlace, this.toPlace),
    bookingRef: _pick(bookingRef, this.bookingRef),
    cancelUntil: _pick(cancelUntil, this.cancelUntil),
    address: _pick(address, this.address),
    phone: _pick(phone, this.phone),
    lat: _pick(lat, this.lat),
    lon: _pick(lon, this.lon),
    startsOn: _pick(startsOn, this.startsOn),
    startsTime: _pick(startsTime, this.startsTime),
    endsOn: _pick(endsOn, this.endsOn),
    endsTime: _pick(endsTime, this.endsTime),
    position: position ?? this.position,
    sourceUid: _pick(sourceUid, this.sourceUid),
  );
}

/// An `api.trip_combos` row: a named set of entries kept for comparing.
class TripCombo {
  const TripCombo({
    required this.id,
    required this.tripId,
    required this.name,
    this.entryIds = const [],
    this.position = 0,
  });

  factory TripCombo.fromJson(Map<String, dynamic> json) => TripCombo(
    id: json['id'] as String,
    tripId: json['trip_id'] as String,
    name: json['name'] as String? ?? '',
    entryIds: _strings(json['entry_ids']),
    position: (json['position'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String tripId;

  /// 1–60 characters.
  final String name;

  /// Entries of the trip, at most 40. An entry that was deleted has left the set.
  final List<String> entryIds;
  final int position;

  /// The `p_combo` of `api.trip_combo_save`.
  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'name': name.trim(),
    'entry_ids': entryIds,
  };

  TripCombo copyWith({String? name, List<String>? entryIds}) => TripCombo(
    id: id,
    tripId: tripId,
    name: name ?? this.name,
    entryIds: entryIds ?? this.entryIds,
    position: position,
  );
}

/// The two kinds of check of a trip (specs/30 "Packing and preparing").
enum CheckKind {
  /// The packing list.
  pack,

  /// What has to happen before the trip.
  todo;

  static CheckKind parse(String? v) => v == 'todo' ? todo : pack;

  String get wire => name;
}

/// An `api.trip_checks` row: a packing item or a to-do. Nothing counts or earns points.
class TripCheck {
  const TripCheck({
    required this.id,
    required this.tripId,
    required this.kind,
    required this.title,
    this.profileId,
    this.dueDaysBefore,
    this.doneAt,
    this.doneBy,
    this.position = 0,
  });

  factory TripCheck.fromJson(Map<String, dynamic> json) => TripCheck(
    id: json['id'] as String,
    tripId: json['trip_id'] as String,
    kind: CheckKind.parse(json['kind'] as String?),
    title: json['title'] as String? ?? '',
    profileId: json['profile_id'] as String?,
    dueDaysBefore: (json['due_days_before'] as num?)?.toInt(),
    doneAt: json['done_at'] == null
        ? null
        : DateTime.parse(json['done_at'] as String),
    doneBy: json['done_by_profile_id'] as String?,
    position: (json['position'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String tripId;
  final CheckKind kind;

  /// 1–120 characters.
  final String title;

  /// Packing: whose item it is; null for the family. Not used by to-dos.
  final String? profileId;

  /// To-dos: how many days before the first day it is due (0–365).
  final int? dueDaysBefore;
  final DateTime? doneAt;
  final String? doneBy;
  final int position;

  bool get done => doneAt != null;

  /// The day a to-do is due: [dueDaysBefore] days before the trip's first day; null
  /// without either.
  DateTime? dueOn(Trip trip) => dueDaysBefore == null || trip.startsOn == null
      ? null
      : addDays(trip.startsOn!, -dueDaysBefore!);

  /// The `p_check` of `api.trip_check_save`. Ticking goes through `tickCheck`.
  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'kind': kind.wire,
    'title': title.trim(),
    'profile_id': kind == CheckKind.pack ? profileId : null,
    'due_days_before': kind == CheckKind.todo ? dueDaysBefore : null,
  };

  TripCheck copyWith({
    String? title,
    Object? profileId = _keep,
    Object? dueDaysBefore = _keep,
  }) => TripCheck(
    id: id,
    tripId: tripId,
    kind: kind,
    title: title ?? this.title,
    profileId: _pick(profileId, this.profileId),
    dueDaysBefore: _pick(dueDaysBefore, this.dueDaysBefore),
    doneAt: doneAt,
    doneBy: doneBy,
    position: position,
  );
}

/// The household's home place, the start of the travel effort (`api.trip_home`).
class TripHome {
  const TripHome({
    required this.name,
    required this.lat,
    required this.lon,
    this.updatedAt,
  });

  factory TripHome.fromJson(Map<String, dynamic> json) => TripHome(
    name: json['name'] as String? ?? '',
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String),
  );

  /// At most 120 characters.
  final String name;

  /// Two decimals at most: the server stores a rounded place.
  final double lat;
  final double lon;
  final DateTime? updatedAt;

  /// The `p_home` of `api.trip_home_set`, coordinates rounded to two decimals.
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'lat': (lat * 100).round() / 100,
    'lon': (lon * 100).round() / 100,
  };
}

/// The answer of `api.trip_save`.
class TripSaved {
  const TripSaved({required this.id, this.eventId});

  factory TripSaved.fromJson(Map<String, dynamic> json) =>
      TripSaved(id: json['id'] as String, eventId: json['event_id'] as String?);

  final String id;

  /// The trip's calendar entry; null while the trip is an idea.
  final String? eventId;
}

/// The answer of `api.trip_combo_choose` ("Diese nehmen").
class ComboChoice {
  const ComboChoice({
    required this.chosen,
    required this.released,
    required this.datesSet,
  });

  factory ComboChoice.fromJson(Map<String, dynamic> json) => ComboChoice(
    chosen: (json['chosen'] as num?)?.toInt() ?? 0,
    released: (json['released'] as num?)?.toInt() ?? 0,
    datesSet: json['dates_set'] as bool? ?? false,
  );

  /// Entries set to `chosen`.
  final int chosen;

  /// Other `chosen` transport, stay and rental entries set back to `option`.
  final int released;

  /// The trip's dates were set to the combination's.
  final bool datesSet;
}

/// The answer of `api.trip_entries_import`.
class EntriesImported {
  const EntriesImported({required this.added, required this.updated});

  factory EntriesImported.fromJson(Map<String, dynamic> json) =>
      EntriesImported(
        added: (json['added'] as num?)?.toInt() ?? 0,
        updated: (json['updated'] as num?)?.toInt() ?? 0,
      );

  final int added;
  final int updated;
}
