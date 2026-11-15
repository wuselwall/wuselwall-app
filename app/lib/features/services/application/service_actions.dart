import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/services/application/service_providers.dart';
import 'package:wuselwall/features/services/data/services_repository.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';

/// The writes and asks of the opt-in services as the acting profile. A guardian switches
/// providers on and off and stores keys; any adult may search a place.
class ServiceActions {
  const ServiceActions(this._ref);

  final Ref _ref;

  ServicesRepository get _repo => _ref.read(servicesRepositoryProvider);
  String? get _actor => _ref.read(actingProfileProvider);

  /// Changes how the household uses [provider]; only the given parts change. Enabling
  /// should list the [capabilities] the provider is used for (a provider with none serves
  /// none). [key]: a string stores the key, `''` removes it, null keeps it. A guardian.
  Future<Result<void>> setProvider(
    String provider, {
    bool? enabled,
    List<ServiceCapability>? capabilities,
    int? position,
    String? key,
  }) async {
    final result = await _repo.setProvider(
      actor: _actor,
      provider: provider,
      enabled: enabled,
      capabilities: capabilities,
      position: position,
      key: key,
    );
    if (result.isOk) _ref.invalidate(serviceStatesProvider);
    return result;
  }

  /// One small real call with the stored key; reads the provider's state again so
  /// `lastOkAt` / `lastError` are current. A guardian.
  Future<Result<ServiceTestResult>> test(String provider) async {
    final result = await _repo.test(provider: provider, actor: _actor);
    _ref.invalidate(serviceStatesProvider);
    return result;
  }

  /// Finds places by name for a destination or the home place; [lang] is the language of
  /// the names. Fails with `service_off` when no geocoding provider is on.
  Future<Result<GeocodeResult>> geocode(String query, {String? lang}) =>
      _repo.geocode(q: query, lang: lang, actor: _actor);
}

final serviceActionsProvider = Provider<ServiceActions>(ServiceActions.new);
