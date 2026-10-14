import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/core/realtime/household_channel.dart';
import 'package:wuselwall/features/calendar/data/external_calendars_repository.dart';
import 'package:wuselwall/features/calendar/domain/external_calendar.dart';
import 'package:wuselwall/features/identity/application/device_providers.dart';

/// The household's subscribed calendars. Refetched when the server stores a fetch (the
/// `calendar` topic) and after this device saves one.
final externalCalendarsProvider =
    FutureProvider.autoDispose<List<ExternalCalendar>>((ref) async {
      ref.watch(deviceKeyProvider);
      final householdId = ref.watch(deviceProvider).value?.householdId;
      if (householdId != null) {
        refreshOnInvalidation(ref, householdId: householdId, topic: 'calendar');
      }
      return (await ref.watch(externalCalendarsRepositoryProvider).calendars())
          .unwrap();
    });
