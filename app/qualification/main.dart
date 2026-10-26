// Only built explicitly by qualification. No backend or production sessions.
import 'package:flutter/material.dart';
import 'package:wuselwall/app/licenses.dart';

import 'fixture.dart';
import 'ready.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final q = Uri.base.queryParameters;
  runApp(
    QualificationReady(
      id: q['state'] ?? 'today',
      destination: q['destination'] ?? 'TodayPage',
      child: qualificationApp(
        stateId: q['state'],
        scenario: q['scenario'] ?? 'adult',
        locale: Locale(q['locale'] ?? 'de'),
        shade: q['shade'] ?? 'light',
        tab: q['tab'] ?? 'today',
        advanced: q['advanced'] == '1',
      ),
    ),
  );
}
