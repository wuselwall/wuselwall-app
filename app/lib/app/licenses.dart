import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled fonts' SIL Open Font Licences to the app's licence page; the OFL
/// requires the licence to travel with the font files.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (package, file) in const [
      ('Atkinson Hyperlegible Next', 'OFL-AtkinsonHyperlegibleNext.txt'),
      ('Barlow Semi Condensed', 'OFL-BarlowSemiCondensed.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        package,
      ], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}
