import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/date_time_patterns.dart';
import 'package:intl/intl.dart';

/// Austrian dates (specs/09 "Regional German"): Flutter ships German date symbols but no
/// Austrian ones, so `de-AT` would fall back to German and print "Januar". After the
/// German symbols are loaded, this registers a copy for `de_AT` with Austria's January,
/// "Jänner". Listed after the Global delegates, so the German symbols exist by then.
class AustrianDatesDelegate extends LocalizationsDelegate<AustrianDates> {
  const AustrianDatesDelegate();

  // Every locale, so Flutter does not warn about a delegate missing; it acts on de_AT.
  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AustrianDates> load(Locale locale) {
    if (locale.languageCode == 'de' && locale.countryCode == 'AT') {
      registerAustrianDates();
    }
    return SynchronousFuture(const AustrianDates());
  }

  @override
  bool shouldReload(AustrianDatesDelegate old) => false;
}

/// What [AustrianDatesDelegate] loads: nothing to read, only proof the dates are set up.
class AustrianDates {
  const AustrianDates();
}

/// Registers `de_AT` once, from the loaded German symbols.
void registerAustrianDates() {
  if (DateFormat.localeExists('de_AT') || !DateFormat.localeExists('de')) {
    return;
  }
  final de = DateFormat('MMMM', 'de').dateSymbols;
  List<String> jaenner(List<String> months, String first) => [
    first,
    ...months.skip(1),
  ];
  initializeDateFormattingCustom(
    locale: 'de_AT',
    symbols: DateSymbols(
      NAME: 'de_AT',
      ERAS: de.ERAS,
      ERANAMES: de.ERANAMES,
      NARROWMONTHS: de.NARROWMONTHS,
      STANDALONENARROWMONTHS: de.STANDALONENARROWMONTHS,
      MONTHS: jaenner(de.MONTHS, 'Jänner'),
      STANDALONEMONTHS: jaenner(de.STANDALONEMONTHS, 'Jänner'),
      SHORTMONTHS: jaenner(de.SHORTMONTHS, 'Jän.'),
      STANDALONESHORTMONTHS: jaenner(de.STANDALONESHORTMONTHS, 'Jän'),
      WEEKDAYS: de.WEEKDAYS,
      STANDALONEWEEKDAYS: de.STANDALONEWEEKDAYS,
      SHORTWEEKDAYS: de.SHORTWEEKDAYS,
      STANDALONESHORTWEEKDAYS: de.STANDALONESHORTWEEKDAYS,
      NARROWWEEKDAYS: de.NARROWWEEKDAYS,
      STANDALONENARROWWEEKDAYS: de.STANDALONENARROWWEEKDAYS,
      SHORTQUARTERS: de.SHORTQUARTERS,
      QUARTERS: de.QUARTERS,
      AMPMS: de.AMPMS,
      ZERODIGIT: de.ZERODIGIT,
      DATEFORMATS: de.DATEFORMATS,
      TIMEFORMATS: de.TIMEFORMATS,
      AVAILABLEFORMATS: de.AVAILABLEFORMATS,
      FIRSTDAYOFWEEK: de.FIRSTDAYOFWEEK,
      WEEKENDRANGE: de.WEEKENDRANGE,
      FIRSTWEEKCUTOFFDAY: de.FIRSTWEEKCUTOFFDAY,
      DATETIMEFORMATS: de.DATETIMEFORMATS,
    ),
    patterns: dateTimePatternMap()['de_AT'] ?? dateTimePatternMap()['de']!,
  );
}
