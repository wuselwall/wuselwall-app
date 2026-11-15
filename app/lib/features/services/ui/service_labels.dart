import 'package:flutter/material.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';

/// The words of the services page (ADR-022): what a provider offers, what it receives,
/// what it costs and why a call failed. One place, so the page and its tests read the same.

String serviceCapabilityLabel(AppLocalizations l10n, ServiceCapability c) =>
    switch (c) {
      ServiceCapability.climate => l10n.serviceCapClimate,
      ServiceCapability.forecast => l10n.serviceCapForecast,
      ServiceCapability.geocode => l10n.serviceCapGeocode,
      ServiceCapability.route => l10n.serviceCapRoute,
      ServiceCapability.map => l10n.serviceCapMap,
    };

IconData serviceCapabilityIcon(ServiceCapability c) => switch (c) {
  ServiceCapability.climate => Icons.thermostat_outlined,
  ServiceCapability.forecast => Icons.wb_cloudy_outlined,
  ServiceCapability.geocode => Icons.travel_explore_outlined,
  ServiceCapability.route => Icons.directions_car_outlined,
  ServiceCapability.map => Icons.map_outlined,
};

String serviceReceivesLabel(AppLocalizations l10n, ServiceReceives r) =>
    switch (r) {
      ServiceReceives.coordinates => l10n.serviceReceivesCoordinates,
      ServiceReceives.searchText => l10n.serviceReceivesSearchText,
      ServiceReceives.homeCoordinates => l10n.serviceReceivesHome,
    };

String serviceCostLabel(AppLocalizations l10n, ServiceCost c) => switch (c) {
  ServiceCost.free => l10n.serviceCostFree,
  ServiceCost.freeKey => l10n.serviceCostFreeKey,
  ServiceCost.paidKey => l10n.serviceCostPaidKey,
};

/// A provider's failure code (`service_key_missing`, `unauthorized`, `quota`, `timeout`,
/// `http_500`, `bad_answer`, ...) in words; anything unknown reads generically.
String serviceErrorText(AppLocalizations l10n, String? code) => switch (code) {
  'service_key_missing' => l10n.serviceErrorKeyMissing,
  'unauthorized' => l10n.serviceErrorUnauthorized,
  'quota' => l10n.serviceErrorQuota,
  'timeout' => l10n.serviceErrorTimeout,
  _ => l10n.serviceErrorGeneric,
};
