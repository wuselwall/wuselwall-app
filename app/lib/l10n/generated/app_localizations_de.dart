// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'WuselWall';

  @override
  String get unexpectedError => 'Ein unerwarteter Fehler ist aufgetreten';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get errorNetwork =>
      'Keine Verbindung zum Server. Prüfe dein Netzwerk und versuche es erneut.';

  @override
  String get errorAuth =>
      'Du bist nicht angemeldet oder deine Sitzung ist abgelaufen.';

  @override
  String get errorPermission => 'Das darfst du nicht.';

  @override
  String get errorNotFound => 'Das wurde nicht gefunden.';

  @override
  String get errorConflict =>
      'Das steht im Konflikt mit etwas, das schon existiert.';

  @override
  String get errorValidation => 'Diese Eingabe ist ungültig.';

  @override
  String get errorUnknown => 'Etwas ist schiefgelaufen.';

  @override
  String configMissing(String missing) {
    return 'Diesem Build fehlt die Konfiguration: $missing';
  }

  @override
  String get registerAdult => 'Erwachsene';

  @override
  String get registerKid => 'Kind';

  @override
  String get registerKiosk => 'Wandanzeige';

  @override
  String get systemTitle => 'System';

  @override
  String get systemBuild => 'Build';

  @override
  String get systemEnvironment => 'Umgebung';

  @override
  String get systemBackendUrl => 'Backend-URL';

  @override
  String get systemConnectivity => 'Konnektivität';

  @override
  String get systemNetwork => 'Netzwerk';

  @override
  String get systemOnline => 'Online';

  @override
  String get systemOffline => 'Offline';

  @override
  String get systemUnknown => 'Unbekannt';

  @override
  String get systemBackend => 'Backend';

  @override
  String get systemStatus => 'Status';

  @override
  String get systemStatusOk => 'OK';

  @override
  String get systemDbVersion => 'Datenbankversion';

  @override
  String get systemServerTime => 'Serverzeit';

  @override
  String get setupHeadline => 'Willkommen bei WuselWall';

  @override
  String get doorTagline => 'Der Familienplan für die Küchenwand';

  @override
  String get setupHouseholdAction => 'Neue Familie anlegen';

  @override
  String get wizardTitle => 'Neuer Haushalt';

  @override
  String get wizardCreate => 'Haushalt anlegen';

  @override
  String get fieldSetupToken => 'Einrichtungs-Token';

  @override
  String get fieldHouseholdName => 'Haushaltsname';

  @override
  String get fieldYourName => 'Dein Name';

  @override
  String get fieldEmail => 'E-Mail';

  @override
  String get fieldPassword => 'Passwort (mindestens 10 Zeichen)';

  @override
  String get fieldPasswordSimple => 'Passwort';

  @override
  String get fieldPin => '6-stellige PIN';

  @override
  String get fieldRequired => 'Pflichtfeld';

  @override
  String get signInTitle => 'Anmelden';

  @override
  String get signInAction => 'Anmelden';

  @override
  String get enrolTitle => 'Gerät verbinden';

  @override
  String get enrolBody =>
      'Gib den Code ein, der auf einem Gerät angezeigt wird, das schon verbunden ist.';

  @override
  String get enrolCodeLabel => 'Einrichtungscode';

  @override
  String get enrolAction => 'Verbinden';

  @override
  String get errSetupTokenInvalid => 'Das Einrichtungs-Token ist ungültig.';

  @override
  String get errSetupClosed => 'Dieses System ist bereits eingerichtet.';

  @override
  String get errPasswordTooShort =>
      'Das Passwort braucht mindestens 10 Zeichen.';

  @override
  String get errPinFormat => 'Die PIN muss genau 6 Ziffern haben.';

  @override
  String get errCodeInvalid => 'Dieser Code ist falsch oder abgelaufen.';

  @override
  String get errGuardianRequired => 'Das darf nur ein Erziehungsberechtigter.';

  @override
  String get errDeviceRevoked => 'Dieses Gerät wurde gesperrt.';

  @override
  String get errActorRequired => 'Tippe zuerst auf deinen Namen.';

  @override
  String get errNameRequired => 'Bitte gib einen Namen ein.';

  @override
  String get errInvalidLogin => 'E-Mail oder Passwort ist falsch.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get close => 'Schließen';

  @override
  String get delete => 'Löschen';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get shoppingTitle => 'Einkaufsliste';

  @override
  String get shoppingAddHint => 'Artikel hinzufügen';

  @override
  String get shoppingQuantityHint => 'Menge';

  @override
  String get shoppingEmpty => 'Nichts zu kaufen';

  @override
  String get shoppingFinish => 'Einkauf beenden';

  @override
  String get shoppingFinishConfirm =>
      'Einkauf beenden? Abgehakte Artikel werden entfernt, der Rest bleibt auf der Liste.';

  @override
  String shoppingFinished(int bought, int left) {
    return '$bought gekauft, $left übernommen';
  }

  @override
  String get actingWho => 'Wer bist du?';

  @override
  String get pinTitle => 'PIN für Erziehungsberechtigte';

  @override
  String pinPrompt(String name) {
    return 'PIN für $name eingeben';
  }

  @override
  String pinWrong(int left) {
    return 'Falsche PIN. Noch $left Versuche.';
  }

  @override
  String get pinBackoff => 'Zu viele Versuche. Bitte warte einen Moment.';

  @override
  String get pinLocked =>
      'PIN gesperrt. Ein Erziehungsberechtigter muss sich zum Entsperren anmelden.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsMembers => 'Mitglieder';

  @override
  String get settingsDevices => 'Geräte';

  @override
  String get addMember => 'Mitglied hinzufügen';

  @override
  String get memberName => 'Name';

  @override
  String get roleGuardian => 'Erziehungsberechtigter';

  @override
  String get roleMember => 'Mitglied';

  @override
  String get addDevice => 'Gerät hinzufügen';

  @override
  String get deviceLabel => 'Gerätename';

  @override
  String get createCode => 'Code erzeugen';

  @override
  String get enrolmentCodeTitle => 'Einrichtungscode';

  @override
  String get enrolmentCodeHint =>
      'Gib diesen Code innerhalb von 10 Minuten auf dem neuen Gerät ein. Er gilt nur einmal.';

  @override
  String get thisDevice => 'dieses Gerät';

  @override
  String get deviceRevoked => 'gesperrt';

  @override
  String get revoke => 'Sperren';

  @override
  String revokeConfirm(String device) {
    return '„$device“ sperren? Es verliert sofort den Zugriff.';
  }

  @override
  String get signOutDevice => 'Dieses Gerät abmelden';

  @override
  String get classPersonal => 'Persönlich';

  @override
  String get classShared => 'Geteilt (Antippen zum Wechseln)';

  @override
  String get classKiosk => 'Wandanzeige';

  @override
  String get systemDevice => 'Dieses Gerät';

  @override
  String get systemRegister => 'Ansicht';

  @override
  String get systemEnrolled => 'Eingerichtet';

  @override
  String get errRateLimited =>
      'Zu viele Versuche. Bitte warte ein paar Minuten und versuche es erneut.';

  @override
  String get errMfaRequired =>
      'Gib zuerst den Code aus deiner Authenticator-App ein.';

  @override
  String get scanQr => 'QR-Code scannen';

  @override
  String get scanTitle => 'Einrichtungscode scannen';

  @override
  String get enrolmentQrLabel => 'QR-Code für den Einrichtungscode';

  @override
  String get mfaTitle => 'Zweiter Faktor';

  @override
  String get mfaBody =>
      'Gib den 6-stelligen Code aus deiner Authenticator-App ein.';

  @override
  String get mfaCodeLabel => '6-stelliger Code';

  @override
  String get mfaVerify => 'Bestätigen';

  @override
  String get registerTitle => 'Dieses Gerät benennen';

  @override
  String registerBody(String name) {
    return '$name, dieses Handy ist neu im Haushalt. Gib ihm einen Namen, damit du es später erkennen (und sperren) kannst.';
  }

  @override
  String registerDefaultLabel(String name) {
    return 'Handy von $name';
  }

  @override
  String get registerAction => 'Dieses Gerät verwenden';

  @override
  String get signInPasskey => 'Mit Passkey anmelden';

  @override
  String get settingsSecurity => 'Sicherheit';

  @override
  String get totpTitle => 'Zwei-Faktor-Anmeldung';

  @override
  String get totpOn => 'An: bei jeder Anmeldung wird ein Code verlangt.';

  @override
  String get totpOff => 'Aus';

  @override
  String get totpEnable => 'Einschalten';

  @override
  String get totpDisable => 'Ausschalten';

  @override
  String get totpScanBody =>
      'Scanne diesen Code mit einer Authenticator-App und gib dann den angezeigten 6-stelligen Code ein.';

  @override
  String get totpQrLabel => 'QR-Code zum Einrichten der Authenticator-App';

  @override
  String get passkeyTitle => 'Passkey';

  @override
  String get passkeyBody =>
      'Mit Fingerabdruck oder Gesicht statt mit Passwort anmelden.';

  @override
  String get passkeyAdd => 'Hinzufügen';

  @override
  String get passkeyAdded => 'Passkey hinzugefügt.';

  @override
  String get shoppingHistory => 'Verlauf';

  @override
  String get shoppingHistoryEmpty => 'Noch keine abgeschlossenen Einkäufe';

  @override
  String get shoppingSearchHint => 'Suchen oder hinzufügen';

  @override
  String get shoppingTilesEmpty =>
      'Kacheln erscheinen hier, sobald ihr etwas gekauft habt. Tippe einen Namen, um einen Artikel hinzuzufügen.';

  @override
  String shoppingInTrolley(int count) {
    return 'Im Wagen ($count)';
  }

  @override
  String get shoppingUncategorised => 'Ohne Kategorie';

  @override
  String get shoppingNewList => 'Neue Liste';

  @override
  String get shoppingListName => 'Name';

  @override
  String get shoppingListKind => 'Aufteilung';

  @override
  String get shoppingKindSupermarket => 'Supermarkt';

  @override
  String get shoppingKindDrugstore => 'Drogerie';

  @override
  String get shoppingKindHardware => 'Baumarkt';

  @override
  String get shoppingKindOther => 'Sonstiges';

  @override
  String get shoppingMakeDefault => 'Als Standardliste festlegen';

  @override
  String get shoppingEditItem => 'Artikel bearbeiten';

  @override
  String get shoppingSpecHint => 'Hinweis, z. B. Bio oder 500 g';

  @override
  String get shoppingCategory => 'Kategorie';

  @override
  String get shoppingRemoveOne => 'Eins weniger';

  @override
  String get errListExists => 'Eine Liste mit diesem Namen gibt es schon.';

  @override
  String get errSpecTooLong =>
      'Der Hinweis ist zu lang (höchstens 40 Zeichen).';

  @override
  String get errKioskForbidden => 'Das geht am Wandbildschirm nicht.';

  @override
  String get shoppingCat_produce => 'Obst & Gemüse';

  @override
  String get shoppingCat_bakery => 'Brot & Backwaren';

  @override
  String get shoppingCat_dairy => 'Milch & Käse';

  @override
  String get shoppingCat_meat_fish => 'Fleisch & Fisch';

  @override
  String get shoppingCat_pantry => 'Vorrat';

  @override
  String get shoppingCat_frozen => 'Tiefkühl';

  @override
  String get shoppingCat_drinks => 'Getränke';

  @override
  String get shoppingCat_household => 'Haushalt';

  @override
  String get shoppingCat_other => 'Sonstiges';

  @override
  String get shoppingCat_care => 'Körperpflege';

  @override
  String get shoppingCat_baby => 'Baby & Kind';

  @override
  String get shoppingCat_cleaning => 'Reinigung';

  @override
  String get shoppingCat_health => 'Gesundheit';

  @override
  String get shoppingCat_tools => 'Werkzeug';

  @override
  String get shoppingCat_screws => 'Schrauben & Befestigung';

  @override
  String get shoppingCat_electrical => 'Elektro';

  @override
  String get shoppingCat_garden => 'Garten';

  @override
  String shoppingCreateTile(String name) {
    return '„$name“ neu anlegen';
  }

  @override
  String shoppingAddedBy(String name) {
    return 'Hinzugefügt von $name';
  }

  @override
  String get pinChangeTitle => 'PIN für Erziehungsberechtigte';

  @override
  String get pinChangeBody =>
      'Lege eine neue 6-stellige PIN fest. Das entsperrt auch eine PIN, die nach zu vielen Fehlversuchen gesperrt wurde.';

  @override
  String get pinChangeAction => 'Ändern';

  @override
  String get pinChangeField => 'Neue PIN (6 Ziffern)';

  @override
  String get pinChanged => 'PIN geändert.';

  @override
  String shoppingTripItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel',
      one: '1 Artikel',
    );
    return '$_temp0';
  }

  @override
  String shoppingPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen warten aufs Senden',
      one: '1 Änderung wartet aufs Senden',
    );
    return '$_temp0';
  }

  @override
  String get shoppingItemPending => 'Wartet aufs Senden';

  @override
  String get errCategoryNotFound =>
      'Diese Kategorie gibt es nicht mehr. Die Änderung wurde nicht gespeichert.';

  @override
  String get errNameTooLong => 'Der Name ist zu lang.';

  @override
  String get errActorInvalid =>
      'Diese Person gehört nicht mehr zum Haushalt. Die Änderung wurde nicht gespeichert.';

  @override
  String get doorApple => 'Mit Apple fortfahren';

  @override
  String get doorGoogle => 'Mit Google fortfahren';

  @override
  String get doorEmail => 'Mit E-Mail fortfahren';

  @override
  String get doorOr => 'oder';

  @override
  String get errProviderFailed =>
      'Das hat nicht geklappt. Versuch es nochmal oder melde dich mit deiner E-Mail an.';

  @override
  String get errSignupDisabled =>
      'Zu dieser Adresse gibt es noch kein WuselWall-Konto. Melde dich mit E-Mail und Passwort an und verbinde Apple oder Google dann unter Einstellungen → Anmeldung.';

  @override
  String get errIdentityAlreadyExists =>
      'Dieses Apple- oder Google-Konto ist schon mit einem anderen WuselWall-Konto verbunden.';

  @override
  String get errLastSignInMethod =>
      'Das ist deine einzige Anmeldemethode, darum kann sie nicht entfernt werden.';

  @override
  String get errEmailExists =>
      'Diese E-Mail-Adresse gehört schon zu einem anderen Konto.';

  @override
  String get signInMethodsTitle => 'Anmeldung';

  @override
  String get signInMethodEmail => 'E-Mail-Code';

  @override
  String get signInMethodApple => 'Apple';

  @override
  String get signInMethodGoogle => 'Google';

  @override
  String get signInMethodNotConnected => 'Nicht verbunden';

  @override
  String get signInMethodConnect => 'Verbinden';

  @override
  String get signInMethodRemove => 'Entfernen';

  @override
  String get signInMethodLinkElsewhere =>
      'Verbinden geht in der App auf deinem Handy.';

  @override
  String signInMethodConnected(String provider) {
    return '$provider ist verbunden.';
  }

  @override
  String signInMethodRemoveConfirm(String provider) {
    return '$provider entfernen? Du kannst dich dann nicht mehr damit anmelden.';
  }

  @override
  String boardWeekNumber(int week) {
    return 'KW $week';
  }

  @override
  String get boardToday => 'Heute';

  @override
  String get boardNow => 'Jetzt';

  @override
  String get boardNextUp => 'Als Nächstes';

  @override
  String get boardThen => 'danach';

  @override
  String boardInMinutes(int minutes) {
    return 'in $minutes Min.';
  }

  @override
  String boardInHours(int hours, int minutes) {
    return 'in $hours Std. $minutes Min.';
  }

  @override
  String get boardNothingMoreToday => 'Heute steht nichts mehr an';

  @override
  String boardUpdatedSecondsAgo(int seconds) {
    return 'aktualisiert vor $seconds s';
  }

  @override
  String boardUpdatedMinutesAgo(int minutes) {
    return 'aktualisiert vor $minutes Min.';
  }

  @override
  String boardLastUpdatedAt(String time) {
    return 'zuletzt aktualisiert $time';
  }

  @override
  String get boardOffline =>
      'Keine Verbindung – das ist der letzte bekannte Stand.';

  @override
  String get boardLoading => 'Die Woche wird geladen …';

  @override
  String get boardZoneWhere => 'Wer ist wo';

  @override
  String get boardZoneWhereHint => 'blass = wie immer · kräftig = Abweichung';

  @override
  String get boardZoneEvents => 'Termine';

  @override
  String get boardZoneEventsHint =>
      'Punkte = wer betroffen ist · gestrichelt = noch nicht sicher';

  @override
  String get boardZoneMeal => 'Warmes Essen';

  @override
  String get boardZoneMealHint =>
      'voller Punkt = isst mit · offener Punkt = nicht da';

  @override
  String get boardMorning => 'Vormittag';

  @override
  String get boardAfternoon => 'Nachmittag';

  @override
  String get boardEvening => 'Abend';

  @override
  String boardUntil(String time) {
    return 'bis $time';
  }

  @override
  String boardFrom(String time) {
    return 'ab $time';
  }

  @override
  String get boardAllDay => 'ganztägig';

  @override
  String boardMoreEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count weitere',
      one: '+1 weiterer',
    );
    return '$_temp0';
  }

  @override
  String boardMoreCount(int count) {
    return '+$count';
  }

  @override
  String get boardNoSchool => 'frei';

  @override
  String boardCareUntil(String label, String time) {
    return '$label bis $time';
  }

  @override
  String get boardCareDefault => 'Betreuung';

  @override
  String boardBusyUntil(String time) {
    return 'Termine bis $time';
  }

  @override
  String get boardMealLunch => 'Mittag';

  @override
  String get boardMealDinner => 'Abend';

  @override
  String get boardMealNothingPlanned => 'nichts geplant';

  @override
  String boardMealCook(String name) {
    return '$name kocht';
  }

  @override
  String boardMealGuests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count Gäste',
      one: '+1 Gast',
    );
    return '$_temp0';
  }

  @override
  String boardEating(String name) {
    return '$name isst mit';
  }

  @override
  String boardNotEating(String name) {
    return '$name isst nicht mit';
  }

  @override
  String get boardOpenToday => 'Heute offen';

  @override
  String get boardAllDone => 'Heute alles erledigt';

  @override
  String get boardShoppingList => 'Einkaufsliste';

  @override
  String get boardNightMode => 'Nachtansicht';

  @override
  String get boardBackToWeek => 'Zurück zur Woche';

  @override
  String get boardTentative => 'noch nicht sicher';

  @override
  String get boardNoAppointments => 'Keine Termine';

  @override
  String get boardSchool => 'Schule';

  @override
  String boardSchoolSpan(String span) {
    return 'Schule $span';
  }

  @override
  String get boardNoSchoolToday => 'Keine Schule';

  @override
  String get boardWeekend => 'Wochenende';

  @override
  String boardWeekOf(String name) {
    return 'Die Woche von $name';
  }

  @override
  String boardTimetableTitle(String name) {
    return 'Stundenplan von $name';
  }

  @override
  String boardClass(String label) {
    return 'Klasse $label';
  }

  @override
  String boardPeriod(int index) {
    return '$index. Stunde';
  }

  @override
  String get boardBreak => 'Pause';

  @override
  String get boardLessonOver => 'vorbei';

  @override
  String get boardLessonNow => 'jetzt';

  @override
  String get boardLessonCancelled => 'Entfall';

  @override
  String get boardLessonSubstituted => 'Vertretung';

  @override
  String get boardLessonRoomChange => 'Raumwechsel';

  @override
  String get boardLessonExtra => 'Zusätzlich';

  @override
  String boardPackTomorrow(String items) {
    return 'Morgen einpacken: $items';
  }

  @override
  String boardPackToday(String items) {
    return 'Heute dabei: $items';
  }

  @override
  String get boardWholeWeek => 'Die ganze Woche';

  @override
  String get boardMealWeek => 'Essen dieser Woche';

  @override
  String boardBaseline(String label) {
    return 'Normalerweise: $label';
  }

  @override
  String get boardNoDeviation => 'wie immer';

  @override
  String get boardCooking => 'Kocht';

  @override
  String get boardAppointmentsOf => 'Termine';

  @override
  String boardTasksOf(String name) {
    return 'Aufgaben von $name';
  }

  @override
  String get boardTasksComingSoon => 'Aufgaben kommen mit dem nächsten Update.';

  @override
  String get presenceWorking => 'Arbeit';

  @override
  String get presenceHomeOffice => 'Homeoffice';

  @override
  String get presenceTravel => 'Unterwegs';

  @override
  String get presenceAway => 'Weg';

  @override
  String get presenceOff => 'Frei';

  @override
  String get presenceChildcare => 'Betreuung';

  @override
  String get errSettingInvalid =>
      'Dieser Wert liegt außerhalb des erlaubten Bereichs.';

  @override
  String get errSettingUnknown => 'Diese Einstellung gibt es nicht.';

  @override
  String get errSettingTarget =>
      'Diese Einstellung lässt sich für diese Person oder dieses Gerät nicht ändern.';

  @override
  String get householdSettingsTitle => 'Haushalt einstellen';

  @override
  String get householdSettingsSubtitle =>
      'Standards für Aufgaben, Kalender, Essen und die Küchenwand';

  @override
  String get settingsSectionHousehold => 'Haushalt und Mitglieder';

  @override
  String get settingsSectionTasks => 'Aufgaben';

  @override
  String get settingsSectionCalendar => 'Kalender und Schule';

  @override
  String get settingsSectionMeals => 'Essen';

  @override
  String get settingsSectionKitchen => 'Küchenwand';

  @override
  String get settingsSectionDevice => 'Dieses Gerät';

  @override
  String get settingsSectionMine => 'Meine Einstellungen';

  @override
  String get settingPickPersonFirst =>
      'Wähle zuerst, wer du bist. Dann erscheinen hier deine Einstellungen.';

  @override
  String get settingIsDefault => 'Standard';

  @override
  String get settingIsCustom => 'angepasst';

  @override
  String get settingReset => 'Auf Standard zurücksetzen';

  @override
  String get settingOn => 'An';

  @override
  String get settingOff => 'Aus';

  @override
  String get settingFrom => 'von';

  @override
  String get settingTo => 'bis';

  @override
  String get settingIncrease => 'Erhöhen';

  @override
  String get settingDecrease => 'Verringern';

  @override
  String get settingDayPartsMorningEnds => 'Vormittag bis';

  @override
  String get settingDayPartsEveningStarts => 'Abend ab';

  @override
  String settingUnitPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '1 Punkt',
    );
    return '$_temp0';
  }

  @override
  String settingUnitMinutes(int count) {
    return '$count Min.';
  }

  @override
  String settingUnitSeconds(int count) {
    return '$count s';
  }

  @override
  String get settingValueName => 'Vollname';

  @override
  String get settingValueInitial => 'Initiale';

  @override
  String get settingValueDuty => 'Pflicht';

  @override
  String get settingValueBonus => 'Bonus';

  @override
  String get settingValueRequired => 'Freigabe';

  @override
  String get settingValueSelfServe => 'Selbst einlösen';

  @override
  String get settingValueWholeFamily => 'Ganze Familie';

  @override
  String get settingValueAll => 'Alle';

  @override
  String get settingValueNone => 'Keine';

  @override
  String get settingValueLunch => 'Mittagessen';

  @override
  String get settingValueDinner => 'Abendessen';

  @override
  String get settingBoardMemberLabelTitle => 'Namen auf der Küchenwand';

  @override
  String get settingBoardMemberLabelHelp =>
      'Aus zwei Metern liest man einen Namen besser als eine Initiale. Bei häufigem Besuch passen Initialen vielleicht besser.';

  @override
  String get settingTasksDutyPointsTitle => 'Punkte für eine Pflicht';

  @override
  String get settingTasksDutyPointsHelp =>
      'Pflichten erwartet man von allen, darum bringen sie wenig oder nichts. Die Serie ist ihre Belohnung.';

  @override
  String get settingTasksBonusPointsTitle => 'Punkte für eine Bonusaufgabe';

  @override
  String get settingTasksBonusPointsHelp =>
      'Eine Bonusaufgabe reicht für die günstigste Startbelohnung, sodass ein jüngeres Kind schnell ankommt.';

  @override
  String get settingTasksKindTitle => 'Neue Aufgaben sind';

  @override
  String get settingTasksKindHelp =>
      'Eine neue Aufgabe ist eine Pflicht, bis jemand sie bewusst zum Bonus macht. So bleibt die Verdienstfläche klein.';

  @override
  String get settingTasksVerificationTitle =>
      'Erziehungsberechtigte prüfen Aufgaben';

  @override
  String get settingTasksVerificationHelp =>
      'Prüfen macht aus jeder Aufgabe eine Kontrolle. Nur für wertvolle Bonusaufgaben einschalten.';

  @override
  String get settingTasksJokersTitle => 'Serien-Joker pro Monat';

  @override
  String get settingTasksJokersHelp =>
      'Ein Joker hält eine Serie an einem verpassten Tag am Leben. Ein Krankheitstag zerstört so keine dreiwöchige Serie.';

  @override
  String get settingTasksRewardApprovalTitle => 'Belohnungen brauchen Freigabe';

  @override
  String get settingTasksRewardApprovalHelp =>
      'Eine erziehungsberechtigte Person gibt jede Einlösung mit der PIN frei. Selbst einlösen passt nur zu Kleinigkeiten.';

  @override
  String get settingCalendarMembersEditTitle =>
      'Mitglieder ändern eigene Termine';

  @override
  String get settingCalendarMembersEditHelp =>
      'Kinder legen Termine an und ändern sie, wenn sie selbst dabei sind. Fremde Termine löschen bleibt Sache der Erziehungsberechtigten.';

  @override
  String get settingCalendarKeyDefaultTitle =>
      'Neue Termine auf der Küchenwand';

  @override
  String get settingCalendarKeyDefaultHelp =>
      'Legt fest, welche neuen Termine ohne Häkchen auf der Küchenwand erscheinen. Nach zwei Wochen Nutzung prüfen.';

  @override
  String get settingSchoolReportTitle => 'Mitglieder melden Plan-Änderungen';

  @override
  String get settingSchoolReportHelp =>
      'Nur Erziehungsberechtigte pflegen den Stundenplan. Mit dieser Option kann ein Kind einen Entfall melden, den eine erziehungsberechtigte Person bestätigt.';

  @override
  String get settingSchoolEquipmentTitle => 'Hinweis auf Sachen für morgen';

  @override
  String get settingSchoolEquipmentHelp =>
      'Zeigt aus dem Stundenplan von morgen, was mitgebracht werden muss, zum Beispiel Sportsachen.';

  @override
  String get settingMealsSchoolDayTitle => 'Warmes Essen an Schultagen';

  @override
  String get settingMealsSchoolDayHelp =>
      'Die eine warme Mahlzeit auf der Küchenwand. An Schultagen essen Kinder mittags in der Schule oder im Hort.';

  @override
  String get settingMealsFreeDayTitle => 'Warmes Essen an freien Tagen';

  @override
  String get settingMealsFreeDayHelp => 'Für Wochenenden und Ferien.';

  @override
  String get settingMealsAwayTitle => 'Abwesend heißt nicht essen';

  @override
  String get settingMealsAwayHelp =>
      'Wer zur Essenszeit unterwegs oder weg ist, isst nicht mit. So brauchen die meisten Tage keine Eingabe.';

  @override
  String get settingMealsCareCutoffTitle => 'Mittagsgrenze für Betreuung';

  @override
  String get settingMealsCareCutoffHelp =>
      'Ein Kind, dessen Betreuung über diese Zeit hinausgeht, isst mittags auswärts.';

  @override
  String get settingBoardRolloverTitle => 'Küchenwand wechselt am';

  @override
  String get settingBoardRolloverHelp =>
      'Wann die Wand zur kommenden Woche wechselt. Am Sonntagabend plant man die nächste Woche, am Samstagmorgen noch diese.';

  @override
  String get settingBoardDayPartsTitle => 'Vormittag, Nachmittag, Abend';

  @override
  String get settingBoardDayPartsHelp =>
      'Wo die Terminzone in Vormittag, Nachmittag und Abend geteilt wird.';

  @override
  String get settingDeviceNightHoursTitle => 'Zeiten des Nachtdesigns';

  @override
  String get settingDeviceNightHoursHelp =>
      'Wann das Gerät auf das bernsteinfarbene Nachtdesign wechselt.';

  @override
  String get settingDeviceIdleRevertTitle => 'Zurück zur Wand nach';

  @override
  String get settingDeviceIdleRevertHelp =>
      'Wie lange eine geöffnete Person oder Detailansicht offen bleibt, bevor das Gerät zur Küchenwand zurückkehrt.';

  @override
  String get settingMemberCompletionSoundTitle =>
      'Ton beim Abhaken einer Aufgabe';

  @override
  String get settingMemberCompletionSoundHelp =>
      'Beim Abhaken einer Aufgabe ertönt ein kurzer Ton. Ausschalten, wenn du ihn nicht willst.';

  @override
  String get settingCalendarTentativeTitle => 'Unsichere Termine prüfen um';

  @override
  String get settingCalendarTentativeHelp =>
      'Fragt nach, ob ein unsicherer Termin stattfindet, damit er bis zum Beginn nicht offen bleibt.';

  @override
  String get settingNotifyMorningTitle => 'Morgenübersicht';

  @override
  String get settingNotifyMorningHelp =>
      'Die heutigen Aufgaben und Termine für dich. Offene Einlösungen erscheinen hier für Erziehungsberechtigte.';

  @override
  String get settingNotifyEventReminderTitle => 'Erinnerung vor Terminen';

  @override
  String get settingNotifyEventReminderHelp =>
      'Eine Benachrichtigung, bevor ein Termin beginnt.';

  @override
  String get settingNotifyTaskVerifiedTitle =>
      'Wenn eine Aufgabe bestätigt wird';

  @override
  String get settingNotifyTaskVerifiedHelp =>
      'Eine Benachrichtigung, wenn eine erziehungsberechtigte Person eine Aufgabe bestätigt und die Punkte gutgeschrieben werden.';

  @override
  String get settingNotifyRedemptionTitle =>
      'Wenn eine Belohnung angefragt wird';

  @override
  String get settingNotifyRedemptionHelp =>
      'Sofort eine Benachrichtigung, wenn ein Kind eine Belohnung anfragt.';

  @override
  String boardCareShort(String label, String time) {
    return '$label $time';
  }

  @override
  String get calendarTitle => 'Kalender';

  @override
  String get calendarDay => 'Tag';

  @override
  String get calendarThreeDays => '3 Tage';

  @override
  String get calendarWeek => 'Woche';

  @override
  String get calendarPrevious => 'Zurück';

  @override
  String get calendarNext => 'Weiter';

  @override
  String get calendarToday => 'Heute';

  @override
  String calendarRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get calendarNewEvent => 'Neuer Termin';

  @override
  String get calendarEmpty => 'Nichts geplant';

  @override
  String get calendarEditorPlaceholder => 'Der Termin-Editor kommt bald.';

  @override
  String get eventEditTitle => 'Termin bearbeiten';

  @override
  String get eventTitleLabel => 'Titel';

  @override
  String get eventTitleRequired => 'Bitte einen Titel eingeben.';

  @override
  String get eventKindAppointment => 'Termin';

  @override
  String get eventKindPresence => 'Anwesenheit';

  @override
  String get eventPresenceState => 'Zustand';

  @override
  String get eventPresenceStateRequired => 'Bitte einen Zustand wählen.';

  @override
  String get eventAllDay => 'Ganztägig';

  @override
  String get eventStarts => 'Beginn';

  @override
  String get eventEnds => 'Ende';

  @override
  String get eventEndBeforeStart => 'Das Ende muss nach dem Beginn liegen.';

  @override
  String get eventAttendees => 'Wer';

  @override
  String get eventAttendeesWholeFamily =>
      'Niemand ausgewählt: Der Termin gilt für die ganze Familie.';

  @override
  String get eventLocation => 'Ort';

  @override
  String get eventNotes => 'Notizen';

  @override
  String get eventTentative => 'Noch nicht sicher';

  @override
  String get eventKeyDisplay => 'Auf dem Küchendisplay zeigen';

  @override
  String get eventRepeat => 'Wiederholung';

  @override
  String get eventRepeatNever => 'Nie';

  @override
  String get eventRepeatDaily => 'Täglich';

  @override
  String get eventRepeatWeekly => 'Wöchentlich';

  @override
  String get eventRepeatBiweekly => 'Alle 2 Wochen';

  @override
  String get eventRepeatMonthly => 'Monatlich';

  @override
  String get eventRepeatSpecificDays => 'Bestimmte Tage (Dienstplan)';

  @override
  String eventRepeatMonthlyDay(int day) {
    return 'am $day.';
  }

  @override
  String eventRepeatMonthlyNth(int n, String weekday) {
    return 'jeden $n. $weekday';
  }

  @override
  String eventRepeatMonthlyLast(String weekday) {
    return 'letzten $weekday';
  }

  @override
  String get eventRepeatDays => 'An diesen Tagen';

  @override
  String get eventRepeatEnds => 'Ende der Wiederholung';

  @override
  String get eventRepeatUntil => 'bis Datum';

  @override
  String eventRepeatCount(int count) {
    return 'nach $count Mal';
  }

  @override
  String eventDaysPicked(int count) {
    return '$count Tage';
  }

  @override
  String get eventDienstplanHelp =>
      'Tippe die Tage an, an denen gearbeitet wird. Der Starttag gehört immer dazu.';

  @override
  String get eventCustomRule => 'Eigene Regel';

  @override
  String get eventCustomRuleHelp =>
      'Diese Wiederholung lässt sich hier nicht bearbeiten. Sie bleibt, wie sie ist.';

  @override
  String get eventWeekdaysRequired =>
      'Bitte mindestens einen Wochentag wählen.';

  @override
  String get eventDeleteConfirm => 'Diesen Termin löschen?';

  @override
  String get eventScopeTitle => 'Welche Termine?';

  @override
  String get eventScopeDeleteTitle => 'Welche Termine löschen?';

  @override
  String get eventScopeThis => 'Nur dieser Termin';

  @override
  String get eventScopeSeries => 'Alle Termine der Serie';

  @override
  String get errEventInvalid => 'Der Termin ist nicht gültig.';

  @override
  String get errRruleInvalid =>
      'Diese Wiederholung kann nicht gespeichert werden.';

  @override
  String get errAttendeeInvalid =>
      'Eine ausgewählte Person gehört nicht zu diesem Haushalt.';

  @override
  String get errEventNotFound => 'Dieser Termin gibt es nicht mehr.';

  @override
  String get scheduleTitle => 'Stundenplan';

  @override
  String get tasksTitle => 'Aufgaben';

  @override
  String get mealsTitle => 'Essen';

  @override
  String get comingSoon => 'Dieser Teil wird gerade gebaut.';

  @override
  String mealsWeekRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get mealsPrevWeek => 'Vorige Woche';

  @override
  String get mealsNextWeek => 'Nächste Woche';

  @override
  String get mealsThisWeek => 'Diese Woche';

  @override
  String get mealsRecipes => 'Rezepte';

  @override
  String get mealsFillShopping => 'Einkaufsliste füllen';

  @override
  String get mealsSlotBreakfast => 'Frühstück';

  @override
  String get mealsSlotLunch => 'Mittagessen';

  @override
  String get mealsSlotDinner => 'Abendessen';

  @override
  String get mealsSlotSnack => 'Snack';

  @override
  String get mealsNothingYet => 'Noch nichts geplant';

  @override
  String get mealsAddOther => 'Mahlzeit hinzufügen';

  @override
  String get mealsDragHint =>
      'Eine Mahlzeit gedrückt halten und auf einen anderen Tag ziehen, um sie zu verschieben.';

  @override
  String mealsEditTitle(String day) {
    return 'Essen am $day';
  }

  @override
  String get mealsFieldLabel => 'Gericht oder Notiz';

  @override
  String get mealsFieldHint => 'Pizza, Reste, ein Rezeptname …';

  @override
  String get mealsSuggestionHelp =>
      'Passende Rezepte. Antippen, um eins zu nehmen; seine Zutaten kommen dann auf die Einkaufsliste.';

  @override
  String get mealsServings => 'Portionen';

  @override
  String get mealsCook => 'Kocht';

  @override
  String get mealsCookNobody => 'Niemand';

  @override
  String get mealsTime => 'Uhrzeit';

  @override
  String get mealsTimeNone => 'Keine Uhrzeit';

  @override
  String get mealsGuests => 'Gäste';

  @override
  String get mealsEatingTitle => 'Wer isst mit';

  @override
  String get mealsEatingHelp =>
      'Wer zur Essenszeit verreist oder unterwegs ist oder nach dem Hort-Schluss nicht mehr da ist, ist automatisch nicht dabei. Nur von Hand setzen, wenn das nicht stimmt.';

  @override
  String get mealsEatingAuto => 'Automatisch';

  @override
  String get mealsEatingYes => 'Isst mit';

  @override
  String get mealsEatingNo => 'Isst nicht';

  @override
  String get mealsDelete => 'Mahlzeit löschen';

  @override
  String get mealsPreviewTitle => 'Einkaufsliste füllen';

  @override
  String get mealsPreviewEmpty =>
      'Nichts hinzuzufügen. Freie Notizen haben keine Zutaten; Rezepte legen ihre Zutaten auf die Liste.';

  @override
  String get mealsPreviewOnList => 'Steht schon auf der Liste';

  @override
  String mealsPreviewFor(String meals) {
    return 'Für $meals';
  }

  @override
  String mealsPreviewAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel hinzufügen',
      one: '1 Artikel hinzufügen',
      zero: 'Nichts hinzufügen',
    );
    return '$_temp0';
  }

  @override
  String mealsPreviewAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel auf die Einkaufsliste gesetzt',
      one: '1 Artikel auf die Einkaufsliste gesetzt',
    );
    return '$_temp0';
  }

  @override
  String get mealsRecipesTitle => 'Rezepte';

  @override
  String get mealsRecipeSearch => 'Rezepte suchen';

  @override
  String get mealsRecipesEmpty =>
      'Noch keine Rezepte. Für eine Mahlzeit reicht ein Gerichtname; ein Rezept legt seine Zutaten auf die Einkaufsliste.';

  @override
  String get mealsRecipeNew => 'Neues Rezept';

  @override
  String get mealsRecipeEdit => 'Rezept bearbeiten';

  @override
  String get mealsRecipeTitleField => 'Titel';

  @override
  String get mealsIngredients => 'Zutaten';

  @override
  String get mealsIngredientName => 'Zutat';

  @override
  String get mealsIngredientQuantity => 'Menge';

  @override
  String get mealsIngredientUnit => 'Einheit';

  @override
  String get mealsIngredientNote => 'Notiz';

  @override
  String get mealsIngredientAdd => 'Zutat hinzufügen';

  @override
  String get mealsIngredientRemove => 'Zutat entfernen';

  @override
  String get mealsIngredientMove => 'Zum Umordnen ziehen';

  @override
  String get mealsNoIngredients => 'Keine Zutaten eingetragen.';

  @override
  String get mealsSteps => 'Zubereitung';

  @override
  String get mealsStepsHint => 'Ein Schritt pro Zeile';

  @override
  String get mealsTags => 'Schlagwörter';

  @override
  String get mealsTagsHint =>
      'Durch Kommas getrennt, z. B. schnell, vegetarisch';

  @override
  String get mealsSourceUrl => 'Quelle (Link)';

  @override
  String get mealsSource => 'Quelle';

  @override
  String get mealsRecipeSave => 'Rezept speichern';

  @override
  String get mealsRecipeDelete => 'Rezept löschen';

  @override
  String mealsRecipeDeleteConfirm(String title) {
    return '„$title“ löschen? Mahlzeiten, die es nutzen, behalten ihren Namen.';
  }

  @override
  String get mealsRecipeTitleRequired => 'Ein Rezept braucht einen Titel.';

  @override
  String get mealsKioskHint =>
      'Einen Punkt antippen, um zu ändern, wer mitisst';

  @override
  String get errMealInvalid =>
      'Diese Mahlzeit konnte nicht gespeichert werden. Prüfe den Eintrag und versuche es erneut.';

  @override
  String get schoolSetupCardTitle => 'Schule einrichten';

  @override
  String get schoolSetupCardBody =>
      'Lege Schule, Klingelzeiten und Zeiträume an. Danach lässt sich der Stundenplan eintragen.';

  @override
  String get schoolSetupAction => 'Schule einrichten';

  @override
  String get schoolEnterTimetableTitle => 'Stundenplan eingeben';

  @override
  String schoolEnterTimetableBody(String name) {
    return 'Für $name ist für diesen Zeitraum noch kein Stundenplan eingetragen.';
  }

  @override
  String get schoolEnterTimetableAction => 'Stundenplan eingeben';

  @override
  String get schoolNoChildren => 'Im Haushalt ist noch kein Kind eingetragen.';

  @override
  String get schoolEditSchool => 'Schule bearbeiten';

  @override
  String get schoolEditTimetable => 'Stundenplan bearbeiten';

  @override
  String get schoolPrevWeek => 'Vorige Woche';

  @override
  String get schoolNextWeek => 'Nächste Woche';

  @override
  String get schoolThisWeek => 'Diese Woche';

  @override
  String schoolWeekLabel(int week, String from, String to) {
    return 'KW $week · $from – $to';
  }

  @override
  String get schoolChooseChild => 'Kind wählen';

  @override
  String schoolHolidayBand(String name, String range) {
    return '$name · $range';
  }

  @override
  String get schoolNoLessonsToday => 'Kein Unterricht';

  @override
  String get schoolPackTomorrowNone => 'Morgen ist nichts einzupacken.';

  @override
  String schoolLessonActions(String subject, String day, String period) {
    return '$subject, $day, $period';
  }

  @override
  String get schoolCancelLesson => 'Fällt aus';

  @override
  String get schoolSubstitute => 'Vertretung';

  @override
  String get schoolRoomChange => 'Raum geändert';

  @override
  String get schoolResetException => 'Zurücksetzen';

  @override
  String get schoolPickSubject => 'Fach';

  @override
  String get schoolSearchSubject => 'Fach suchen';

  @override
  String get schoolTeacher => 'Lehrkraft';

  @override
  String get schoolNote => 'Notiz';

  @override
  String get schoolRoom => 'Raum';

  @override
  String get schoolApply => 'Übernehmen';

  @override
  String get schoolSaved => 'Gespeichert.';

  @override
  String get schoolNoSubjects =>
      'Noch keine Fächer. Lege sie unter „Schule bearbeiten“ an.';

  @override
  String get schoolSetupTitle => 'Schule';

  @override
  String get schoolSectionSchool => 'Schule';

  @override
  String get schoolName => 'Name der Schule';

  @override
  String get schoolBellTimes => 'Klingelzeiten';

  @override
  String get schoolAddLesson => 'Stunde hinzufügen';

  @override
  String get schoolAddBreak => 'Pause hinzufügen';

  @override
  String get schoolRemove => 'Entfernen';

  @override
  String get schoolStart => 'Beginn';

  @override
  String get schoolEnd => 'Ende';

  @override
  String get schoolTerms => 'Zeiträume';

  @override
  String get schoolAddTerm => 'Zeitraum hinzufügen';

  @override
  String get schoolTermEdit => 'Zeitraum';

  @override
  String get schoolTermName => 'Name';

  @override
  String get schoolFrom => 'Von';

  @override
  String get schoolTo => 'Bis';

  @override
  String get schoolAbWeek => 'A/B-Ankerwoche (Kalenderwoche)';

  @override
  String get schoolAbWeekHint =>
      'Eine Kalenderwoche, die eine A-Woche ist. Leer: jede Woche ist gleich.';

  @override
  String get schoolCurrent => 'aktuell';

  @override
  String get schoolSubjects => 'Fächer';

  @override
  String get schoolAddSubject => 'Fach hinzufügen';

  @override
  String get schoolSubjectEdit => 'Fach';

  @override
  String get schoolSubjectShort => 'Kürzel';

  @override
  String get schoolTint => 'Farbe';

  @override
  String get schoolEquipment => 'Sachen zum Mitnehmen';

  @override
  String get schoolNotable => 'Auf der Wand zeigen';

  @override
  String get schoolSubjectInUse =>
      'Dieses Fach steht noch in einem Stundenplan. Entferne es dort zuerst.';

  @override
  String get schoolInvalid => 'Diese Angaben passen nicht zusammen.';

  @override
  String get schoolHolidays => 'Ferien und freie Tage';

  @override
  String get schoolAddHoliday => 'Ferien hinzufügen';

  @override
  String get schoolHolidayEdit => 'Ferien';

  @override
  String get schoolHolidayName => 'Name';

  @override
  String get schoolEditorClass => 'Klasse';

  @override
  String get schoolWeekCycle => 'Wochenrhythmus';

  @override
  String get schoolCycleWeekly => 'Jede Woche';

  @override
  String get schoolCycleAb => 'A/B-Wochen';

  @override
  String get schoolParityAll => 'Jede Woche';

  @override
  String get schoolParityA => 'A-Woche';

  @override
  String get schoolParityB => 'B-Woche';

  @override
  String get schoolClearDay => 'Tag leeren';

  @override
  String get schoolClearCell => 'Leeren';

  @override
  String get schoolCopyFrom => 'Kopieren von…';

  @override
  String get schoolCopyPick => 'Stundenplan kopieren von';

  @override
  String get schoolCareRows => 'Hort und Betreuung';

  @override
  String get schoolAddCare => 'Betreuung hinzufügen';

  @override
  String get schoolCareTitle => 'Bezeichnung';

  @override
  String get schoolCareDays => 'An';

  @override
  String get schoolSaveTimetable => 'Stundenplan speichern';

  @override
  String get schoolWeekdayPick => 'Tage';

  @override
  String get feedTitle => 'Kalender-Abos';

  @override
  String get feedSettingsSubtitle =>
      'Der Familienkalender in Outlook oder auf dem iPhone';

  @override
  String get feedNew => 'Neues Abo';

  @override
  String get feedEmpty =>
      'Noch kein Abo. Ein Abo zeigt Termine in Outlook oder auf dem iPhone, nur zum Lesen.';

  @override
  String get feedRevoked => 'Gesperrt';

  @override
  String get feedNeverFetched => 'Noch nie abgerufen';

  @override
  String feedLastFetched(String when) {
    return 'Zuletzt abgerufen: $when';
  }

  @override
  String get feedAgoJustNow => 'gerade eben';

  @override
  String feedAgoMinutes(int count) {
    return 'vor $count Min.';
  }

  @override
  String feedAgoHours(int count) {
    return 'vor $count Std.';
  }

  @override
  String feedAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tagen',
      one: '1 Tag',
    );
    return 'vor $_temp0';
  }

  @override
  String feedFetchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-mal abgerufen',
      one: '1-mal abgerufen',
    );
    return '$_temp0';
  }

  @override
  String get feedSummaryAppointments => 'Termine';

  @override
  String get feedSummaryPresence => 'Anwesenheit';

  @override
  String get feedSummaryEveryone => 'Alle Mitglieder';

  @override
  String get feedSummarySchoolDay => 'Schultag';

  @override
  String get feedSummarySchoolLessons => 'Stunden';

  @override
  String get feedWhoseTitle => 'Wessen Termine';

  @override
  String get feedWhoseHelp => 'Ohne Auswahl: alle Mitglieder';

  @override
  String get feedLabelField => 'Name des Abos';

  @override
  String get feedLabelHint => 'z. B. Arbeits-Laptop Outlook';

  @override
  String get feedWhatTitle => 'Was';

  @override
  String get feedKindPresenceTitle => 'Anwesenheit';

  @override
  String get feedPresenceHint =>
      'Zeigt, wer wann wo ist (Dienst, Homeoffice, Frei …). Für Arbeitsgeräte und Kinder lieber aus lassen.';

  @override
  String get feedSchoolTitle => 'Schule';

  @override
  String get feedSchoolOff => 'Aus';

  @override
  String get feedSchoolHint =>
      'Schultage als ganzer Tag oder jede Unterrichtsstunde.';

  @override
  String get feedCreate => 'Abo erstellen';

  @override
  String get feedUrlTitle => 'Abo-Adresse';

  @override
  String get feedUrlOnce =>
      'Diese Adresse wird nur jetzt angezeigt. Wer sie hat, sieht die Termine, also behandle sie wie ein Passwort.';

  @override
  String get feedCopyUrl => 'Adresse kopieren';

  @override
  String get feedCopyWebcal => 'webcal-Link kopieren';

  @override
  String get feedWebcalLabel => 'webcal-Link (öffnet das Dialogfeld am iPhone)';

  @override
  String get feedCopied => 'Adresse kopiert.';

  @override
  String get feedQrLabel => 'QR-Code mit der Abo-Adresse';

  @override
  String get feedHowTitle => 'So abonnierst du';

  @override
  String get feedHowOutlook =>
      'Outlook im Web: Kalender → Kalender hinzufügen → Aus dem Web abonnieren → Adresse einfügen → Namen „Familie“ wählen.';

  @override
  String get feedHowIphone =>
      'iPhone: Einstellungen → Apps → Kalender → Accounts → Account hinzufügen → Andere → Abo-Kalender hinzufügen → Adresse einfügen. Oder den webcal-Link antippen.';

  @override
  String get feedRevokeAction => 'Sperren';

  @override
  String feedRevokeConfirm(String label) {
    return '„$label“ sperren? Es bekommt sofort keine Termine mehr.';
  }

  @override
  String get baselineTitle => 'Grundzustand';

  @override
  String get baselineSettingsSubtitle => 'Wo alle normalerweise sind';

  @override
  String get baselineHelp =>
      'Wo du normalerweise bist. Nur Abweichungen trägst du ein, ein normaler Tag bleibt leer.';

  @override
  String get baselineNone => 'Nichts eingetragen';

  @override
  String get baselineLabelField => 'Eigene Bezeichnung (optional)';

  @override
  String get baselineLabelHint => 'z. B. zu Hause';

  @override
  String get baselineSaved => 'Gespeichert.';

  @override
  String get busyTitle => 'Termine bis';

  @override
  String get busyPickTime => 'Uhrzeit wählen';

  @override
  String get busyThisDay => 'Nur diesen Tag';

  @override
  String get busyWholeWeek => 'Für die ganze Woche übernehmen (Mo–Fr)';

  @override
  String get busyRemove => 'Entfernen';

  @override
  String get busyHelp =>
      'Bis wann du nicht verfügbar bist. Nur die Uhrzeit, keine Termine und keine Details.';

  @override
  String get busyFor => 'Für';

  @override
  String get tasksTabToday => 'Heute';

  @override
  String get tasksTabApprovals => 'Freigaben';

  @override
  String get tasksTabChores => 'Aufgaben';

  @override
  String get tasksTabRewards => 'Belohnungen';

  @override
  String get tasksTabPoints => 'Punkte';

  @override
  String get tasksNothingToday => 'Heute steht nichts an.';

  @override
  String get tasksOpenForAnyone => 'Offen für alle';

  @override
  String get tasksWaitingApproval => 'wartet auf Freigabe';

  @override
  String get tasksDone => 'Erledigt';

  @override
  String get tasksUndo => 'Rückgängig';

  @override
  String tasksCompletedSnack(String title) {
    return '$title erledigt';
  }

  @override
  String tasksPointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte',
      one: '1 Punkt',
    );
    return '$_temp0';
  }

  @override
  String tasksStreakBadge(int count) {
    return '🔥 $count';
  }

  @override
  String tasksStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage in Folge',
      one: '1 Tag in Folge',
    );
    return '$_temp0';
  }

  @override
  String tasksOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offen',
      one: '1 offen',
      zero: 'keine offen',
    );
    return '$_temp0';
  }

  @override
  String get tasksKindDuty => 'Pflicht';

  @override
  String get tasksKindBonus => 'Extra';

  @override
  String get tasksApprovalsEmpty => 'Nichts zu prüfen.';

  @override
  String get tasksCheckChores => 'Erledigt, zu prüfen';

  @override
  String get tasksRewardRequests => 'Belohnungswünsche';

  @override
  String get tasksApprove => 'Freigeben';

  @override
  String get tasksDecline => 'Ablehnen';

  @override
  String tasksRequestedBy(String name, String reward) {
    return '$name wünscht sich $reward';
  }

  @override
  String tasksDoneBy(String name) {
    return 'Erledigt von $name';
  }

  @override
  String get tasksNoteOptional => 'Notiz (optional)';

  @override
  String get tasksNoChores => 'Noch keine Aufgaben.';

  @override
  String get tasksStarterTitle => 'Mit dem Startpaket beginnen';

  @override
  String get tasksStarterHelp =>
      'Fünf Aufgaben, drei Belohnungen und vier Abzeichen zum Start. Alles lässt sich danach ändern.';

  @override
  String get tasksStarterAdd => 'Startpaket anlegen';

  @override
  String get tasksStarterDone => 'Startpaket angelegt.';

  @override
  String get tasksNewChore => 'Neue Aufgabe';

  @override
  String get tasksEditChore => 'Aufgabe bearbeiten';

  @override
  String get tasksFieldTitle => 'Titel';

  @override
  String get tasksTitleRequired => 'Bitte einen Titel eingeben.';

  @override
  String get tasksFieldIcon => 'Symbol';

  @override
  String get tasksNoIcon => 'Ohne Symbol';

  @override
  String get tasksFieldKind => 'Art';

  @override
  String get tasksKindDutyHelp => 'Wird erwartet und bringt wenig Punkte.';

  @override
  String get tasksKindBonusHelp => 'Freiwillig und extra; bringt Punkte.';

  @override
  String get tasksFieldPoints => 'Punkte';

  @override
  String get tasksFieldRepeat => 'Wiederholung';

  @override
  String get tasksRepeatOnce => 'Einmalig';

  @override
  String get tasksRepeatDaily => 'Täglich';

  @override
  String get tasksRepeatWeekdays => 'An Wochentagen';

  @override
  String get tasksRepeatWeekly => 'Wöchentlich';

  @override
  String get tasksRepeatBiweekly => 'Alle 2 Wochen';

  @override
  String get tasksRepeatMonthly => 'Monatlich';

  @override
  String get tasksWeekdayOne => 'Wochentag';

  @override
  String get tasksWeekdayMany => 'Wochentage';

  @override
  String get tasksWeekdaysRequired => 'Mindestens ein Wochentag.';

  @override
  String get tasksFieldStarts => 'Ab dem';

  @override
  String get tasksFieldWindow => 'Erledigbar';

  @override
  String tasksWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage ab Fälligkeitstag',
      one: 'Nur am Fälligkeitstag',
    );
    return '$_temp0';
  }

  @override
  String get tasksFieldWho => 'Wer';

  @override
  String get tasksWhoFixed => 'Eine Person';

  @override
  String get tasksWhoRotating => 'Reihum';

  @override
  String get tasksWhoOpen => 'Wer will';

  @override
  String get tasksWhoEach => 'Jede Person';

  @override
  String get tasksPickOne => 'Wer macht es?';

  @override
  String get tasksPickPool => 'Wer ist dabei?';

  @override
  String get tasksPickOpenPool => 'Wer darf es übernehmen? Leer heißt alle.';

  @override
  String get tasksPoolRequired => 'Mindestens eine Person auswählen.';

  @override
  String get tasksFieldVerification => 'Freigabe durch Erwachsene';

  @override
  String get tasksVerificationHelp => 'Punkte gibt es erst nach einer Prüfung.';

  @override
  String get tasksArchive => 'Archivieren';

  @override
  String get tasksArchiveHelp =>
      'Die Aufgabe verschwindet. Ihre offenen Termine in der Zukunft werden entfernt.';

  @override
  String get tasksNoRewards => 'Noch keine Belohnungen.';

  @override
  String get tasksNewReward => 'Neue Belohnung';

  @override
  String get tasksEditReward => 'Belohnung bearbeiten';

  @override
  String get tasksFieldCost => 'Kosten in Punkten';

  @override
  String get tasksFieldStock => 'Vorrat (leer heißt unbegrenzt)';

  @override
  String get tasksFieldNeedsApproval => 'Vorher freigeben';

  @override
  String get tasksNeedsApprovalHelp => 'Aus passt nur zu Kleinigkeiten.';

  @override
  String get tasksAskForReward => 'Wünschen';

  @override
  String get tasksRequestSent => 'Wunsch gesendet.';

  @override
  String get tasksRedeemed => 'Eingelöst.';

  @override
  String get tasksSoldOut => 'Ausverkauft';

  @override
  String tasksMissingPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte fehlen',
      one: '1 Punkt fehlt',
    );
    return '$_temp0';
  }

  @override
  String get tasksHistory => 'Verlauf';

  @override
  String get tasksNoHistory => 'Noch nichts eingelöst.';

  @override
  String get tasksRedemptionRequested => 'Wartet auf Freigabe';

  @override
  String get tasksRedemptionApproved => 'Eingelöst, noch nicht übergeben';

  @override
  String get tasksRedemptionDeclined => 'Abgelehnt';

  @override
  String get tasksRedemptionFulfilled => 'Übergeben';

  @override
  String get tasksHandOver => 'Als übergeben markieren';

  @override
  String get tasksNoLedger => 'Noch keine Bewegungen.';

  @override
  String get tasksLedgerTask => 'Aufgabe erledigt';

  @override
  String get tasksLedgerUndo => 'Zurückgenommen';

  @override
  String get tasksLedgerRedemption => 'Belohnung';

  @override
  String get tasksLedgerAdjustment => 'Korrektur';

  @override
  String get tasksLedgerBadge => 'Abzeichen';

  @override
  String get tasksLedgerBonus => 'Bonus';

  @override
  String get tasksAdjust => 'Korrigieren';

  @override
  String tasksAdjustTitle(String name) {
    return 'Punkte von $name korrigieren';
  }

  @override
  String get tasksFieldAmount => 'Punkte (+ oder −)';

  @override
  String get tasksAmountInvalid => 'Bitte eine Zahl ungleich 0 eingeben.';

  @override
  String get tasksFieldReason => 'Grund (Pflicht)';

  @override
  String get tasksReasonRequired => 'Bitte einen Grund angeben.';

  @override
  String get tasksBalanceTitle => 'Stand';

  @override
  String get tasksBoardStreakLabel => 'Serie';

  @override
  String get errTaskInvalid => 'Diese Aufgabe ist nicht gültig.';

  @override
  String get errTaskNotYours =>
      'Das kann nur die Person, für die sie gedacht ist.';

  @override
  String get errBalanceInsufficient => 'Dafür reichen die Punkte nicht.';

  @override
  String get errRewardOutOfStock => 'Diese Belohnung ist ausverkauft.';

  @override
  String get errTaskNotOpen => 'Diese Aufgabe ist nicht mehr offen.';

  @override
  String get tasksActionTick => 'Abhaken';

  @override
  String get tasksPointsInvalid => 'Bitte eine ganze Zahl ab 0 eingeben.';

  @override
  String get kidTabToday => 'Mein Tag';

  @override
  String get kidTabSchool => 'Stundenplan';

  @override
  String get kidTabPoints => 'Punkte';

  @override
  String get kidTabShopping => 'Einkaufen';

  @override
  String get kidTabFamily => 'Familie';

  @override
  String get kidWhoAreYou => 'Hallo! Tipp auf deinen Namen.';

  @override
  String kidGreeting(String name) {
    return 'Hallo, $name!';
  }

  @override
  String get kidTasksTitle => 'Meine Aufgaben';

  @override
  String get kidTasksNone => 'Heute hast du keine Aufgaben.';

  @override
  String get kidTasksAllDone => 'Alles geschafft! 🎉';

  @override
  String get kidTasksAllDoneBody => 'Super gemacht, heute ist alles erledigt.';

  @override
  String get kidAwaitsCheck => 'wird noch geprüft';

  @override
  String get kidDone => 'Erledigt';

  @override
  String kidTaskDoneSnack(String title) {
    return '$title geschafft!';
  }

  @override
  String get kidUndo => 'Rückgängig';

  @override
  String get kidSchoolTitle => 'Heute in der Schule';

  @override
  String get kidNoSchoolToday => 'Heute ist keine Schule.';

  @override
  String kidHoliday(String name) {
    return 'Ferien: $name';
  }

  @override
  String get kidNoTimetable =>
      'Für dich ist noch kein Stundenplan eingetragen.';

  @override
  String kidRoom(String room) {
    return 'Raum $room';
  }

  @override
  String get kidNow => 'Jetzt';

  @override
  String get kidLessonCancelled => 'fällt aus';

  @override
  String get kidLessonSubstituted => 'Vertretung';

  @override
  String get kidLessonRoomChange => 'anderer Raum';

  @override
  String kidCareUntil(String time) {
    return 'Betreuung bis $time';
  }

  @override
  String kidTomorrowNeeds(String items) {
    return 'Morgen brauchst du: $items';
  }

  @override
  String kidMealDinner(String dish) {
    return 'Heute Abend gibt es $dish';
  }

  @override
  String kidMealLunch(String dish) {
    return 'Heute Mittag gibt es $dish';
  }

  @override
  String get kidMealNoneDinner => 'Heute Abend ist noch nichts geplant.';

  @override
  String get kidMealNoneLunch => 'Heute Mittag ist noch nichts geplant.';

  @override
  String get kidMealEatingYou => 'Du isst mit.';

  @override
  String get kidEventsTitle => 'Meine Termine heute';

  @override
  String get kidNoEvents => 'Heute keine Termine.';

  @override
  String get kidAllDay => 'ganztägig';

  @override
  String get kidTimetableTitle => 'Mein Stundenplan';

  @override
  String get kidTodayMarker => 'Heute';

  @override
  String get kidYourPoints => 'Deine Punkte';

  @override
  String get kidRewardsTitle => 'Belohnungen';

  @override
  String get kidRedeem => 'Einlösen';

  @override
  String kidNeedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Punkte',
      one: 'Noch 1 Punkt',
    );
    return '$_temp0';
  }

  @override
  String get kidWaitsApproval => 'wartet auf Freigabe';

  @override
  String get kidRequestSent => 'Deine Belohnung wartet auf Freigabe.';

  @override
  String get kidRedeemed => 'Eingelöst! 🎉';

  @override
  String get kidSoldOut => 'Gerade ausverkauft';

  @override
  String get kidBadgesTitle => 'Meine Abzeichen';

  @override
  String get kidStreaksTitle => 'Meine Serien';

  @override
  String kidStreak(int days, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage $title 🔥',
      one: '1 Tag $title 🔥',
    );
    return '$_temp0';
  }

  @override
  String get kidFamilyTitle => 'Familie heute';

  @override
  String kidOpenTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben offen',
      one: '1 Aufgabe offen',
      zero: 'Keine Aufgaben offen',
    );
    return '$_temp0';
  }

  @override
  String get kidNoPlanToday => 'Heute nichts Besonderes';

  @override
  String get schoolsUiAddSchool => 'Weitere Schule';

  @override
  String get schoolsUiNewSchool => 'Neue Schule';

  @override
  String get schoolsUiPickSchool => 'Schule wählen';

  @override
  String get schoolsUiAskSchool => 'Welche Schule?';

  @override
  String schoolsUiSchoolOf(String name) {
    return 'Schule: $name';
  }

  @override
  String get schoolsUiDayMenu => 'Tagesaktionen';

  @override
  String get schoolsUiCopyDay => 'Tag kopieren nach…';

  @override
  String schoolsUiCopyDayTitle(String day) {
    return '$day kopieren nach';
  }

  @override
  String get schoolsUiCopyDayApply => 'Kopieren';

  @override
  String get schoolsUiSwapDay => 'Tag tauschen mit…';

  @override
  String schoolsUiSwapDayTitle(String day) {
    return '$day tauschen mit';
  }

  @override
  String get schoolsUiDayCleared => 'Tag geleert';

  @override
  String get schoolsUiDayCopied => 'Tag kopiert';

  @override
  String get schoolsUiDaySwapped => 'Tage getauscht';

  @override
  String get schoolsUiUndo => 'Rückgängig';

  @override
  String get mealsUxSuggestOften => 'Oft bei uns';

  @override
  String get mealsUxSuggestRare => 'Lange nicht gegessen';

  @override
  String mealsUxClearedSnack(String title) {
    return '„$title“ entfernt';
  }

  @override
  String get mealsUxUndo => 'Rückgängig';

  @override
  String get mealsUxFromMealPlan => 'Kommt aus dem Essensplan';

  @override
  String mealsUxForMeal(String meal, String day) {
    return 'Für: $meal · $day';
  }

  @override
  String get todayTitle => 'Heute';

  @override
  String get todayEmpty => 'Heute ist noch nichts geplant. Genieß die Ruhe.';

  @override
  String get todayAgendaTitle => 'Termine';

  @override
  String get todayAllDay => 'ganztägig';

  @override
  String get todayTasksTitle => 'Deine Aufgaben heute';

  @override
  String get todayMealTitle => 'Warmes Essen';

  @override
  String todayMealLine(String slot, String dish) {
    return '$slot: $dish';
  }

  @override
  String get todayShoppingTitle => 'Einkaufsliste';

  @override
  String todayShoppingOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel offen',
      one: '1 Artikel offen',
    );
    return '$_temp0';
  }

  @override
  String get todayStartTitle => 'Erste Schritte';

  @override
  String todayStartProgress(int done, int total) {
    return '$done von $total';
  }

  @override
  String get todayStartNotNeeded => 'Brauchen wir nicht';

  @override
  String get todayStartInvitePartner => 'Partner:in einladen';

  @override
  String get todayStartConnectTablet => 'Familien-Tablet verbinden';

  @override
  String get todayStartWallDisplay => 'Wandanzeige einrichten';

  @override
  String get todayStartSetPin => 'Deine PIN festlegen';

  @override
  String get todayStartSubscribeFeed => 'Kalender abonnieren';

  @override
  String get todayStartSchool => 'Stundenplan eintragen';

  @override
  String get settingsGettingStarted => 'Erste Schritte';

  @override
  String get settingsGettingStartedSubtitle =>
      'Die Einrichtungskarte wieder auf dem Heute-Tab zeigen';

  @override
  String get exportFamilyTitle => 'Familie';

  @override
  String get exportAction => 'Daten exportieren';

  @override
  String get exportExplanation =>
      'Alle Daten eurer Familie als Datei, z. B. für einen Umzug auf einen anderen Server.';

  @override
  String get exportInProgress => 'Daten werden exportiert';

  @override
  String get exportPersonalDeviceRequired =>
      'Der Export geht nur vom eigenen Telefon aus.';

  @override
  String boardHolidayLabel(String name) {
    return 'Feiertag · $name';
  }

  @override
  String get regionSettingTitle => 'Region';

  @override
  String get regionSettingHelp =>
      'Bestimmt, welche Feiertage gelten und welche Schulferien du übernehmen kannst. Wähle Kanton, Bundesland oder Gemeinde.';

  @override
  String get regionFieldLabel => 'Region';

  @override
  String get regionFieldEmpty => 'Keine Region gewählt';

  @override
  String get regionFieldClear => 'Region entfernen';

  @override
  String get regionCountryDE => 'Deutschland';

  @override
  String get regionCountryAT => 'Österreich';

  @override
  String get regionCountryCH => 'Schweiz';

  @override
  String get regionCountryLI => 'Liechtenstein';

  @override
  String get regionCountryOther => 'Anderes Land (ohne Region)';

  @override
  String get regionPickCountryTitle => 'Land';

  @override
  String get regionPickRegionTitle => 'Kanton oder Bundesland';

  @override
  String get regionPickSearch => 'Suchen';

  @override
  String regionPickWholeRegion(String name) {
    return 'Ganze Region: $name';
  }

  @override
  String get regionPickDeeperTitle => 'Genauer wählen (Bezirk/Gemeinde)';

  @override
  String get regionPickDeeperSearch => 'Gemeinde oder Bezirk eingeben';

  @override
  String get regionPickNoMatch => 'Nichts gefunden';

  @override
  String get regionPickLoading => 'Regionen werden geladen…';

  @override
  String get regionPickRetry => 'Erneut versuchen';

  @override
  String get regionPickSkip => 'Ohne Region weiter';

  @override
  String get regionPickEmpty => 'Keine Regionen für dieses Land gefunden.';

  @override
  String get regionUnavailable =>
      'Die Regionsliste ist gerade nicht verfügbar. Prüfe die Verbindung und versuche es erneut.';

  @override
  String regionNameTop(String category, String name) {
    return '$category $name';
  }

  @override
  String regionNameDeeper(String name, String category, String parent) {
    return '$name ($category), $parent';
  }

  @override
  String get regionImportAction => 'Ferien übernehmen';

  @override
  String get regionImportNeedsRegion =>
      'Wähle zuerst eine Region für die Schule.';

  @override
  String get regionImportTitle => 'Schulferien';

  @override
  String get regionImportIntro =>
      'Feiertage der Region gelten automatisch. Hier übernimmst du die Schulferien.';

  @override
  String get regionImportSwissHint =>
      'In der Schweiz können die Schulferien je Gemeinde abweichen. Bitte die Daten prüfen.';

  @override
  String get regionImportNone =>
      'Keine Schulferien in den nächsten 18 Monaten gefunden.';

  @override
  String get regionImportAlready => 'schon übernommen';

  @override
  String get regionImportOverlaps =>
      'überschneidet sich mit einem eigenen Eintrag';

  @override
  String get regionImportButton => 'Übernehmen';

  @override
  String regionImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ferien übernommen',
      one: '1 Ferien übernommen',
      zero: 'Keine Ferien übernommen',
    );
    return '$_temp0';
  }

  @override
  String get regionImportAttribution => 'Daten: OpenHolidays API · ODbL';

  @override
  String get regionImported => 'importiert';

  @override
  String get extCalTitle => 'Abonnierte Kalender';

  @override
  String get extCalSettingsSubtitle =>
      'Termine aus Vereins- und Abfallkalendern';

  @override
  String get extCalEmpty =>
      'Noch kein Kalender abonniert. Ein Abo bringt Termine von außen in den Familienkalender, zum Beispiel den Spielplan deines Vereins.';

  @override
  String get extCalNew => 'Kalender abonnieren';

  @override
  String get extCalNewTitle => 'Neuer Kalender';

  @override
  String get extCalEditTitle => 'Kalender bearbeiten';

  @override
  String get extCalEdit => 'Bearbeiten';

  @override
  String get extCalNameLabel => 'Name';

  @override
  String get extCalNameHint => 'z. B. FC Spielplan';

  @override
  String get extCalNameRequired => 'Gib dem Kalender einen Namen.';

  @override
  String get extCalUrlLabel => 'Adresse (ICS)';

  @override
  String get extCalUrlHelp =>
      'Die Adresse, unter der der Kalender veröffentlicht ist, meist mit .ics am Ende. Beispiele: Abfallkalender deiner Gemeinde, Spielplan des Vereins. webcal://-Adressen gehen auch.';

  @override
  String get extCalUrlInvalid =>
      'Das sieht nicht nach einer Internet-Adresse aus (https://…).';

  @override
  String get extCalColourLabel => 'Farbe';

  @override
  String extCalColourOption(int number) {
    return 'Farbe $number';
  }

  @override
  String get extCalMembersLabel => 'Für wen?';

  @override
  String get extCalMembersHelp =>
      'Ohne Auswahl gilt der Kalender für die ganze Familie.';

  @override
  String get extCalMembersWhole => 'Ganze Familie';

  @override
  String get extCalShowOnBoard => 'Auf dem Küchendisplay zeigen';

  @override
  String get extCalShowOnBoardHelp =>
      'Seine Termine erscheinen als wichtige Termine in der Wochenansicht des Küchendisplays.';

  @override
  String extCalDeleteConfirm(String name) {
    return '„$name“ und alle seine Termine werden entfernt.';
  }

  @override
  String get extCalDeleted => 'Kalender entfernt.';

  @override
  String get extCalRefreshNow => 'Jetzt aktualisieren';

  @override
  String extCalRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine geladen',
      one: '1 Termin geladen',
      zero: 'Keine Termine gefunden',
    );
    return '$_temp0';
  }

  @override
  String get extCalNotModified => 'Keine Änderungen seit dem letzten Abruf.';

  @override
  String get extCalRecent =>
      'Gerade eben abgerufen. Versuch es in ein paar Minuten nochmal.';

  @override
  String extCalRefreshFailed(String reason) {
    return 'Der Kalender konnte nicht geladen werden: $reason';
  }

  @override
  String get extCalStatusPaused => 'Pausiert';

  @override
  String get extCalStatusNever => 'Wird zum ersten Mal geladen …';

  @override
  String extCalStatusUpdated(String when) {
    return 'Aktualisiert $when';
  }

  @override
  String get extCalReadOnlyHint =>
      'Nur Eltern können Kalender abonnieren oder ändern.';

  @override
  String get extCalErrUnreachable => 'Die Adresse ist gerade nicht erreichbar.';

  @override
  String get extCalErrTimeout => 'Die Adresse antwortet zu langsam.';

  @override
  String get extCalErrForbiddenHost => 'Diese Adresse ist nicht erlaubt.';

  @override
  String get extCalErrTooLarge => 'Der Kalender ist zu groß (mehr als 2 MB).';

  @override
  String get extCalErrNotIcs => 'Das ist kein Kalender (ICS).';

  @override
  String get extCalErrHttp404 => 'Adresse nicht gefunden (404).';

  @override
  String extCalErrHttp(int status) {
    return 'Die Adresse antwortet mit Fehler $status.';
  }

  @override
  String get extCalErrInternal =>
      'Auf dem Server ist etwas schiefgegangen. Versuch es später nochmal.';

  @override
  String get extCalErrDb => 'Die Termine konnten nicht gespeichert werden.';

  @override
  String get extCalErrUnknown => 'Der Abruf hat nicht geklappt.';

  @override
  String get extCalErrInvalid =>
      'Der Kalender passt so nicht: Prüfe Name und Farbe.';

  @override
  String get extCalErrUrlInvalid =>
      'Diese Adresse kann nicht gespeichert werden. Sie muss mit https:// beginnen.';

  @override
  String get extCalErrNotFound => 'Diesen Kalender gibt es nicht mehr.';

  @override
  String get extCalImportedNote =>
      'Abonnierter Kalender — Änderungen kommen von der Quelle';

  @override
  String extCalFromCalendar(String name) {
    return 'Aus $name';
  }

  @override
  String get extCalAllDay => 'Ganztägig';

  @override
  String get extCalSheetTitle => 'Termin aus einem Abo';

  @override
  String get extCalSettingsRefreshHint =>
      'Der Server ruft jeden Kalender etwa einmal pro Stunde ab.';

  @override
  String get extCalActive => 'Aktiv';

  @override
  String get extCalUrlLoading => 'Adresse wird geladen';

  @override
  String get shoppingNavLabel => 'Einkauf';

  @override
  String get scanHint => 'Halte die Kamera auf den QR-Code am anderen Gerät.';

  @override
  String get scanCameraDenied =>
      'WuselWall hat keinen Kamerazugriff und kann den Code deshalb nicht scannen. Erlaube die Kamera in den Systemeinstellungen oder gib den Code ein.';

  @override
  String get scanCameraUnavailable =>
      'Auf diesem Gerät gibt es keine Kamera, die WuselWall nutzen kann. Gib den Code stattdessen ein.';

  @override
  String get scanWebUnsupported =>
      'Dieser Browser kann keine QR-Codes scannen. Gib den Code stattdessen ein.';

  @override
  String get scanTypeCode => 'Code eintippen';

  @override
  String get feedSubTitle => 'Abonnierte Kalender einschließen';

  @override
  String get feedSubHelp =>
      'Termine aus importierten Kalendern (z. B. Verein, Müllabfuhr) erscheinen auch im Abo.';

  @override
  String get feedSubSummary => 'Abonnierte Kalender';

  @override
  String get boardAllEvents => 'Alle Termine';

  @override
  String get reminderChannelName => 'Erinnerungen';

  @override
  String get reminderStartLabel => 'Erinnerungen einschalten';

  @override
  String reminderMorningEventsAndTasks(int events, int tasks) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events Termine',
      one: '1 Termin',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks Aufgaben',
      one: '1 Aufgabe',
    );
    return 'Heute: $_temp0, $_temp1';
  }

  @override
  String reminderMorningEventsOnly(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events Termine',
      one: '1 Termin',
    );
    return 'Heute: $_temp0';
  }

  @override
  String reminderMorningTasksOnly(int tasks) {
    String _temp0 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks Aufgaben',
      one: '1 Aufgabe',
    );
    return 'Heute: $_temp0';
  }

  @override
  String get reminderMorningNoEvents => 'Heute steht kein Termin an.';

  @override
  String reminderMorningFirst(String time, String title) {
    return 'Als Erstes um $time: $title';
  }

  @override
  String reminderMorningAllDay(String title) {
    return 'Ganztägig: $title';
  }

  @override
  String reminderEventBody(String time) {
    return 'Beginnt um $time';
  }

  @override
  String get reminderSettingsTitle => 'Erinnerungen';

  @override
  String get reminderSettingsSubtitle => 'Auf diesem Telefon';

  @override
  String get reminderSettingsSection => 'Woran du erinnert werden willst';

  @override
  String get reminderStatusOn =>
      'Erinnerungen sind auf diesem Telefon eingeschaltet.';

  @override
  String get reminderStatusOff => 'Erinnerungen sind auf diesem Telefon aus.';

  @override
  String get reminderStatusUnavailable =>
      'Auf diesem Gerät gibt es keine Erinnerungen.';

  @override
  String get reminderEnableAction => 'Erinnerungen einschalten';

  @override
  String get reminderDeniedNote =>
      'Ohne Erlaubnis gibt es keine Erinnerungen. Die Erlaubnis kannst du in den Systemeinstellungen ändern.';

  @override
  String get reminderLocalNote =>
      'Erinnerungen entstehen auf diesem Telefon. Nichts davon wird an einen Server oder an Dritte geschickt.';

  @override
  String get reminderOnlyPersonal =>
      'Erinnerungen gibt es nur auf dem persönlichen Gerät eines Familienmitglieds.';

  @override
  String get pairFrontDoorAction =>
      'Familien-Tablet oder Wanddisplay verbinden';

  @override
  String get pairTitle => 'Familien-Tablet oder Wanddisplay verbinden';

  @override
  String get pairScanHint =>
      'Öffne WuselWall auf deinem Handy und scanne diesen Code.';

  @override
  String get pairCodeHint =>
      'Oder auf dem Handy: Einstellungen → Geräte → Gerät verbinden, dann den Code eintippen.';

  @override
  String get pairQrLabel => 'QR-Code zum Verbinden dieses Geräts';

  @override
  String get pairWaiting => 'Warte auf die Bestätigung …';

  @override
  String pairConnected(String household) {
    return 'Verbunden mit $household';
  }

  @override
  String get pairOldCodeLink =>
      'Ich habe einen Code vom Handy (ältere Version)';

  @override
  String get pairConnectAction => 'Gerät verbinden';

  @override
  String get pairOldCodeAction => 'Code für ein älteres Gerät erzeugen';

  @override
  String get pairEntryBody =>
      'Scanne den Code, den das neue Gerät zeigt, oder tippe ihn ab.';

  @override
  String get pairCodeField => 'Code vom neuen Gerät';

  @override
  String get pairNext => 'Weiter';

  @override
  String get pairReviewBody =>
      'Das ist der Code des Geräts, das verbunden werden soll.';

  @override
  String get pairConfirmHint =>
      'Nur bestätigen, wenn du dieses Gerät vor dir siehst.';

  @override
  String get pairKindLabel => 'Was ist das für ein Gerät?';

  @override
  String get pairKindWall => 'Wanddisplay';

  @override
  String get pairKindKid => 'Kinder-Tablet';

  @override
  String get pairKindFamily => 'Tablet für alle';

  @override
  String get pairKindChild => 'Handy eines Kindes';

  @override
  String get pairChildLabel => 'Welches Kind?';

  @override
  String get pairNameLabel => 'Name des Geräts';

  @override
  String get pairDefaultWall => 'Wanddisplay';

  @override
  String get pairDefaultKid => 'Kinder-Tablet';

  @override
  String get pairDefaultFamily => 'Tablet';

  @override
  String pairDefaultChild(String name) {
    return 'Handy von $name';
  }

  @override
  String get pairApproveAction => 'Verbinden';

  @override
  String get pairApproved => 'Gerät verbunden';

  @override
  String get pairOnlyOnPersonal => 'Das geht nur auf deinem eigenen Handy.';

  @override
  String get pairPinTitle => 'Eltern-PIN festlegen';

  @override
  String get pairPinBody =>
      'Die PIN bestätigt Änderungen auf gemeinsam genutzten Geräten. Lege sie einmal fest.';

  @override
  String get pairPinConfirm => 'PIN noch einmal eingeben';

  @override
  String get pairPinMismatch =>
      'Die PINs stimmen nicht überein. Versuch es noch einmal.';

  @override
  String get firstRunKioskTitle => 'Wanddisplay einrichten';

  @override
  String get firstRunKioskBody =>
      'Drei Schritte, einmal auf diesem Gerät. Danach zeigt es die Woche.';

  @override
  String get firstRunPinTitle => 'App festhalten';

  @override
  String get firstRunPinIos =>
      'Einstellungen → Bedienungshilfen → Geführter Zugriff einschalten. WuselWall öffnen und die obere Taste dreimal schnell drücken.';

  @override
  String get firstRunPinAndroid =>
      'Einstellungen → Sicherheit → App-Anheftung einschalten (je nach Gerät auch „Bildschirm anpinnen“). WuselWall öffnen, die Übersicht aufrufen und die Nadel antippen.';

  @override
  String get firstRunAwakeTitle => 'Bildschirm anlassen';

  @override
  String get firstRunAwakeIos =>
      'Einstellungen → Anzeige & Helligkeit → Automatische Sperre → Nie.';

  @override
  String get firstRunAwakeAndroid =>
      'Einstellungen → Anzeige → Bildschirm-Timeout auf das Maximum stellen.';

  @override
  String get firstRunPowerTitle => 'Am Strom lassen';

  @override
  String get firstRunPowerBody =>
      'Dauerhaft ans Stromnetz hängen, damit es nach einem Stromausfall wieder bereit ist.';

  @override
  String get firstRunDone => 'Fertig';

  @override
  String get firstRunKidTitle => 'Willkommen';

  @override
  String get firstRunKidBody =>
      'Tipp auf dein Bild, dann weiß WuselWall, wer du bist.';

  @override
  String get firstRunKidStart => 'Los geht’s';

  @override
  String get householdNewTitle => 'Neue Familie';

  @override
  String get householdNewFamilyName => 'Familienname';

  @override
  String get householdNewYourName => 'Dein Name';

  @override
  String get householdNewColour => 'Deine Farbe';

  @override
  String householdNewColourOption(String number) {
    return 'Farbe $number';
  }

  @override
  String householdNewFamilyPrefill(String name) {
    return 'Familie $name';
  }

  @override
  String householdNewDefaults(String timezone, String language) {
    return 'Zeitzone $timezone · Sprache $language — von deinem Gerät';
  }

  @override
  String get householdLanguageDe => 'Deutsch';

  @override
  String get householdLanguageEn => 'Englisch';

  @override
  String get householdNewFounderCode => 'Gründungscode';

  @override
  String get householdNewFounderHelp =>
      'Den Gründungscode bekommst du von der Person, die deinen Server betreibt.';

  @override
  String get householdSeedExamples =>
      'Mit Beispielen starten — 5 Aufgaben, 3 Belohnungen';

  @override
  String get householdNewCreate => 'Familie anlegen';

  @override
  String get householdNewInvited => 'Ich wurde eingeladen';

  @override
  String get householdInvitedNote =>
      'Einladungen kommen mit dem nächsten Update.';

  @override
  String get householdNewSignOut => 'Abmelden';

  @override
  String get householdNewErrNoCode =>
      'Neue Familien gibt es gerade nur mit Gründungscode.';

  @override
  String get householdNewErrCodeWrong => 'Der Gründungscode stimmt nicht.';

  @override
  String get householdNewErrRateLimited =>
      'Zu viele Versuche. Warte ein paar Minuten und probier es dann nochmal.';

  @override
  String get householdMembersTitle => 'Wer gehört noch zu euch?';

  @override
  String householdMembersYou(String name) {
    return '$name (du)';
  }

  @override
  String get householdKindChild => 'Kind';

  @override
  String get householdKindAdult => 'Erwachsen';

  @override
  String get householdMembersName => 'Name';

  @override
  String get householdMembersAdd => 'Person hinzufügen';

  @override
  String get householdMembersRemove => 'Entfernen';

  @override
  String get householdMembersDone => 'Fertig';

  @override
  String get householdMembersSkip => 'Überspringen';

  @override
  String get householdMembersHelp => 'Einladen kannst du Erwachsene später.';

  @override
  String householdDeviceLabel(String owner, String device) {
    return '$owner $device';
  }

  @override
  String get householdDeviceIphone => 'iPhone';

  @override
  String get householdDeviceAndroid => 'Android-Handy';

  @override
  String get householdDeviceBrowser => 'Browser';

  @override
  String get householdDeviceComputer => 'Computer';

  @override
  String get emailContinue => 'Weiter';

  @override
  String get emailHavePassword => 'Ich habe ein Passwort';

  @override
  String get emailWrongCredentials => 'E-Mail oder Passwort stimmt nicht.';

  @override
  String get emailUseCodeInstead => 'Stattdessen Code per E-Mail';

  @override
  String get emailOffline =>
      'Keine Verbindung – die Anmeldung per E-Mail braucht eine Verbindung.';

  @override
  String get emailCodeTitle => 'Code aus der E-Mail';

  @override
  String emailCodeSent(String email) {
    return 'Wir haben einen 6-stelligen Code an $email geschickt. Er ist 10 Minuten gültig.';
  }

  @override
  String get emailCodeFieldLabel => 'Sechsstelliger Code';

  @override
  String get emailCodeWrong =>
      'Der Code stimmt nicht oder ist abgelaufen. Probier es noch einmal oder fordere einen neuen an.';

  @override
  String emailCodeResendIn(int seconds) {
    return 'Kein Code? Erneut senden (in $seconds s)';
  }

  @override
  String get emailCodeResend => 'Kein Code? Erneut senden';

  @override
  String get emailCodeSpam => 'Schau im Spam-Ordner nach.';

  @override
  String get emailCodeResent => 'Ein neuer Code ist unterwegs.';

  @override
  String get emailCodeOtherMethod => 'Andere Methode wählen';

  @override
  String get emailCodeOtherAddress => 'Andere E-Mail-Adresse';

  @override
  String get signInMethodTitle => 'Wie möchtest du dich künftig anmelden?';

  @override
  String get signInMethodCode => 'Mit Code per E-Mail — nichts zu merken';

  @override
  String get signInMethodPassword => 'Mit Passwort';

  @override
  String get passwordStrengthShort => 'Noch zu kurz';

  @override
  String get passwordStrengthWeak => 'Schwach';

  @override
  String get passwordStrengthFair => 'Mittel';

  @override
  String get passwordStrengthStrong => 'Stark';

  @override
  String get settingsPasswordTitle => 'Passwort';

  @override
  String get settingsPasswordSet =>
      'Festgelegt. Du kannst dich auch mit E-Mail und Passwort anmelden.';

  @override
  String get settingsPasswordNotSet =>
      'Nicht festgelegt. Anmelden geht weiterhin mit einem Code per E-Mail.';

  @override
  String get passwordSetAction => 'Passwort festlegen';

  @override
  String get passwordChangeAction => 'Passwort ändern';

  @override
  String get passwordSaved => 'Dein Passwort ist gespeichert.';

  @override
  String get passwordDialogBody =>
      'Mindestens 10 Zeichen. Der Code per E-Mail bleibt immer möglich.';

  @override
  String signInMethodEmailSubtitle(String email) {
    return '$email — immer verfügbar';
  }

  @override
  String get signInMethodAlwaysAvailable => 'Immer verfügbar';
}
