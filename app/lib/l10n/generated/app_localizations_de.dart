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
  String get setupOfflineWelcome =>
      'Du bist offline. Verbinde dich mit dem Internet, um dich anzumelden, eine Einladung anzunehmen oder ein gemeinsames Gerät zu verbinden. Danach sind diese Möglichkeiten wieder verfügbar.';

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
  String get errSetupTokenInvalid => 'Der Einrichtungsschlüssel ist ungültig.';

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
  String get errGuardianRequired => 'Das darf nur ein Elternteil.';

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
  String get timeWheelTitle => 'Uhrzeit';

  @override
  String get timeWheelHour => 'Stunde';

  @override
  String get timeWheelMinute => 'Minute';

  @override
  String get timeWheelPeriod => 'Vormittag oder Nachmittag';

  @override
  String get timeWheelExact => 'Jede Minute';

  @override
  String get timeWheelDone => 'Fertig';

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
  String get pinTitle => 'PIN für Eltern';

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
      'PIN gesperrt. Ein Elternteil muss sich zum Entsperren anmelden.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsMembers => 'Mitglieder';

  @override
  String get settingsDevices => 'Geräte';

  @override
  String get addMember => 'Mitglied hinzufügen';

  @override
  String get addMemberSubtitle => 'Ein Kind oder jemand ohne eigenes Konto';

  @override
  String get memberName => 'Name';

  @override
  String get roleGuardian => 'Elternteil';

  @override
  String get roleMember => 'Weitere:r Erwachsene:r';

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
  String get classShared => 'Geteilt';

  @override
  String get classSharedHint =>
      'Mehrere nutzen es: zum Wechseln den Namen antippen.';

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
  String get shoppingRemoveItem => 'Entfernen';

  @override
  String shoppingItemRemoved(String name) {
    return '$name entfernt';
  }

  @override
  String get shoppingUndo => 'Rückgängig';

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
  String get shoppingCat_snacks => 'Snacks';

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
  String get shoppingTileOnList => 'Schon auf der Liste';

  @override
  String shoppingAddedBy(String name) {
    return 'Hinzugefügt von $name';
  }

  @override
  String get pinChangeTitle => 'PIN für Eltern';

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
  String get doorEmail => 'Anmelden oder Konto erstellen';

  @override
  String get doorOr => 'oder';

  @override
  String get errSignupDisabled =>
      'Zu dieser Adresse gibt es noch kein WuselWall-Konto. Lass dich von deiner Familie einladen oder gründe eine neue Familie.';

  @override
  String get errEmailExists =>
      'Diese E-Mail-Adresse gehört schon zu einem anderen Konto.';

  @override
  String get signInMethodsTitle => 'Anmeldung';

  @override
  String get signInMethodEmail => 'E-Mail-Code';

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
  String get boardZoneMeal => 'Warmes Essen';

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
  String get boardSchoolOff => 'schulfrei';

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
  String get boardShoppingAskAdult =>
      'Die Einkaufsliste ist für die Großen. Tipp auf deinen Namen.';

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
  String get boardTasksComingSoon => 'Aufgaben werden hier nicht angezeigt.';

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
      'Eine neue Aufgabe ist eine Pflicht, bis jemand sie bewusst zum Bonus macht.';

  @override
  String get settingTasksVerificationTitle => 'Eltern prüfen Aufgaben';

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
      'Ein Elternteil gibt jede Einlösung mit der PIN frei. Selbst einlösen passt nur zu Kleinigkeiten.';

  @override
  String get settingCalendarMembersEditTitle => 'Kinder ändern eigene Termine';

  @override
  String get settingCalendarMembersEditHelp =>
      'Kinder legen Termine an und ändern sie, wenn sie selbst dabei sind. Fremde Termine löschen bleibt Sache der Eltern.';

  @override
  String get settingCalendarKeyDefaultTitle =>
      'Neue Termine auf der Küchenwand';

  @override
  String get settingCalendarKeyDefaultHelp =>
      'Legt fest, welche neuen Termine ohne Häkchen auf der Küchenwand erscheinen.';

  @override
  String get settingSchoolReportTitle => 'Kinder melden Plan-Änderungen';

  @override
  String get settingSchoolReportHelp =>
      'Nur Eltern pflegen den Stundenplan. Mit dieser Option kann ein Kind einen Entfall melden, den ein Elternteil bestätigt.';

  @override
  String get settingSchoolEquipmentTitle => 'Hinweis auf Sachen für morgen';

  @override
  String get settingSchoolEquipmentHelp =>
      'Zeigt aus dem Stundenplan von morgen, was mitgebracht werden muss, zum Beispiel Sportsachen.';

  @override
  String get settingMealsSchoolDayTitle => 'Warmes Essen an Schultagen';

  @override
  String get settingMealsSchoolDayHelp =>
      'Die warme Mahlzeit auf der Küchenwand. Beide an heißt zwei warme Mahlzeiten, beide aus keine. An Schultagen essen Kinder mittags oft in der Schule oder im Hort.';

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
      'Ab diesem Zeitpunkt zeigt die Wand die kommende Woche statt der aktuellen.';

  @override
  String get settingBoardDayPartsTitle => 'Vormittag, Nachmittag, Abend';

  @override
  String get settingBoardDayPartsHelp =>
      'Wo der Tag auf der Wand in Vormittag, Nachmittag und Abend geteilt wird.';

  @override
  String get settingDeviceNightHoursTitle => 'Zeiten des Nachtdesigns';

  @override
  String get settingDeviceNightHoursHelp =>
      'Wann das Gerät auf die Nachtfarben wechselt.';

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
      'Die heutigen Aufgaben und Termine für dich. Offene Einlösungen erscheinen hier für Eltern.';

  @override
  String get settingNotifyEventReminderTitle => 'Erinnerung vor Terminen';

  @override
  String get settingNotifyEventReminderHelp =>
      'Eine Benachrichtigung, bevor ein Termin beginnt. Hat ein Termin eine eigene Erinnerung, gilt diese.';

  @override
  String get settingNotifyTaskVerifiedTitle =>
      'Wenn eine Aufgabe bestätigt wird';

  @override
  String get settingNotifyTaskVerifiedHelp =>
      'Eine Benachrichtigung, wenn ein Elternteil eine Aufgabe bestätigt und die Punkte gutgeschrieben werden.';

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
  String get calendarChooseView => 'Kalenderansicht';

  @override
  String get calendarToday => 'Heute';

  @override
  String get calendarChildDays => 'Heute und die nächsten drei Tage';

  @override
  String calendarRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get calendarNewEvent => 'Neuer Termin';

  @override
  String get calendarEmpty => 'Nichts geplant';

  @override
  String get calendarEditorPlaceholder => 'Hier legst du Termine an.';

  @override
  String get eventEditTitle => 'Termin bearbeiten';

  @override
  String get eventTitleLabel => 'Titel';

  @override
  String get eventTitleRequired => 'Bitte einen Titel eingeben.';

  @override
  String get suggestFieldOptions => 'Vorschläge';

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
  String get eventReminder => 'Erinnerung vorher';

  @override
  String get eventReminderNone => 'Keine';

  @override
  String eventReminderMinutes(int count) {
    return '$count Minuten';
  }

  @override
  String eventReminderHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String eventReminderDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String eventReminderWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wochen',
      one: '1 Woche',
    );
    return '$_temp0';
  }

  @override
  String get eventReminderHelp =>
      'Alle, für die der Termin ist, bekommen sie auf dem eigenen Telefon, wenn dort Erinnerungen eingeschaltet sind.';

  @override
  String eventReminderAllDayHelp(String time) {
    return 'Ein ganztägiger Termin erinnert um $time. Alle, für die er ist, bekommen die Erinnerung auf dem eigenen Telefon, wenn dort Erinnerungen eingeschaltet sind.';
  }

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
  String get eventKeyDisplayOn =>
      'Dieser Termin erscheint auf dem Küchendisplay.';

  @override
  String get eventKeyDisplayOff =>
      'Dieser Termin erscheint nicht auf dem Küchendisplay.';

  @override
  String get eventKeyDisplayOffWholeFamily =>
      'Erscheint nicht auf dem Küchendisplay. Termine der ganzen Familie erscheinen dort von selbst.';

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
  String get eventShare => 'Termin teilen';

  @override
  String get eventShareHelp =>
      'Erstellt eine Kalenderdatei und gibt sie an eine App auf diesem Gerät weiter, zum Beispiel an den Messenger oder das Mailprogramm. Die anderen öffnen sie in ihrem eigenen Kalender.';

  @override
  String get eventShareSent => 'Das wird gesendet';

  @override
  String get eventShareNotSent =>
      'Nicht gesendet: wer teilnimmt, der Name eurer Familie und alles andere aus eurem Kalender.';

  @override
  String get eventShareIncludeNote => 'Notizen mitsenden';

  @override
  String get eventShareReminder => 'Erinnerung für die Empfänger';

  @override
  String get eventShareReminderHelp =>
      'Ihre Kalender-App zeigt sie an. Manche Apps fragen vorher oder lassen sie weg.';

  @override
  String get eventShareReminderNone => 'Keine';

  @override
  String get eventShareReminderHour => '1 Stunde vorher';

  @override
  String get eventShareReminderDay => 'Am Tag davor';

  @override
  String get eventShareSeriesNote =>
      'Einzeln verschobene Termine der Serie werden mit ihrer üblichen Zeit gesendet.';

  @override
  String get eventShareSend => 'Teilen';

  @override
  String get eventImportTile => 'Aus einer Datei';

  @override
  String get eventImportTileHelp =>
      'Eine Kalenderdatei (.ics), die euch jemand geschickt hat';

  @override
  String get eventImportTitle => 'Termin übernehmen';

  @override
  String get eventImportIntro =>
      'Jemand hat euch diesen Termin geschickt. Schau ihn an und übernimm ihn dann in euren Familienkalender. Er wird eure eigene Kopie.';

  @override
  String get eventImportAdd => 'In den Kalender übernehmen';

  @override
  String get eventImportUpdate => 'Termin aktualisieren';

  @override
  String get eventImportExisting =>
      'Diesen Termin habt ihr schon übernommen. Die Datei ersetzt Titel, Zeit, Ort und Notizen.';

  @override
  String get eventImportOwn =>
      'Dieser Termin steht schon in eurem Kalender: Es ist euer eigener.';

  @override
  String get eventImportOpen => 'Termin öffnen';

  @override
  String get eventImportRepeats => 'Wiederholt sich';

  @override
  String get eventImportRepeatDropped =>
      'Die Datei wiederholt sich auf eine Art, die WuselWall nicht speichern kann. Nur der erste Termin wird übernommen.';

  @override
  String get eventImportAdded => 'In den Kalender übernommen.';

  @override
  String get eventImportUpdated => 'Termin aktualisiert.';

  @override
  String get eventImportTooLarge =>
      'Diese Datei ist zu groß für einen einzelnen Termin.';

  @override
  String get eventImportNotAnEvent =>
      'In dieser Datei steht kein Termin, der sich lesen lässt.';

  @override
  String get eventImportSeveral =>
      'In dieser Datei stehen mehrere Termine. Hier lässt sich nur eine Datei mit einem Termin übernehmen.';

  @override
  String get eventImportCancelled => 'Der Absender hat diesen Termin abgesagt.';

  @override
  String get eventImportParentsOnly =>
      'Einen Termin aus einer Datei können nur Eltern übernehmen, auf ihrem eigenen Gerät.';

  @override
  String get eventImportUnreadable => 'Die Datei ließ sich nicht öffnen.';

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
  String get comingSoon => 'Diese Seite ist nicht verfügbar.';

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
      'Lege die Schule an. Klingelzeiten und Fächer werden vorgeschlagen; den Stundenplan trägst du danach ein oder liest ihn ein.';

  @override
  String get schoolSetupAction => 'Schule einrichten';

  @override
  String get schoolEnterTimetableTitle => 'Stundenplan eingeben';

  @override
  String schoolEnterTimetableBody(String name) {
    return 'Für $name ist für die angezeigte Woche noch kein Stundenplan eingetragen.';
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
  String get schoolTermEdit => 'Zeitraum bearbeiten';

  @override
  String get schoolTermNew => 'Neuer Zeitraum';

  @override
  String get schoolTermName => 'Name';

  @override
  String get schoolTermNameHint => 'z. B. Schuljahr 2026/27 oder 1. Halbjahr';

  @override
  String get schoolFrom => 'Von';

  @override
  String get schoolTo => 'Bis';

  @override
  String get schoolTermPickDate => 'Datum wählen';

  @override
  String get schoolTermEndBeforeStart => 'Endet vor dem Anfang';

  @override
  String schoolTermMustCoverWeek(String week) {
    return 'Muss die angezeigte Woche ($week) enthalten';
  }

  @override
  String get schoolAbWeeks => 'A- und B-Wochen';

  @override
  String get schoolAbWeeksHint =>
      'Einschalten, wenn sich der Stundenplan wöchentlich abwechselt.';

  @override
  String get schoolAbWeek => 'Kalenderwoche einer A-Woche';

  @override
  String get schoolAbWeekHint =>
      'Wochennummer, zum Beispiel 43. Danach wechseln sich B, A, B … ab.';

  @override
  String schoolAbWeekShown(int week) {
    return 'Die angezeigte Woche ist Kalenderwoche $week.';
  }

  @override
  String get schoolAbWeekInvalid => 'Wochennummer von 1 bis 53 eingeben';

  @override
  String get schoolCurrent => 'aktuell';

  @override
  String get schoolCurrentTerm => 'Aktueller Zeitraum';

  @override
  String get schoolCurrentTermHint =>
      'Markiert den Zeitraum, in dem ihr gerade seid. Nur einer pro Schule.';

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
  String get feedTitle => 'Familienkalender teilen';

  @override
  String get feedSettingsSubtitle =>
      'Nur zum Lesen, in Outlook oder auf dem iPhone';

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
  String get baselineTitle => 'Übliche Woche';

  @override
  String get baselineSettingsSubtitle =>
      'Wo alle an welchem Tag normalerweise sind';

  @override
  String get baselineHelp =>
      'Wo du an jedem Wochentag normalerweise bist. Nur Abweichungen trägst du ein, eine normale Woche bleibt leer.';

  @override
  String get baselineNone => 'Nichts eingetragen';

  @override
  String get baselineLabelField => 'Eigene Bezeichnung (optional)';

  @override
  String get baselineLabelHint => 'z. B. zu Hause';

  @override
  String get baselineSaved => 'Gespeichert.';

  @override
  String get usualCopyMonday => 'Dienstag bis Freitag wie Montag';

  @override
  String usualDayTitle(String name, String weekday) {
    return '$name am $weekday';
  }

  @override
  String get usualDayApply => 'Übernehmen';

  @override
  String get usualWholeDay => 'Ganzer Tag';

  @override
  String get usualSlots => 'Zeitfenster';

  @override
  String get usualSlotState => 'Wo';

  @override
  String get usualSlotFrom => 'Von';

  @override
  String get usualSlotUntil => 'Bis';

  @override
  String get usualAddSlot => 'Zeitfenster hinzufügen';

  @override
  String get usualRemoveSlot => 'Zeitfenster entfernen';

  @override
  String get usualSlotsInvalid =>
      'Jedes Zeitfenster endet nach seinem Beginn, und Zeitfenster überschneiden sich nicht.';

  @override
  String get usualAlternating => 'Abwechselnde Wochen (A/B)';

  @override
  String get usualAlternatingHelp =>
      'Für einen Plan, der sich alle zwei Wochen wiederholt.';

  @override
  String get usualWeekA => 'Woche A';

  @override
  String get usualWeekB => 'Woche B';

  @override
  String usualThisWeekIs(String week) {
    return 'Diese Woche ist $week.';
  }

  @override
  String get usualWhichWeek => 'Welche Woche ist diese Woche?';

  @override
  String get errUsualWeekInvalid => 'Diese übliche Woche ist nicht gültig.';

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
  String tasksPointsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Punkte',
      one: 'Punkt',
    );
    return '$_temp0';
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
  String get taskIcon_dishes => 'Teller';

  @override
  String get taskIcon_table => 'Löffel';

  @override
  String get taskIcon_trash => 'Mülleimer';

  @override
  String get taskIcon_bed => 'Bett';

  @override
  String get taskIcon_dog => 'Hund';

  @override
  String get taskIcon_plant => 'Pflanze';

  @override
  String get taskIcon_bike => 'Fahrrad';

  @override
  String get taskIcon_book => 'Bücher';

  @override
  String get taskIcon_laundry => 'Wäschekorb';

  @override
  String get taskIcon_teeth => 'Zahnbürste';

  @override
  String get taskIcon_shopping => 'Einkaufswagen';

  @override
  String get taskIcon_cooking => 'Pfanne';

  @override
  String get taskIcon_car => 'Auto';

  @override
  String get taskIcon_toys => 'Teddybär';

  @override
  String get taskIcon_star => 'Stern';

  @override
  String get taskIcon_cinema => 'Film';

  @override
  String get taskIcon_moon => 'Mond';

  @override
  String get taskIcon_trip => 'Kompass';

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
  String get tasksFieldVerification => 'Freigabe durch Eltern';

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
  String get kidSimpleBack => 'Zurück';

  @override
  String get kidSimpleTomorrow => 'Morgen';

  @override
  String get kidSimpleAppointments => 'Meine Termine';

  @override
  String get kidSimpleNoSchool => 'Keine Schule.';

  @override
  String kidSimpleNeeds(String items) {
    return 'Du brauchst: $items';
  }

  @override
  String get kidSimpleNothing => 'Noch ist nichts geplant.';

  @override
  String kidGreeting(String name) {
    return 'Hallo, $name!';
  }

  @override
  String get kidTasksTitle => 'Meine Aufgaben';

  @override
  String get kidTasksNone => 'Heute hast du keine Aufgaben.';

  @override
  String get kidTasksAllDone => 'Alles geschafft!';

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
  String kidSchoolNowSubject(String subject) {
    return 'Jetzt: $subject';
  }

  @override
  String kidSchoolChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Heute $count Änderungen',
      one: 'Heute 1 Änderung',
    );
    return '$_temp0';
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
  String get kidEventsTitle => 'Meine Termine heute';

  @override
  String get kidAllDay => 'ganztägig';

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
  String get kidRedeemed => 'Eingelöst!';

  @override
  String get kidSoldOut => 'Gerade ausverkauft';

  @override
  String get kidBadgesTitle => 'Meine Abzeichen';

  @override
  String get kidBadgeEarned => 'Verdient';

  @override
  String get kidBadgeNotYet => 'Noch nicht verdient';

  @override
  String get kidStreaksTitle => 'Meine Serien';

  @override
  String kidStreak(int days, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage $title',
      one: '1 Tag $title',
    );
    return '$_temp0';
  }

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
  String todayNoticeJoined(String name) {
    return '$name ist beigetreten';
  }

  @override
  String todayNoticeSignIn(String device) {
    return 'Neu angemeldet: $device';
  }

  @override
  String get todayNoticeDismiss => 'Gesehen';

  @override
  String todayNoticeShopping(String name, String list) {
    return '$name kauft gerade ein ($list). Brauchst du noch etwas?';
  }

  @override
  String get todayNoticeShoppingList => 'Zur Liste';

  @override
  String shoppingStartNotifyTitle(String name) {
    return '$name geht einkaufen';
  }

  @override
  String shoppingStartNotifyBody(String list) {
    return 'Brauchst du noch etwas? Setz es auf die Liste „$list“.';
  }

  @override
  String get shoppingStartTold =>
      'Die anderen Erwachsenen sehen, dass du einkaufst.';

  @override
  String get todayNoticeMembers => 'Mitglieder';

  @override
  String get todayNoticeDevices => 'Geräte';

  @override
  String get todayApprovalsTitle => 'Wartet auf deine Freigabe';

  @override
  String todayApprovalsChecks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben zu prüfen',
      one: '1 Aufgabe zu prüfen',
    );
    return '$_temp0';
  }

  @override
  String todayApprovalsRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Belohnungswünsche',
      one: '1 Belohnungswunsch',
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
  String get settingsLicenses => 'Open-Source-Lizenzen';

  @override
  String get settingsLicensesSubtitle =>
      'Die Lizenzen der Software und Schriften, aus denen WuselWall gebaut ist';

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
  String regionPickKindOf(String kind, String parent) {
    return '$kind · $parent';
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
  String get regionCategoryCanton => 'Kanton';

  @override
  String regionNameWithAbbreviation(String name, String abbreviation) {
    return '$name ($abbreviation)';
  }

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
  String get extCalTitle => 'Externe Kalender';

  @override
  String get extCalSettingsSubtitle =>
      'Spielplan, Abfuhrtermine und mehr im Familienkalender';

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
  String get scheduleNavLabel => 'Schule';

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
  String get feedSubTitle => 'Kalender von außen einschließen';

  @override
  String get feedSubHelp =>
      'Termine aus importierten Kalendern (z. B. Verein, Müllabfuhr) erscheinen auch im Abo.';

  @override
  String get feedSubSummary => 'Kalender von außen';

  @override
  String get boardAllEvents => 'Alle Termine';

  @override
  String get boardNextWeek => 'Nächste Woche';

  @override
  String get boardThisWeek => 'Diese Woche';

  @override
  String get boardNextWeekUnavailable =>
      'Die nächste Woche lässt sich gerade nicht laden';

  @override
  String boardMemberDay(String name, String date) {
    return '$name, $date';
  }

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
  String reminderMorningApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Freigaben warten',
      one: '1 Freigabe wartet',
    );
    return '$_temp0';
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
  String reminderEventBodyAhead(int days, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days Tagen um $time',
      one: 'Morgen um $time',
    );
    return '$_temp0';
  }

  @override
  String reminderEventBodyAheadAllDay(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days Tagen, ganztägig',
      one: 'Morgen, ganztägig',
    );
    return '$_temp0';
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
  String get pairTitle => 'Dieses Gerät verbinden';

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
  String get householdLanguageFr => 'Französisch';

  @override
  String get householdLanguageEs => 'Spanisch';

  @override
  String get householdNewFounderCode => 'Einrichtungsschlüssel';

  @override
  String get householdNewFounderHelp =>
      'Nimm den Einrichtungsschlüssel aus der Serverinstallation oder frage die Person, die euren Server betreibt. Das ist nicht der Code aus deiner Anmelde-E-Mail.';

  @override
  String get householdNewCodeSaved =>
      'Einrichtungsschlüssel aus deinem Einrichtungslink gespeichert. Du musst ihn nicht erneut eingeben.';

  @override
  String get householdSeedExamples =>
      'Mit Beispielen starten — 5 Aufgaben, 3 Belohnungen';

  @override
  String get householdNewCreate => 'Familie anlegen';

  @override
  String get householdNewCreating => 'Familie wird angelegt …';

  @override
  String get householdNewInvited => 'Ich wurde eingeladen';

  @override
  String get householdInvitedNote =>
      'Mit einem Einladungscode trittst du einer Familie bei.';

  @override
  String get householdNewSignOut => 'Abmelden';

  @override
  String get householdNewErrNoCode =>
      'Dieser Server braucht einen Einrichtungsschlüssel, um eine Familie anzulegen. Nimm den Schlüssel aus der Serverinstallation, nicht den E-Mail-Code.';

  @override
  String get householdNewErrCodeWrong =>
      'Dieser Einrichtungsschlüssel ist ungültig oder wurde schon verwendet. Bitte die Person, die euren Server betreibt, um einen neuen Einrichtungslink oder Schlüssel.';

  @override
  String get householdNewErrRateLimited =>
      'Zu viele Versuche. Warte ein paar Minuten und probier es dann nochmal.';

  @override
  String get householdNewStalled =>
      'Das dauert länger als üblich. Bitte warte kurz oder melde dich ab und wieder an. Die Familie bitte nicht noch einmal anlegen.';

  @override
  String get claimTitle => 'Server einrichten';

  @override
  String claimLead(String host) {
    return '$host hat noch keine Familie. Mit dem Einrichtungsschlüssel aus der Installation gründest du sie. Gib die E-Mail-Adresse ein, die das erste Elternkonto wird.';
  }

  @override
  String claimHeader(String host) {
    return '$host wird eingerichtet';
  }

  @override
  String get claimKeyLabel => 'Einrichtungsschlüssel';

  @override
  String get claimKeyHelp =>
      'Aus der Serverinstallation: der Einrichtungslink oder QR-Code enthält ihn. Sonst frage die Person, die euren Server betreibt.';

  @override
  String get claimChecking => 'Einrichtungsschlüssel wird geprüft …';

  @override
  String get claimKeyReady =>
      'Einrichtungsschlüssel angenommen. Der Server wartet auf seine Familie.';

  @override
  String get claimKeyUsed =>
      'Dieser Einrichtungsschlüssel wurde schon verwendet. Bitte die Person, die euren Server betreibt, um einen neuen – oder melde dich an, wenn es die Familie schon gibt.';

  @override
  String get claimKeyInvalid => 'Dieser Einrichtungsschlüssel ist ungültig.';

  @override
  String get claimNextCode =>
      'Danach: ein Code aus deiner E-Mail, dann eure Familie.';

  @override
  String get claimNextPassword =>
      'Danach: ein Passwort für dein Konto, dann eure Familie.';

  @override
  String get claimHaveAccount => 'Ich habe schon ein Konto';

  @override
  String get doorUnclaimedTitle => 'Dieser Server hat noch keine Familie';

  @override
  String get doorUnclaimedBody =>
      'Wer ihn installiert hat, hat den Einrichtungsschlüssel. Damit gründest du die Familie; alle anderen kommen danach per Einladung dazu.';

  @override
  String get doorUnclaimedAction => 'Ich habe den Einrichtungsschlüssel';

  @override
  String get errSetupKeyRequired =>
      'Dieser Server hat noch keine Familie. Nur mit dem Einrichtungsschlüssel aus der Installation entsteht das erste Konto.';

  @override
  String get setupPrivacy => 'Datenschutz';

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
  String get emailSendCode => 'Code senden';

  @override
  String get signInAccountTitle => 'Dein Konto';

  @override
  String get signInCodeLead =>
      'Wir schicken einen 6-stelligen Code an deine E-Mail-Adresse. Neu hier? Der Code erstellt dein Konto. Schon ein Konto? Der Code meldet dich an.';

  @override
  String get signInCodeLeadUnclaimed =>
      'Wir schicken einen 6-stelligen Code an deine E-Mail-Adresse, damit du dich anmelden kannst. Ein neues Konto braucht zuerst den Einrichtungsschlüssel.';

  @override
  String get signInPasswordLead =>
      'Für Konten, die schon ein Passwort haben. Noch kein Passwort oder vergessen? Nimm stattdessen einen Code per E-Mail.';

  @override
  String get passwordSignInLeadUnclaimed =>
      'Für Konten, die es schon gibt. Ein neues Konto braucht zuerst den Einrichtungsschlüssel.';

  @override
  String get signInMethodReady => 'Dein Konto ist bereit.';

  @override
  String get emailHavePassword => 'Mit Passwort anmelden';

  @override
  String get emailWrongCredentials => 'E-Mail oder Passwort stimmt nicht.';

  @override
  String get emailUseCodeInstead => 'Stattdessen Code per E-Mail';

  @override
  String get emailOffline =>
      'Keine Verbindung – die Anmeldung per E-Mail braucht eine Verbindung.';

  @override
  String get emailRequired => 'Gib deine E-Mail-Adresse ein.';

  @override
  String get emailInvalid => 'Gib eine gültige E-Mail-Adresse ein.';

  @override
  String get passwordRequired => 'Gib dein Passwort ein.';

  @override
  String get emailSendingCode => 'Code wird gesendet …';

  @override
  String get signInProgress => 'Anmeldung läuft …';

  @override
  String get emailCodeTitle => 'Code aus der E-Mail';

  @override
  String emailCodeSent(String email) {
    return 'Wir haben einen 6-stelligen Code an $email geschickt. Gib ihn innerhalb von 10 Minuten hier ein.';
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

  @override
  String get leaveLeaveTile => 'Familie verlassen';

  @override
  String get leaveLeaveExplain =>
      'Dein Konto verlässt die Familie. Deine Geräte melden sich ab. Die Einträge bleiben bei der Familie; du kannst danach eine andere Familie gründen oder ihr beitreten.';

  @override
  String get leaveLeaveBlocked =>
      'Lade zuerst einen weiteren Elternteil ein oder lösche die Familie.';

  @override
  String get leaveLeaveDialogTitle => 'Familie verlassen?';

  @override
  String get leaveLeaveDialogBody =>
      'Du verlierst den Zugang zu dieser Familie. Die Familie bleibt bestehen, und die anderen bleiben drin.';

  @override
  String get leaveLeaveConfirm => 'Verlassen';

  @override
  String get leaveCancel => 'Abbrechen';

  @override
  String get leaveDeleteTile => 'Familie löschen';

  @override
  String get leaveDeleteExplain =>
      'Die Familie wird mit allen Daten sofort und endgültig gelöscht. Alle Geräte melden sich ab. Das lässt sich nicht rückgängig machen.';

  @override
  String get leaveDeleteDialogTitle => 'Familie löschen?';

  @override
  String get leaveDeleteDialogBody =>
      'Alle Geräte melden sich ab, und die Familie wird mit allen Daten endgültig gelöscht.';

  @override
  String leaveDeleteNameLabel(String name) {
    return 'Tippe ‚$name‘ zum Bestätigen';
  }

  @override
  String get leaveDeleteNext => 'Weiter';

  @override
  String get leaveDeleteWordTitle => 'Endgültig löschen?';

  @override
  String get leaveDeleteWordBody =>
      'Die Familie und alle ihre Daten werden sofort und endgültig gelöscht. Niemand kann sie wiederherstellen, auch kein Elternteil. Willst du etwas behalten, exportiere die Daten vorher.';

  @override
  String get leaveDeleteWord => 'LÖSCHEN';

  @override
  String leaveDeleteWordLabel(String word) {
    return 'Tippe $word, um die Familie endgültig zu löschen';
  }

  @override
  String get leaveDeleteConfirm => 'Familie löschen';

  @override
  String leaveDeletedTitle(String family, String date) {
    return '$family wird am $date endgültig gelöscht';
  }

  @override
  String get leaveDeletedBodyGuardian =>
      'Du kannst die Familie wiederherstellen. Alle Daten sind noch da. Dieses Gerät ist danach wieder euer Familientelefon; die anderen Geräte melden sich neu an.';

  @override
  String get leaveDeletedBodyMember =>
      'Nur ein Elternteil kann die Familie wiederherstellen. Du kannst auch neu anfangen; dann verlässt dein Konto diese Familie.';

  @override
  String get leaveRestore => 'Wiederherstellen';

  @override
  String get leaveStartAfresh => 'Neu anfangen';

  @override
  String get leaveStartAfreshHint =>
      'Dein Konto verlässt die gelöschte Familie, und du gründest eine neue.';

  @override
  String get leaveErrConfirmName => 'Der Name stimmt nicht.';

  @override
  String get leaveErrHouseholdDeleted => 'Diese Familie ist gelöscht.';

  @override
  String get leaveErrRestoreExpired =>
      'Diese Familie kann nicht mehr wiederhergestellt werden.';

  @override
  String get leaveErrNotDeleted => 'Diese Familie ist nicht gelöscht.';

  @override
  String get leaveErrAdultRequired => 'Nur Erwachsene haben ein eigenes Konto.';

  @override
  String get leaveErrAlreadyInHousehold =>
      'Dieses Konto gehört schon zu einer Familie.';

  @override
  String get inviteDoorAction => 'Ich habe einen Einladungscode';

  @override
  String get inviteCodeTitle => 'Einladung';

  @override
  String get inviteCodeBody =>
      'Gib den Code ein oder füge den Link ein, den du bekommen hast.';

  @override
  String get inviteCodeLabel => 'Code oder Link';

  @override
  String get inviteCheckAction => 'Einladung prüfen';

  @override
  String get inviteCodeInvalidFormat =>
      'Das ist weder ein Einladungscode noch ein WuselWall-Link.';

  @override
  String get inviteCodeEmpty => 'Gib den Code oder Link ein.';

  @override
  String get inviteNoLonger =>
      'Diese Einladung gilt nicht mehr. Bitte die Person, die dich eingeladen hat, um eine neue.';

  @override
  String get inviteRateLimited =>
      'Zu viele Versuche. Warte ein paar Minuten und versuch es noch einmal.';

  @override
  String inviteBanner(String inviter, String household) {
    return '$inviter hat dich zu $household eingeladen';
  }

  @override
  String inviteBannerNoInviter(String household) {
    return 'Du bist zu $household eingeladen';
  }

  @override
  String get inviteRoleLineGuardian =>
      'Als Elternteil siehst du alles und bestätigst Belohnungen.';

  @override
  String get inviteRoleLineMember =>
      'Als weitere:r Erwachsene:r erledigst du Aufgaben, bestätigst aber keine Belohnungen.';

  @override
  String get inviteContinue => 'Weiter zur Anmeldung';

  @override
  String get inviteJoin => 'Beitreten';

  @override
  String get inviteNewFamilyInstead => 'Eigene Familie anlegen';

  @override
  String inviteJoinTitle(String name, String household) {
    return 'Du bist $name in $household';
  }

  @override
  String get inviteJoinHint =>
      'Dein Name und deine Farbe, so wie die Familie sie sieht. Später änderbar in den Einstellungen.';

  @override
  String get inviteJoinDecline => 'Nicht beitreten';

  @override
  String inviteAlreadyIn(String household) {
    return 'Du bist schon in $household.';
  }

  @override
  String inviteAlreadyInTitle(String household) {
    return 'Du bist schon in $household';
  }

  @override
  String inviteAlreadyInSame(String household) {
    return 'Diese Einladung ist für $household, und da bist du schon dabei. Du musst nichts weiter tun.';
  }

  @override
  String get inviteAlreadyInLeaveHint =>
      'Ein Konto gehört zu genau einer Familie. Um beizutreten, verlässt du zuerst deine jetzige Familie; danach geht es mit der Einladung weiter.';

  @override
  String get inviteAlreadyInLeaveHintUnknown =>
      'Ein Konto gehört zu genau einer Familie. Um einer anderen beizutreten, verlässt du zuerst deine jetzige Familie und öffnest die Einladung danach noch einmal.';

  @override
  String get inviteAlreadyInDevice =>
      'Dieses Gerät gehört schon zu einer Familie. Öffne die Einladung auf dem eigenen Handy der eingeladenen Person.';

  @override
  String get invitePartnerPickTitle => 'Wen möchtest du einladen?';

  @override
  String get invitePartnerExisting => 'Schon in der Familie, noch ohne Konto';

  @override
  String get invitePartnerSomeoneElse => 'Jemand anderes';

  @override
  String get invitePartnerSomeoneElseHint =>
      'Legt eine neue erwachsene Person an';

  @override
  String get inviteNothingKept => 'Es liegt keine Einladung mehr vor.';

  @override
  String inviteResultTitle(String name) {
    return 'Einladung für $name';
  }

  @override
  String get inviteResultHint =>
      'Die Person gibt den Code in WuselWall ein oder scannt den QR-Code.';

  @override
  String inviteValidUntil(String date) {
    return 'Gültig bis $date';
  }

  @override
  String get inviteQrLabel => 'QR-Code der Einladung';

  @override
  String get inviteShare => 'Teilen';

  @override
  String get inviteDone => 'Fertig';

  @override
  String inviteShareMessage(
    String household,
    String link,
    String code,
    String server,
  ) {
    return 'Komm zu $household in WuselWall: $link — oder gib in der App den Code $code ein, auf dem Server $server.';
  }

  @override
  String get inviteAdultTitle => 'Erwachsene Person einladen';

  @override
  String get inviteAdultName => 'Name';

  @override
  String get inviteAdultRole => 'Rolle';

  @override
  String get inviteRoleGuardian => 'Elternteil';

  @override
  String get inviteRoleMember => 'Weitere:r Erwachsene:r';

  @override
  String get inviteRoleGuardianHelp => 'Sieht alles und bestätigt Belohnungen.';

  @override
  String get inviteRoleMemberHelp =>
      'Erledigt Aufgaben, bestätigt aber keine Belohnungen. Etwa für eine Au-pair oder Großeltern.';

  @override
  String get inviteAdultEmail => 'E-Mail (optional)';

  @override
  String get inviteAdultEmailHelp =>
      'Mit dieser Adresse findet die Person die Einladung von selbst, wenn sie sich anmeldet.';

  @override
  String get inviteEmailInvalid =>
      'Das sieht nicht nach einer E-Mail-Adresse aus.';

  @override
  String get inviteCreate => 'Einladung erstellen';

  @override
  String get inviteInviteAction => 'Einladen';

  @override
  String inviteOpenUntil(String date) {
    return 'Eingeladen · bis $date';
  }

  @override
  String get inviteShareAgain => 'Erneut teilen';

  @override
  String get inviteWithdraw => 'Zurückziehen';

  @override
  String get inviteWithdrawn => 'Einladung zurückgezogen.';

  @override
  String get inviteScanTitle => 'Einladung scannen';

  @override
  String get accountDeleteTile => 'Konto löschen';

  @override
  String get accountDeleteExplain =>
      'Dein Konto und seine Anmeldemethoden werden gelöscht, und du wirst überall abgemeldet. Dein Profil bleibt mit allem, was du getan hast, in der Familie.';

  @override
  String get accountDeleteBlocked =>
      'Du bist der letzte Elternteil mit Konto in dieser Familie. Lade zuerst einen weiteren Elternteil ein oder lösche die Familie.';

  @override
  String get accountDeleteDialogTitle => 'Konto löschen?';

  @override
  String get accountDeleteDialogBody =>
      'Das lässt sich nicht rückgängig machen. Deine Anmeldung wird entfernt, und dein Profil bleibt in der Familie.';

  @override
  String get accountDeleteConfirm => 'Konto löschen';

  @override
  String get accountDeleteRefused =>
      'Das Konto konnte nicht gelöscht werden. Versuch es später noch einmal.';

  @override
  String get accountDeleteReauthTitle => 'Bitte bestätige, dass du es bist';

  @override
  String accountDeleteReauthBody(String email) {
    return 'Zum Löschen brauchen wir eine frische Anmeldung. Wir schicken einen Code an $email.';
  }

  @override
  String get accountDeleteReauthSend => 'Code senden';

  @override
  String get accountDeleteReauthCodeLabel => 'Code aus der E-Mail';

  @override
  String get accountDeleteReauthConfirm => 'Bestätigen';

  @override
  String get accountDeleteReauthSignInAgain =>
      'Melde dich zuerst neu an, dann kannst du das Konto löschen.';

  @override
  String get mfaResetAction => 'Zwei-Faktor zurücksetzen';

  @override
  String get mfaResetHint => 'Wenn die Authenticator-App verloren ist';

  @override
  String get mfaResetConfirmTitle => 'Zwei-Faktor zurücksetzen?';

  @override
  String mfaResetConfirmBody(String name) {
    return '$name kann sich danach ohne zweiten Faktor anmelden und ihn neu einrichten.';
  }

  @override
  String get mfaResetConfirm => 'Zurücksetzen';

  @override
  String mfaResetDone(String name) {
    return 'Der zweite Faktor von $name ist zurückgesetzt.';
  }

  @override
  String get serverTitle => 'Mit welchem Server?';

  @override
  String get serverLead =>
      'WuselWall speichert eure Daten auf dem Server eurer Familie. Gib seine Adresse ein oder scanne seinen QR-Code.';

  @override
  String get serverAddressLabel => 'Adresse des Servers';

  @override
  String get serverAddressHint => 'z. B. api.example.org';

  @override
  String get serverAddressHelper =>
      'Mit Einladung: den Link, oder Code und Server wie K7QM3XRP@api.example.org';

  @override
  String get serverConnect => 'Verbinden';

  @override
  String get serverScan => 'QR-Code scannen';

  @override
  String get serverDemo => 'Ohne Server ausprobieren';

  @override
  String get serverDemoHint =>
      'Mit einer Beispielfamilie. Nichts verlässt dieses Gerät.';

  @override
  String get serverHelp =>
      'Noch kein Server? Die Anleitung auf wuselwall.app/docs zeigt, wie ihr einen einrichtet.';

  @override
  String get serverInvalid => 'Das ist keine Serveradresse.';

  @override
  String get serverEmpty => 'Gib die Adresse des Servers ein.';

  @override
  String get serverUnreachable =>
      'Der Server antwortet nicht. Stimmt die Adresse, und bist du online?';

  @override
  String get serverNotWuselwall =>
      'Unter dieser Adresse läuft kein WuselWall-Server.';

  @override
  String get serverTooOld =>
      'Dieser Server braucht ein Update. Bitte die Person, die ihn betreibt, WuselWall zu aktualisieren.';

  @override
  String get serverAppTooOld =>
      'Dieser Server braucht eine neuere Version der App. Bitte aktualisiere WuselWall.';

  @override
  String get serverLinkWithoutServer =>
      'Dieser Link sagt nicht, zu welchem Server er gehört. Gib oben die Adresse des Servers ein, danach den Code.';

  @override
  String inviteResultServer(String server) {
    return 'Server: $server';
  }

  @override
  String get linkOtherServerTitle =>
      'Dieser Link gehört zu einem anderen Server';

  @override
  String linkSwitchBody(String host, String current) {
    return 'Der Link zeigt auf $host, aber diese App ist mit $current verbunden. Zu $host wechseln?';
  }

  @override
  String get linkSwitchAction => 'Server wechseln';

  @override
  String linkOtherServerBody(String host, String current) {
    return 'Der Link zeigt auf $host, aber du bist auf $current angemeldet. Melde dich zuerst ab (Einstellungen → Server wechseln) und öffne den Link dann erneut.';
  }

  @override
  String get serverIncompatibleTitle => 'Server und App passen nicht zusammen';

  @override
  String get serverChooseOther => 'Anderen Server wählen';

  @override
  String get demoBanner => 'Beispielfamilie: nichts wird gespeichert';

  @override
  String get demoExit => 'Beenden';

  @override
  String get settingsServer => 'Server';

  @override
  String settingsServerBody(String address) {
    return 'Diese App spricht mit $address. Scanne diesen Code mit der WuselWall-App auf einem anderen Gerät, um es mit demselben Server zu verbinden.';
  }

  @override
  String get settingsServerSwitch => 'Server wechseln';

  @override
  String get settingsServerSwitchConfirm =>
      'Dieses Gerät wird abgemeldet und vergisst alles, was darauf gespeichert ist. Danach kannst du einen anderen Server wählen.';

  @override
  String get setupPhoneTitle => 'Auf dem Handy weitermachen';

  @override
  String get setupPhoneBody =>
      'Öffne die WuselWall-App auf deinem Handy, wähle diesen Server, indem du den Code scannst, und melde dich dort an.';

  @override
  String get shortcutTitle => 'Apps und Automationen';

  @override
  String get shortcutIntro =>
      'Ein Schlüssel lässt eine andere App als eine bestimmte Person mit WuselWall arbeiten. Ein Schlüssel für Automationen, zum Beispiel für einen Kurzbefehl mit Siri auf dem iPhone oder jede andere App, die eine Webadresse aufrufen kann, liest und fügt hinzu: Er setzt Dinge auf die Einkaufsliste und sagt, was heute ansteht, was es zu essen gibt oder wer morgen Sport hat. Löschen oder verwalten kann er nichts.';

  @override
  String get shortcutEmpty => 'Noch keine Schlüssel.';

  @override
  String get shortcutKioskNote =>
      'Schlüssel werden auf einem eigenen Handy erstellt, nicht an der Wand.';

  @override
  String get shortcutNew => 'Neuer Schlüssel';

  @override
  String get shortcutLabelField => 'Name';

  @override
  String get shortcutLabelHint => 'z. B. iPhone';

  @override
  String get shortcutForWhom => 'Für wen?';

  @override
  String get shortcutForWhomHelp =>
      'Der Kurzbefehl handelt als diese Person: Er hakt ihre Aufgaben ab und nennt ihre Punkte.';

  @override
  String get shortcutCreate => 'Schlüssel erstellen';

  @override
  String shortcutKeyTitle(String name) {
    return 'Schlüssel für $name';
  }

  @override
  String shortcutKeyOnce(String name) {
    return 'Dieser Schlüssel wird nur jetzt angezeigt. Wer ihn hat, kann als $name lesen und hinzufügen, also behandle ihn wie ein Passwort. In Apples Kurzbefehle-App wird er über iCloud synchronisiert.';
  }

  @override
  String get shortcutCopyKey => 'Schlüssel kopieren';

  @override
  String get shortcutAddressLabel => 'Adresse';

  @override
  String get shortcutCopyAddress => 'Adresse kopieren';

  @override
  String get shortcutCopied => 'Kopiert.';

  @override
  String get shortcutHowTitle => 'So geht’s';

  @override
  String get shortcutHowSteps =>
      'Jede App schickt dieselbe Anfrage. In Apples Kurzbefehle-App einen Kurzbefehl mit der Aktion „Inhalte von URL abrufen“ anlegen: die Adresse mit /today am Ende und als Header „Authorization“ mit „Bearer “, einem Leerzeichen und dem Schlüssel. Danach „Ergebnis anzeigen“ oder „Text sprechen“ dazunehmen. Die Anleitung auf wuselwall.app/docs/settings/shortcuts zeigt alle Kurzbefehle.';

  @override
  String shortcutLastUsed(String when) {
    return 'Zuletzt benutzt: $when';
  }

  @override
  String get shortcutNeverUsed => 'Noch nie benutzt';

  @override
  String shortcutUseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Abfragen',
      one: '1 Abfrage',
    );
    return '$_temp0';
  }

  @override
  String get shortcutRevoked => 'Gesperrt';

  @override
  String get shortcutRevokeAction => 'Sperren';

  @override
  String shortcutRevokeConfirm(String label) {
    return '„$label“ sperren? Der Kurzbefehl funktioniert sofort nicht mehr.';
  }

  @override
  String get shortcutErrLabel =>
      'Bitte einen Namen mit höchstens 60 Zeichen eingeben.';

  @override
  String get shortcutErrLimit =>
      'Diese Person hat schon zehn Schlüssel. Bitte zuerst einen sperren.';

  @override
  String get shortcutSectionAutomations => 'Automationen';

  @override
  String get shortcutSectionAssistants => 'KI-Assistenten';

  @override
  String get shortcutKindShortcut => 'Automation';

  @override
  String get shortcutKindAssistant => 'KI-Assistent';

  @override
  String get shortcutKindShortcutHelp =>
      'Für Siri und Apples Kurzbefehle oder jede App, die eine Webadresse aufrufen kann: Er liest und fügt hinzu, zum Beispiel zur Einkaufsliste.';

  @override
  String get shortcutKindAssistantHelp =>
      'Für einen KI-Assistenten, der MCP spricht, etwa Claude: Er liest nur, und nur Erwachsene bekommen einen.';

  @override
  String get shortcutAssistantLabelHint => 'z. B. Claude auf dem Laptop';

  @override
  String shortcutAssistantKeyOnce(String name) {
    return 'Dieser Schlüssel wird nur jetzt angezeigt. Damit liest ein Assistent als $name die ganze Woche der Familie: Termine, wer weg ist, die Stundenpläne der Kinder, Aufgaben, Essen und die Einkaufsliste. Was er liest, geht an den Anbieter des Assistenten. Behandle den Schlüssel wie ein Passwort.';
  }

  @override
  String get shortcutAssistantHowSteps =>
      'Trage die Adresse in deinem Assistenten als MCP-Server ein und schicke den Schlüssel als Header „Authorization“ mit „Bearer “, einem Leerzeichen und dem Schlüssel. Die Anleitung auf wuselwall.app/docs/settings/shortcuts zeigt, wie das bei einigen Assistenten geht.';

  @override
  String get shortcutErrAdultOnly =>
      'Einen Schlüssel für einen Assistenten bekommen nur Erwachsene.';

  @override
  String get reminderPackTitle => 'Für morgen einpacken';

  @override
  String reminderPackChild(String name, String items) {
    return '$name: $items';
  }

  @override
  String get settingNotifyPackingTitle => 'Einpack-Erinnerung am Vorabend';

  @override
  String get settingNotifyPackingHelp =>
      'Um diese Uhrzeit sagt dein Handy, was für morgen in die Schultasche gehört, aus den Stundenplänen (zum Beispiel Sportsachen). Nur wenn etwas einzupacken ist.';

  @override
  String get settingNotifyShoppingStartTitle => 'Wenn jemand einkaufen geht';

  @override
  String get settingNotifyShoppingStartHelp =>
      'Tippt ein anderer Erwachsener auf „Einkaufen gehen“, siehst du es auf Heute und, solange die App läuft, als Mitteilung. So kannst du noch etwas auf die Liste setzen. Eine geschlossene App wird nicht erreicht.';

  @override
  String get appearanceTitle => 'Darstellung';

  @override
  String get appearanceSystem => 'Automatisch';

  @override
  String get appearanceSystemHelp =>
      'Hell oder dunkel, wie auf diesem Gerät eingestellt';

  @override
  String get appearanceLight => 'Hell';

  @override
  String get appearanceDark => 'Dunkel';

  @override
  String get appearanceNightNote =>
      'Nachts zeigt das Wanddisplay immer seine Nachtansicht.';

  @override
  String get appearanceLookLight => 'Helles Design';

  @override
  String get appearanceLookDark => 'Dunkles Design';

  @override
  String get lookFrisch => 'Frisch';

  @override
  String get lookSonnig => 'Sonnig';

  @override
  String get lookBlaueStunde => 'Blaue Stunde';

  @override
  String get lookSchiefer => 'Schiefer';

  @override
  String get lookPflaume => 'Pflaume';

  @override
  String get lookKakao => 'Kakao';

  @override
  String get firstLookTitle => 'Wie soll WuselWall aussehen?';

  @override
  String get firstLookHelp =>
      'Nur auf diesem Gerät. Du kannst es jederzeit unter Einstellungen, Darstellung ändern.';

  @override
  String get firstLookDone => 'Fertig';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageSystem => 'Automatisch';

  @override
  String languageSystemCurrent(String name) {
    return 'Automatisch: $name';
  }

  @override
  String get languageSystemHelp =>
      'Die Sprache dieses Geräts; Deutsch, wenn die App sie nicht hat. Deutsch so, wie man es im Land eurer Familie schreibt.';

  @override
  String get languageNameDe => 'Deutsch';

  @override
  String get languageNameDeDe => 'Deutsch (Deutschland)';

  @override
  String get languageNameDeCh => 'Deutsch (Schweiz)';

  @override
  String get languageNameDeAt => 'Deutsch (Österreich)';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameFr => 'Français';

  @override
  String get languageNameEs => 'Español';

  @override
  String get settingsViewLabel => 'Welche Einstellungen angezeigt werden';

  @override
  String get settingsViewAdvanced => 'Erweitert';

  @override
  String get settingsViewMoreHint =>
      'Mehr unter „Erweitert“ oben. Ausgeblendetes gilt weiter.';

  @override
  String get schoolTimetableNeedsTerm =>
      'Die angezeigte Woche gehört noch zu keinem Zeitraum. Lege den Zeitraum an, zu dem sie gehört, und trage danach die Stunden ein.';

  @override
  String get schoolTermContinue => 'Zeitraum speichern und weiter';

  @override
  String get schoolSetupFirstHint =>
      'Klingelzeiten (ab 8:00, 45 Minuten) und eine Fächerliste werden vorgeschlagen. Beides lässt sich danach anpassen.';

  @override
  String get schoolSetupCreate => 'Schule anlegen';

  @override
  String get schoolNextSteps => 'Nächste Schritte';

  @override
  String schoolNextStepEnter(String name) {
    return 'Stundenplan für $name eintragen';
  }

  @override
  String get schoolTermProposedHint =>
      'Vorgeschlagen: das laufende Schuljahr. Passe Name und Daten an, falls eure Schule anders zählt.';

  @override
  String schoolYearName(String from, String to) {
    return 'Schuljahr $from/$to';
  }

  @override
  String schoolCreateSubject(String name) {
    return '„$name“ als Fach anlegen';
  }

  @override
  String get schoolImportAction => 'Einlesen…';

  @override
  String get schoolImportFromText => 'Aus Text einfügen';

  @override
  String get schoolImportFromPhoto => 'Foto scannen';

  @override
  String get schoolImportTitle => 'Stundenplan einlesen';

  @override
  String schoolImportProposedBy(String assistant) {
    return 'Vorschlag von $assistant';
  }

  @override
  String schoolImportLessons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Stunden',
      one: '1 Stunde',
    );
    return '$_temp0';
  }

  @override
  String schoolImportTermNew(String name) {
    return 'Zeitraum: $name (wird angelegt)';
  }

  @override
  String schoolImportTermExisting(String name) {
    return 'Zeitraum: $name';
  }

  @override
  String schoolImportReplaces(String name, int count) {
    return 'Ersetzt den bestehenden Stundenplan von $name ($count Stunden).';
  }

  @override
  String get schoolImportNewSubjects => 'Neue Fächer';

  @override
  String get schoolImportCreateSubjects => 'Neue Fächer anlegen';

  @override
  String get schoolImportSkipNewSubjects =>
      'Stunden mit neuen Fächern werden weggelassen.';

  @override
  String get schoolImportCreateNew => 'Neu anlegen';

  @override
  String get schoolImportMergeHint =>
      'Gibt es das Fach schon? Wähle es aus, dann merkt sich WuselWall das Wort vom Blatt.';

  @override
  String schoolImportWarnUnmatchedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Stunden passen zu keiner Klingelzeit und werden weggelassen.',
      one: '1 Stunde passt zu keiner Klingelzeit und wird weggelassen.',
    );
    return '$_temp0';
  }

  @override
  String schoolImportWarnPeriodsExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die Klingelzeiten bekommen $count weitere Stunden.',
      one: 'Die Klingelzeiten bekommen 1 weitere Stunde.',
    );
    return '$_temp0';
  }

  @override
  String get schoolImportWarnPeriodsDiffer =>
      'Die Klingelzeiten auf dem Blatt weichen von denen der Schule ab; die der Schule bleiben.';

  @override
  String schoolImportWarnSchoolDiffers(String name) {
    return 'Das Blatt nennt eine andere Schule: $name.';
  }

  @override
  String get schoolImportApply => 'Übernehmen';

  @override
  String get schoolImportDiscard => 'Verwerfen';

  @override
  String get schoolImportApplied => 'Stundenplan übernommen.';

  @override
  String get schoolImportDiscarded => 'Vorschlag verworfen.';

  @override
  String get schoolImportNoChild => 'Lege zuerst ein Kind unter Mitglieder an.';

  @override
  String get schoolImportPasteTitle => 'Aus Text einlesen';

  @override
  String get schoolImportPasteIntro =>
      'Füge einen Stundenplan als JSON im WuselWall-Format ein. Vor dem Speichern siehst du eine Vorschau.';

  @override
  String get schoolImportCopyPrompt => 'Anleitung für den Assistenten kopieren';

  @override
  String get schoolImportPromptCopied => 'Anleitung kopiert.';

  @override
  String get schoolImportPrompt =>
      'Bitte lies den Stundenplan auf dem Foto und gib ihn als JSON im folgenden Format zurück, ohne weiteren Text. Tage als Mo, Di, Mi, Do, Fr; Stunden als Nummer (1 = erste Stunde) oder mit Beginn und Ende; Fächer mit dem Kürzel vom Blatt und, wenn bekannt, dem vollen Namen. Leere Felder weglassen. Bei A- und B-Wochen trägst du week: a oder b ein. Hort oder Betreuung kommen unter care.';

  @override
  String get schoolImportPasteHint => 'Stundenplan als JSON hier einfügen';

  @override
  String get schoolImportRead => 'Einlesen';

  @override
  String get schoolImportErrNotJson =>
      'Das ist kein Stundenplan im WuselWall-Format. Füge den vollständigen JSON-Text ein.';

  @override
  String get schoolImportErrNoLessons => 'Der Text enthält keine Stunden.';

  @override
  String get schoolImportErrTooMany =>
      'Das sind mehr Einträge, als ein Stundenplan haben kann.';

  @override
  String get schoolImportErrBadLesson =>
      'Eine Stunde hat keinen Tag, keine Stundennummer oder kein Fach.';

  @override
  String schoolImportErrBadDay(String value) {
    return '„$value“ ist kein Wochentag.';
  }

  @override
  String schoolImportErrBadTime(String value) {
    return '„$value“ ist keine Uhrzeit.';
  }

  @override
  String schoolProposalTitle(String assistant) {
    return 'Vorschlag von $assistant';
  }

  @override
  String schoolProposalSummary(String name, int count) {
    return 'Stundenplan für $name, $count Stunden';
  }

  @override
  String get schoolProposalReview => 'Prüfen';

  @override
  String get schoolProposalUnreadable =>
      'Dieser Vorschlag hat ein Format, das diese App-Version nicht lesen kann.';

  @override
  String get schoolProposalErrInvalid =>
      'Der Vorschlag hat ein ungültiges Format.';

  @override
  String get schoolProposalErrLimit =>
      'Es warten schon fünf Vorschläge. Prüfe oder verwirf sie zuerst.';

  @override
  String get schoolProposalErrGone =>
      'Dieser Vorschlag ist schon erledigt oder abgelaufen.';

  @override
  String get schoolScanIntro =>
      'Dein Server liest das Foto oder die PDF-Datei; nichts verlässt euer Zuhause. Ein gerades, helles Foto des ganzen Blatts klappt am besten; die PDF-Datei der Schule ist am genauesten.';

  @override
  String get schoolScanCamera => 'Foto aufnehmen';

  @override
  String get schoolScanPick => 'Foto auswählen';

  @override
  String get schoolScanBusy => 'Das Blatt wird gelesen…';

  @override
  String get schoolScanNotConfigured =>
      'Dein Server hat keine Texterkennung eingerichtet. Wie sie dazukommt, steht in der Anleitung unter „Extras für den Server“. Bis dahin: aus Text einlesen.';

  @override
  String get schoolScanNothingFound =>
      'Auf dem Foto wurde kein Stundenplan erkannt. Versuche ein geraderes, helleres Foto, oder lies den Plan aus Text ein.';

  @override
  String get schoolScanTooLarge => 'Das Foto ist zu groß (höchstens 6 MB).';

  @override
  String get schoolScanFailed =>
      'Die Texterkennung auf dem Server hat nicht geantwortet. Versuche es später noch einmal.';

  @override
  String schoolScanWarnUnplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Textstücke konnten keinem Feld zugeordnet werden. Vergleiche die Vorschau mit dem Blatt.',
      one: '1 Textstück konnte keinem Feld zugeordnet werden. Vergleiche die Vorschau mit dem Blatt.',
    );
    return '$_temp0';
  }

  @override
  String get savedMessage => 'Gespeichert.';

  @override
  String get settingsSectionThisDevice => 'Dieses Gerät';

  @override
  String get settingsSectionConnect => 'Teilen und Verbindungen';

  @override
  String get settingsMembersHint =>
      'Tippe auf eine Person, um Name, Farbe, Bild oder Rolle zu ändern. Ziehe am Griff, um die Reihenfolge auf der Wand zu ändern.';

  @override
  String get familySettingsSubtitle => 'Name, Zeitzone, Datenexport, Löschen';

  @override
  String get familySettingsSubtitleBasic => 'Der Name eurer Familie';

  @override
  String get familyTimezone => 'Zeitzone';

  @override
  String get familyTimezoneHelp =>
      'Wand und Erinnerungen folgen dieser Zeitzone.';

  @override
  String get familyTimezoneSearch => 'Zeitzone suchen';

  @override
  String get familyLocale => 'Sprache auf der Wand';

  @override
  String get familyLocaleHelp =>
      'Feiertage auf der Wandanzeige heißen in dieser Sprache.';

  @override
  String get familyErrTimezone => 'Unbekannte Zeitzone.';

  @override
  String get memberColour => 'Farbe';

  @override
  String get memberAvatar => 'Bild';

  @override
  String get memberAvatarInitial => 'Initiale';

  @override
  String get memberKind => 'Kind oder Erwachsen';

  @override
  String get memberRole => 'Rolle';

  @override
  String get memberRoleHelp =>
      'Eltern sehen alles und bestätigen Belohnungen. Weitere Erwachsene haken Aufgaben ab.';

  @override
  String get memberReadOnlyHint =>
      'Andere Personen ändern nur Eltern. Deinen eigenen Namen, deine Farbe und dein Bild kannst du selbst ändern.';

  @override
  String get memberKioskReadOnly =>
      'An der Wandanzeige wird niemand geändert. Namen, Farben, Bilder und Geburtstage änderst du in der App auf einem Handy oder Tablet.';

  @override
  String get memberInactive => 'Nicht mehr dabei';

  @override
  String get memberInactiveBody =>
      'Nicht auf der Wand, in den Avatar-Reihen und bei neuen Aufgaben. Verlauf und Punkte bleiben.';

  @override
  String get memberDeactivate => 'Nicht mehr dabei';

  @override
  String memberDeactivateBody(String name) {
    return '$name verschwindet von der Wand, aus den Avatar-Reihen und aus neuen Aufgaben. Verlauf und Punkte bleiben, und du kannst die Person hier zurückholen.';
  }

  @override
  String memberDeactivateConfirm(String name) {
    return '$name von den Bildschirmen der Familie nehmen? Verlauf und Punkte bleiben.';
  }

  @override
  String get memberReactivate => 'Wieder dabei';

  @override
  String memberHasAccountHint(String name) {
    return '$name hat ein Konto und verlässt die Familie vom eigenen Handy aus (Einstellungen → Familie verlassen).';
  }

  @override
  String get memberReorderHandle => 'Reihenfolge ändern';

  @override
  String get memberErrKindAdult =>
      'Eltern und Personen mit Konto sind Erwachsene.';

  @override
  String get memberErrRoleChild =>
      'Ein Kind kann kein Elternteil sein. Mache die Person zuerst zu einem Erwachsenen.';

  @override
  String get memberErrSelf =>
      'Dich selbst kannst du nicht entfernen. Ein anderer Elternteil kann es.';

  @override
  String get memberErrHasAccount =>
      'Diese Person hat ein Konto und verlässt die Familie vom eigenen Handy aus.';

  @override
  String get deviceRename => 'Gerät umbenennen';

  @override
  String deviceLastSeen(String ago) {
    return 'zuletzt aktiv $ago';
  }

  @override
  String get deviceNeverSeen => 'noch nicht aktiv';

  @override
  String get shoppingEditList => 'Liste bearbeiten';

  @override
  String get shoppingListDefault => 'Standardliste';

  @override
  String get shoppingListDefaultHelp =>
      'Die Wandanzeige schreibt auf die Standardliste.';

  @override
  String get shoppingCategories => 'Kategorien';

  @override
  String get shoppingCategoriesHelp =>
      'In der Reihenfolge, in der man durch den Laden geht. Ziehe am Griff, um sie zu ändern.';

  @override
  String get shoppingCategoryAdd => 'Kategorie hinzufügen';

  @override
  String get shoppingCategoryRename => 'Kategorie umbenennen';

  @override
  String get shoppingCategoryName => 'Name der Kategorie';

  @override
  String shoppingCategoryDeleteConfirm(String name) {
    return '„$name“ entfernen? Ihre Artikel bleiben ohne Kategorie auf der Liste.';
  }

  @override
  String get shoppingListDelete => 'Liste löschen';

  @override
  String shoppingListDeleteConfirm(String name) {
    return '„$name“ löschen? Offene Artikel wandern auf die Standardliste; Verlauf und Kacheln dieser Liste sind weg.';
  }

  @override
  String get shoppingErrListDefault =>
      'Die Standardliste kann nicht gelöscht werden. Mache zuerst eine andere Liste zur Standardliste.';

  @override
  String get shoppingErrTileExists =>
      'Eine Kachel mit diesem Namen gibt es schon.';

  @override
  String get shoppingTileAddEdit => 'Hinzufügen und bearbeiten';

  @override
  String get shoppingTileRename => 'Kachel umbenennen';

  @override
  String get shoppingTileForget => 'Nicht mehr vorschlagen';

  @override
  String get shoppingTileForgetHelp =>
      'Die Kachel verschwindet; der Verlauf behält sie.';

  @override
  String shoppingTileForgetConfirm(String name) {
    return 'Die Kachel „$name“ entfernen? Beim nächsten Kauf kommt sie zurück.';
  }

  @override
  String get schoolScanFile => 'Datei wählen (PDF oder Bild)';

  @override
  String get schoolImportPhotoUnavailable =>
      'Dein Server liest noch keine Fotos.';

  @override
  String get settingsVersions => 'Versionen';

  @override
  String settingsVersionsLine(String app, String server, String api) {
    return 'App $app · Server $server · Schnittstelle $api';
  }

  @override
  String get settingsVersionUnknown => 'unbekannt';

  @override
  String get settingMemberWuselTitle => 'Wusel';

  @override
  String get settingMemberWuselHelp =>
      'Wie oft Wusel bei dir auftaucht. Automatisch: lebhaft für Kinder, ruhig für Erwachsene.';

  @override
  String get settingMemberWuselOutfitTitle => 'Was Wusel trägt';

  @override
  String get settingMemberWuselOutfitHelp =>
      'Was Wusel im Gespräch mit dir anhat. Alle Sachen sind von Anfang an da.';

  @override
  String get settingDeviceWuselTitle => 'Wusel auf diesem Gerät';

  @override
  String get settingDeviceWuselHelp =>
      'Wie lebhaft Wusel hier ist, solange niemand ausgewählt ist. Die eigene Einstellung einer Person gilt, solange sie ausgewählt ist.';

  @override
  String get settingDeviceSoundsTitle => 'Töne auf diesem Gerät';

  @override
  String get settingDeviceSoundsHelp =>
      'Automatisch: an der Wand aus, sonst an. Nachts nie.';

  @override
  String get settingDeviceSkyTitle => 'Himmel in der Kopfzeile';

  @override
  String get settingDeviceSkyHelp =>
      'Die Kopfzeile zeigt einen Himmel, der sich mit der Tageszeit ändert.';

  @override
  String get settingDevicePixelShiftTitle =>
      'Bildschirm vor Einbrennen schützen';

  @override
  String get settingDevicePixelShiftHelp =>
      'Verschiebt alles alle 10 Minuten um bis zu 2 Pixel, für OLED-Bildschirme, die immer an sind. Automatisch: an der Wand an.';

  @override
  String get settingAmbienceSeasonTitle => 'Jahreszeiten';

  @override
  String get settingAmbienceSeasonHelp =>
      'Blüten, Sonne, Blätter oder Schneeflocken am Himmel.';

  @override
  String get settingAmbienceBirthdaysTitle => 'Geburtstage';

  @override
  String get settingAmbienceBirthdaysHelp =>
      'Wimpel in der Farbe der Person und ein Partyhut für Wusel an ihrem Geburtstag.';

  @override
  String get settingAmbienceFerienTitle => 'Ferien';

  @override
  String get settingAmbienceFerienHelp =>
      'Ein Band am ersten und am letzten Ferientag.';

  @override
  String get settingAmbienceAdventTitle => 'Advent';

  @override
  String get settingAmbienceAdventHelp =>
      'Kerzen in der Kopfzeile, an jedem der vier Sonntage vor Weihnachten eine mehr.';

  @override
  String get settingAmbienceEasterWesternTitle => 'Ostern';

  @override
  String get settingAmbienceEasterWesternHelp =>
      'Eier in den Hügeln, zwei Tage vor bis zwei Tage nach dem Ostersonntag.';

  @override
  String get settingAmbienceEasterOrthodoxTitle => 'Orthodoxes Ostern';

  @override
  String get settingAmbienceEasterOrthodoxHelp =>
      'Dieselben Eier am orthodoxen Datum, das für jedes Jahr berechnet wird.';

  @override
  String get settingAmbienceNewYearTitle => 'Silvester';

  @override
  String get settingAmbienceNewYearHelp =>
      'Kleines Feuerwerk am Nachthimmel am 31. Dezember und 1. Januar.';

  @override
  String get settingAmbienceChristmasTitle => 'Weihnachten';

  @override
  String get settingAmbienceChristmasHelp =>
      'Ein geschmückter Baum auf dem Hügel vom 24. bis 26. Dezember (am 6. und 7. Januar, wo Weihnachten nach dem orthodoxen Kalender gefeiert wird).';

  @override
  String get settingAmbienceStNicholasTitle => 'Nikolaus';

  @override
  String get settingAmbienceStNicholasHelp =>
      'Ein gefüllter Stiefel am 6. Dezember (in den Niederlanden am 5.).';

  @override
  String get settingAmbienceNationalDayTitle => 'Nationalfeiertag';

  @override
  String get settingAmbienceNationalDayHelp =>
      'Die Flagge eures Landes auf dem Hügel an seinem Nationalfeiertag, etwa am 1. August in der Schweiz. Das Land kommt aus eurer Region.';

  @override
  String get settingHouseholdKidShoppingTitle => 'Einkaufen für Kinder';

  @override
  String get settingHouseholdKidShoppingHelp =>
      'Kinder fügen auf der Einkaufsliste Artikel hinzu und haken sie ab. Aus: Kinder haben keine Einkaufsliste, und am Tablet für alle und am Wanddisplay öffnet sie sich erst, wenn ein Erwachsener auf seinen Namen getippt hat.';

  @override
  String get settingHouseholdKidCalendarTitle => 'Kalender für Kinder';

  @override
  String get settingHouseholdKidCalendarHelp =>
      'Kinder sehen ihre eigenen Termine für heute und die nächsten drei Tage. Aus: nur heute. Das Tablet für alle hat dann keinen Reiter Kalender, bis ein Erwachsener auf seinen Namen tippt.';

  @override
  String get settingRitualsCountdownDaysTitle => 'Vorfreude beginnt';

  @override
  String get settingRitualsCountdownDaysHelp =>
      'Wie viele Tage vor einem Geburtstag, den Ferien oder einem markierten Termin der Countdown erscheint.';

  @override
  String get settingRitualsCountdownReturnTitle =>
      'Countdown bis jemand zurückkommt';

  @override
  String get settingRitualsCountdownReturnHelp =>
      '\"In 2× schlafen zurück\", wenn ein Erwachsener zwei Nächte oder länger verreist ist.';

  @override
  String get settingMealsWishesTitle => 'Wunschessen';

  @override
  String get settingMealsWishesHelp =>
      'Wer sich ein Essen wünschen darf. Ein Wunsch wird in der App nie abgelehnt; er wartet, bis er geplant ist.';

  @override
  String get settingMealsWishesPerWeekTitle => 'Offene Wünsche pro Person';

  @override
  String get settingMealsWishesPerWeekHelp =>
      'Wie viele Wünsche jede Person gleichzeitig offen haben darf.';

  @override
  String get settingTableQuestionTitle => 'Tischfrage';

  @override
  String get settingTableQuestionHelp =>
      'Eine Gesprächsfrage an der Wand und in der App während des Essens. Sie wird laut beantwortet, nichts wird gespeichert.';

  @override
  String get settingTableQuestionLunchTitle => 'Tischfrage mittags';

  @override
  String get settingTableQuestionLunchHelp =>
      'Wann die Frage mittags erscheint.';

  @override
  String get settingTableQuestionDinnerTitle => 'Tischfrage abends';

  @override
  String get settingTableQuestionDinnerHelp =>
      'Wann die Frage abends erscheint.';

  @override
  String get settingTableQuestionAgeLimitTitle => 'Altersgrenze';

  @override
  String get settingTableQuestionAgeLimitHelp =>
      'Die Fragen richten sich nach dem Alter der Kinder, aus ihren Geburtstagen. Liegen Kinder mindestens 5 Jahre auseinander, bekommt jedes eine eigene Frage. Einschalten blendet Fragen ab dem gewählten Alter aus.';

  @override
  String get settingWeekReviewTitle => 'Unsere Woche';

  @override
  String get settingWeekReviewHelp =>
      'Wann der Rückblick auf die Woche erscheint. Er bleibt bis zum nächsten Morgen.';

  @override
  String get settingValueAuto => 'Automatisch';

  @override
  String get settingValueLively => 'Lebhaft';

  @override
  String get settingValueQuiet => 'Ruhig';

  @override
  String get settingValueOn => 'An';

  @override
  String get settingValueOff => 'Aus';

  @override
  String get settingValueChildren => 'Kinder';

  @override
  String get settingValueEveryone => 'Alle';

  @override
  String get settingValueWarmMeal => 'Warme Mahlzeit';

  @override
  String get settingValueMainMeals => 'Mittag- und Abendessen';

  @override
  String settingUnitFromAge(int age) {
    return 'ab $age Jahren';
  }

  @override
  String settingUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get wuselOutfitNone => 'Nichts';

  @override
  String get wuselOutfitParty => 'Partyhut';

  @override
  String get wuselOutfitCrown => 'Krone';

  @override
  String get wuselOutfitWizard => 'Zauberhut';

  @override
  String get wuselOutfitWreath => 'Blumenkranz';

  @override
  String get wuselOutfitSunglasses => 'Sonnenbrille';

  @override
  String get wuselOutfitScarf => 'Schal';

  @override
  String get wuselOutfitHeadphones => 'Kopfhörer';

  @override
  String get wuselOutfitBow => 'Schleife';

  @override
  String wuselHelloMorning1(String name) {
    return 'Guten Morgen, $name!';
  }

  @override
  String wuselHelloMorning2(String name) {
    return 'Morgen, $name! Ein neuer Tag.';
  }

  @override
  String wuselHelloMorning3(String name) {
    return 'Hallo $name, schön, dass du wach bist.';
  }

  @override
  String wuselHelloDay1(String name) {
    return 'Hallo $name!';
  }

  @override
  String wuselHelloDay2(String name) {
    return 'Da bist du ja, $name!';
  }

  @override
  String wuselHelloDay3(String name) {
    return 'Schön, dich zu sehen, $name.';
  }

  @override
  String wuselHelloEvening1(String name) {
    return 'Guten Abend, $name!';
  }

  @override
  String wuselHelloEvening2(String name) {
    return 'Na, $name? Was für ein Tag.';
  }

  @override
  String wuselHelloEvening3(String name) {
    return 'Hallo $name! Bald ist Ausruhzeit.';
  }

  @override
  String wuselHelloNight(String name) {
    return 'Schlaf gut, $name.';
  }

  @override
  String get wuselFactBirthdayYou => 'Alles Gute zum Geburtstag!';

  @override
  String wuselFactBirthday(String name) {
    return '$name hat Geburtstag!';
  }

  @override
  String wuselFactFirstLesson(String subject) {
    return 'Heute hast du zuerst $subject.';
  }

  @override
  String wuselFactTradition(String tradition) {
    return 'Heute ist $tradition!';
  }

  @override
  String wuselFactMealDinner(String dish) {
    return 'Heute Abend gibt es $dish.';
  }

  @override
  String wuselFactMealLunch(String dish) {
    return 'Mittags gibt es $dish.';
  }

  @override
  String wuselFactCountdown(String what, String when) {
    return '$what: $when';
  }

  @override
  String wuselBirthdayCheer(String name) {
    return 'Alles Gute zum Geburtstag, $name!';
  }

  @override
  String get wuselAllDone1 => 'Alles erledigt. Das hat gut geklappt!';

  @override
  String get wuselAllDone2 => 'Alles abgehakt. Danke dir!';

  @override
  String get wuselAllDone3 => 'Für heute fertig. Das Haus sagt danke!';

  @override
  String get wuselAllDone4 => 'Deine Liste ist leer. Zeit zum Spielen!';

  @override
  String get wuselRewardSent1 => 'Abgeschickt! Jetzt entscheiden deine Eltern.';

  @override
  String get wuselRewardSent2 => 'Dein Wunsch ist unterwegs.';

  @override
  String get wuselRewardSent3 =>
      'Wunsch verschickt! Deine Eltern schauen ihn sich an.';

  @override
  String wuselBadge(String badge) {
    return 'Ein neues Abzeichen: $badge!';
  }

  @override
  String get wuselWaiting => 'Einen Moment …';

  @override
  String get wuselOffline => 'Moment, ich suche das Internet …';

  @override
  String get wuselWallMorning1 => 'Guten Morgen, ihr alle!';

  @override
  String get wuselWallMorning2 => 'Aufgewacht, Familie!';

  @override
  String get wuselWallMorning3 => 'Ein neuer Tag für uns alle.';

  @override
  String wuselWallMemberDone1(String name) {
    return '$name hat heute alles geschafft!';
  }

  @override
  String wuselWallMemberDone2(String name) {
    return 'Alles abgehakt, $name. Danke!';
  }

  @override
  String wuselWallMemberDone3(String name) {
    return 'Alle Aufgaben von $name sind erledigt!';
  }

  @override
  String wuselWallTradition1(String name) {
    return 'Heute ist $name!';
  }

  @override
  String wuselWallTradition2(String name) {
    return 'Juhu, heute ist $name!';
  }

  @override
  String wuselWallTradition3(String name) {
    return 'Guten Morgen! Heute ist $name.';
  }

  @override
  String get wuselSetupDone => 'Alles eingerichtet. Willkommen zu Hause!';

  @override
  String get wuselHideLine => 'Wusels Satz ausblenden';

  @override
  String get wuselFerienFirst1 => 'Die Ferien fangen an. Schöne freie Tage!';

  @override
  String get wuselFerienFirst2 => 'Ferien! Heute beginnt die freie Zeit.';

  @override
  String get wuselFerienFirst3 =>
      'Erster Ferientag. Genießt die Zeit zusammen!';

  @override
  String get ambienceFerienFirst => 'Ferien!';

  @override
  String get ambienceFerienLast => 'Morgen ist wieder Schule';

  @override
  String get shoppingEmptyTapTile =>
      'Noch nichts auf der Liste. Tipp auf eine Kachel.';

  @override
  String get memberBirthday => 'Geburtstag';

  @override
  String get memberBirthdayHelp =>
      'Steht am Tag an der Wand, und vorher wird heruntergezählt. Bei einem Kind bestimmt er auch, welche Fragen am Tisch kommen.';

  @override
  String get memberBirthdayOptional => 'Geburtstag (freiwillig)';

  @override
  String get memberBirthdayPick => 'Datum wählen';

  @override
  String get memberBirthdayClear => 'Geburtstag entfernen';

  @override
  String countdownBirthdayOf(String name) {
    return 'Geburtstag von $name';
  }

  @override
  String countdownBirthdayTurns(String name, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$name wird $age',
      one: '$name wird 1',
    );
    return '$_temp0';
  }

  @override
  String countdownHomecoming(String name) {
    return '$name kommt nach Hause';
  }

  @override
  String countdownSleeps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'noch $count× schlafen',
      one: 'noch 1× schlafen',
    );
    return '$_temp0';
  }

  @override
  String countdownDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'noch $count Tage',
      one: 'noch 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String countdownInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count Tagen',
      one: 'in 1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get countdownTomorrow => 'Morgen!';

  @override
  String get countdownToday => 'Heute!';

  @override
  String get kidLookingForward => 'Worauf ich mich freue';

  @override
  String get todayLookingForward => 'Vorfreude';

  @override
  String tripTodayDayOf(int day, int count) {
    return 'Tag $day von $count';
  }

  @override
  String tripTodayMore(int count) {
    return '+$count weitere';
  }

  @override
  String tripTodayPacked(int packed, int total) {
    return '$packed von $total gepackt';
  }

  @override
  String get tripTodayTodos => 'Noch zu erledigen';

  @override
  String get tripTodayTonight => 'Heute Nacht';

  @override
  String get tripTodayTomorrow => 'Morgen';

  @override
  String get tripTodayNothing => 'Heute steht nichts an.';

  @override
  String get tripTodayCheckIn => 'Einchecken';

  @override
  String get tripTodayCheckOut => 'Auschecken';

  @override
  String get tripTodayPickUp => 'Abholung';

  @override
  String get tripTodayReturn => 'Rückgabe';

  @override
  String get tripTodayDeparture => 'Abfahrt';

  @override
  String get tripTodayArrival => 'Ankunft';

  @override
  String tripTodayOpen(String title) {
    return 'Reise $title öffnen';
  }

  @override
  String get tripTodayCall => 'Anrufen';

  @override
  String get tripTodayMap => 'Auf der Karte zeigen';

  @override
  String get tripTodayCannotOpen => 'Das lässt sich hier nicht öffnen.';

  @override
  String get tripTodayAllTrips => 'Alle Reisen';

  @override
  String get tripImportAction => 'Zur Reise hinzufügen';

  @override
  String get tripImportTitle => 'Zu welcher Reise?';

  @override
  String get tripImportIntro =>
      'Jedes Ereignis der Datei wird ein Eintrag der Reise, als gebucht.';

  @override
  String tripImportEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diese $count Einträge werden hinzugefügt',
      one: 'Dieser Eintrag wird hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String tripImportSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Ereignisse der Datei werden übersprungen (abgesagt oder ohne Beginn).',
      one:
          '1 Ereignis der Datei wird übersprungen (abgesagt oder ohne Beginn).',
    );
    return '$_temp0';
  }

  @override
  String get tripImportNothing => 'In dieser Datei ist kein Ereignis lesbar.';

  @override
  String get tripImportConfirm => 'Hinzufügen';

  @override
  String tripImportDone(int added, int updated) {
    return '$added hinzugefügt, $updated aktualisiert';
  }

  @override
  String get tripImportFallbackTitle => 'Buchung';

  @override
  String get tripImportSeveral =>
      'Die Datei enthält mehrere Termine. Sie können in eine Reise.';

  @override
  String get tripCalendarNotice =>
      'Dieser Termin gehört zu einer Reise und wird dort geändert.';

  @override
  String get tripCalendarOpen => 'Reise öffnen';

  @override
  String get tripCalendarPlanTitle => 'Reise planen';

  @override
  String get tripCalendarPlanLine => 'Vergleichen, buchen, packen';

  @override
  String get settingsServicesTitle => 'Wetter und Karten';

  @override
  String get settingsServicesSubtitle =>
      'Vorhersage, Orte und Routen für die Reisen';

  @override
  String get eventIconNone => 'Kein Bild';

  @override
  String get eventIconLabel => 'Bild';

  @override
  String get eventCountdownTitle => 'Darauf freuen wir uns';

  @override
  String get eventCountdownHelp =>
      'Zählt an der Wand und auf dem Kinder-Tablet herunter.';

  @override
  String get eventTraditionTitle => 'Familientradition';

  @override
  String get eventTraditionHelp =>
      'Etwas, das die Familie immer wieder macht. Steht immer an der Wand, mit einem Band.';

  @override
  String get eventTraditionMeal => 'Mit Essen';

  @override
  String get eventTraditionMealHint => 'z. B. Pizza';

  @override
  String get calendarNewTradition => 'Neue Tradition';

  @override
  String get traditionStartersHelp =>
      'Wähle eine Vorlage. Tag und Uhrzeit änderst du gleich danach.';

  @override
  String get traditionStarterGameNight => 'Spieleabend';

  @override
  String get traditionStarterPizzaFriday => 'Pizza-Freitag';

  @override
  String get traditionStarterFilmNight => 'Filmabend';

  @override
  String get traditionStarterSundayBreakfast => 'Sonntagsfrühstück';

  @override
  String get traditionStarterStoryTime => 'Vorlesezeit';

  @override
  String get traditionStarterDayOut => 'Ausflugstag';

  @override
  String get traditionStarterPizzaMeal => 'Pizza';

  @override
  String get traditionStarterOwn => 'Eigene Tradition';

  @override
  String get traditionStarterOwnHelp => 'Name, Bild und Tag wählst du selbst.';

  @override
  String traditionStarterWhen(String weekday, String time) {
    return 'Jeden $weekday, $time';
  }

  @override
  String traditionStarterWhenAllDay(String weekday) {
    return 'Jeden $weekday, ganztägig';
  }

  @override
  String get eventIcon_cake => 'Geburtstagskuchen';

  @override
  String get eventIcon_game_die => 'Spiel';

  @override
  String get eventIcon_pizza => 'Pizza';

  @override
  String get eventIcon_cinema => 'Film';

  @override
  String get eventIcon_croissant => 'Frühstück';

  @override
  String get eventIcon_book => 'Lesen';

  @override
  String get eventIcon_hiking => 'Wandern';

  @override
  String get eventIcon_beach => 'Ferien';

  @override
  String get eventIcon_plane => 'Reise';

  @override
  String get eventIcon_zoo => 'Zoo';

  @override
  String get eventIcon_tent => 'Zelten';

  @override
  String get eventIcon_football => 'Sport';

  @override
  String get eventIcon_music => 'Musik';

  @override
  String get eventIcon_gift => 'Geschenk';

  @override
  String get eventIcon_balloon => 'Feier';

  @override
  String get eventIcon_backpack => 'Schule';

  @override
  String get eventIcon_swim => 'Schwimmen';

  @override
  String get eventIcon_ferris => 'Rummel';

  @override
  String get eventIcon_house => 'Zuhause';

  @override
  String get eventIcon_broom => 'Putzen';

  @override
  String get eventIcon_star => 'Besonderes';

  @override
  String get kidWishTitle => 'Dein Wunschessen';

  @override
  String get kidWishInvite => 'Was möchtest du diese Woche essen?';

  @override
  String kidWishWaiting(String title) {
    return 'Du wünschst dir $title. Deine Eltern suchen einen Tag aus.';
  }

  @override
  String kidWishPlanned(String title, String day) {
    return 'Dein Wunsch $title gibt es am $day!';
  }

  @override
  String get kidWishMake => 'Wünschen';

  @override
  String get kidWishChange => 'Ändern';

  @override
  String get kidWishSent => 'Dein Wunsch ist unterwegs.';

  @override
  String get wishPickerTitle => 'Was möchtest du essen?';

  @override
  String get wishPickerOwn => 'Etwas anderes';

  @override
  String get wishPickerOwnHint => 'z. B. Pfannkuchen';

  @override
  String get wishPickerSend => 'Das wünsche ich mir';

  @override
  String get wishPickerRecipes => 'Unsere Rezepte';

  @override
  String get wishPickerSearch => 'Rezept suchen';

  @override
  String get wishPickerNoMatch =>
      'Kein Rezept mit diesem Namen. Wünsch es dir unten.';

  @override
  String get wishPickerIcon => 'Such dir ein Bild aus';

  @override
  String get mealsWishEarlier => 'von letzter Woche';

  @override
  String get mealsWishOlder => 'von vor ein paar Wochen';

  @override
  String get mealsWishMine => 'Selbst wünschen';

  @override
  String get mealsWishMineChange => 'Meinen Wunsch ändern';

  @override
  String get mealIcon_pizza => 'Pizza';

  @override
  String get mealIcon_pasta => 'Nudeln';

  @override
  String get mealIcon_pancakes => 'Pfannkuchen';

  @override
  String get mealIcon_waffle => 'Waffeln';

  @override
  String get mealIcon_burger => 'Burger';

  @override
  String get mealIcon_fries => 'Pommes';

  @override
  String get mealIcon_hotdog => 'Würstchen';

  @override
  String get mealIcon_sandwich => 'Sandwich';

  @override
  String get mealIcon_taco => 'Tacos';

  @override
  String get mealIcon_burrito => 'Wrap';

  @override
  String get mealIcon_kebab => 'Döner';

  @override
  String get mealIcon_curry => 'Curry';

  @override
  String get mealIcon_rice => 'Reis';

  @override
  String get mealIcon_noodles => 'Nudelsuppe';

  @override
  String get mealIcon_soup => 'Suppe oder Eintopf';

  @override
  String get mealIcon_paella => 'Paella';

  @override
  String get mealIcon_salad => 'Salat';

  @override
  String get mealIcon_sushi => 'Sushi';

  @override
  String get mealIcon_dumpling => 'Teigtaschen';

  @override
  String get mealIcon_chicken => 'Hähnchen';

  @override
  String get mealIcon_fish => 'Fisch';

  @override
  String get mealIcon_meat => 'Fleisch';

  @override
  String get mealIcon_egg => 'Eier';

  @override
  String get mealIcon_falafel => 'Falafel';

  @override
  String get mealIcon_fondue => 'Fondue';

  @override
  String get mealIcon_pie => 'Quiche oder Auflauf';

  @override
  String get mealIcon_cake => 'Kuchen';

  @override
  String get mealIcon_ice_cream => 'Eis';

  @override
  String get mealIcon_bread => 'Brot';

  @override
  String get mealIcon_pretzel => 'Brezel';

  @override
  String get mealIcon_croissant => 'Croissant';

  @override
  String get mealIcon_potato => 'Kartoffeln';

  @override
  String get mealIcon_cheese => 'Käse';

  @override
  String get mealIcon_porridge => 'Brei oder Müsli';

  @override
  String get mealIcon_vegetables => 'Gemüse';

  @override
  String get mealsWishesTray => 'Wünsche';

  @override
  String mealsWishChip(String name, String title) {
    return '$name: $title';
  }

  @override
  String get mealsWishPlan => 'Einplanen';

  @override
  String mealsWishPlanTitle(String dish) {
    return '$dish einplanen';
  }

  @override
  String get mealsWishRemove => 'Wunsch entfernen';

  @override
  String mealsWishedBy(String name) {
    return 'Wunsch von $name';
  }

  @override
  String mealsTraditionSuggestion(String meal, String tradition) {
    return '$meal einplanen ($tradition)';
  }

  @override
  String get tableQuestionTitle => 'Tischfrage';

  @override
  String get tableQuestionNext => 'Andere Frage';

  @override
  String get tableQuestionAnswer => 'Antwort zeigen';

  @override
  String tableQuestionFrom(String name) {
    return 'Frage von $name';
  }

  @override
  String get tableQuestionsManage => 'Unsere Fragen';

  @override
  String get tableQuestionAdd => 'Frage hinzufügen';

  @override
  String get tableQuestionOwnLabel => 'Deine Frage';

  @override
  String get tableQuestionAddHint => 'Was möchtest du am Tisch fragen?';

  @override
  String get tableQuestionHide => 'Diese Frage nicht mehr stellen';

  @override
  String get tableQuestionRemove => 'Frage entfernen';

  @override
  String get tableQuestionsHidden => 'Weggelassene Fragen';

  @override
  String get tableQuestionShowAgain => 'Wieder stellen';

  @override
  String get kidWishWithdraw => 'Zurücknehmen';

  @override
  String get kidWishAnother => 'Noch etwas wünschen';

  @override
  String get mealsWishSlotFree => 'Noch nichts geplant';

  @override
  String get mealsWishReplaceTitle => 'Essen ersetzen?';

  @override
  String mealsWishReplaceBody(
    String dish,
    String slot,
    String day,
    String wish,
  ) {
    return 'Schon geplant: $dish ($slot, $day). Stattdessen den Wunsch $wish einplanen? Wer kocht, die Uhrzeit und die Portionen bleiben.';
  }

  @override
  String get mealsWishReplace => 'Ersetzen';

  @override
  String get errSlotTaken => 'Für diese Mahlzeit ist schon etwas geplant.';

  @override
  String get tableQuestionDismiss => 'Für dieses Essen ausblenden';

  @override
  String get weekReviewTitle => 'Unsere Woche';

  @override
  String get weekReviewOpen => 'Auf unsere Woche zurückschauen';

  @override
  String get weekReviewTogether => 'Das haben wir zusammen geschafft';

  @override
  String weekReviewChores(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufgaben erledigt',
      one: '1 Aufgabe erledigt',
      zero: 'Eine Woche zum Durchatmen',
    );
    return '$_temp0';
  }

  @override
  String get weekReviewMoments => 'Jede und jeder hatte einen Moment';

  @override
  String get weekReviewMeals => 'Lecker';

  @override
  String get weekReviewNewRecipe => 'neu';

  @override
  String get weekReviewTraditions => 'Unsere Traditionen';

  @override
  String get weekReviewNext => 'Nächste Woche freuen wir uns auf';

  @override
  String get weekReviewCalmAhead => 'Eine ruhige Woche kommt.';

  @override
  String weekReviewCardOf(int index, int count) {
    return 'Karte $index von $count';
  }

  @override
  String get weekReviewNextCard => 'Nächste Karte';

  @override
  String get weekReviewPreviousCard => 'Vorige Karte';

  @override
  String weekHighlightBadge(String title) {
    return 'Neues Abzeichen: $title';
  }

  @override
  String weekHighlightStreak(String title) {
    return '$title, jeden Tag geschafft';
  }

  @override
  String get weekHighlightAllDone =>
      'hatte einen Tag, an dem alles erledigt war';

  @override
  String weekHighlightReward(String title) {
    return 'Belohnung: $title';
  }

  @override
  String weekHighlightWish(String title) {
    return 'Wunschessen auf dem Tisch: $title';
  }

  @override
  String weekHighlightCooked(String title) {
    return 'hat $title gekocht';
  }

  @override
  String weekHighlightAttended(String title) {
    return 'war bei $title dabei';
  }

  @override
  String get weekHighlightHelped => 'hat bei den Aufgaben mitgeholfen';

  @override
  String get weekHighlightHere => 'war diese Woche mit dabei';

  @override
  String get settingsGroupPersonalTitle => 'Persönlich';

  @override
  String get settingsGroupPersonalSubtitle =>
      'Wusel, Töne und Erinnerungen für dich';

  @override
  String get settingsGroupFamilyTitle => 'Familie';

  @override
  String get settingsGroupFamilySubtitle =>
      'Name, Region, Mitglieder und die übliche Woche';

  @override
  String get settingsGroupTasksTitle => 'Aufgaben & Belohnungen';

  @override
  String get settingsGroupTasksShortTitle => 'Aufgaben';

  @override
  String get settingsGroupTasksSubtitle => 'Punkte, Serien-Joker und Freigaben';

  @override
  String get settingsGroupTasksSubtitleBasic => 'Serien-Joker und Freigaben';

  @override
  String get settingsGroupCalendarTitle => 'Kalender & Schule';

  @override
  String get settingsGroupCalendarShortTitle => 'Kalender';

  @override
  String get settingsGroupCalendarSubtitle =>
      'Termine, Plan-Änderungen und Teilen';

  @override
  String get settingsGroupCalendarSubtitleBasic =>
      'Wer eigene Termine ändern darf';

  @override
  String get settingsGroupMealsTitle => 'Essen';

  @override
  String get settingsGroupMealsSubtitle =>
      'Warme Mahlzeit, Wunschessen und Mittagsbetreuung';

  @override
  String get settingsGroupMealsSubtitleBasic =>
      'Warme Mahlzeit und Wunschessen';

  @override
  String get settingsGroupRitualsTitle => 'Rituale';

  @override
  String get settingsGroupRitualsSubtitle =>
      'Tischfrage, unsere Woche, Vorfreude';

  @override
  String get settingsGroupRitualsSubtitleBasic => 'Tischfrage und unsere Woche';

  @override
  String get settingsGroupCelebrationsTitle => 'Feste & Jahreszeiten';

  @override
  String get settingsGroupCelebrationsShortTitle => 'Feste';

  @override
  String get settingsGroupCelebrationsSubtitle =>
      'Advent, Ostern, Silvester, Geburtstage und die Jahreszeiten';

  @override
  String get settingsGroupCelebrationsSubtitleBasic =>
      'Advent, Ostern und Silvester';

  @override
  String get settingsGroupKitchenTitle => 'Küchenwand';

  @override
  String get settingsGroupKitchenShortTitle => 'Küchenwand';

  @override
  String get settingsGroupKitchenSubtitle =>
      'Namen, Wochenwechsel und Tageszeiten';

  @override
  String get settingsGroupDevicesTitle => 'Geräte';

  @override
  String get settingsGroupDevicesSubtitle =>
      'Dieses Gerät und alle Geräte der Familie';

  @override
  String get settingsGroupAccountTitle => 'Konto & Sicherheit';

  @override
  String get settingsGroupAccountShortTitle => 'Konto';

  @override
  String get settingsGroupAccountSubtitle =>
      'Anmeldung, Passwort, Zwei-Faktor, Familie verlassen';

  @override
  String get settingsGroupServerTitle => 'Server';

  @override
  String get settingsGroupServerSubtitle =>
      'Adresse, QR-Code und Serverwechsel';

  @override
  String get settingsGroupHelpTitle => 'Hilfe & Info';

  @override
  String get settingsGroupHelpShortTitle => 'Hilfe';

  @override
  String get settingsGroupHelpSubtitle => 'Erste Schritte, Versionen, Lizenzen';

  @override
  String get settingsSectionWusel => 'Wusel';

  @override
  String get settingsSectionSound => 'Ton';

  @override
  String get settingsSectionNotifications => 'Benachrichtigungen';

  @override
  String get settingsSectionTableQuestion => 'Tischfrage';

  @override
  String get settingsSectionWeekReview => 'Wochenrückblick';

  @override
  String get settingsSectionCountdowns => 'Vorfreude';

  @override
  String get settingsSectionHolidays => 'Feiertage';

  @override
  String get settingsSectionThroughYear => 'Durchs Jahr';

  @override
  String get settingsSectionAllDevices => 'Alle Geräte';

  @override
  String get settingsSectionLeave => 'Verlassen oder löschen';

  @override
  String get settingsSectionOther => 'Weitere Einstellungen';

  @override
  String get familyProfileTitle => 'Familienprofil';

  @override
  String get settingsMembersSubtitle =>
      'Namen, Farben, Rollen und die Reihenfolge an der Wand';

  @override
  String get calendarMonth => 'Monat';

  @override
  String get calendarWeekNumberShort => 'KW';

  @override
  String calendarWeekNumberLabel(int week) {
    return 'Kalenderwoche $week';
  }

  @override
  String calendarMonthMore(int count) {
    return '+$count';
  }

  @override
  String calendarMonthOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weitere Termine',
      one: '1 weiterer Termin',
    );
    return '$_temp0';
  }

  @override
  String calendarMonthFerien(String name) {
    return 'Ferien: $name';
  }

  @override
  String get calendarMonthOpenDay => 'Tag öffnen';

  @override
  String get eventRepeatYearly => 'Jährlich';

  @override
  String get eventTemplatesIntro =>
      'Womit fängst du an? Alles lässt sich danach noch ändern.';

  @override
  String get eventTemplatesSuggested => 'Häufig bei euch';

  @override
  String get eventTemplatesSaved => 'Eure Vorlagen';

  @override
  String get eventTemplatesBuiltIn => 'Vorlagen';

  @override
  String get eventTemplatesBuiltInMore => 'Weitere Vorlagen';

  @override
  String get eventTemplatesSchool => 'Schule';

  @override
  String get eventTemplateBlank => 'Ohne Vorlage';

  @override
  String get eventTemplateBlankHelp => 'Alles selbst eintragen';

  @override
  String get eventStarterBirthday => 'Geburtstag';

  @override
  String get eventStarterGuestDinner => 'Gäste zum Essen';

  @override
  String get eventStarterPlaydate => 'Spielen mit Freunden';

  @override
  String get eventStarterSportsPractice => 'Sporttraining';

  @override
  String get eventStarterDoctor => 'Arzttermin';

  @override
  String get eventStarterCinema => 'Kinobesuch';

  @override
  String get eventStarterDayOut => 'Familienausflug';

  @override
  String get eventStarterHoliday => 'Familienurlaub';

  @override
  String get eventStarterCleaning => 'Putzhilfe kommt';

  @override
  String get eventStarterParentsEvening => 'Elternabend';

  @override
  String get eventStarterParentTeacherTalk => 'Elterngespräch';

  @override
  String get eventStarterSchoolTrip => 'Schulausflug';

  @override
  String get eventStarterSchoolTest => 'Klassenarbeit';

  @override
  String get eventStarterSchoolParty => 'Schulfest';

  @override
  String get eventStarterSportsDay => 'Sporttag der Schule';

  @override
  String get eventTemplateAllDay => 'Ganztägig';

  @override
  String eventTemplateDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String eventTemplateHours(int count) {
    return '$count Std.';
  }

  @override
  String eventTemplateHoursMinutes(int hours, int minutes) {
    return '$hours Std. $minutes Min.';
  }

  @override
  String eventTemplateMinutes(int count) {
    return '$count Min.';
  }

  @override
  String eventTemplateCount(int count) {
    return '$count× benutzt';
  }

  @override
  String eventTemplateCountShort(int count) {
    return '$count×';
  }

  @override
  String eventTemplateMenu(String name) {
    return 'Mehr zu $name';
  }

  @override
  String get eventTemplateKeep => 'Als Vorlage behalten';

  @override
  String get eventTemplateHide => 'Nicht mehr vorschlagen';

  @override
  String get eventTemplateHidden => 'Wird nicht mehr vorgeschlagen.';

  @override
  String get eventTemplateDelete => 'Vorlage löschen';

  @override
  String get eventTemplateDeleted => 'Vorlage gelöscht.';

  @override
  String get eventSaveAsTemplate => 'Als Vorlage speichern';

  @override
  String get eventTemplateSavedNote => 'Als Vorlage gespeichert.';

  @override
  String get eventTemplateErrLimit =>
      'Ihr habt schon 50 Vorlagen. Löscht zuerst eine.';

  @override
  String get tripListWindows => 'Zeitfenster';

  @override
  String get tripListWindowsHelp => 'Wann können wir alle weg?';

  @override
  String get tripListDiscover => 'Wohin?';

  @override
  String get tripListDiscoverHelp => 'Wo ist es dann warm und trocken?';

  @override
  String get tripListNewIdea => 'Neue Idee';

  @override
  String get tripListUpcoming => 'Unterwegs und bald';

  @override
  String get tripListIdeas => 'Ideen';

  @override
  String tripListPast(int count) {
    return 'Vergangene Reisen ($count)';
  }

  @override
  String get tripListEmptyTitle => 'Noch keine Reisen';

  @override
  String get tripListEmpty =>
      'Fangt mit einer Idee an: ein Ort, wohin ihr gern einmal wollt, noch ohne Datum.';

  @override
  String tripListInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count Tagen',
      one: 'Morgen',
      zero: 'Heute',
    );
    return '$_temp0';
  }

  @override
  String tripListDayOf(int day, int total) {
    return 'Tag $day von $total';
  }

  @override
  String get tripListNoDates => 'Noch kein Datum';

  @override
  String get tripPageUnavailable => 'Reisen gibt es hier nicht.';

  @override
  String get tripPageNotFound => 'Diese Reise gibt es nicht mehr.';

  @override
  String get tripPageToList => 'Zu allen Reisen';

  @override
  String get tripPageMore => 'Mehr';

  @override
  String get tripPageEdit => 'Bearbeiten';

  @override
  String get tripPageBackToIdea => 'Zurück zur Idee';

  @override
  String get tripPageDelete => 'Reise löschen';

  @override
  String tripPageDeleteConfirm(String title) {
    return '„$title“ mit allen Optionen, dem Plan und den Listen löschen?';
  }

  @override
  String get tripPageWholeFamily => 'Die ganze Familie';

  @override
  String tripPageDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get tripPageChooseDates => 'Zeitraum wählen';

  @override
  String get tripPageFindWindow => 'Zeitfenster suchen';

  @override
  String get tripPageEnterDates => 'Zeitraum eingeben';

  @override
  String get tripPageChangeDates => 'Zeitraum ändern';

  @override
  String get tripPageDatesTooLong =>
      'Eine Reise kann höchstens 366 Tage dauern.';

  @override
  String get tripPageFix => 'Das machen wir';

  @override
  String get tripPagePencil => 'Diesen Zeitraum vormerken';

  @override
  String get tripPageDecided =>
      'Beschlossene Sache. Darauf kann sich die Familie freuen.';

  @override
  String get tripPageUnfix => 'Zurück auf geplant';

  @override
  String get tripPageCalPlanned => 'Im Kalender als gestrichelter Eintrag.';

  @override
  String get tripPageCalFixed => 'Im Kalender mit Countdown, auch an der Wand.';

  @override
  String get tripPageTabPlan => 'Plan';

  @override
  String get tripPageTabPack => 'Packen';

  @override
  String get tripPageTabPrepare => 'Vorbereiten';

  @override
  String get tripEditTitle => 'Reise bearbeiten';

  @override
  String get tripEditName => 'Name der Reise';

  @override
  String get tripEditNameHint => 'z. B. Sardinien im Sommer';

  @override
  String get tripEditNameRequired => 'Gebt der Reise einen Namen.';

  @override
  String get tripEditDestination => 'Reiseziel (optional)';

  @override
  String get tripEditFindPlace => 'Ort suchen';

  @override
  String get tripEditNoPlaces => 'Kein Ort gefunden.';

  @override
  String get tripEditPlaceFound => 'Ort gefunden';

  @override
  String get tripEditWho => 'Wer reist mit?';

  @override
  String get tripEditWholeFamily =>
      'Niemand ausgewählt: die ganze Familie reist.';

  @override
  String get tripEditCurrency => 'Währung';

  @override
  String get tripEditCurrencyHelp => 'Drei Buchstaben, z. B. CHF oder EUR';

  @override
  String get tripEditCurrencyInvalid => 'Bitte drei Buchstaben.';

  @override
  String get tripEditNote => 'Notiz';

  @override
  String tripPlanDay(int number, String date) {
    return 'Tag $number · $date';
  }

  @override
  String get tripPlanToday => 'Heute';

  @override
  String get tripPlanDayEmpty => 'Noch nichts geplant';

  @override
  String tripPlanStayTonight(String title) {
    return 'Übernachtung: $title';
  }

  @override
  String get tripPlanRoleCheckIn => 'Einchecken';

  @override
  String get tripPlanRoleCheckOut => 'Auschecken';

  @override
  String get tripPlanRolePickUp => 'Abholung';

  @override
  String get tripPlanRoleReturn => 'Rückgabe';

  @override
  String get tripPlanRoleDeparture => 'Abfahrt';

  @override
  String get tripPlanRoleArrival => 'Ankunft';

  @override
  String get tripPlanRoleStart => 'Beginn';

  @override
  String get tripPlanRoleEnd => 'Ende';

  @override
  String get tripPlanUndated => 'Ohne Datum';

  @override
  String get tripPlanOutside => 'Außerhalb der Reisedaten';

  @override
  String get tripPlanNoDatesHint =>
      'Wählt einen Zeitraum, dann erscheinen hier die Tage der Reise mit allem, was ihr ausgesucht habt.';

  @override
  String get tripPlanChosen => 'Ausgewählt und gebucht';

  @override
  String get tripPlanOptions => 'Optionen';

  @override
  String tripPlanOptionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Optionen',
      one: '1 Option',
    );
    return '$_temp0';
  }

  @override
  String tripPlanPriceRange(String low, String high) {
    return '$low bis $high';
  }

  @override
  String tripPlanPriceChecked(String date) {
    return 'Preis vom $date';
  }

  @override
  String tripPlanBookingRef(String ref) {
    return 'Buchung $ref';
  }

  @override
  String get tripPlanCompare => 'Vergleichen';

  @override
  String get tripPlanAddOption => 'Option hinzufügen';

  @override
  String get tripPlanOpenLink => 'Link öffnen';

  @override
  String get tripPlanCall => 'Anrufen';

  @override
  String get tripPlanOpenMap => 'Auf der Karte zeigen';

  @override
  String get tripPlanOpenFailed => 'Das konnte nicht geöffnet werden.';

  @override
  String tripInfoSum(String amount) {
    return 'Ausgewählt und gebucht: $amount';
  }

  @override
  String tripInfoSumAtLeast(String amount) {
    return 'Ausgewählt und gebucht: mindestens $amount';
  }

  @override
  String get tripInfoForecast => 'Vorhersage';

  @override
  String get tripInfoClimate => 'Typisch für diese Jahreszeit';

  @override
  String tripInfoClimateMonth(String month, String tmax, String tmin) {
    return '$month: $tmax° / $tmin°';
  }

  @override
  String tripInfoRainDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Regentage',
      one: '1 Regentag',
    );
    return '$_temp0';
  }

  @override
  String tripInfoSea(String temp) {
    return 'Meer $temp°';
  }

  @override
  String tripInfoRoute(String time, String km) {
    return 'Mit dem Auto von zu Hause: $time, $km km';
  }

  @override
  String tripInfoDurationHM(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String tripInfoDurationM(int minutes) {
    return '$minutes min';
  }

  @override
  String get tripInfoMap => 'Karte des Reiseziels';

  @override
  String tripInfoForecastDay(
    String date,
    String weather,
    String tmax,
    String tmin,
  ) {
    return '$date: $weather, $tmax° / $tmin°';
  }

  @override
  String get tripInfoWeatherClear => 'Klar';

  @override
  String get tripInfoWeatherPartly => 'Teils bewölkt';

  @override
  String get tripInfoWeatherCloudy => 'Bewölkt';

  @override
  String get tripInfoWeatherFog => 'Nebel';

  @override
  String get tripInfoWeatherRain => 'Regen';

  @override
  String get tripInfoWeatherSnow => 'Schnee';

  @override
  String get tripInfoWeatherStorm => 'Gewitter';

  @override
  String tripPackProgress(int done, int total) {
    return '$done von $total';
  }

  @override
  String get tripPackForAll => 'Für alle';

  @override
  String get tripPackAddHint => 'Etwas hinzufügen';

  @override
  String get tripPackAdd => 'Hinzufügen';

  @override
  String get tripPackItem => 'Sache';

  @override
  String get tripPackEmpty => 'Noch nichts auf der Liste.';

  @override
  String get tripPackRename => 'Umbenennen';

  @override
  String get tripPackRemove => 'Entfernen';

  @override
  String get tripPackSuggestions => 'Vorschläge';

  @override
  String get tripPackSuggestionsHelp =>
      'Wählt, was dazukommen soll. Was jede Person braucht, kommt für alle Mitreisenden dazu.';

  @override
  String get tripPackSuggestionsAdd => 'Zur Liste hinzufügen';

  @override
  String get tripPackLastTime => 'Wie letztes Mal';

  @override
  String get tripPackLastTimeChoose => 'Liste welcher Reise übernehmen?';

  @override
  String get tripPackLastTimeNone =>
      'Keine andere Reise hat schon eine Packliste.';

  @override
  String tripPackAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge hinzugefügt.',
      one: '1 Eintrag hinzugefügt.',
      zero: 'Alles stand schon auf der Liste.',
    );
    return '$_temp0';
  }

  @override
  String get tripPackGroupDocuments => 'Dokumente';

  @override
  String get tripPackGroupHealth => 'Gesundheit';

  @override
  String get tripPackGroupElectronics => 'Elektronik';

  @override
  String get tripPackGroupClothes => 'Kleidung';

  @override
  String get tripPackGroupBeach => 'Strand und Sonne';

  @override
  String get tripPackGroupKids => 'Für die Kinder';

  @override
  String get tripPackStarterPassports => 'Pass oder Ausweis';

  @override
  String get tripPackStarterHealthInsuranceCard => 'Krankenkassenkarte';

  @override
  String get tripPackStarterBookingConfirmations => 'Buchungsbestätigungen';

  @override
  String get tripPackStarterCashAndCards => 'Bargeld und Bankkarten';

  @override
  String get tripPackStarterPharmacyBag => 'Reiseapotheke';

  @override
  String get tripPackStarterRegularMedication => 'Medikamente';

  @override
  String get tripPackStarterSunscreen => 'Sonnencreme';

  @override
  String get tripPackStarterInsectRepellent => 'Mückenschutz';

  @override
  String get tripPackStarterChargers => 'Handy-Ladegeräte';

  @override
  String get tripPackStarterPowerAdapter => 'Reisestecker';

  @override
  String get tripPackStarterPowerBank => 'Powerbank';

  @override
  String get tripPackStarterHeadphones => 'Kopfhörer';

  @override
  String get tripPackStarterUnderwearSocks => 'Unterwäsche und Socken';

  @override
  String get tripPackStarterTshirts => 'T-Shirts';

  @override
  String get tripPackStarterTrousersShorts => 'Hosen und Shorts';

  @override
  String get tripPackStarterWarmJumper => 'Warmer Pullover';

  @override
  String get tripPackStarterRainJacket => 'Regenjacke';

  @override
  String get tripPackStarterWalkingShoes => 'Bequeme Schuhe';

  @override
  String get tripPackStarterSleepwear => 'Schlafanzug';

  @override
  String get tripPackStarterSwimwear => 'Badesachen';

  @override
  String get tripPackStarterBeachTowels => 'Strandtuch';

  @override
  String get tripPackStarterSunHat => 'Sonnenhut';

  @override
  String get tripPackStarterSunglasses => 'Sonnenbrille';

  @override
  String get tripPackStarterCuddlyToy => 'Kuscheltier';

  @override
  String get tripPackStarterKidsGames => 'Spiele und Bücher für unterwegs';

  @override
  String get tripPackStarterNappiesWipes => 'Windeln und Feuchttücher';

  @override
  String get tripPackStarterJourneySnacks => 'Snacks für unterwegs';

  @override
  String get tripTodoAdd => 'To-do hinzufügen';

  @override
  String get tripTodoEdit => 'To-do bearbeiten';

  @override
  String get tripTodoTitleLabel => 'Was ist zu tun?';

  @override
  String get tripTodoDaysLabel => 'Tage vor der Reise (optional)';

  @override
  String tripTodoDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage vorher',
      one: '1 Tag vorher',
      zero: 'Am ersten Reisetag',
    );
    return '$_temp0';
  }

  @override
  String tripTodoDue(String date) {
    return 'Bis $date';
  }

  @override
  String tripTodoWasDue(String date) {
    return 'Eigentlich bis $date';
  }

  @override
  String get tripTodoEmpty =>
      'Noch nichts vorzubereiten. Pässe, Nachbarn, die Katze: Schreibt auf, was vor der Abreise passieren muss.';

  @override
  String get tripTodoDone => 'Erledigt';

  @override
  String get passwordSignUpTab => 'Neues Konto';

  @override
  String get passwordSignInTab => 'Anmelden';

  @override
  String get passwordSignUpAction => 'Konto erstellen';

  @override
  String get passwordNoMailHint =>
      'Dieser Server verschickt keine E-Mails. Wähl ein Passwort, das du dir merken kannst: Vergisst du es, gibt dir ein Elternteil deiner Familie einen Code für ein neues.';

  @override
  String get passwordAccountExists =>
      'Zu dieser Adresse gibt es schon ein Konto. Melde dich mit seinem Passwort an.';

  @override
  String get passwordForgot => 'Passwort vergessen?';

  @override
  String get passwordResetTitle => 'Neues Passwort';

  @override
  String get passwordResetIntro =>
      'Bitte einen Elternteil deiner Familie um einen Code: in der App unter Mitglieder, bei deinem Namen, „Passwort zurücksetzen“. Er gilt einmal, 10 Minuten lang.';

  @override
  String get passwordResetCodeLabel => 'Code zum Zurücksetzen';

  @override
  String get passwordResetSave => 'Speichern und anmelden';

  @override
  String get errResetCodeExpired =>
      'Dieser Code ist abgelaufen. Bitte um einen neuen.';

  @override
  String get passwordResetMemberAction => 'Passwort zurücksetzen';

  @override
  String passwordResetConfirmTitle(String name) {
    return 'Neues Passwort für $name?';
  }

  @override
  String passwordResetConfirmBody(String name) {
    return 'Du bekommst einen Code, mit dem $name auf dem eigenen Gerät ein neues Passwort wählt. Er gilt einmal, 10 Minuten lang. Gib ihn nur persönlich weiter.';
  }

  @override
  String get passwordResetConfirm => 'Code erstellen';

  @override
  String passwordResetCodeTitle(String name) {
    return 'Code für $name';
  }

  @override
  String passwordResetCodeHint(String name, String time) {
    return 'Auf dem Gerät von $name: Anmelden oder Konto erstellen → Anmelden → Passwort vergessen? Dann die E-Mail-Adresse, diesen Code und ein neues Passwort. Gültig bis $time.';
  }

  @override
  String get settingsPasswordNoMail =>
      'Der Server deiner Familie verschickt keine E-Mails: Du meldest dich mit deiner Adresse und diesem Passwort an.';

  @override
  String get passwordDialogBodyNoMail =>
      'Mindestens 10 Zeichen. Vergisst du es, gibt dir ein Elternteil deiner Familie einen Code für ein neues.';

  @override
  String get errEmailNotConfirmed =>
      'Dieser Server will die Adresse per E-Mail bestätigen, verschickt aber keine. Frag, wer ihn betreibt.';

  @override
  String accountDeleteReauthPasswordBody(String email) {
    return 'Zum Löschen eines Kontos brauchst du eine frische Anmeldung. Gib das Passwort von $email ein.';
  }

  @override
  String get shoppingModePlan => 'Planungsmodus';

  @override
  String get shoppingStartShopping => 'Einkaufen gehen';

  @override
  String get shoppingAddInStore => 'Hinzufügen';

  @override
  String get shoppingShopEmpty =>
      'Nichts auf der Liste. Tippe auf „Hinzufügen“ oder geh zurück zu „Planen“.';

  @override
  String get shoppingSearchClear => 'Leeren und schließen';

  @override
  String shoppingTripTitle(String name, int open) {
    return '$name · $open';
  }

  @override
  String get shoppingItemDone => 'Fertig';

  @override
  String get shoppingAddOne => 'Eins mehr';

  @override
  String get shoppingCategoryAuto =>
      'Kategorie automatisch aus dem Namen gewählt';

  @override
  String shoppingCountTimes(int count) {
    return '$count ×';
  }

  @override
  String get shoppingTilePin => 'Kachel anheften';

  @override
  String get shoppingTileUnpin => 'Anheften aufheben';

  @override
  String get shoppingTilePinHelp => 'Angeheftete Kacheln stehen immer vorn.';

  @override
  String get shoppingTilePinned => 'Angeheftet';

  @override
  String get shoppingTileStarter => 'Vorschlag';

  @override
  String get tripEntryNewTitle => 'Option hinzufügen';

  @override
  String get tripEntryEditTitle => 'Eintrag bearbeiten';

  @override
  String get tripEntryName => 'Name';

  @override
  String get tripEntryNameRequired => 'Gib einen Namen ein.';

  @override
  String get tripEntryMode => 'Verkehrsmittel';

  @override
  String tripEntryPrice(String currency) {
    return 'Preis ($currency)';
  }

  @override
  String tripEntryPriceFrom(String date) {
    return 'Preis vom $date';
  }

  @override
  String get tripEntryPriceInvalid =>
      'Gib einen Betrag ein, z. B. 840 oder 1249,50.';

  @override
  String get tripEntryLink => 'Link';

  @override
  String get tripEntryLinkInvalid =>
      'Nimm eine Webadresse, die mit http:// oder https:// beginnt.';

  @override
  String get tripEntryPasteLink => 'Link einfügen';

  @override
  String get tripEntryPasteNone =>
      'In der Zwischenablage ist keine Webadresse.';

  @override
  String get tripEntryOpenLink => 'Link öffnen';

  @override
  String get tripEntryOpenFailed => 'Das konnte nicht geöffnet werden.';

  @override
  String get tripEntryMore => 'Mehr Angaben';

  @override
  String get tripEntryLess => 'Weniger Angaben';

  @override
  String get tripEntryDetails => 'Details';

  @override
  String get tripEntryDetailsHint => '1 Stopp, Gepäck inklusive';

  @override
  String get tripEntryFrom => 'Von';

  @override
  String get tripEntryTo => 'Nach';

  @override
  String get tripEntryPickUpPlace => 'Abholort';

  @override
  String get tripEntryReturnPlace => 'Rückgabeort';

  @override
  String get tripEntryStartTransport => 'Abfahrt';

  @override
  String get tripEntryEndTransport => 'Ankunft';

  @override
  String get tripEntryStartStay => 'Einchecken';

  @override
  String get tripEntryEndStay => 'Auschecken';

  @override
  String get tripEntryStartRental => 'Abholung';

  @override
  String get tripEntryEndRental => 'Rückgabe';

  @override
  String get tripEntryStartPlain => 'Beginn';

  @override
  String get tripEntryEndPlain => 'Ende';

  @override
  String get tripEntryAddDate => 'Datum wählen';

  @override
  String get tripEntryAddTime => 'Uhrzeit wählen';

  @override
  String get tripEntryClearDate => 'Datum entfernen';

  @override
  String get tripEntryClearTime => 'Uhrzeit entfernen';

  @override
  String get tripEntryEndBeforeStart => 'Das Ende liegt vor dem Beginn.';

  @override
  String get tripEntryCancelUntil => 'Gratis stornierbar bis';

  @override
  String get tripEntryAddress => 'Adresse';

  @override
  String get tripEntryOpenAddress => 'Auf der Karte zeigen';

  @override
  String get tripEntryPhone => 'Telefon';

  @override
  String get tripEntryCallPhone => 'Anrufen';

  @override
  String get tripEntryBookingRef => 'Buchungsnummer';

  @override
  String get tripEntryNote => 'Notiz';

  @override
  String get tripEntryState => 'Stand';

  @override
  String get tripEntryCopy => 'Als weitere Option kopieren';

  @override
  String get tripEntryCopied => 'Kopiert. Das ist die Kopie.';

  @override
  String get tripEntryDelete => 'Eintrag löschen';

  @override
  String get tripEntryDeleteTitle => 'Diesen Eintrag löschen?';

  @override
  String tripEntryDeleteBody(String title) {
    return '„$title“ wird aus der Reise und aus gemerkten Kombinationen entfernt.';
  }

  @override
  String get tripEntryGone => 'Diese Reise gibt es nicht mehr.';

  @override
  String get tripEntryUnavailable =>
      'Reisen sind auf diesem Gerät nicht verfügbar.';

  @override
  String get tripCompareTitle => 'Vergleichen';

  @override
  String get tripCompareUnavailable =>
      'Vergleichen ist auf diesem Gerät nicht verfügbar.';

  @override
  String get tripCompareGone => 'Diese Reise gibt es nicht mehr.';

  @override
  String tripCompareSection(String kind, int count) {
    return '$kind · $count';
  }

  @override
  String tripCompareStripLabel(String kind) {
    return '$kind, Optionen nebeneinander';
  }

  @override
  String get tripCompareCheapest => 'Günstigste';

  @override
  String tripComparePerNight(String price) {
    return '$price pro Nacht';
  }

  @override
  String tripComparePerDay(String price) {
    return '$price pro Tag';
  }

  @override
  String get tripCompareNoPrice => 'Noch kein Preis';

  @override
  String tripCompareFromTo(String from, String to) {
    return '$from – $to';
  }

  @override
  String tripCompareRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String tripCompareFreeCancel(String date) {
    return 'Gratis stornierbar bis $date';
  }

  @override
  String get tripCompareCancelPassed => 'Gratis stornieren geht nicht mehr';

  @override
  String tripCompareTick(String title) {
    return '„$title“ in der Kombination ausprobieren';
  }

  @override
  String get tripCompareEdit => 'Bearbeiten';

  @override
  String get tripCompareAdd => 'Option hinzufügen';

  @override
  String get tripCompareAddTransport => 'Transport hinzufügen';

  @override
  String get tripCompareAddStay => 'Unterkunft hinzufügen';

  @override
  String get tripCompareAddRental => 'Mietwagen hinzufügen';

  @override
  String get tripCompareEmptyTitle => 'Noch keine Optionen';

  @override
  String get tripCompareEmptyMessage =>
      'Sammelt hier Flüge, Unterkünfte und Mietwagen, vergleicht sie und probiert Kombinationen aus.';

  @override
  String get tripCompareHint =>
      'Hake je eine Option pro Art an und merke dir dann die Kombination.';

  @override
  String get tripComboSection => 'Gemerkte Kombinationen';

  @override
  String tripComboTotal(String amount) {
    return 'Total $amount';
  }

  @override
  String tripComboTotalAtLeast(String amount) {
    return 'Mindestens $amount';
  }

  @override
  String tripComboNights(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nächte',
      one: '1 Nacht',
    );
    return '$_temp0';
  }

  @override
  String tripComboDates(String dates, String nights) {
    return '$dates · $nights';
  }

  @override
  String get tripComboNoDates => 'Noch kein Zeitraum';

  @override
  String get tripComboFits => 'Passt zusammen';

  @override
  String tripComboWarningsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Punkte passen nicht',
      one: '1 Punkt passt nicht',
    );
    return '$_temp0';
  }

  @override
  String get tripComboShowAll => 'Alle zeigen';

  @override
  String get tripComboShowLess => 'Weniger zeigen';

  @override
  String get tripComboKeep => 'Als Kombination merken';

  @override
  String tripComboWarnNights(int count, String dates) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Nächte ohne Unterkunft: $dates',
      one: '1 Nacht ohne Unterkunft: $dates',
    );
    return '$_temp0';
  }

  @override
  String tripComboWarnRentalNoTransport(String name) {
    return '$name: Mietwagen ohne Transport';
  }

  @override
  String tripComboWarnRentalBefore(String name) {
    return '$name beginnt vor der Ankunft';
  }

  @override
  String tripComboWarnRentalAfter(String name) {
    return '$name endet nach der Abreise';
  }

  @override
  String tripComboWarnOverlap(String first, String second, String dates) {
    return '$first und $second überschneiden sich: $dates';
  }

  @override
  String tripComboWarnPrice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Optionen ohne Preis, die Summe ist ein Mindestwert',
      one: '1 Option ohne Preis, die Summe ist ein Mindestwert',
    );
    return '$_temp0';
  }

  @override
  String get tripComboKeepTitle => 'Kombination merken';

  @override
  String get tripComboName => 'Name der Kombination';

  @override
  String get tripComboKept => 'Kombination gemerkt.';

  @override
  String get tripComboRename => 'Umbenennen';

  @override
  String get tripComboLoad => 'In die Haken laden';

  @override
  String tripComboLoaded(String name) {
    return '„$name“ ist geladen. Ändere die Haken und merke sie dir wieder.';
  }

  @override
  String get tripComboDelete => 'Kombination löschen';

  @override
  String tripComboDeleteTitle(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get tripComboDeleteBody => 'Die Optionen selbst bleiben erhalten.';

  @override
  String get tripComboTake => 'Diese nehmen';

  @override
  String tripComboTakeTitle(String name) {
    return '„$name“ nehmen?';
  }

  @override
  String get tripComboTakeBody =>
      'Diese werden zu den gewählten. Andere gewählte Transporte, Unterkünfte und Mietwagen werden wieder zu Optionen. Gebuchte bleiben, wie sie sind.';

  @override
  String tripComboSetDates(String dates) {
    return 'Auch die Reisedaten auf $dates setzen';
  }

  @override
  String tripComboTaken(int chosen, int released) {
    return 'Gewählt: $chosen. Zurück zu Optionen: $released.';
  }

  @override
  String tripComboTakenDates(int chosen, int released) {
    return 'Gewählt: $chosen. Zurück zu Optionen: $released. Die Reisedaten sind gesetzt.';
  }

  @override
  String get settingsGroupShoppingTitle => 'Einkaufen';

  @override
  String get settingsGroupShoppingSubtitle => 'Gelernte Wörter';

  @override
  String get settingsSectionLearnedWords => 'Gelernte Wörter';

  @override
  String get tripWindowsTitle => 'Zeitfenster';

  @override
  String get tripWindowsUnavailable => 'Reisen gibt es hier nicht.';

  @override
  String get tripWindowsIntro =>
      'Wann können wir verreisen? Das sind die Zeiten, in denen alle frei sind, die mitkommen.';

  @override
  String get tripWindowsLengthLabel => 'Kürzester Aufenthalt';

  @override
  String get tripWindowsWhoLabel => 'Wer verreist?';

  @override
  String get tripWindowsWhoHint => 'Ohne Auswahl sind alle dabei.';

  @override
  String tripWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get tripWindowKindLongWeekend => 'Langes Wochenende';

  @override
  String get tripWindowHolidaysFallback => 'Ferien';

  @override
  String tripWindowLeave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Urlaubstage für die Erwachsenen',
      one: '1 Urlaubstag für die Erwachsenen',
      zero: 'Kein Urlaub nötig',
    );
    return '$_temp0';
  }

  @override
  String tripWindowPartialBefore(String name, String date) {
    return '$name hat schon ab $date frei';
  }

  @override
  String tripWindowPartialAfter(String name, String date) {
    return '$name hat noch bis $date frei';
  }

  @override
  String get tripWindowFree => 'Nichts im Weg';

  @override
  String get tripWindowConflicts => 'Im Weg';

  @override
  String get tripWindowTake => 'Diese Tage nehmen';

  @override
  String get tripWindowTakeHelp => 'Reisetage';

  @override
  String get tripWindowTaken => 'Die Tage sind jetzt in der Reise.';

  @override
  String get tripWindowWhere => 'Wo ist es dann schön?';

  @override
  String get tripWindowNewTrip => 'Neue Reise in diesem Zeitfenster';

  @override
  String get tripWindowNewTripTitle => 'Neue Reise';

  @override
  String get tripWindowNewTripLabel => 'Name der Reise';

  @override
  String get tripWindowEmpty =>
      'Noch kein freies Zeitfenster gefunden. Die Schulferien kommen aus den Einstellungen für Region und Schule, und die Tage lassen sich bei einer Reise immer auch von Hand eintragen.';

  @override
  String get tripWindowEmptyAction => 'Einstellungen für Region und Schule';

  @override
  String get tripDiscoverTitle => 'Wohin?';

  @override
  String get tripDiscoverUnavailable => 'Reisen gibt es hier nicht.';

  @override
  String get tripDiscoverWhen => 'Reisezeit';

  @override
  String get tripDiscoverChange => 'Ändern';

  @override
  String get tripDiscoverPickHelp => 'Wann wollt ihr los?';

  @override
  String get tripDiscoverWishes => 'Wünsche';

  @override
  String get tripDiscoverWishesNone => 'Noch keine Wünsche';

  @override
  String tripDiscoverWishesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wünsche',
      one: '1 Wunsch',
    );
    return '$_temp0';
  }

  @override
  String get tripDiscoverAny => 'egal';

  @override
  String tripDiscoverDegrees(int degrees) {
    return '$degrees °C';
  }

  @override
  String get tripDiscoverTempMinLabel => 'Tagsüber mindestens';

  @override
  String get tripDiscoverTempMaxLabel => 'Tagsüber höchstens';

  @override
  String get tripDiscoverDry => 'Wenig Regen';

  @override
  String get tripDiscoverSeaLabel => 'Meer mindestens';

  @override
  String get tripDiscoverTagsLabel => 'Art des Ortes';

  @override
  String get tripDiscoverTagSea => 'Meer';

  @override
  String get tripDiscoverTagIsland => 'Insel';

  @override
  String get tripDiscoverTagMountains => 'Berge';

  @override
  String get tripDiscoverTagLake => 'See';

  @override
  String get tripDiscoverTagCity => 'Stadt';

  @override
  String get tripDiscoverTagCountryside => 'Land';

  @override
  String get tripDiscoverTagNorth => 'Der Norden';

  @override
  String get tripDiscoverTagLongHaul => 'Weit weg';

  @override
  String get tripDiscoverEffortLabel => 'Anreise höchstens';

  @override
  String get tripDiscoverEffortNear => 'nah';

  @override
  String get tripDiscoverEffortCar => 'eine lange Autofahrt';

  @override
  String get tripDiscoverEffortShort => 'ein Kurzstreckenflug';

  @override
  String get tripDiscoverEffortMedium => 'ein Mittelstreckenflug';

  @override
  String get tripDiscoverEffortLong => 'weit weg';

  @override
  String get tripDiscoverNeedsClimate =>
      'Mit einem Wetterdienst zeigt WuselWall, wie warm es ist. Ein Elternteil kann einen einschalten.';

  @override
  String get tripDiscoverNeedsHome =>
      'Für Entfernungen braucht es einen Ort für Zuhause. Ein Elternteil kann ihn eintragen.';

  @override
  String get tripDiscoverOpenServices => 'Einstellungen für Wetter und Karten';

  @override
  String get tripDiscoverIdea => 'Eure Idee';

  @override
  String get tripDiscoverKeep => 'Als Idee merken';

  @override
  String tripDiscoverKept(String name) {
    return 'Als Idee gemerkt: $name';
  }

  @override
  String get tripDiscoverOpen => 'Öffnen';

  @override
  String tripDiscoverDistance(String km, String effort) {
    return 'etwa $km km · $effort';
  }

  @override
  String tripDiscoverTemps(int max, int min) {
    return '$max° tags, $min° nachts';
  }

  @override
  String tripDiscoverRain(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Regentage',
      one: '1 Regentag',
    );
    return '$_temp0';
  }

  @override
  String tripDiscoverSun(int hours) {
    return '$hours Std. Sonne am Tag';
  }

  @override
  String tripDiscoverSea(int temp) {
    return 'Meer $temp°';
  }

  @override
  String get tripDiscoverNoClimate => 'Noch keine Klimawerte';

  @override
  String get tripDiscoverMisses => 'Erfüllt nicht alle Wünsche';

  @override
  String tripDiscoverPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'noch $count Orte',
      one: 'noch 1 Ort',
    );
    return 'Klimawerte werden geladen: $_temp0';
  }

  @override
  String get tripDiscoverPendingLater =>
      'Weitere Werte folgen später; der Anbieter erlaubt nur ein paar Orte pro Minute.';

  @override
  String get tripDiscoverEmpty =>
      'Kein Ort passt zu diesen Wünschen. Lockert einen oder zwei.';

  @override
  String get tripDiscoverNote =>
      'Das sind typische Werte für die Jahreszeit, keine Vorhersage. WuselWall nennt kein Hotel, keinen Preis und keine Verbindung, und die Entfernungen sind Schätzungen.';

  @override
  String get tripHomeTitle => 'Zuhause';

  @override
  String get tripHomeNotSet => 'Nicht festgelegt';

  @override
  String get tripHomeExplain =>
      'Wird auf etwa einen Kilometer gerundet gespeichert. Es dient für Entfernungen und wird mit einem Routendienst an diesen Dienst gesendet.';

  @override
  String get tripHomeSet => 'Festlegen';

  @override
  String get tripHomeChange => 'Ändern';

  @override
  String get tripHomeForget => 'Vergessen';

  @override
  String get tripHomeForgetAsk =>
      'Den Ort für Zuhause vergessen? Die Entfernungen verschwinden, bis ein neuer festgelegt ist.';

  @override
  String get tripHomeDialogTitle => 'Ort für Zuhause';

  @override
  String get tripHomeName => 'Name des Ortes';

  @override
  String get tripHomeSearch => 'Suchen';

  @override
  String get tripHomeNoResults => 'Kein Ort gefunden.';

  @override
  String get tripHomeCoordsHint =>
      'Oder die Koordinaten von Hand eintragen, mit zwei Nachkommastellen.';

  @override
  String get tripHomeNoGeocode =>
      'Es ist keine Ortssuche eingeschaltet; die Koordinaten müssen von Hand eingetragen werden.';

  @override
  String get tripHomeLat => 'Breitengrad';

  @override
  String get tripHomeLon => 'Längengrad';

  @override
  String get tripHomeInvalid =>
      'Breitengrad von -90 bis 90, Längengrad von -180 bis 180.';

  @override
  String get serviceTitle => 'Wetter und Karten';

  @override
  String get serviceUnavailable => 'Wetter und Karten gibt es hier nicht.';

  @override
  String get serviceNoProviders => 'Dieser Server bietet keine Anbieter an.';

  @override
  String get serviceIntro =>
      'Alles hier ist aus, bis ihr es einschaltet. Nur euer Server fragt einen Anbieter, nie ein Handy oder die Wand. Ein Anbieter erfährt den Ort, den ihr anseht oder sucht, und die Adresse eures Servers, nichts über eure Familie.';

  @override
  String get serviceReadOnly => 'Das kann ein Elternteil ändern.';

  @override
  String get serviceProvidersHeading => 'Anbieter';

  @override
  String get serviceCostFree => 'Gratis, ohne Schlüssel';

  @override
  String get serviceCostFreeKey => 'Gratis mit eigenem Schlüssel';

  @override
  String get serviceCostPaidKey => 'Eigener Schlüssel, kann kosten';

  @override
  String get serviceCapClimate => 'Typisches Klima';

  @override
  String get serviceCapForecast => 'Vorhersage';

  @override
  String get serviceCapGeocode => 'Ortssuche';

  @override
  String get serviceCapRoute => 'Fahrzeit';

  @override
  String get serviceCapMap => 'Kartenbild';

  @override
  String get serviceReceivesCoordinates => 'die Koordinaten eines Ortes';

  @override
  String get serviceReceivesSearchText => 'den Text, den ihr sucht';

  @override
  String get serviceReceivesHome => 'euren Ort für Zuhause, gerundet';

  @override
  String serviceReceivesLine(String what) {
    return 'Es erhält: $what';
  }

  @override
  String get serviceWebsite => 'Webseite';

  @override
  String get serviceGetKey => 'Schlüssel holen';

  @override
  String get serviceSwitch => 'Eingeschaltet';

  @override
  String get serviceNeedsKeyFirst => 'Braucht zuerst einen Schlüssel';

  @override
  String get serviceKeyLabel => 'Schlüssel';

  @override
  String get serviceKeyHelp =>
      'Einmal eingetippt, auf eurem Server gespeichert und nie wieder angezeigt.';

  @override
  String get serviceKeySaveOn => 'Schlüssel speichern und einschalten';

  @override
  String get serviceKeySave => 'Schlüssel speichern';

  @override
  String serviceKeyStored(String hint) {
    return 'Schlüssel gespeichert $hint';
  }

  @override
  String get serviceKeyReplace => 'Ersetzen';

  @override
  String get serviceKeyRemove => 'Entfernen';

  @override
  String serviceKeyRemoveAsk(String name) {
    return 'Den Schlüssel von $name entfernen? Der Anbieter wird dann ausgeschaltet.';
  }

  @override
  String get serviceTest => 'Testen';

  @override
  String get serviceTestOk => 'Funktioniert';

  @override
  String get serviceErrorKeyMissing =>
      'Dieser Anbieter braucht einen Schlüssel.';

  @override
  String get serviceErrorUnauthorized =>
      'Der Anbieter hat den Schlüssel abgelehnt.';

  @override
  String get serviceErrorQuota =>
      'Das Kontingent beim Anbieter ist vorerst aufgebraucht.';

  @override
  String get serviceErrorTimeout =>
      'Der Anbieter hat nicht rechtzeitig geantwortet.';

  @override
  String get serviceErrorGeneric =>
      'Der Anbieter hat diesmal nicht funktioniert.';

  @override
  String serviceLastError(String reason) {
    return 'Letzter Aufruf: $reason';
  }

  @override
  String get serviceUsedFor => 'Verwendet für';

  @override
  String get serviceMoveUp => 'Früher fragen';

  @override
  String get serviceMoveDown => 'Später fragen';

  @override
  String get serviceOrderHint =>
      'Wo mehrere Anbieter dasselbe können, gewinnt der erste in dieser Reihenfolge, der antwortet.';

  @override
  String serviceCallsToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufrufe heute',
      one: '1 Aufruf heute',
    );
    return '$_temp0';
  }

  @override
  String get serviceClosing =>
      'Die Bedingungen eines Anbieters nehmt ihr selbst an; manche kostenlosen Angebote gelten nur für private Nutzung. Schaltet ihr einen Anbieter aus, stoppt jeder Aufruf sofort.';

  @override
  String get learnedWordsHelp =>
      'Diese Wörter hat die Familie gelernt: Der Artikel kommt künftig in diese Kategorie. Vergessen nimmt ein Wort wieder weg.';

  @override
  String get learnedWordsEmpty =>
      'Noch nichts gelernt. Wenn jemand die Kategorie eines Artikels ändert, merkt sich die Familie das Wort hier.';

  @override
  String learnedWordsMeta(String category, String date) {
    return '$category · $date';
  }

  @override
  String learnedWordsMetaBy(String category, String name, String date) {
    return '$category · von $name, $date';
  }

  @override
  String get learnedWordsForget => 'Vergessen';

  @override
  String learnedWordsForgetWord(String word) {
    return '„$word“ vergessen';
  }

  @override
  String serverCaption(String host) {
    return 'Server: $host';
  }

  @override
  String get serverConfirmTitle => 'Mit diesem Server verbinden?';

  @override
  String get serverConfirmBody =>
      'Hier liegen die Daten deiner Familie, und hier meldest du dich an. Verbinde dich nur, wenn du diese Adresse kennst, etwa von deiner Familie. Im Zweifel abbrechen und die Adresse selbst eintippen.';

  @override
  String serverConfirmVia(String address) {
    return '$address verweist auf diesen Server.';
  }

  @override
  String serverMovedBody(String host) {
    return 'Der Server nennt eine neue Adresse: $host. Die App bleibt bei der bisherigen, bis du neu verbindest.';
  }

  @override
  String serverMovedConfirm(String host) {
    return 'Mit $host verbinden? Dieses Gerät meldet sich dabei ab, danach meldest du dich dort neu an. Nur wenn du sicher bist, dass der Server umgezogen ist.';
  }

  @override
  String get serverKeyChangedBody =>
      'Der Server hat neue Verbindungsdaten für die App. Verbinde neu, damit die App sie verwendet.';

  @override
  String get serverMovedAction => 'Neu verbinden';

  @override
  String get accountMfaRequired =>
      'Bestätige zuerst den Code aus deiner Authenticator-App und versuche es dann noch einmal.';

  @override
  String accountPasswordReauthBody(String email) {
    return 'Zum Ändern des Passworts brauchen wir eine frische Anmeldung. Wir schicken einen Code an $email.';
  }

  @override
  String accountPasswordReauthPasswordBody(String email) {
    return 'Zum Ändern des Passworts brauchen wir eine frische Anmeldung. Gib das bisherige Passwort von $email ein.';
  }

  @override
  String accountResetReauthBody(String email) {
    return 'Zum Zurücksetzen bei einer anderen Person brauchen wir deine frische Anmeldung. Wir schicken einen Code an $email.';
  }

  @override
  String accountResetReauthPasswordBody(String email) {
    return 'Zum Zurücksetzen bei einer anderen Person brauchen wir deine frische Anmeldung. Gib das Passwort von $email ein.';
  }

  @override
  String accountMfaResetRecent(String name) {
    return 'Du hast die Zwei-Faktor-Anmeldung von $name vor weniger als einem Tag zurückgesetzt. Ein anderer Elternteil kann den Code erstellen, oder du wartest einen Tag.';
  }

  @override
  String accountPasswordResetRecent(String name) {
    return 'Du hast für $name vor weniger als einem Tag einen Passwort-Code erstellt. Ein anderer Elternteil kann die Zwei-Faktor-Anmeldung zurücksetzen, oder du wartest einen Tag.';
  }

  @override
  String get accountPasswordSavedOthersOut =>
      'Passwort gespeichert. Deine anderen Geräte wurden abgemeldet.';

  @override
  String trustFeedCreatedBy(String name) {
    return 'Erstellt von $name';
  }

  @override
  String get errInvitationRequired =>
      'Dieser Server nimmt nur eingeladene Personen auf. Lass dich von einem Elternteil der Familie einladen.';

  @override
  String get errTripInvalid =>
      'Die Reise ist nicht gültig. Prüfe den Namen und die Daten.';

  @override
  String get errTripNotFound => 'Diese Reise gibt es nicht mehr.';

  @override
  String get errTripEntryInvalid =>
      'Der Eintrag ist nicht gültig. Prüfe Name, Daten und Preis.';

  @override
  String get errTripEntryNotFound => 'Diesen Eintrag gibt es nicht mehr.';

  @override
  String get errTripComboInvalid =>
      'Die Kombination ist nicht gültig. Prüfe ihren Namen und ihre Einträge.';

  @override
  String get errTripComboNotFound => 'Diese Kombination gibt es nicht mehr.';

  @override
  String get errTripCheckInvalid => 'Der Listenpunkt ist nicht gültig.';

  @override
  String get errTripCheckNotFound => 'Diesen Listenpunkt gibt es nicht mehr.';

  @override
  String get errTripEvent =>
      'Der Kalendereintrag einer Reise wird in der Reise geändert, nicht im Kalender.';

  @override
  String get errTripHomeInvalid => 'Dieser Heimatort ist nicht gültig.';

  @override
  String get errAdultsOnly => 'Das dürfen nur Erwachsene.';

  @override
  String get errServiceInvalid =>
      'Diese Einstellung des Dienstes ist nicht gültig.';

  @override
  String get errServiceOff =>
      'Dafür braucht es einen Wetter- oder Kartendienst. Ein Elternteil kann einen in den Einstellungen einschalten.';

  @override
  String get errServiceKeyMissing =>
      'Dieser Dienst braucht einen Schlüssel. Ein Elternteil kann ihn in den Einstellungen eintragen.';

  @override
  String get errServiceLimit =>
      'Dieser Dienst wurde zu oft gefragt. Versuch es später noch einmal.';

  @override
  String get errServiceFailed =>
      'Der Dienst hat nicht geantwortet. Versuch es später noch einmal.';

  @override
  String get tripsTitle => 'Reisen';

  @override
  String get tripStageIdea => 'Idee';

  @override
  String get tripStagePlanned => 'Geplant';

  @override
  String get tripStageFixed => 'Fest';

  @override
  String get tripKindTransport => 'Transport';

  @override
  String get tripKindStay => 'Unterkunft';

  @override
  String get tripKindRental => 'Mietwagen';

  @override
  String get tripKindActivity => 'Aktivität';

  @override
  String get tripKindNote => 'Notiz';

  @override
  String get tripKindTransportPlural => 'Transport';

  @override
  String get tripKindStayPlural => 'Unterkünfte';

  @override
  String get tripKindRentalPlural => 'Mietwagen';

  @override
  String get tripKindActivityPlural => 'Aktivitäten';

  @override
  String get tripKindNotePlural => 'Notizen';

  @override
  String get tripModeFlight => 'Flug';

  @override
  String get tripModeTrain => 'Zug';

  @override
  String get tripModeCar => 'Auto';

  @override
  String get tripModeFerry => 'Fähre';

  @override
  String get tripModeBus => 'Bus';

  @override
  String get tripModeOther => 'Anderes';

  @override
  String get tripStateOption => 'Option';

  @override
  String get tripStateChosen => 'Gewählt';

  @override
  String get tripStateBooked => 'Gebucht';

  @override
  String accountNoticeMfaResetYou(String name) {
    return '$name hat deine Zwei-Faktor-Anmeldung zurückgesetzt';
  }

  @override
  String accountNoticeMfaReset(String name, String target) {
    return '$name hat die Zwei-Faktor-Anmeldung von $target zurückgesetzt';
  }

  @override
  String accountNoticePasswordResetYou(String name) {
    return '$name hat einen Passwort-Code für dich erstellt';
  }

  @override
  String accountNoticePasswordReset(String name, String target) {
    return '$name hat einen Passwort-Code für $target erstellt';
  }

  @override
  String get totpSingleGuardianWarning =>
      'Du hast als einziger Elternteil ein angemeldetes Konto. Wenn du den Zugang zu deiner Authenticator-App verlierst, kann kein anderer Elternteil deinen zweiten Faktor zurücksetzen. Lade zuerst einen zweiten Elternteil ein und lass ihn sich anmelden, oder sichere deinen Authenticator getrennt. Sonst brauchst du Hilfe von der Person, die euren Server betreibt. Trotzdem einschalten?';

  @override
  String get packItemTile => 'Mitbringen';

  @override
  String get packItemTileHelp => 'Für ein Kind, an einem Tag';

  @override
  String get packItemAdd => 'Etwas mitbringen';

  @override
  String get packItemWho => 'Wer bringt es mit';

  @override
  String get packItemWhen => 'Wann';

  @override
  String get packItemToday => 'Heute';

  @override
  String get packItemTomorrow => 'Morgen';

  @override
  String get packItemDayAfter => 'Übermorgen';

  @override
  String get packItemOtherDay => 'Anderer Tag …';

  @override
  String get packItemWhat => 'Was';

  @override
  String get packItemWhatHint => 'z. B. Turnbeutel, unterschriebener Zettel';

  @override
  String get packItemSave => 'Hinzufügen';

  @override
  String packItemSaved(String name, String title) {
    return 'Für $name notiert: $title';
  }

  @override
  String packItemRemove(String title) {
    return '$title entfernen';
  }

  @override
  String packItemRemoved(String title) {
    return '$title entfernt';
  }

  @override
  String get errPackItemInvalid =>
      'Das lässt sich so nicht notieren: höchstens 80 Zeichen, für ein Kind der Familie, höchstens 20 Dinge pro Tag.';

  @override
  String get errPackItemNotFound => 'Das steht nicht mehr auf der Packliste.';

  @override
  String get errPackItemNotYours =>
      'Du kannst nur für dich selbst etwas notieren.';
}

