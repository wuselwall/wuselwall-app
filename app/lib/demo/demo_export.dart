import 'dart:convert';

import 'package:wuselwall/core/error/result.dart';
import 'package:wuselwall/demo/demo_data.dart';
import 'package:wuselwall/features/settings/data/household_export_repository.dart';

/// The export of the reference household, shaped like the server's document but small.
class DemoHouseholdExportRepository implements HouseholdExportRepository {
  @override
  Future<Result<String>> export({required String? actor}) async {
    final document = {
      'format': 'wuselwall-export',
      'version': 1,
      'exported_at': '2026-10-14T09:00:00Z',
      'household': {
        'name': DemoData.tr4('Familie', 'Family', 'Famille', 'Familia'),
        'timezone': 'Europe/Berlin',
      },
      'tables': {
        'profile': [
          {'display_name': DemoData.name(DemoData.papa), 'role': 'guardian'},
          {'display_name': DemoData.name(DemoData.mama), 'role': 'guardian'},
          {
            'display_name': DemoData.name(DemoData.daughter),
            'role': 'member',
            'kind': 'child',
          },
          {
            'display_name': DemoData.name(DemoData.son),
            'role': 'member',
            'kind': 'child',
          },
        ],
        'shopping_item': [
          {
            'name': DemoData.tr4('Milch', 'Milk', 'Lait', 'Leche'),
            'checked': false,
          },
          {
            'name': DemoData.tr4('Brot', 'Bread', 'Pain', 'Pan'),
            'checked': true,
          },
        ],
      },
    };
    return Ok(_pretty(document));
  }

  static String _pretty(Object document) =>
      const JsonEncoder.withIndent('  ').convert(document);
}
