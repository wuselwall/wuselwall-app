import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wuselwall/features/invitations/ui/invite_flow.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('de');
  });

  test('an invitation date follows the language', () {
    final date = DateTime(2026, 10, 22);
    expect(formatInviteDate('en', date), 'Oct 22');
    expect(formatInviteDate('de', date), '22. Okt.');
  });
}
