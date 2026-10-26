// Only built explicitly by qualification. No backend or production sessions.
import 'package:flutter/material.dart';
import 'package:wuselwall/app/licenses.dart';

import 'fixture.dart';
import 'ready.dart';

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Test with assistive technology enabled from launch. Enabling it only after
  // an autofocus field has connected selects Flutter web's non-semantic input
  // strategy for that field, making the audit inspect an inconsistent session.
  // The test entry point owns this handle for the lifetime of the page.
  binding.ensureSemantics();
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
