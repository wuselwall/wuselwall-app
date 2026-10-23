import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wuselwall/app/router.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/core/l10n/l10n.dart';
import 'package:wuselwall/core/ui/snackbars.dart';
import 'package:wuselwall/features/identity/application/acting_profile.dart';
import 'package:wuselwall/features/identity/ui/guardian_gate.dart';
import 'package:wuselwall/features/school/application/school_providers.dart';
import 'package:wuselwall/features/school/data/school_repository.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';
import 'package:wuselwall/features/school/ui/school_setup_page.dart';
import 'package:wuselwall/features/school/ui/timetable_editor_page.dart';

/// Opens the timetable editor for [profileId] on the term of [monday] (default: the
/// week on screen), after the guardian check. With siblings at several schools, the
/// household first says which school the timetable is for. A missing term is proposed
/// as the school year around that week (specs/24 "Fewer required facts"): the dialog
/// comes prefilled, and one tap continues to lesson entry.
Future<void> openTimetableEditor(
  BuildContext context,
  WidgetRef ref, {
  required SchoolData data,
  required String profileId,
  DateTime? monday,
}) async {
  if (!await ensureGuardian(context, ref) || !context.mounted) return;
  String? schoolId = data.schools.firstOrNull?.id;
  if (data.schools.length > 1) {
    final picked = await showDialog<SchoolRecord>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(dialogContext.l10n.schoolsUiAskSchool),
        children: [
          for (final s in data.schools)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(s),
              child: Text(s.name),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    schoolId = picked.id;
  }
  if (schoolId == null) {
    unawaited(context.push(Routes.schoolSetup));
    return;
  }
  final DateTime selectedDate = monday ?? ref.read(selectedWeekProvider);
  var termId = data.termFor(selectedDate, schoolId: schoolId)?.id;
  if (termId == null) {
    final draft = await showDialog<TermRecord>(
      context: context,
      builder: (dialogContext) => SchoolTermDialog(
        schoolId: schoolId!,
        forTimetableOn: selectedDate,
        proposed: proposedTerm(
          dialogContext.l10n,
          schoolId: schoolId,
          around: selectedDate,
          // The first term of a school is its current one.
          current: !data.terms.any((t) => t.schoolId == schoolId),
        ),
      ),
    );
    if (draft == null || !context.mounted) return;
    final result = await ref
        .read(schoolRepositoryProvider)
        .saveTerm(actor: ref.read(actingProfileProvider), term: draft);
    if (!context.mounted) return;
    switch (result) {
      case Err(:final failure):
        context.showFailure(failure);
        return;
      case Ok(:final value):
        termId = value;
        ref.invalidate(schoolDataProvider);
    }
  }
  unawaited(
    context.push(
      Routes.timetableEdit,
      extra: TimetableEditArgs(profileId: profileId, termId: termId),
    ),
  );
}

/// The term a family gets without being asked: the school year around [around], from
/// 1 August to 31 July, named "Schuljahr 2026/27" in the app's language.
TermRecord proposedTerm(
  AppLocalizations l10n, {
  required String schoolId,
  required DateTime around,
  bool current = true,
}) {
  final year = schoolYearAround(around);
  return TermRecord(
    id: '',
    schoolId: schoolId,
    name: l10n.schoolYearName(
      year.startYear.toString(),
      (year.startYear + 1).toString().substring(2),
    ),
    startsOn: year.from,
    endsOn: year.to,
    isCurrent: current,
  );
}
