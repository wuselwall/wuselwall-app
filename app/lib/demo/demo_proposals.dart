import 'dart:typed_data';

import 'package:wuselwall/core/error/failure.dart';
import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/demo/demo_english.dart';
import 'package:wuselwall/features/school/data/proposals_repository.dart';
import 'package:wuselwall/features/school/data/scan_repository.dart';
import 'package:wuselwall/features/school/domain/proposal_models.dart';
import 'package:wuselwall/features/school/domain/school_models.dart';

/// The demo has no assistant and no OCR service: no proposals, and a scan that answers
/// as a server without OCR would, so the screens show their real words. With
/// [timetable] (the `import` scenario of the docs' screenshots) one timetable waits as
/// an assistant's proposal, so the preview can be shown.
class DemoProposalsRepository implements ProposalsRepository {
  const DemoProposalsRepository({this.timetable = false});

  final bool timetable;

  @override
  Future<Result<List<ProposalRecord>>> open() async {
    if (!timetable) return const Ok([]);
    final now = DateTime.now();
    return Ok([
      ProposalRecord(
        id: 'proposal-demo',
        kind: 'timetable',
        payload: demoTimetablePayload(),
        source: 'mcp',
        status: 'open',
        createdAt: now,
        expiresAt: now.add(const Duration(days: 14)),
        assistantLabel: 'Claude',
      ),
    ]);
  }

  @override
  Future<Result<void>> resolve({
    required String? actor,
    required String id,
    required bool applied,
  }) async => const Ok(null);
}

/// The son's sheet as an assistant would hand it in: mostly the family's subjects, one
/// the sheet calls by another word (offered as the family's Sachunterricht), one that is
/// new, and the Hort.
Map<String, dynamic> demoTimetablePayload() {
  final (
    otherWord,
    otherName,
    newWord,
    newName,
  ) = switch (DemoData.languageCode) {
    'en' => ('Geo', 'Geography', 'Fr', 'French'),
    'fr' => ('QLM', 'Questionner le monde', 'Ang', 'Anglais'),
    'es' => ('CM', 'Conocimiento del Medio', 'Ing', 'Inglés'),
    _ => ('HSU', 'Heimat- und Sachunterricht', 'E', 'Englisch'),
  };
  final other = {
    'subject': otherWord,
    'name': otherName,
    'like': demoShort('SU'),
  };
  final added = {'subject': newWord, 'name': newName};
  String s(String code) => demoShort(code);
  final sport = s('Sp');
  final swim = s('Sw');
  return {
    'member': DemoData.name(DemoData.son),
    'school': demoText('Grundschule Lindenhof'),
    'class': demoText('SAPh E'),
    'week_cycle': 'weekly',
    'grid': {
      '1': [s('D'), s('Ma'), other, sport],
      '2': [s('Ma'), s('D'), s('Mu'), added, other],
      '3': [swim, swim, s('D'), s('Ma')],
      '4': [s('D'), s('Ma'), other, s('Mu'), sport],
      '5': [s('Ma'), s('D'), s('Ku'), s('Ku'), added],
    },
    'care': [
      {
        'title': demoText('Hort'),
        'days': [1, 2, 4],
        'starts': '12:45',
        'ends': '15:00',
      },
    ],
  };
}

class DemoScanRepository implements ScanRepository {
  const DemoScanRepository();

  @override
  Future<Result<ScanResult>> scan({
    required Uint8List image,
    required String mime,
    List<String> languages = const [],
    List<String> subjects = const [],
    List<SubjectRecord> subjectList = const [],
  }) async => const Err(NotFoundFailure(code: 'ocr_not_configured'));
}