/// The translations for German, as used in Austria (`de_AT`).
class AppLocalizationsDeAt extends AppLocalizationsDe {
  AppLocalizationsDeAt() : super('de_AT');

  @override
  String get settingSchoolEquipmentHelp =>
      'Zeigt aus dem Stundenplan von morgen, was mitgebracht werden muss, zum Beispiel Turnsachen.';

  @override
  String get mealsSlotSnack => 'Jause';

  @override
  String get taskIcon_trash => 'Mistkübel';

  @override
  String get kidWhoAreYou => 'Servus! Tipp auf deinen Namen.';

  @override
  String kidGreeting(String name) {
    return 'Servus, $name!';
  }

  @override
  String get settingNotifyPackingHelp =>
      'Um diese Uhrzeit sagt dein Handy, was für morgen in die Schultasche gehört, aus den Stundenplänen (zum Beispiel Turnsachen). Nur wenn etwas einzupacken ist.';

  @override
  String get settingAmbienceNewYearHelp =>
      'Kleines Feuerwerk am Nachthimmel am 31. Dezember und 1. Jänner.';

  @override
  String wuselHelloMorning3(String name) {
    return 'Servus $name, schön, dass du wach bist.';
  }

  @override
  String wuselHelloDay1(String name) {
    return 'Servus $name!';
  }

