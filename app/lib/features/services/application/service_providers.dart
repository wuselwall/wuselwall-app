import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/app/theme/ui_register.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';
import 'package:wuselwall/features/services/data/services_repository.dart';
import 'package:wuselwall/features/services/domain/service_models.dart';

/// Whether the person acting is a guardian: who may switch services on and off, store
/// keys and set the home place (specs/30 "Who does what"). The server enforces it; this
/// hides what would be refused. On a shared device the page still asks for the PIN step-up
/// (`ensureGuardian`) before a write.
final actingGuardianProvider = Provider.autoDispose<bool>((ref) {
  final acting = ref.watch(actingProfileProvider);
  final members = ref.watch(membersProvider).value ?? const [];
  return members.any((m) => m.id == acting && m.isGuardian);
});

/// The providers the server knows (action `catalogue`); empty on a server without
/// services. A failure is an error value, for the settings page to show.
final serviceCatalogueProvider =
    FutureProvider.autoDispose<List<ServiceProviderInfo>>((ref) async {
      ref.watch(deviceKeyProvider);
      if (!ref.watch(servicesSupportedProvider)) return const [];
      return (await ref.watch(servicesRepositoryProvider).catalogue()).unwrap();
    });

/// What the household did with each provider (`api.service_providers`); empty on a
/// server without services. Refreshed when the settings change (topic `settings`).
final serviceStatesProvider =
    FutureProvider.autoDispose<List<ServiceProviderState>>((ref) async {
      ref.watch(deviceKeyProvider);
      if (!ref.watch(servicesSupportedProvider)) return const [];
      final householdId = ref.watch(deviceProvider).value?.householdId;
      if (householdId != null) {
        refreshOnInvalidation(ref, householdId: householdId, topic: 'settings');
      }
      return (await ref.watch(servicesRepositoryProvider).providers()).unwrap();
    });

/// The settings page's list: every provider of the catalogue with the household's state,
/// the enabled ones first in the household's order, then the others in the catalogue's.
final serviceSetupProvider =
    FutureProvider.autoDispose<List<ServiceProviderView>>((ref) async {
      final catalogue = await ref.watch(serviceCatalogueProvider.future);
      final states = await ref.watch(serviceStatesProvider.future);
      final byId = {for (final s in states) s.provider: s};
      final views = [
        for (final info in catalogue) ServiceProviderView(info, byId[info.id]),
      ];
      final enabled = [
        for (final v in views)
          if (v.enabled) v,
      ]..sort((a, b) => a.state!.position.compareTo(b.state!.position));
      return [
        ...enabled,
        for (final v in views)
          if (!v.enabled) v,
      ];
    });

/// Whether some enabled provider of the household will be asked for [capability]: the
/// signal to show a forecast, a route, a map or a place search at all. False for a
/// child's device and the wall (the server refuses them), on a server without services,
/// while loading and when the catalogue cannot be read.
final serviceOffersProvider = Provider.autoDispose
    .family<bool, ServiceCapability>((ref, capability) {
      if (!ref.watch(servicesSupportedProvider) ||
          ref.watch(uiRegisterProvider) != UiRegister.adult) {
        return false;
      }
      final views = ref.watch(serviceSetupProvider).value;
      return views != null && views.any((v) => v.servesCapability(capability));
    });
