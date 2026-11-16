import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/trips/domain/trip_functions.dart';

/// The words and icons of the discovery (specs/30 "Discovery"): the tags of a place and
/// the bands of travel effort.

/// The tags the filter offers, in the order the page lists them; the wire names of the
/// server's catalogue.
const discoverTags = <String>[
  'sea',
  'island',
  'mountains',
  'lake',
  'city',
  'countryside',
  'north',
  'long_haul',
];

String discoverTagLabel(AppLocalizations l10n, String tag) => switch (tag) {
  'sea' => l10n.tripDiscoverTagSea,
  'island' => l10n.tripDiscoverTagIsland,
  'mountains' => l10n.tripDiscoverTagMountains,
  'lake' => l10n.tripDiscoverTagLake,
  'city' => l10n.tripDiscoverTagCity,
  'countryside' => l10n.tripDiscoverTagCountryside,
  'north' => l10n.tripDiscoverTagNorth,
  'long_haul' => l10n.tripDiscoverTagLongHaul,
  _ => tag,
};

IconData discoverTagIcon(String tag) => switch (tag) {
  'sea' => Icons.beach_access_outlined,
  'island' => Icons.landscape_outlined,
  'mountains' => Icons.terrain_outlined,
  'lake' => Icons.water_outlined,
  'city' => Icons.location_city_outlined,
  'countryside' => Icons.park_outlined,
  'north' => Icons.ac_unit_outlined,
  'long_haul' => Icons.flight_outlined,
  _ => Icons.place_outlined,
};

String travelEffortLabel(AppLocalizations l10n, TravelEffort effort) =>
    switch (effort) {
      TravelEffort.near => l10n.tripDiscoverEffortNear,
      TravelEffort.car => l10n.tripDiscoverEffortCar,
      TravelEffort.short => l10n.tripDiscoverEffortShort,
      TravelEffort.medium => l10n.tripDiscoverEffortMedium,
      TravelEffort.long => l10n.tripDiscoverEffortLong,
    };