  @override
  String wuselHelloEvening3(String name) {
    return 'Servus $name! Bald ist Ausruhzeit.';
  }

  @override
  String get wishPickerOwnHint => 'z. B. Palatschinken';

  @override
  String get mealIcon_pancakes => 'Palatschinken';

  @override
  String get mealIcon_potato => 'Erdäpfel';

  @override
  String get eventStarterSchoolTrip => 'Wandertag';

  @override
  String get eventStarterSchoolTest => 'Schularbeit';

  @override
  String get packItemWhatHint => 'z. B. Turnsackerl, unterschriebener Zettel';
}

/// The translations for German, as used in Switzerland (`de_CH`).
class AppLocalizationsDeCh extends AppLocalizationsDe {
  AppLocalizationsDeCh() : super('de_CH');

  @override
  String get close => 'Schliessen';

  @override
  String get boardShoppingAskAdult =>
      'Die Einkaufsliste ist für die Grossen. Tipp auf deinen Namen.';

  @override
  String boardPeriod(int index) {
    return '$index. Lektion';
  }

  @override
  String boardTasksOf(String name) {
    return 'Ämtli von $name';
  }

  @override
  String get boardTasksComingSoon => 'Hier erscheinen die Ämtli.';

  @override
  String get errSettingInvalid =>
      'Dieser Wert liegt ausserhalb des erlaubten Bereichs.';

