import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The adult home's destinations, in tab order. Remembered while the app runs, so
/// coming back from a detail screen lands on the same tab.
enum HomeTab { calendar, schedule, tasks, meals, shopping }

class HomeTabNotifier extends Notifier<HomeTab> {
  @override
  HomeTab build() => HomeTab.calendar;

  void select(HomeTab tab) => state = tab;
}

final homeTabProvider = NotifierProvider<HomeTabNotifier, HomeTab>(
  HomeTabNotifier.new,
);
