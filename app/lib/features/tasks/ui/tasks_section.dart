import 'package:flutter/material.dart';
import 'package:wuselwall/features/home/application/home_section.dart';
import 'package:wuselwall/features/tasks/ui/tasks_body.dart';

/// The adult home's tasks destination: today, approvals, chores, rewards and points.
final tasksSection = HomeSection(
  icon: Icons.task_alt,
  label: (l10n) => l10n.tasksTitle,
  body: const TasksBody(),
);