  @override
  String get settingValueLunch => 'Zmittag';

  @override
  String get settingValueDinner => 'Znacht';

  @override
  String get settingTasksBonusPointsTitle => 'Punkte für ein Bonus-Ämtli';

  @override
  String get settingTasksBonusPointsHelp =>
      'Ein Bonus-Ämtli reicht für die günstigste Startbelohnung, sodass ein jüngeres Kind schnell ankommt.';

  @override
  String get settingTasksKindTitle => 'Neue Ämtli sind';

  @override
  String get settingTasksKindHelp =>
      'Ein neues Ämtli ist eine Pflicht, bis jemand es bewusst zum Bonus macht.';

  @override
  String get settingTasksVerificationTitle => 'Eltern prüfen Ämtli';

  @override
  String get settingTasksVerificationHelp =>
      'Prüfen macht aus jedem Ämtli eine Kontrolle. Nur für wertvolle Bonus-Ämtli einschalten.';

  @override
  String get settingSchoolReportHelp =>
      'Nur Eltern pflegen den Stundenplan. Mit dieser Option kann ein Kind melden, dass eine Lektion ausfällt; ein Elternteil bestätigt es.';

  @override
  String get settingSchoolEquipmentHelp =>
      'Zeigt aus dem Stundenplan von morgen, was mitgebracht werden muss, zum Beispiel Turnsachen.';

