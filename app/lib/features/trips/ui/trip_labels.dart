import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/trips/domain/trip_models.dart';

/// The words, icons and formats every trips page shares (specs/30). One place, so a stage, a
/// kind or a price reads the same on the list, the trip, the comparison and Today.

String tripStageLabel(AppLocalizations l10n, TripStage stage) =>
    switch (stage) {
      TripStage.idea => l10n.tripStageIdea,
      TripStage.planned => l10n.tripStagePlanned,
      TripStage.fixed => l10n.tripStageFixed,
    };

/// One entry of that kind ("Unterkunft").
String entryKindLabel(AppLocalizations l10n, EntryKind kind) => switch (kind) {
  EntryKind.transport => l10n.tripKindTransport,
  EntryKind.stay => l10n.tripKindStay,
  EntryKind.rental => l10n.tripKindRental,
  EntryKind.activity => l10n.tripKindActivity,
  EntryKind.note => l10n.tripKindNote,
};

/// The section of that kind ("Unterkünfte").
String entryKindPlural(AppLocalizations l10n, EntryKind kind) => switch (kind) {
  EntryKind.transport => l10n.tripKindTransportPlural,
  EntryKind.stay => l10n.tripKindStayPlural,
  EntryKind.rental => l10n.tripKindRentalPlural,
  EntryKind.activity => l10n.tripKindActivityPlural,
  EntryKind.note => l10n.tripKindNotePlural,
};

String transportModeLabel(AppLocalizations l10n, TransportMode mode) =>
    switch (mode) {
      TransportMode.flight => l10n.tripModeFlight,
      TransportMode.train => l10n.tripModeTrain,
      TransportMode.car => l10n.tripModeCar,
      TransportMode.ferry => l10n.tripModeFerry,
      TransportMode.bus => l10n.tripModeBus,
      TransportMode.other => l10n.tripModeOther,
    };

String entryStateLabel(AppLocalizations l10n, EntryState state) =>
    switch (state) {
      EntryState.option => l10n.tripStateOption,
      EntryState.chosen => l10n.tripStateChosen,
      EntryState.booked => l10n.tripStateBooked,
    };

IconData entryKindIcon(EntryKind kind) => switch (kind) {
  EntryKind.transport => Icons.commute_outlined,
  EntryKind.stay => Icons.hotel_outlined,
  EntryKind.rental => Icons.car_rental_outlined,
  EntryKind.activity => Icons.local_activity_outlined,
  EntryKind.note => Icons.sticky_note_2_outlined,
};

IconData transportModeIcon(TransportMode mode) => switch (mode) {
  TransportMode.flight => Icons.flight_outlined,
  TransportMode.train => Icons.train_outlined,
  TransportMode.car => Icons.directions_car_outlined,
  TransportMode.ferry => Icons.directions_boat_outlined,
  TransportMode.bus => Icons.directions_bus_outlined,
  TransportMode.other => Icons.commute_outlined,
};

/// The icon of one entry: a transport shows its mode.
IconData entryIcon(TripEntry entry) {
  final mode = entry.mode;
  return entry.kind == EntryKind.transport && mode != null
      ? transportModeIcon(mode)
      : entryKindIcon(entry.kind);
}

String _tag(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

/// "CHF 840" or "1.249,50 €": whole amounts without decimals, the currency as the trip names it.
String formatTripMoney(BuildContext context, int cents, String currency) {
  final whole = cents % 100 == 0;
  final name = currency.isEmpty ? null : currency;
  return NumberFormat.currency(
    locale: _tag(context),
    name: name,
    symbol: name == null ? '' : null,
    decimalDigits: whole ? 0 : 2,
  ).format(cents / 100).trim();
}

/// "Sa., 12. Juli": one day of a trip.
String formatTripDay(BuildContext context, DateTime day) =>
    DateFormat.MMMEd(_tag(context)).format(day);

/// "12. Juli": a day without its weekday.
String formatTripDate(BuildContext context, DateTime day) =>
    DateFormat.MMMd(_tag(context)).format(day);

/// "12. Juli – 21. Juli 2027": the dates of a trip, a window or an entry.
String formatTripDates(BuildContext context, DateTime from, DateTime to) {
  final tag = _tag(context);
  if (DateUtils.isSameDay(from, to)) return DateFormat.yMMMd(tag).format(from);
  return '${DateFormat.MMMd(tag).format(from)} – ${DateFormat.yMMMd(tag).format(to)}';
}

/// "10:40" in the place's own time, as written on the ticket.
String formatTripTime(BuildContext context, TimeOfDay time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Shorthand for pages that only have a context.
extension TripLabels on BuildContext {
  String tripStage(TripStage stage) => tripStageLabel(l10n, stage);
  String entryKind(EntryKind kind) => entryKindLabel(l10n, kind);
  String entryKinds(EntryKind kind) => entryKindPlural(l10n, kind);
  String transportMode(TransportMode mode) => transportModeLabel(l10n, mode);
  String entryState(EntryState state) => entryStateLabel(l10n, state);
}
