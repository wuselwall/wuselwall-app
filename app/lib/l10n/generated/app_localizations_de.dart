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
  String get setupTitle => 'Einrichtung';

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
  String get setupHeadline => 'Dieses Gerät ist noch nicht eingerichtet';

  @override
  String get setupBody =>
      'Richte dieses Gerät mit einem Code von einem Erziehungsberechtigten ein, melde dich als Erziehungsberechtigter an oder lege einen neuen Haushalt an.';

  @override
  String get setupEnrolAction => 'Dieses Gerät mit Code einrichten';

  @override
  String get setupSignInAction => 'Als Erziehungsberechtigter anmelden';

  @override
  String get setupHouseholdAction => 'Neuen Haushalt einrichten';

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
  String get enrolTitle => 'Gerät einrichten';

  @override
  String get enrolBody =>
      'Gib den Code ein, der auf einem bereits eingerichteten Gerät angezeigt wird.';

  @override
  String get enrolCodeLabel => 'Einrichtungscode';

  @override
  String get enrolAction => 'Einrichten';

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
}