  @override
  String get settingMealsSchoolDayHelp =>
      'Die warme Mahlzeit auf der Küchenwand. Beide an heisst zwei warme Mahlzeiten, beide aus keine. An Schultagen essen Kinder mittags oft in der Schule oder im Hort.';

  @override
  String get settingMealsAwayTitle => 'Abwesend heisst nicht essen';

  @override
  String get settingMemberCompletionSoundTitle =>
      'Ton beim Abhaken eines Ämtlis';

  @override
  String get settingMemberCompletionSoundHelp =>
      'Beim Abhaken eines Ämtlis ertönt ein kurzer Ton. Ausschalten, wenn du ihn nicht willst.';

  @override
  String get settingNotifyMorningHelp =>
      'Die heutigen Ämtli und Termine für dich. Offene Einlösungen erscheinen hier für Eltern.';

  @override
  String get settingNotifyTaskVerifiedTitle => 'Wenn ein Ämtli bestätigt wird';

  @override
  String get settingNotifyTaskVerifiedHelp =>
      'Eine Benachrichtigung, wenn ein Elternteil ein Ämtli bestätigt und die Punkte gutgeschrieben werden.';

  @override
  String get eventImportTooLarge =>
      'Diese Datei ist zu gross für einen einzelnen Termin.';

  @override
  String get eventImportUnreadable => 'Die Datei liess sich nicht öffnen.';

