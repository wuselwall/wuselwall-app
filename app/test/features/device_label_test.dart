import 'package:flutter_test/flutter_test.dart';
import 'package:wuselwall/features/household/domain/device_label.dart';
import 'package:wuselwall/l10n/generated/app_localizations_de.dart';
import 'package:wuselwall/l10n/generated/app_localizations_en.dart';

void main() {
  final de = AppLocalizationsDe();
  final en = AppLocalizationsEn();

  group('possessiveName', () {
    test('German adds an s', () {
      expect(possessiveName('Daniel', 'de'), 'Daniels');
      expect(possessiveName('Anna', 'de'), 'Annas');
    });

    test('German after s, ß, x and z takes an apostrophe only', () {
      expect(possessiveName('Lukas', 'de'), 'Lukas’');
      expect(possessiveName('Strauß', 'de'), 'Strauß’');
      expect(possessiveName('Max', 'de'), 'Max’');
      expect(possessiveName('Franz', 'de'), 'Franz’');
    });

    test('English adds \'s, or only an apostrophe after an s', () {
      expect(possessiveName('Daniel', 'en'), "Daniel's");
      expect(possessiveName('James', 'en'), "James'");
    });

    test('an empty name stays empty', () {
      expect(possessiveName('  ', 'de'), '');
    });
  });

  group('deviceLabel', () {
    test('German: Daniels iPhone', () {
      expect(
        deviceLabel(l10n: de, ownerName: 'Daniel', host: DeviceHost.iphone),
        'Daniels iPhone',
      );
    });

    test('English: Daniel\'s iPhone', () {
      expect(
        deviceLabel(l10n: en, ownerName: 'Daniel', host: DeviceHost.iphone),
        "Daniel's iPhone",
      );
    });

    test('a name ending in s: Hans’ iPhone and James\' iPhone', () {
      expect(
        deviceLabel(l10n: de, ownerName: 'Hans', host: DeviceHost.iphone),
        'Hans’ iPhone',
      );
      expect(
        deviceLabel(l10n: en, ownerName: 'James', host: DeviceHost.iphone),
        "James' iPhone",
      );
    });

    test('the other platforms', () {
      expect(
        deviceLabel(l10n: de, ownerName: 'Daniel', host: DeviceHost.android),
        'Daniels Android-Handy',
      );
      expect(
        deviceLabel(l10n: en, ownerName: 'Daniel', host: DeviceHost.android),
        "Daniel's Android phone",
      );
      expect(
        deviceLabel(l10n: en, ownerName: 'Daniel', host: DeviceHost.web),
        "Daniel's browser",
      );
      expect(
        deviceLabel(l10n: de, ownerName: 'Lotta', host: DeviceHost.computer),
        'Lottas Computer',
      );
    });

    test('without a name only the device', () {
      expect(
        deviceLabel(l10n: de, ownerName: ' ', host: DeviceHost.iphone),
        'iPhone',
      );
    });
  });
}
