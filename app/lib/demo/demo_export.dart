import 'dart:convert';

import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/features/settings/data/household_export_repository.dart';

/// The export of the reference household, shaped like the server's document but small.
class DemoHouseholdExportRepository implements HouseholdExportRepository {
  @override
  Future<Result<String>> export({required String? actor}) async {
    const document = {
      'format': 'wuselwall-export',
      'version': 1,
      'exported_at': '2026-10-14T09:00:00Z',
      'household': {'name': 'Familie', 'timezone': 'Europe/Berlin'},
      'tables': {
        'profile': [
          {'display_name': 'Lukas', 'role': 'guardian'},
          {'display_name': 'Sabine', 'role': 'guardian'},
          {'display_name': 'Lotta', 'role': 'member', 'kind': 'child'},
          {'display_name': 'Hanna', 'role': 'member', 'kind': 'child'},
        ],
        'shopping_item': [
          {'name': 'Milch', 'checked': false},
          {'name': 'Brot', 'checked': true},
        ],
      },
    };
    return Ok(_pretty(document));
  }

  static String _pretty(Object document) =>
      const JsonEncoder.withIndent('  ').convert(document);
}