  @override
  String get tasksTitle => 'Ämtli';

  @override
  String get mealsSlotBreakfast => 'Zmorge';

  @override
  String get mealsSlotLunch => 'Zmittag';

  @override
  String get mealsSlotDinner => 'Znacht';

  @override
  String get mealsSlotSnack => 'Zvieri';

  @override
  String get schoolAddLesson => 'Lektion hinzufügen';

  @override
  String get feedSummarySchoolLessons => 'Lektionen';

  @override
  String get feedSchoolHint => 'Schultage als ganzer Tag oder jede Lektion.';

  @override
  String get tasksTabChores => 'Ämtli';

  @override
  String get tasksNoChores => 'Noch keine Ämtli.';

  @override
  String get tasksStarterHelp =>
      'Fünf Ämtli, drei Belohnungen und vier Abzeichen zum Start. Alles lässt sich danach ändern.';

  @override
  String get tasksNewChore => 'Neues Ämtli';

  @override
  String get tasksEditChore => 'Ämtli bearbeiten';

  @override
  String get taskIcon_trash => 'Abfallkübel';

  @override
  String get taskIcon_bike => 'Velo';

  @override
  String get tasksPickOpenPool => 'Wer darf es übernehmen? Leer heisst alle.';

  @override
  String get tasksArchiveHelp =>
      'Das Ämtli verschwindet. Seine offenen Termine in der Zukunft werden entfernt.';

