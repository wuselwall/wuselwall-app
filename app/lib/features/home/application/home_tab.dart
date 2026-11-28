import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuselwall/features/kid/application/child_view.dart';

/// The adult home's destinations, in tab order. Today is first and the default.
/// Remembered while the app runs, so coming back from a detail screen lands on the
/// same tab.
enum HomeTab { today, calendar, schedule, tasks, meals, shopping }

class HomeTabNotifier extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.today;

  void select(HomeTab tab) => state = tab;
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, HomeTab>(
  HomeTabNotifier.new,
);

/// The destinations whoever is at the device is offered: all six for an adult. A child,
/// and a shared device with nobody chosen, lose the calendar and the shopping list
/// where the family switched them off for children (specs/09 "What a child sees").
final homeTabsProvider = Provider<List<HomeTab>>((ref) {
  final calendar = ref.watch(calendarOfferedProvider);
  final shopping = ref.watch(shoppingOfferedProvider);
  return [
    for (final tab in HomeTab.values)
      if ((tab != HomeTab.calendar || calendar) &&
          (tab != HomeTab.shopping || shopping))
        tab,
  ];
});
