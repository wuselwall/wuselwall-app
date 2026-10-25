import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/core/server/server_providers.dart';
import 'package:wuselwall/features/calendar/data/event_templates_repository.dart';
import 'package:wuselwall/features/calendar/domain/event_templates.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// Whether the server keeps templates and suggests them (specs/28). Without it the
/// new-event page shows only the built-in templates.
final eventTemplatesSupportedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(serverSupportsProvider(featureEventTemplates)),
);

/// The family's saved templates, oldest first. Refetched when another device changes
/// the calendar (the `calendar` topic).
final eventTemplatesProvider = FutureProvider.autoDispose<List<EventTemplate>>((
  ref,
) async {
  if (!ref.watch(eventTemplatesSupportedProvider)) return const [];
  ref.watch(deviceKeyProvider);
  final householdId = ref.watch(deviceProvider).value?.householdId;
  if (householdId != null) {
    refreshOnInvalidation(ref, householdId: householdId, topic: 'calendar');
  }
  return (await ref.watch(eventTemplatesRepositoryProvider).templates())
      .unwrap();
});

/// Up to four suggestions from the family's history for a new event on [day].
final eventSuggestionsProvider = FutureProvider.autoDispose
    .family<List<EventTemplate>, DateTime>((ref, day) async {
      if (!ref.watch(eventTemplatesSupportedProvider)) return const [];
      ref.watch(deviceKeyProvider);
      final householdId = ref.watch(deviceProvider).value?.householdId;
      if (householdId != null) {
        refreshOnInvalidation(ref, householdId: householdId, topic: 'calendar');
      }
      return (await ref
              .watch(eventTemplatesRepositoryProvider)
              .suggestions(on: day))
          .unwrap();
    });
