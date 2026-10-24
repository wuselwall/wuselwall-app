import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The segments of the adult tasks screen, in tab order. Remembered while the app runs,
/// so another screen can open one (Today's approvals card opens [approvals]).
enum TasksTab { today, approvals, chores, rewards, points }

class TasksTabNotifier extends Notifier<TasksTab> {
  @override
  TasksTab build() => TasksTab.today;

  void select(TasksTab tab) => state = tab;
}

final tasksTabProvider = NotifierProvider<TasksTabNotifier, TasksTab>(
  TasksTabNotifier.new,
);
