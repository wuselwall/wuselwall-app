import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled fonts' SIL Open Font Licences to the app's licence page; the OFL
/// requires the licence to travel with the font files. Also adds the MIT licence of
/// the Fluent Emoji pictures the shopping tiles, chores and rewards show.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (package, file) in const [
      ('Atkinson Hyperlegible Next', 'OFL-AtkinsonHyperlegibleNext.txt'),
      ('Barlow Semi Condensed', 'OFL-BarlowSemiCondensed.txt'),
      ('Noto Sans Symbols', 'OFL-NotoSansSymbols.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        package,
      ], await rootBundle.loadString('assets/fonts/$file'));
    }
    yield LicenseEntryWithLineBreaks([
      'Fluent Emoji',
    ], await rootBundle.loadString('assets/emoji/LICENSE-FluentEmoji.txt'));
  });
}