  @override
  String get tasksFieldStock => 'Vorrat (leer heisst unbegrenzt)';

  @override
  String get tasksLedgerTask => 'Ämtli erledigt';

  @override
  String get errTaskInvalid => 'Dieses Ämtli ist nicht gültig.';

  @override
  String get errTaskNotOpen => 'Dieses Ämtli ist nicht mehr offen.';

  @override
  String get kidWhoAreYou => 'Hoi! Tipp auf deinen Namen.';

  @override
  String kidGreeting(String name) {
    return 'Hoi $name!';
  }

  @override
  String get kidTasksTitle => 'Meine Ämtli';

  @override
  String get kidTasksNone => 'Heute hast du keine Ämtli.';

  @override
  String kidOpenTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ämtli offen',
      one: '1 Ämtli offen',
      zero: 'Keine Ämtli offen',
    );
    return '$_temp0';
  }

  @override
  String get todayEmpty => 'Heute ist noch nichts geplant. Geniess die Ruhe.';

  @override
  String get todayTasksTitle => 'Deine Ämtli heute';

  @override
  String todayApprovalsChecks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ämtli zu prüfen',
      one: '1 Ämtli zu prüfen',
    );
    return '$_temp0';
  }

  @override
  String get extCalEmpty =>
      'Noch kein Kalender abonniert. Ein Abo bringt Termine von aussen in den Familienkalender, zum Beispiel den Spielplan deines Vereins.';

  @override
  String get extCalErrTooLarge => 'Der Kalender ist zu gross (mehr als 2 MB).';

  @override
  String get feedSubTitle => 'Kalender von aussen einschliessen';

  @override
  String get feedSubHelp =>
      'Termine aus importierten Kalendern (z. B. Verein, Kehrichtabfuhr) erscheinen auch im Abo.';

  @override
  String get feedSubSummary => 'Kalender von aussen';

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
      other: '$tasks Ämtli',
      one: '1 Ämtli',
    );
    return 'Heute: $_temp0, $_temp1';
  }

  @override
  String reminderMorningTasksOnly(int tasks) {
    String _temp0 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks Ämtli',
      one: '1 Ämtli',
    );
    return 'Heute: $_temp0';
  }

  @override
  String get firstRunKidBody =>
      'Tipp auf dein Bild, dann weiss WuselWall, wer du bist.';

  @override
  String get householdSeedExamples =>
      'Mit Beispielen starten — 5 Ämtli, 3 Belohnungen';

  @override
  String get inviteRoleLineMember =>
      'Als weitere:r Erwachsene:r erledigst du Ämtli, bestätigst aber keine Belohnungen.';

  @override
  String get inviteRoleMemberHelp =>
      'Erledigt Ämtli, bestätigt aber keine Belohnungen. Etwa für eine Au-pair oder Grosseltern.';

  @override
  String get shortcutForWhomHelp =>
      'Der Kurzbefehl handelt als diese Person: Er hakt ihre Ämtli ab und nennt ihre Punkte.';

  @override
  String shortcutAssistantKeyOnce(String name) {
    return 'Dieser Schlüssel wird nur jetzt angezeigt. Damit liest ein Assistent als $name die ganze Woche der Familie: Termine, wer weg ist, die Stundenpläne der Kinder, Ämtli, Essen und die Einkaufsliste. Was er liest, geht an den Anbieter des Assistenten. Behandle den Schlüssel wie ein Passwort.';
  }

  @override
  String get settingNotifyPackingHelp =>
      'Um diese Uhrzeit sagt dein Handy, was für morgen in den Thek gehört, aus den Stundenplänen (zum Beispiel Turnsachen). Nur wenn etwas einzupacken ist.';

  @override
  String get schoolTimetableNeedsTerm =>
      'Die angezeigte Woche gehört noch zu keinem Zeitraum. Lege den Zeitraum an, zu dem sie gehört, und trage danach die Lektionen ein.';

  @override
  String schoolImportLessons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Lektionen',
      one: '1 Lektion',
    );
    return '$_temp0';
  }

  @override
  String schoolImportReplaces(String name, int count) {
    return 'Ersetzt den bestehenden Stundenplan von $name ($count Lektionen).';
  }

  @override
  String get schoolImportSkipNewSubjects =>
      'Lektionen mit neuen Fächern werden weggelassen.';

  @override
  String schoolImportWarnUnmatchedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Lektionen passen zu keiner Klingelzeit und werden weggelassen.',
      one: '1 Lektion passt zu keiner Klingelzeit und wird weggelassen.',
    );
    return '$_temp0';
  }

  @override
  String schoolImportWarnPeriodsExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die Klingelzeiten bekommen $count weitere Lektionen.',
      one: 'Die Klingelzeiten bekommen 1 weitere Lektion.',
    );
    return '$_temp0';
  }

  @override
  String get schoolImportErrNoLessons => 'Der Text enthält keine Lektionen.';

  @override
  String get schoolImportErrBadLesson =>
      'Eine Lektion hat keinen Tag, keine Lektionsnummer oder kein Fach.';

  @override
  String schoolProposalSummary(String name, int count) {
    return 'Stundenplan für $name, $count Lektionen';
  }

  @override
  String get schoolScanTooLarge => 'Das Foto ist zu gross (höchstens 6 MB).';

  @override
  String get familyLocaleHelp =>
      'Feiertage auf der Wandanzeige heissen in dieser Sprache.';

  @override
  String get memberRoleHelp =>
      'Eltern sehen alles und bestätigen Belohnungen. Weitere Erwachsene haken Ämtli ab.';

  @override
  String get memberInactiveBody =>
      'Nicht auf der Wand, in den Avatar-Reihen und bei neuen Ämtli. Verlauf und Punkte bleiben.';

  @override
  String memberDeactivateBody(String name) {
    return '$name verschwindet von der Wand, aus den Avatar-Reihen und aus neuen Ämtli. Verlauf und Punkte bleiben, und du kannst die Person hier zurückholen.';
  }

  @override
  String get settingAmbienceStNicholasTitle => 'Samichlaus';

  @override
  String get settingValueMainMeals => 'Zmittag und Znacht';

  @override
  String wuselHelloMorning3(String name) {
    return 'Hoi $name, schön, dass du wach bist.';
  }

  @override
  String wuselHelloDay1(String name) {
    return 'Hoi $name!';
  }

  @override
  String wuselHelloEvening3(String name) {
    return 'Hoi $name! Bald ist Ausruhzeit.';
  }

  @override
  String wuselWallMemberDone3(String name) {
    return 'Alle Ämtli von $name sind erledigt!';
  }

  @override
  String get wuselFerienFirst3 =>
      'Erster Ferientag. Geniesst die Zeit zusammen!';

  @override
  String get traditionStarterSundayBreakfast => 'Sonntagszmorge';

  @override
  String get eventIcon_croissant => 'Zmorge';

  @override
  String get wishPickerOwnHint => 'z. B. Omeletten';

  @override
  String get mealIcon_pancakes => 'Omeletten';

  @override
  String weekReviewChores(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ämtli erledigt',
      one: '1 Ämtli erledigt',
      zero: 'Eine Woche zum Durchatmen',
    );
    return '$_temp0';
  }

  @override
  String get weekHighlightHelped => 'hat bei den Ämtli mitgeholfen';

  @override
  String get settingsGroupTasksTitle => 'Ämtli & Belohnungen';

  @override
  String get settingsGroupTasksShortTitle => 'Ämtli';

  @override
  String get settingsGroupMealsSubtitle =>
      'Warme Mahlzeit, Wunschessen und Mittagstisch';

  @override
  String get eventStarterGuestDinner => 'Gäste zum Znacht';

  @override
  String get eventStarterHoliday => 'Familienferien';

  @override
  String get eventStarterSchoolTrip => 'Schulreise';

  @override
  String get eventStarterSchoolTest => 'Prüfung';

  @override
  String get eventStarterSportsDay => 'Sporttag';

  @override
  String get tripPlanOutside => 'Ausserhalb der Reisedaten';

  @override
  String get shoppingSearchClear => 'Leeren und schliessen';

  @override
  String get packItemWhatHint => 'z. B. Turnsack, unterschriebener Zettel';
}
