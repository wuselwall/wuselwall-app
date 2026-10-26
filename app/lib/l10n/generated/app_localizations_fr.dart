// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'WuselWall';

  @override
  String get unexpectedError => 'Une erreur inattendue est survenue';

  @override
  String get retry => 'Réessayer';

  @override
  String get errorNetwork =>
      'Impossible de se connecter au serveur. Vérifie ta connexion et réessaie.';

  @override
  String get errorAuth => 'Tu n’es pas connecté ou ta session a expiré.';

  @override
  String get errorPermission => 'Tu n’as pas l’autorisation de faire cela.';

  @override
  String get errorNotFound => 'Cet élément est introuvable.';

  @override
  String get errorConflict =>
      'Cela entre en conflit avec un élément déjà existant.';

  @override
  String get errorValidation => 'Cette saisie n’est pas valide.';

  @override
  String get errorUnknown => 'Un problème est survenu.';

  @override
  String configMissing(String missing) {
    return 'Il manque la configuration de cette version : $missing';
  }

  @override
  String get registerAdult => 'Adulte';

  @override
  String get registerKid => 'Enfant';

  @override
  String get registerKiosk => 'Écran mural';

  @override
  String get systemTitle => 'Système';

  @override
  String get systemBuild => 'Version de compilation';

  @override
  String get systemEnvironment => 'Environnement';

  @override
  String get systemBackendUrl => 'URL du serveur';

  @override
  String get systemConnectivity => 'Connectivité';

  @override
  String get systemNetwork => 'Réseau';

  @override
  String get systemOnline => 'En ligne';

  @override
  String get systemOffline => 'Hors ligne';

  @override
  String get systemUnknown => 'Inconnu';

  @override
  String get systemBackend => 'Serveur';

  @override
  String get systemStatus => 'État';

  @override
  String get systemStatusOk => 'OK';

  @override
  String get systemDbVersion => 'Version de la base de données';

  @override
  String get systemServerTime => 'Heure du serveur';

  @override
  String get setupHeadline => 'Bienvenue sur WuselWall';

  @override
  String get setupOfflineWelcome =>
      'Vous êtes hors ligne. Connectez-vous à Internet pour vous connecter, accepter une invitation ou connecter un appareil partagé. Ces options seront disponibles dès que vous serez de nouveau en ligne.';

  @override
  String get doorTagline => 'Le planning familial sur le mur de la cuisine';

  @override
  String get setupHouseholdAction => 'Créer une nouvelle famille';

  @override
  String get wizardTitle => 'Nouveau foyer';

  @override
  String get wizardCreate => 'Créer le foyer';

  @override
  String get fieldSetupToken => 'Jeton de configuration';

  @override
  String get fieldHouseholdName => 'Nom du foyer';

  @override
  String get fieldYourName => 'Ton prénom';

  @override
  String get fieldEmail => 'E-mail';

  @override
  String get fieldPassword => 'Mot de passe (au moins 10 caractères)';

  @override
  String get fieldPasswordSimple => 'Mot de passe';

  @override
  String get fieldPin => 'Code PIN à 6 chiffres';

  @override
  String get fieldRequired => 'Obligatoire';

  @override
  String get signInTitle => 'Connexion';

  @override
  String get signInAction => 'Se connecter';

  @override
  String get enrolTitle => 'Connecter cet appareil';

  @override
  String get enrolBody =>
      'Saisis le code affiché sur un appareil déjà connecté.';

  @override
  String get enrolCodeLabel => 'Code de connexion de l’appareil';

  @override
  String get enrolAction => 'Connecter';

  @override
  String get errSetupTokenInvalid =>
      'Le jeton de configuration n’est pas valide.';

  @override
  String get errSetupClosed => 'Ce système est déjà configuré.';

  @override
  String get errPasswordTooShort =>
      'Le mot de passe doit contenir au moins 10 caractères.';

  @override
  String get errPinFormat => 'Le code PIN doit contenir exactement 6 chiffres.';

  @override
  String get errCodeInvalid => 'Ce code est incorrect ou a expiré.';

  @override
  String get errGuardianRequired =>
      'Seul un responsable parental peut faire cela.';

  @override
  String get errDeviceRevoked => 'Cet appareil a été bloqué.';

  @override
  String get errActorRequired => 'Appuie d’abord sur ton prénom.';

  @override
  String get errNameRequired => 'Saisis un nom.';

  @override
  String get errInvalidLogin =>
      'L’adresse e-mail ou le mot de passe est incorrect.';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get close => 'Fermer';

  @override
  String get delete => 'Supprimer';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get shoppingTitle => 'Liste de courses';

  @override
  String get shoppingAddHint => 'Ajouter un article';

  @override
  String get shoppingQuantityHint => 'Quantité';

  @override
  String get shoppingEmpty => 'Rien à acheter';

  @override
  String get shoppingFinish => 'Terminer les courses';

  @override
  String get shoppingFinishConfirm =>
      'Terminer ces courses ? Les articles cochés seront retirés, les autres resteront sur la liste.';

  @override
  String shoppingFinished(int bought, int left) {
    return '$bought achetés, $left conservés sur la liste';
  }

  @override
  String get actingWho => 'Qui es-tu ?';

  @override
  String get pinTitle => 'Code PIN parental';

  @override
  String pinPrompt(String name) {
    return 'Saisis le code PIN de $name';
  }

  @override
  String pinWrong(int left) {
    return 'Code PIN incorrect. Il reste $left tentatives.';
  }

  @override
  String get pinBackoff => 'Trop de tentatives. Patiente un instant.';

  @override
  String get pinLocked =>
      'Code PIN verrouillé. Un responsable parental doit se connecter pour le déverrouiller.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsMembers => 'Membres';

  @override
  String get settingsDevices => 'Appareils';

  @override
  String get addMember => 'Ajouter un membre';

  @override
  String get memberName => 'Prénom';

  @override
  String get roleGuardian => 'Responsable parental';

  @override
  String get roleMember => 'Membre';

  @override
  String get addDevice => 'Ajouter un appareil';

  @override
  String get deviceLabel => 'Nom de l’appareil';

  @override
  String get createCode => 'Créer un code';

  @override
  String get enrolmentCodeTitle => 'Code de connexion de l’appareil';

  @override
  String get enrolmentCodeHint =>
      'Saisis ce code sur le nouvel appareil dans les 10 minutes. Il ne fonctionne qu’une fois.';

  @override
  String get thisDevice => 'cet appareil';

  @override
  String get deviceRevoked => 'bloqué';

  @override
  String get revoke => 'Bloquer';

  @override
  String revokeConfirm(String device) {
    return 'Bloquer « $device » ? Il perdra immédiatement son accès.';
  }

  @override
  String get signOutDevice => 'Déconnecter cet appareil';

  @override
  String get classPersonal => 'Personnel';

  @override
  String get classShared => 'Partagé';

  @override
  String get classSharedHint =>
      'Plusieurs personnes l’utilisent : appuie sur un prénom pour changer de profil.';

  @override
  String get classKiosk => 'Écran mural';

  @override
  String get systemDevice => 'Cet appareil';

  @override
  String get systemRegister => 'Interface';

  @override
  String get systemEnrolled => 'Connecté';

  @override
  String get errRateLimited =>
      'Trop de tentatives. Patiente quelques minutes et réessaie.';

  @override
  String get errMfaRequired =>
      'Saisis d’abord le code de ton application d’authentification.';

  @override
  String get scanQr => 'Scanner un code QR';

  @override
  String get scanTitle => 'Scanner le code de configuration';

  @override
  String get enrolmentQrLabel => 'Code QR du code de connexion de l’appareil';

  @override
  String get mfaTitle => 'Second facteur';

  @override
  String get mfaBody =>
      'Saisis le code à 6 chiffres de ton application d’authentification.';

  @override
  String get mfaCodeLabel => 'Code à 6 chiffres';

  @override
  String get mfaVerify => 'Confirmer';

  @override
  String get registerTitle => 'Nommer cet appareil';

  @override
  String registerBody(String name) {
    return '$name, ce téléphone est nouveau dans le foyer. Donne-lui un nom pour pouvoir le reconnaître (et le bloquer) plus tard.';
  }

  @override
  String registerDefaultLabel(String name) {
    return 'Téléphone de $name';
  }

  @override
  String get registerAction => 'Utiliser cet appareil';

  @override
  String get signInPasskey => 'Se connecter avec une clé d’accès';

  @override
  String get settingsSecurity => 'Sécurité';

  @override
  String get totpTitle => 'Connexion à deux facteurs';

  @override
  String get totpOn => 'Activée : un code est demandé à chaque connexion.';

  @override
  String get totpOff => 'Désactivée';

  @override
  String get totpEnable => 'Activer';

  @override
  String get totpDisable => 'Désactiver';

  @override
  String get totpScanBody =>
      'Scanne ce code avec une application d’authentification, puis saisis le code à 6 chiffres qu’elle affiche.';

  @override
  String get totpQrLabel =>
      'Code QR pour configurer l’application d’authentification';

  @override
  String get passkeyTitle => 'Clé d’accès';

  @override
  String get passkeyBody =>
      'Connecte-toi avec ton empreinte digitale ou ton visage plutôt qu’un mot de passe.';

  @override
  String get passkeyAdd => 'Ajouter';

  @override
  String get passkeyAdded => 'Clé d’accès ajoutée.';

  @override
  String get shoppingHistory => 'Historique';

  @override
  String get shoppingHistoryEmpty => 'Aucune course terminée pour le moment';

  @override
  String get shoppingSearchHint => 'Rechercher ou ajouter';

  @override
  String get shoppingTilesEmpty =>
      'Les vignettes apparaîtront ici après vos premiers achats. Saisis un nom pour ajouter un article.';

  @override
  String shoppingInTrolley(int count) {
    return 'Dans le chariot ($count)';
  }

  @override
  String get shoppingUncategorised => 'Sans catégorie';

  @override
  String get shoppingNewList => 'Nouvelle liste';

  @override
  String get shoppingListName => 'Nom';

  @override
  String get shoppingListKind => 'Organisation';

  @override
  String get shoppingKindSupermarket => 'Supermarché';

  @override
  String get shoppingKindDrugstore => 'Droguerie';

  @override
  String get shoppingKindHardware => 'Magasin de bricolage';

  @override
  String get shoppingKindOther => 'Autre';

  @override
  String get shoppingMakeDefault => 'Définir comme liste par défaut';

  @override
  String get shoppingEditItem => 'Modifier l’article';

  @override
  String get shoppingSpecHint => 'Précision, par exemple bio ou 500 g';

  @override
  String get shoppingCategory => 'Catégorie';

  @override
  String get shoppingRemoveOne => 'Un de moins';

  @override
  String get shoppingRemoveItem => 'Retirer';

  @override
  String shoppingItemRemoved(String name) {
    return '« $name » retiré de la liste';
  }

  @override
  String get shoppingUndo => 'Annuler';

  @override
  String get errListExists => 'Une liste portant ce nom existe déjà.';

  @override
  String get errSpecTooLong =>
      'Cette précision est trop longue (40 caractères maximum).';

  @override
  String get errKioskForbidden =>
      'Cette action n’est pas possible sur l’écran mural.';

  @override
  String get shoppingCat_produce => 'Fruits et légumes';

  @override
  String get shoppingCat_bakery => 'Pain et boulangerie';

  @override
  String get shoppingCat_dairy => 'Produits laitiers et fromages';

  @override
  String get shoppingCat_meat_fish => 'Viande et poisson';

  @override
  String get shoppingCat_pantry => 'Épicerie';

  @override
  String get shoppingCat_frozen => 'Surgelés';

  @override
  String get shoppingCat_drinks => 'Boissons';

  @override
  String get shoppingCat_household => 'Maison';

  @override
  String get shoppingCat_other => 'Autres';

  @override
  String get shoppingCat_care => 'Hygiène et soins';

  @override
  String get shoppingCat_baby => 'Bébés et enfants';

  @override
  String get shoppingCat_cleaning => 'Entretien';

  @override
  String get shoppingCat_health => 'Santé';

  @override
  String get shoppingCat_tools => 'Outils';

  @override
  String get shoppingCat_screws => 'Vis et fixations';

  @override
  String get shoppingCat_electrical => 'Électricité';

  @override
  String get shoppingCat_garden => 'Jardin';

  @override
  String shoppingCreateTile(String name) {
    return 'Ajouter « $name »';
  }

  @override
  String shoppingAddedBy(String name) {
    return 'Ajouté par $name';
  }

  @override
  String get pinChangeTitle => 'Code PIN parental';

  @override
  String get pinChangeBody =>
      'Définis un nouveau code PIN à 6 chiffres. Cela déverrouille aussi un code PIN bloqué après trop de tentatives incorrectes.';

  @override
  String get pinChangeAction => 'Modifier';

  @override
  String get pinChangeField => 'Nouveau code PIN (6 chiffres)';

  @override
  String get pinChanged => 'Code PIN modifié.';

  @override
  String shoppingTripItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String shoppingPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente d’envoi',
      one: '1 modification en attente d’envoi',
    );
    return '$_temp0';
  }

  @override
  String get shoppingItemPending => 'En attente d’envoi';

  @override
  String get errCategoryNotFound =>
      'Cette catégorie n’existe plus. La modification n’a pas été enregistrée.';

  @override
  String get errNameTooLong => 'Ce nom est trop long.';

  @override
  String get errActorInvalid =>
      'Cette personne ne fait plus partie du foyer. La modification n’a pas été enregistrée.';

  @override
  String get doorEmail => 'Continuer par e-mail';

  @override
  String get doorOr => 'ou';

  @override
  String get errSignupDisabled =>
      'Il n’y a pas encore de compte WuselWall pour cette adresse. Demande une invitation à ta famille ou crée une nouvelle famille.';

  @override
  String get errEmailExists =>
      'Cette adresse e-mail appartient déjà à un autre compte.';

  @override
  String get signInMethodsTitle => 'Connexion';

  @override
  String get signInMethodEmail => 'Code par e-mail';

  @override
  String boardWeekNumber(int week) {
    return 'Semaine $week';
  }

  @override
  String get boardToday => 'Aujourd’hui';

  @override
  String get boardNow => 'Maintenant';

  @override
  String get boardNextUp => 'À suivre';

  @override
  String get boardThen => 'puis';

  @override
  String boardInMinutes(int minutes) {
    return 'dans $minutes min';
  }

  @override
  String boardInHours(int hours, int minutes) {
    return 'dans $hours h $minutes min';
  }

  @override
  String get boardNothingMoreToday => 'Plus rien de prévu aujourd’hui';

  @override
  String boardLastUpdatedAt(String time) {
    return 'dernière mise à jour : $time';
  }

  @override
  String get boardOffline =>
      'Pas de connexion : voici le dernier planning connu.';

  @override
  String get boardLoading => 'Chargement de la semaine…';

  @override
  String get boardZoneWhere => 'Qui est où';

  @override
  String get boardZoneMeal => 'Repas chaud';

  @override
  String get boardMorning => 'Matin';

  @override
  String get boardAfternoon => 'Après-midi';

  @override
  String get boardEvening => 'Soir';

  @override
  String boardUntil(String time) {
    return 'jusqu’à $time';
  }

  @override
  String boardFrom(String time) {
    return 'à partir de $time';
  }

  @override
  String get boardAllDay => 'toute la journée';

  @override
  String boardMoreEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count autres',
      one: '+1 autre',
    );
    return '$_temp0';
  }

  @override
  String boardMoreCount(int count) {
    return '+$count';
  }

  @override
  String get boardNoSchool => 'libre';

  @override
  String boardCareUntil(String label, String time) {
    return '$label jusqu’à $time';
  }

  @override
  String get boardCareDefault => 'Accueil périscolaire';

  @override
  String boardBusyUntil(String time) {
    return 'Rendez-vous jusqu’à $time';
  }

  @override
  String get boardMealLunch => 'Déjeuner';

  @override
  String get boardMealDinner => 'Dîner';

  @override
  String get boardMealNothingPlanned => 'rien de prévu';

  @override
  String boardMealCook(String name) {
    return '$name cuisine';
  }

  @override
  String boardMealGuests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count invités',
      one: '+1 invité',
    );
    return '$_temp0';
  }

  @override
  String boardEating(String name) {
    return '$name mange avec nous';
  }

  @override
  String boardNotEating(String name) {
    return '$name ne mange pas avec nous';
  }

  @override
  String get boardOpenToday => 'À faire aujourd’hui';

  @override
  String get boardAllDone => 'Tout est fait pour aujourd’hui';

  @override
  String get boardShoppingList => 'Liste de courses';

  @override
  String get boardNightMode => 'Vue de nuit';

  @override
  String get boardBackToWeek => 'Revenir à la semaine';

  @override
  String get boardTentative => 'pas encore confirmé';

  @override
  String get boardNoAppointments => 'Aucun rendez-vous';

  @override
  String get boardSchool => 'École';

  @override
  String boardSchoolSpan(String span) {
    return 'École $span';
  }

  @override
  String get boardNoSchoolToday => 'Pas d’école';

  @override
  String get boardWeekend => 'Week-end';

  @override
  String boardWeekOf(String name) {
    return 'La semaine de $name';
  }

  @override
  String boardTimetableTitle(String name) {
    return 'Emploi du temps de $name';
  }

  @override
  String boardClass(String label) {
    return 'Classe $label';
  }

  @override
  String boardPeriod(int index) {
    return 'Cours $index';
  }

  @override
  String get boardBreak => 'Pause';

  @override
  String get boardLessonOver => 'terminé';

  @override
  String get boardLessonNow => 'en cours';

  @override
  String get boardLessonCancelled => 'Annulé';

  @override
  String get boardLessonSubstituted => 'Remplacement';

  @override
  String get boardLessonRoomChange => 'Changement de salle';

  @override
  String get boardLessonExtra => 'Supplémentaire';

  @override
  String boardPackTomorrow(String items) {
    return 'À préparer pour demain : $items';
  }

  @override
  String boardPackToday(String items) {
    return 'À emporter aujourd’hui : $items';
  }

  @override
  String get boardWholeWeek => 'Toute la semaine';

  @override
  String get boardMealWeek => 'Les repas de la semaine';

  @override
  String boardBaseline(String label) {
    return 'D’habitude : $label';
  }

  @override
  String get boardNoDeviation => 'comme d’habitude';

  @override
  String get boardCooking => 'En cuisine';

  @override
  String get boardAppointmentsOf => 'Rendez-vous';

  @override
  String boardTasksOf(String name) {
    return 'Les tâches de $name';
  }

  @override
  String get boardTasksComingSoon =>
      'Les tâches arriveront avec la prochaine mise à jour.';

  @override
  String get presenceWorking => 'Au travail';

  @override
  String get presenceHomeOffice => 'Télétravail';

  @override
  String get presenceTravel => 'En déplacement';

  @override
  String get presenceAway => 'Absent';

  @override
  String get presenceOff => 'En congé';

  @override
  String get presenceChildcare => 'Accueil périscolaire';

  @override
  String get errSettingInvalid =>
      'Cette valeur est en dehors de la plage autorisée.';

  @override
  String get errSettingUnknown => 'Ce paramètre n’existe pas.';

  @override
  String get errSettingTarget =>
      'Ce paramètre ne peut pas être modifié pour cette personne ou cet appareil.';

  @override
  String get settingPickPersonFirst =>
      'Choisis d’abord qui tu es. Tes paramètres personnels apparaîtront ensuite ici.';

  @override
  String get settingIsDefault => 'Par défaut';

  @override
  String get settingIsCustom => 'Personnalisé';

  @override
  String get settingReset => 'Rétablir la valeur par défaut';

  @override
  String get settingOn => 'Activé';

  @override
  String get settingOff => 'Désactivé';

  @override
  String get settingFrom => 'de';

  @override
  String get settingTo => 'à';

  @override
  String get settingIncrease => 'Augmenter';

  @override
  String get settingDecrease => 'Diminuer';

  @override
  String get settingDayPartsMorningEnds => 'Le matin jusqu’à';

  @override
  String get settingDayPartsEveningStarts => 'Le soir à partir de';

  @override
  String settingUnitPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String settingUnitMinutes(int count) {
    return '$count min';
  }

  @override
  String settingUnitSeconds(int count) {
    return '$count s';
  }

  @override
  String get settingValueName => 'Prénom complet';

  @override
  String get settingValueInitial => 'Initiale';

  @override
  String get settingValueDuty => 'Responsabilité';

  @override
  String get settingValueBonus => 'Tâche bonus';

  @override
  String get settingValueRequired => 'Approbation';

  @override
  String get settingValueSelfServe => 'Échange libre';

  @override
  String get settingValueWholeFamily => 'Toute la famille';

  @override
  String get settingValueAll => 'Tous';

  @override
  String get settingValueNone => 'Aucun';

  @override
  String get settingValueLunch => 'Déjeuner';

  @override
  String get settingValueDinner => 'Dîner';

  @override
  String get settingBoardMemberLabelTitle => 'Prénoms sur le tableau';

  @override
  String get settingBoardMemberLabelHelp =>
      'À deux mètres, un prénom se lit mieux qu’une initiale. Choisis les initiales si vous recevez souvent du monde dans la cuisine.';

  @override
  String get settingTasksDutyPointsTitle => 'Points pour une responsabilité';

  @override
  String get settingTasksDutyPointsHelp =>
      'Les responsabilités font partie de la vie de famille et rapportent donc peu ou pas de points. La série est leur récompense.';

  @override
  String get settingTasksBonusPointsTitle => 'Points pour une tâche bonus';

  @override
  String get settingTasksBonusPointsHelp =>
      'Une tâche bonus suffit pour la première récompense la moins chère, afin qu’un jeune enfant puisse l’obtenir en quelques jours.';

  @override
  String get settingTasksKindTitle => 'Les nouvelles tâches sont des';

  @override
  String get settingTasksKindHelp =>
      'Une nouvelle tâche est une responsabilité, sauf si quelqu’un choisit d’en faire une tâche bonus. Les occasions de gagner des points restent ainsi limitées.';

  @override
  String get settingTasksVerificationTitle =>
      'Les responsables parentaux vérifient les tâches';

  @override
  String get settingTasksVerificationHelp =>
      'Vérifier chaque tâche revient à tout contrôler. Réserve cette option aux tâches bonus importantes.';

  @override
  String get settingTasksJokersTitle => 'Jokers de série par mois';

  @override
  String get settingTasksJokersHelp =>
      'Un joker préserve une série quand un jour est manqué. Une journée de maladie ne brise ainsi pas une série de trois semaines.';

  @override
  String get settingTasksRewardApprovalTitle =>
      'Les récompenses nécessitent une approbation';

  @override
  String get settingTasksRewardApprovalHelp =>
      'Un responsable parental approuve chaque échange avec son code PIN. L’échange libre ne convient qu’aux petites récompenses.';

  @override
  String get settingCalendarMembersEditTitle =>
      'Les membres modifient leurs propres événements';

  @override
  String get settingCalendarMembersEditHelp =>
      'Les enfants créent et modifient les événements auxquels ils participent. Seuls les responsables parentaux peuvent supprimer les événements des autres.';

  @override
  String get settingCalendarKeyDefaultTitle =>
      'Nouveaux événements sur l’écran de la cuisine';

  @override
  String get settingCalendarKeyDefaultHelp =>
      'Définit quels nouveaux événements apparaissent sur l’écran de la cuisine sans devoir cocher la case. À revoir après deux semaines d’utilisation.';

  @override
  String get settingSchoolReportTitle =>
      'Les membres signalent les changements d’emploi du temps';

  @override
  String get settingSchoolReportHelp =>
      'Seuls les responsables parentaux gèrent l’emploi du temps. Avec cette option, un enfant peut signaler un cours annulé, à confirmer par un responsable parental.';

  @override
  String get settingSchoolEquipmentTitle => 'Rappel du matériel pour demain';

  @override
  String get settingSchoolEquipmentHelp =>
      'Indique les affaires à emporter demain, comme la tenue de sport, selon les matières prévues.';

  @override
  String get settingMealsSchoolDayTitle => 'Repas chaud les jours d’école';

  @override
  String get settingMealsSchoolDayHelp =>
      'Le repas chaud affiché sur l’écran de la cuisine. Les jours d’école, les enfants déjeunent à l’école ou à l’accueil périscolaire.';

  @override
  String get settingMealsFreeDayTitle => 'Repas chaud les jours sans école';

  @override
  String get settingMealsFreeDayHelp => 'Pour les week-ends et les vacances.';

  @override
  String get settingMealsAwayTitle => 'Les absents ne participent pas au repas';

  @override
  String get settingMealsAwayHelp =>
      'Une personne absente ou en déplacement à l’heure du repas est automatiquement exclue du repas. La plupart des jours, il n’y a donc rien à saisir.';

  @override
  String get settingMealsCareCutoffTitle =>
      'Heure limite de garde pour le déjeuner';

  @override
  String get settingMealsCareCutoffHelp =>
      'Un enfant gardé au-delà de cette heure déjeune à l’extérieur.';

  @override
  String get settingBoardRolloverTitle => 'Passage à la semaine suivante';

  @override
  String get settingBoardRolloverHelp =>
      'Quand le tableau passe à la semaine suivante. Le dimanche soir, on prépare la semaine à venir ; le samedi matin, on veut encore voir celle en cours.';

  @override
  String get settingBoardDayPartsTitle => 'Matin, après-midi, soir';

  @override
  String get settingBoardDayPartsHelp =>
      'Définit les limites entre le matin, l’après-midi et le soir dans la zone des rendez-vous.';

  @override
  String get settingDeviceNightHoursTitle => 'Horaires du thème de nuit';

  @override
  String get settingDeviceNightHoursHelp =>
      'Quand l’écran mural passe au thème de nuit ambré.';

  @override
  String get settingDeviceIdleRevertTitle => 'Retour au tableau après';

  @override
  String get settingDeviceIdleRevertHelp =>
      'Durée pendant laquelle un profil ou une vue détaillée reste ouvert avant le retour au tableau mural.';

  @override
  String get settingMemberCompletionSoundTitle =>
      'Son quand une tâche est cochée';

  @override
  String get settingMemberCompletionSoundHelp =>
      'Cocher une tâche produit un son bref. Désactive-le si tu n’en veux pas.';

  @override
  String get settingCalendarTentativeTitle =>
      'Vérifier les événements incertains à';

  @override
  String get settingCalendarTentativeHelp =>
      'Demande si un événement provisoire aura bien lieu, pour ne pas le laisser incertain jusqu’à son début.';

  @override
  String get settingNotifyMorningTitle => 'Résumé du matin';

  @override
  String get settingNotifyMorningHelp =>
      'Tes tâches et événements du jour. Les responsables parentaux y voient aussi les demandes de récompenses en attente.';

  @override
  String get settingNotifyEventReminderTitle => 'Rappel avant les événements';

  @override
  String get settingNotifyEventReminderHelp =>
      'Une notification avant le début d’un événement.';

  @override
  String get settingNotifyTaskVerifiedTitle => 'Quand une tâche est validée';

  @override
  String get settingNotifyTaskVerifiedHelp =>
      'Une notification quand un responsable parental valide une tâche et que les points sont crédités.';

  @override
  String get settingNotifyRedemptionTitle =>
      'Quand une récompense est demandée';

  @override
  String get settingNotifyRedemptionHelp =>
      'Une notification immédiate quand un enfant demande une récompense.';

  @override
  String boardCareShort(String label, String time) {
    return '$label $time';
  }

  @override
  String get calendarTitle => 'Calendrier';

  @override
  String get calendarDay => 'Jour';

  @override
  String get calendarThreeDays => '3 jours';

  @override
  String get calendarWeek => 'Semaine';

  @override
  String get calendarPrevious => 'Précédent';

  @override
  String get calendarNext => 'Suivant';

  @override
  String get calendarChooseView => 'Vue du calendrier';

  @override
  String get calendarToday => 'Aujourd’hui';

  @override
  String calendarRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get calendarNewEvent => 'Nouvel événement';

  @override
  String get calendarEmpty => 'Rien de prévu';

  @override
  String get calendarEditorPlaceholder =>
      'L’éditeur d’événements arrive bientôt.';

  @override
  String get eventEditTitle => 'Modifier l’événement';

  @override
  String get eventTitleLabel => 'Titre';

  @override
  String get eventTitleRequired => 'Saisis un titre.';

  @override
  String get eventKindAppointment => 'Rendez-vous';

  @override
  String get eventKindPresence => 'Présence';

  @override
  String get eventPresenceState => 'Situation';

  @override
  String get eventPresenceStateRequired => 'Choisis une situation.';

  @override
  String get eventAllDay => 'Toute la journée';

  @override
  String get eventStarts => 'Début';

  @override
  String get eventEnds => 'Fin';

  @override
  String get eventEndBeforeStart => 'La fin doit être après le début.';

  @override
  String get eventAttendees => 'Qui';

  @override
  String get eventAttendeesWholeFamily =>
      'Personne de sélectionné : cet événement concerne toute la famille.';

  @override
  String get eventLocation => 'Lieu';

  @override
  String get eventNotes => 'Notes';

  @override
  String get eventTentative => 'Pas encore confirmé';

  @override
  String get eventKeyDisplay => 'Afficher sur l’écran de la cuisine';

  @override
  String get eventKeyDisplayOn =>
      'Cet événement s’affiche sur l’écran de la cuisine.';

  @override
  String get eventKeyDisplayOff =>
      'Cet événement ne s’affiche pas sur l’écran de la cuisine.';

  @override
  String get eventKeyDisplayOffWholeFamily =>
      'Cet événement ne s’affiche pas sur l’écran de la cuisine. Les événements de toute la famille s’y affichent d’eux-mêmes.';

  @override
  String get eventRepeat => 'Répétition';

  @override
  String get eventRepeatNever => 'Jamais';

  @override
  String get eventRepeatDaily => 'Tous les jours';

  @override
  String get eventRepeatWeekly => 'Toutes les semaines';

  @override
  String get eventRepeatBiweekly => 'Toutes les 2 semaines';

  @override
  String get eventRepeatMonthly => 'Tous les mois';

  @override
  String get eventRepeatSpecificDays => 'Jours précis (planning de travail)';

  @override
  String eventRepeatMonthlyDay(int day) {
    return 'le $day';
  }

  @override
  String eventRepeatMonthlyNth(int n, String weekday) {
    return 'le $nᵉ $weekday du mois';
  }

  @override
  String eventRepeatMonthlyLast(String weekday) {
    return 'le dernier $weekday';
  }

  @override
  String get eventRepeatDays => 'Ces jours-là';

  @override
  String get eventRepeatEnds => 'Fin de la répétition';

  @override
  String get eventRepeatUntil => 'à une date';

  @override
  String eventRepeatCount(int count) {
    return 'après $count fois';
  }

  @override
  String eventDaysPicked(int count) {
    return '$count jours';
  }

  @override
  String get eventDienstplanHelp =>
      'Appuie sur les jours concernés. Le jour de début est toujours inclus.';

  @override
  String get eventCustomRule => 'Règle personnalisée';

  @override
  String get eventCustomRuleHelp =>
      'Cette répétition ne peut pas être modifiée ici. Elle reste telle quelle.';

  @override
  String get eventWeekdaysRequired => 'Choisis au moins un jour de la semaine.';

  @override
  String get eventDeleteConfirm => 'Supprimer cet événement ?';

  @override
  String get eventScopeTitle => 'Quels événements ?';

  @override
  String get eventScopeDeleteTitle => 'Quels événements supprimer ?';

  @override
  String get eventScopeThis => 'Cet événement uniquement';

  @override
  String get eventScopeSeries => 'Tous les événements de la série';

  @override
  String get errEventInvalid => 'Cet événement n’est pas valide.';

  @override
  String get errRruleInvalid =>
      'Cette répétition ne peut pas être enregistrée.';

  @override
  String get errAttendeeInvalid =>
      'Une personne sélectionnée n’appartient pas à ce foyer.';

  @override
  String get errEventNotFound => 'Cet événement n’existe plus.';

  @override
  String get scheduleTitle => 'Emploi du temps';

  @override
  String get tasksTitle => 'Tâches';

  @override
  String get mealsTitle => 'Repas';

  @override
  String get comingSoon => 'Cette partie est en cours de construction.';

  @override
  String mealsWeekRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get mealsPrevWeek => 'Semaine précédente';

  @override
  String get mealsNextWeek => 'Semaine suivante';

  @override
  String get mealsThisWeek => 'Cette semaine';

  @override
  String get mealsRecipes => 'Recettes';

  @override
  String get mealsFillShopping => 'Compléter la liste de courses';

  @override
  String get mealsSlotBreakfast => 'Petit-déjeuner';

  @override
  String get mealsSlotLunch => 'Déjeuner';

  @override
  String get mealsSlotDinner => 'Dîner';

  @override
  String get mealsSlotSnack => 'Collation';

  @override
  String get mealsNothingYet => 'Rien de prévu pour le moment';

  @override
  String get mealsAddOther => 'Ajouter un repas';

  @override
  String get mealsDragHint =>
      'Maintiens un repas appuyé, puis dépose-le sur un autre jour pour le déplacer.';

  @override
  String mealsEditTitle(String day) {
    return 'Repas du $day';
  }

  @override
  String get mealsFieldLabel => 'Plat ou note';

  @override
  String get mealsFieldHint => 'Pizza, restes, nom d’une recette…';

  @override
  String get mealsSuggestionHelp =>
      'Recettes correspondantes. Appuie sur une recette pour la choisir ; ses ingrédients seront alors ajoutés à la liste de courses.';

  @override
  String get mealsServings => 'Portions';

  @override
  String get mealsCook => 'Qui cuisine';

  @override
  String get mealsCookNobody => 'Personne';

  @override
  String get mealsTime => 'Heure';

  @override
  String get mealsTimeNone => 'Sans horaire';

  @override
  String get mealsGuests => 'Invités';

  @override
  String get mealsEatingTitle => 'Qui mange avec nous';

  @override
  String get mealsEatingHelp =>
      'Une personne absente ou en déplacement au moment du repas, ou un enfant gardé au-delà de l’heure limite, est automatiquement exclu du repas. Modifie ce choix à la main seulement si nécessaire.';

  @override
  String get mealsEatingAuto => 'Automatique';

  @override
  String get mealsEatingYes => 'Participe au repas';

  @override
  String get mealsEatingNo => 'Ne participe pas au repas';

  @override
  String get mealsDelete => 'Supprimer le repas';

  @override
  String get mealsPreviewTitle => 'Compléter la liste de courses';

  @override
  String get mealsPreviewEmpty =>
      'Rien à ajouter. Les repas saisis en texte libre n’ont pas d’ingrédients ; les recettes ajoutent les leurs à la liste.';

  @override
  String get mealsPreviewOnList => 'Déjà sur la liste';

  @override
  String mealsPreviewFor(String meals) {
    return 'Pour $meals';
  }

  @override
  String mealsPreviewAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
      zero: 'aucun article',
    );
    return 'Ajouter $_temp0';
  }

  @override
  String mealsPreviewAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles ajoutés à la liste de courses',
      one: '1 article ajouté à la liste de courses',
    );
    return '$_temp0';
  }

  @override
  String get mealsRecipesTitle => 'Recettes';

  @override
  String get mealsRecipeSearch => 'Rechercher des recettes';

  @override
  String get mealsRecipesEmpty =>
      'Pas encore de recettes. Un nom de plat suffit pour un repas ; une recette ajoute ses ingrédients à la liste de courses.';

  @override
  String get mealsRecipeNew => 'Nouvelle recette';

  @override
  String get mealsRecipeEdit => 'Modifier la recette';

  @override
  String get mealsRecipeTitleField => 'Titre';

  @override
  String get mealsIngredients => 'Ingrédients';

  @override
  String get mealsIngredientName => 'Ingrédient';

  @override
  String get mealsIngredientQuantity => 'Quantité';

  @override
  String get mealsIngredientUnit => 'Unité';

  @override
  String get mealsIngredientNote => 'Note';

  @override
  String get mealsIngredientAdd => 'Ajouter un ingrédient';

  @override
  String get mealsIngredientRemove => 'Retirer l’ingrédient';

  @override
  String get mealsIngredientMove => 'Faire glisser pour réorganiser';

  @override
  String get mealsNoIngredients => 'Aucun ingrédient indiqué.';

  @override
  String get mealsSteps => 'Préparation';

  @override
  String get mealsStepsHint => 'Une étape par ligne';

  @override
  String get mealsTags => 'Mots-clés';

  @override
  String get mealsTagsHint =>
      'Séparés par des virgules, par exemple rapide, végétarien';

  @override
  String get mealsSourceUrl => 'Lien de la source';

  @override
  String get mealsSource => 'Source';

  @override
  String get mealsRecipeSave => 'Enregistrer la recette';

  @override
  String get mealsRecipeDelete => 'Supprimer la recette';

  @override
  String mealsRecipeDeleteConfirm(String title) {
    return 'Supprimer « $title » ? Les repas qui utilisent cette recette conserveront leur nom.';
  }

  @override
  String get mealsRecipeTitleRequired => 'Une recette doit avoir un titre.';

  @override
  String get mealsKioskHint =>
      'Appuie sur un point pour modifier les participants au repas';

  @override
  String get errMealInvalid =>
      'Ce repas n’a pas pu être enregistré. Vérifie la saisie et réessaie.';

  @override
  String get schoolSetupCardTitle => 'Configurer l’école';

  @override
  String get schoolSetupCardBody =>
      'Ajoute l’école. Les horaires de cours et les matières sont proposés ; ensuite, saisis l’emploi du temps ou importe-le.';

  @override
  String get schoolSetupAction => 'Configurer l’école';

  @override
  String get schoolEnterTimetableTitle => 'Saisir l’emploi du temps';

  @override
  String schoolEnterTimetableBody(String name) {
    return 'Il n’y a pas encore d’emploi du temps pour $name pour la semaine affichée.';
  }

  @override
  String get schoolEnterTimetableAction => 'Saisir l’emploi du temps';

  @override
  String get schoolNoChildren => 'Aucun enfant dans le foyer pour le moment.';

  @override
  String get schoolEditSchool => 'Modifier l’école';

  @override
  String get schoolEditTimetable => 'Modifier l’emploi du temps';

  @override
  String get schoolPrevWeek => 'Semaine précédente';

  @override
  String get schoolNextWeek => 'Semaine suivante';

  @override
  String get schoolThisWeek => 'Cette semaine';

  @override
  String schoolWeekLabel(int week, String from, String to) {
    return 'Semaine $week · $from – $to';
  }

  @override
  String get schoolChooseChild => 'Choisir un enfant';

  @override
  String schoolHolidayBand(String name, String range) {
    return '$name · $range';
  }

  @override
  String get schoolNoLessonsToday => 'Pas de cours';

  @override
  String get schoolPackTomorrowNone => 'Rien à préparer pour demain.';

  @override
  String schoolLessonActions(String subject, String day, String period) {
    return '$subject, $day, $period';
  }

  @override
  String get schoolCancelLesson => 'Annulé';

  @override
  String get schoolSubstitute => 'Remplacement';

  @override
  String get schoolRoomChange => 'Salle modifiée';

  @override
  String get schoolResetException => 'Réinitialiser';

  @override
  String get schoolPickSubject => 'Matière';

  @override
  String get schoolSearchSubject => 'Rechercher une matière';

  @override
  String get schoolTeacher => 'Enseignant';

  @override
  String get schoolNote => 'Note';

  @override
  String get schoolRoom => 'Salle';

  @override
  String get schoolApply => 'Appliquer';

  @override
  String get schoolSaved => 'Enregistré.';

  @override
  String get schoolNoSubjects =>
      'Aucune matière pour le moment. Ajoute-les dans la configuration de l’école.';

  @override
  String get schoolSetupTitle => 'École';

  @override
  String get schoolSectionSchool => 'École';

  @override
  String get schoolName => 'Nom de l’école';

  @override
  String get schoolBellTimes => 'Horaires des cours et des pauses';

  @override
  String get schoolAddLesson => 'Ajouter un cours';

  @override
  String get schoolAddBreak => 'Ajouter une pause';

  @override
  String get schoolRemove => 'Retirer';

  @override
  String get schoolStart => 'Début';

  @override
  String get schoolEnd => 'Fin';

  @override
  String get schoolTerms => 'Périodes scolaires';

  @override
  String get schoolAddTerm => 'Ajouter une période';

  @override
  String get schoolTermEdit => 'Modifier la période';

  @override
  String get schoolTermNew => 'Nouvelle période';

  @override
  String get schoolTermName => 'Nom';

  @override
  String get schoolTermNameHint =>
      'p. ex. Année scolaire 2026/27 ou 1er semestre';

  @override
  String get schoolFrom => 'Du';

  @override
  String get schoolTo => 'Au';

  @override
  String get schoolTermPickDate => 'Choisir une date';

  @override
  String get schoolTermEndBeforeStart => 'Se termine avant le début';

  @override
  String schoolTermMustCoverWeek(String week) {
    return 'Doit inclure la semaine affichée ($week)';
  }

  @override
  String get schoolAbWeeks => 'Semaines A et B';

  @override
  String get schoolAbWeeksHint =>
      'À activer si l’emploi du temps alterne d’une semaine à l’autre.';

  @override
  String get schoolAbWeek => 'Numéro d’une semaine A';

  @override
  String get schoolAbWeekHint =>
      'Numéro de semaine, par exemple 43. Ensuite les semaines alternent : B, A, B…';

  @override
  String schoolAbWeekShown(int week) {
    return 'La semaine affichée est la semaine $week.';
  }

  @override
  String get schoolAbWeekInvalid => 'Saisissez un numéro de semaine de 1 à 53';

  @override
  String get schoolCurrent => 'en cours';

  @override
  String get schoolCurrentTerm => 'Période en cours';

  @override
  String get schoolCurrentTermHint =>
      'Marque la période où vous êtes maintenant. Une seule par école.';

  @override
  String get schoolSubjects => 'Matières';

  @override
  String get schoolAddSubject => 'Ajouter une matière';

  @override
  String get schoolSubjectEdit => 'Matière';

  @override
  String get schoolSubjectShort => 'Abréviation';

  @override
  String get schoolTint => 'Couleur';

  @override
  String get schoolEquipment => 'Affaires à emporter';

  @override
  String get schoolNotable => 'Afficher sur le tableau mural';

  @override
  String get schoolSubjectInUse =>
      'Cette matière figure encore dans un emploi du temps. Retire-la d’abord de cet emploi du temps.';

  @override
  String get schoolInvalid => 'Ces informations ne sont pas cohérentes.';

  @override
  String get schoolHolidays => 'Vacances et jours sans école';

  @override
  String get schoolAddHoliday => 'Ajouter des vacances';

  @override
  String get schoolHolidayEdit => 'Vacances';

  @override
  String get schoolHolidayName => 'Nom';

  @override
  String get schoolEditorClass => 'Classe';

  @override
  String get schoolWeekCycle => 'Rythme des semaines';

  @override
  String get schoolCycleWeekly => 'Chaque semaine';

  @override
  String get schoolCycleAb => 'Semaines A/B';

  @override
  String get schoolParityAll => 'Chaque semaine';

  @override
  String get schoolParityA => 'Semaine A';

  @override
  String get schoolParityB => 'Semaine B';

  @override
  String get schoolClearDay => 'Vider la journée';

  @override
  String get schoolClearCell => 'Vider';

  @override
  String get schoolCopyFrom => 'Copier depuis…';

  @override
  String get schoolCopyPick => 'Copier l’emploi du temps de';

  @override
  String get schoolCareRows => 'Accueil périscolaire';

  @override
  String get schoolAddCare => 'Ajouter un accueil périscolaire';

  @override
  String get schoolCareTitle => 'Nom';

  @override
  String get schoolCareDays => 'Les';

  @override
  String get schoolSaveTimetable => 'Enregistrer l’emploi du temps';

  @override
  String get schoolWeekdayPick => 'Jours';

  @override
  String get feedTitle => 'Partager le calendrier familial';

  @override
  String get feedSettingsSubtitle =>
      'En lecture seule, dans Outlook ou sur un iPhone';

  @override
  String get feedNew => 'Nouvel abonnement';

  @override
  String get feedEmpty =>
      'Aucun abonnement pour le moment. Un abonnement affiche les rendez-vous dans Outlook ou sur un iPhone, en lecture seule.';

  @override
  String get feedRevoked => 'Révoqué';

  @override
  String get feedNeverFetched => 'Jamais consulté';

  @override
  String feedLastFetched(String when) {
    return 'Dernière consultation : $when';
  }

  @override
  String get feedAgoJustNow => 'à l’instant';

  @override
  String feedAgoMinutes(int count) {
    return 'il y a $count min';
  }

  @override
  String feedAgoHours(int count) {
    return 'il y a $count h';
  }

  @override
  String feedAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String feedFetchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'consulté $count fois',
      one: 'consulté une fois',
    );
    return '$_temp0';
  }

  @override
  String get feedSummaryAppointments => 'Rendez-vous';

  @override
  String get feedSummaryPresence => 'Présence';

  @override
  String get feedSummaryEveryone => 'Tous les membres';

  @override
  String get feedSummarySchoolDay => 'Journée d’école';

  @override
  String get feedSummarySchoolLessons => 'Cours';

  @override
  String get feedWhoseTitle => 'Les événements de qui';

  @override
  String get feedWhoseHelp => 'Sans sélection : tout le monde';

  @override
  String get feedLabelField => 'Nom de l’abonnement';

  @override
  String get feedLabelHint => 'par exemple Outlook sur l’ordinateur du travail';

  @override
  String get feedWhatTitle => 'Contenu';

  @override
  String get feedKindPresenceTitle => 'Présence';

  @override
  String get feedPresenceHint =>
      'Indique qui est où et quand (travail, télétravail, congé…). Mieux vaut laisser cette option désactivée pour les appareils professionnels et les enfants.';

  @override
  String get feedSchoolTitle => 'École';

  @override
  String get feedSchoolOff => 'Désactivé';

  @override
  String get feedSchoolHint =>
      'Les journées d’école en une entrée couvrant toute la journée, ou chaque cours séparément.';

  @override
  String get feedCreate => 'Créer l’abonnement';

  @override
  String get feedUrlTitle => 'Adresse de l’abonnement';

  @override
  String get feedUrlOnce =>
      'Cette adresse ne sera affichée qu’une fois. Toute personne qui la possède peut voir les événements : protège-la comme un mot de passe.';

  @override
  String get feedCopyUrl => 'Copier l’adresse';

  @override
  String get feedCopyWebcal => 'Copier le lien webcal';

  @override
  String get feedWebcalLabel =>
      'Lien webcal (ouvre la boîte de dialogue de l’iPhone)';

  @override
  String get feedCopied => 'Adresse copiée.';

  @override
  String get feedQrLabel => 'Code QR contenant l’adresse de l’abonnement';

  @override
  String get feedHowTitle => 'Comment s’abonner';

  @override
  String get feedHowOutlook =>
      'Outlook sur le web : Calendrier → Ajouter un calendrier → S’abonner à partir du web → colle l’adresse → donne-lui le nom « Famille ».';

  @override
  String get feedHowIphone =>
      'iPhone : Réglages → Apps → Calendrier → Comptes → Ajouter un compte → Autre → Ajouter un calendrier avec abonnement → colle l’adresse. Ou appuie sur le lien webcal.';

  @override
  String get feedRevokeAction => 'Révoquer';

  @override
  String feedRevokeConfirm(String label) {
    return 'Révoquer « $label » ? Cet abonnement cessera immédiatement de recevoir les événements.';
  }

  @override
  String get baselineTitle => 'Semaine habituelle';

  @override
  String get baselineSettingsSubtitle =>
      'Où chacun se trouve habituellement, jour par jour';

  @override
  String get baselineHelp =>
      'L’endroit où tu te trouves d’habitude, pour chaque jour de la semaine. Seules les exceptions sont à saisir : une semaine normale reste vide.';

  @override
  String get baselineNone => 'Rien de défini';

  @override
  String get baselineLabelField => 'Libellé personnel (facultatif)';

  @override
  String get baselineLabelHint => 'par exemple à la maison';

  @override
  String get baselineSaved => 'Enregistré.';

  @override
  String get usualCopyMonday => 'Du mardi au vendredi comme le lundi';

  @override
  String usualDayTitle(String name, String weekday) {
    return '$name le $weekday';
  }

  @override
  String get usualDayApply => 'Appliquer';

  @override
  String get usualWholeDay => 'Toute la journée';

  @override
  String get usualSlots => 'Créneaux';

  @override
  String get usualSlotState => 'Où';

  @override
  String get usualSlotFrom => 'De';

  @override
  String get usualSlotUntil => 'À';

  @override
  String get usualAddSlot => 'Ajouter un créneau';

  @override
  String get usualRemoveSlot => 'Supprimer le créneau';

  @override
  String get usualSlotsInvalid =>
      'Chaque créneau se termine après son début, et les créneaux ne se chevauchent pas.';

  @override
  String get usualAlternating => 'Semaines alternées (A/B)';

  @override
  String get usualAlternatingHelp =>
      'Pour un planning qui se répète toutes les deux semaines.';

  @override
  String get usualWeekA => 'Semaine A';

  @override
  String get usualWeekB => 'Semaine B';

  @override
  String usualThisWeekIs(String week) {
    return 'Cette semaine : $week.';
  }

  @override
  String get usualWhichWeek => 'Quelle semaine est-ce cette semaine ?';

  @override
  String get errUsualWeekInvalid =>
      'Cette semaine habituelle n’est pas valide.';

  @override
  String get busyTitle => 'Rendez-vous jusqu’à';

  @override
  String get busyPickTime => 'Choisir une heure';

  @override
  String get busyThisDay => 'Ce jour uniquement';

  @override
  String get busyWholeWeek => 'Appliquer à toute la semaine (lun–ven)';

  @override
  String get busyRemove => 'Retirer';

  @override
  String get busyHelp =>
      'Jusqu’à quelle heure tu n’es pas disponible. Juste l’heure : aucun rendez-vous ni détail.';

  @override
  String get busyFor => 'Pour';

  @override
  String get tasksTabToday => 'Aujourd’hui';

  @override
  String get tasksTabApprovals => 'Approbations';

  @override
  String get tasksTabChores => 'Tâches';

  @override
  String get tasksTabRewards => 'Récompenses';

  @override
  String get tasksTabPoints => 'Points';

  @override
  String get tasksNothingToday => 'Rien à faire aujourd’hui.';

  @override
  String get tasksOpenForAnyone => 'À prendre par qui veut';

  @override
  String get tasksWaitingApproval => 'en attente d’approbation';

  @override
  String get tasksDone => 'Terminé';

  @override
  String get tasksUndo => 'Annuler';

  @override
  String tasksCompletedSnack(String title) {
    return '$title : terminé';
  }

  @override
  String tasksPointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String tasksStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours de suite',
      one: '1 jour de suite',
    );
    return '$_temp0';
  }

  @override
  String tasksOpenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count à faire',
      one: '1 à faire',
      zero: 'aucune à faire',
    );
    return '$_temp0';
  }

  @override
  String get tasksKindDuty => 'Responsabilité';

  @override
  String get tasksKindBonus => 'Tâche bonus';

  @override
  String get tasksApprovalsEmpty => 'Rien à vérifier.';

  @override
  String get tasksCheckChores => 'Tâches à vérifier';

  @override
  String get tasksRewardRequests => 'Demandes de récompenses';

  @override
  String get tasksApprove => 'Approuver';

  @override
  String get tasksDecline => 'Refuser';

  @override
  String tasksRequestedBy(String name, String reward) {
    return '$name souhaite $reward';
  }

  @override
  String tasksDoneBy(String name) {
    return 'Réalisé par $name';
  }

  @override
  String get tasksNoteOptional => 'Note (facultative)';

  @override
  String get tasksNoChores => 'Pas encore de tâches.';

  @override
  String get tasksStarterHelp =>
      'Cinq tâches, trois récompenses et quatre badges pour commencer. Tout pourra être modifié ensuite.';

  @override
  String get tasksStarterAdd => 'Ajouter le kit de départ';

  @override
  String get tasksStarterDone => 'Kit de départ ajouté.';

  @override
  String get tasksNewChore => 'Nouvelle tâche';

  @override
  String get tasksEditChore => 'Modifier la tâche';

  @override
  String get tasksFieldTitle => 'Titre';

  @override
  String get tasksTitleRequired => 'Saisis un titre.';

  @override
  String get tasksFieldIcon => 'Icône';

  @override
  String get taskIcon_dishes => 'Assiette';

  @override
  String get taskIcon_table => 'Cuillère';

  @override
  String get taskIcon_trash => 'Poubelle';

  @override
  String get taskIcon_bed => 'Lit';

  @override
  String get taskIcon_dog => 'Chien';

  @override
  String get taskIcon_plant => 'Plante';

  @override
  String get taskIcon_bike => 'Vélo';

  @override
  String get taskIcon_book => 'Livres';

  @override
  String get taskIcon_laundry => 'Panier à linge';

  @override
  String get taskIcon_teeth => 'Brosse à dents';

  @override
  String get taskIcon_shopping => 'Chariot de courses';

  @override
  String get taskIcon_cooking => 'Poêle';

  @override
  String get taskIcon_car => 'Voiture';

  @override
  String get taskIcon_toys => 'Ours en peluche';

  @override
  String get taskIcon_star => 'Étoile';

  @override
  String get taskIcon_cinema => 'Film';

  @override
  String get taskIcon_moon => 'Lune';

  @override
  String get taskIcon_trip => 'Boussole';

  @override
  String get tasksNoIcon => 'Sans icône';

  @override
  String get tasksFieldKind => 'Type';

  @override
  String get tasksKindDutyHelp =>
      'Une participation attendue de chacun, qui rapporte peu.';

  @override
  String get tasksKindBonusHelp =>
      'Un effort supplémentaire et facultatif, qui rapporte des points.';

  @override
  String get tasksFieldPoints => 'Points';

  @override
  String get tasksFieldRepeat => 'Répétition';

  @override
  String get tasksRepeatOnce => 'Une seule fois';

  @override
  String get tasksRepeatDaily => 'Tous les jours';

  @override
  String get tasksRepeatWeekdays => 'Certains jours de la semaine';

  @override
  String get tasksRepeatWeekly => 'Toutes les semaines';

  @override
  String get tasksRepeatBiweekly => 'Toutes les 2 semaines';

  @override
  String get tasksRepeatMonthly => 'Tous les mois';

  @override
  String get tasksWeekdayOne => 'Jour de la semaine';

  @override
  String get tasksWeekdayMany => 'Jours de la semaine';

  @override
  String get tasksWeekdaysRequired => 'Choisis au moins un jour de la semaine.';

  @override
  String get tasksFieldStarts => 'À partir du';

  @override
  String get tasksFieldWindow => 'Peut être faite';

  @override
  String tasksWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pendant $count jours à partir du jour prévu',
      one: 'Uniquement le jour prévu',
    );
    return '$_temp0';
  }

  @override
  String get tasksFieldWho => 'Qui';

  @override
  String get tasksWhoFixed => 'Une personne';

  @override
  String get tasksWhoRotating => 'À tour de rôle';

  @override
  String get tasksWhoOpen => 'Qui veut';

  @override
  String get tasksWhoEach => 'Chacun';

  @override
  String get tasksPickOne => 'Qui s’en charge ?';

  @override
  String get tasksPickPool => 'Qui participe ?';

  @override
  String get tasksPickOpenPool =>
      'Qui peut s’en charger ? Sans sélection : tout le monde.';

  @override
  String get tasksPoolRequired => 'Choisis au moins une personne.';

  @override
  String get tasksFieldVerification => 'Approbation par un adulte';

  @override
  String get tasksVerificationHelp =>
      'Les points sont attribués après vérification.';

  @override
  String get tasksArchive => 'Archiver';

  @override
  String get tasksArchiveHelp =>
      'La tâche disparaît. Ses prochaines occurrences non terminées sont supprimées.';

  @override
  String get tasksNoRewards => 'Pas encore de récompenses.';

  @override
  String get tasksNewReward => 'Nouvelle récompense';

  @override
  String get tasksEditReward => 'Modifier la récompense';

  @override
  String get tasksFieldCost => 'Coût en points';

  @override
  String get tasksFieldStock => 'Quantité disponible (vide = illimitée)';

  @override
  String get tasksFieldNeedsApproval => 'Approbation préalable nécessaire';

  @override
  String get tasksNeedsApprovalHelp =>
      'Désactiver cette option ne convient qu’aux petites choses.';

  @override
  String get tasksAskForReward => 'La demander';

  @override
  String get tasksRequestSent => 'Demande envoyée.';

  @override
  String get tasksRedeemed => 'Points échangés.';

  @override
  String get tasksSoldOut => 'Épuisé';

  @override
  String tasksMissingPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Il manque $count points',
      one: 'Il manque 1 point',
    );
    return '$_temp0';
  }

  @override
  String get tasksHistory => 'Historique';

  @override
  String get tasksNoHistory => 'Aucun échange pour le moment.';

  @override
  String get tasksRedemptionRequested => 'En attente d’approbation';

  @override
  String get tasksRedemptionApproved =>
      'Points échangés, récompense pas encore remise';

  @override
  String get tasksRedemptionDeclined => 'Refusé';

  @override
  String get tasksRedemptionFulfilled => 'Récompense remise';

  @override
  String get tasksHandOver => 'Marquer comme remise';

  @override
  String get tasksNoLedger => 'Aucun mouvement pour le moment.';

  @override
  String get tasksLedgerTask => 'Tâche terminée';

  @override
  String get tasksLedgerUndo => 'Annulation';

  @override
  String get tasksLedgerRedemption => 'Récompense';

  @override
  String get tasksLedgerAdjustment => 'Correction';

  @override
  String get tasksLedgerBadge => 'Badge';

  @override
  String get tasksLedgerBonus => 'Bonus';

  @override
  String get tasksAdjust => 'Corriger';

  @override
  String tasksAdjustTitle(String name) {
    return 'Corriger les points de $name';
  }

  @override
  String get tasksFieldAmount => 'Points (+ ou −)';

  @override
  String get tasksAmountInvalid => 'Saisis un nombre différent de 0.';

  @override
  String get tasksFieldReason => 'Motif (obligatoire)';

  @override
  String get tasksReasonRequired => 'Indique un motif.';

  @override
  String get tasksBalanceTitle => 'Solde';

  @override
  String get tasksBoardStreakLabel => 'Série';

  @override
  String get errTaskInvalid => 'Cette tâche n’est pas valide.';

  @override
  String get errTaskNotYours => 'Seule la personne concernée peut faire cela.';

  @override
  String get errBalanceInsufficient =>
      'Il n’y a pas assez de points pour cela.';

  @override
  String get errRewardOutOfStock => 'Cette récompense est épuisée.';

  @override
  String get errTaskNotOpen => 'Cette tâche n’est plus à faire.';

  @override
  String get tasksActionTick => 'Cocher comme terminé';

  @override
  String get tasksPointsInvalid =>
      'Saisis un nombre entier supérieur ou égal à 0.';

  @override
  String get kidTabToday => 'Ma journée';

  @override
  String get kidTabSchool => 'Emploi du temps';

  @override
  String get kidTabPoints => 'Points';

  @override
  String get kidTabShopping => 'Courses';

  @override
  String get kidTabFamily => 'Famille';

  @override
  String get kidWhoAreYou => 'Salut ! Appuie sur ton prénom.';

  @override
  String kidGreeting(String name) {
    return 'Salut, $name !';
  }

  @override
  String get kidTasksTitle => 'Mes tâches';

  @override
  String get kidTasksNone => 'Tu n’as pas de tâches aujourd’hui.';

  @override
  String get kidTasksAllDone => 'Tout est fait !';

  @override
  String get kidAwaitsCheck => 'en cours de vérification';

  @override
  String get kidDone => 'Terminé';

  @override
  String kidTaskDoneSnack(String title) {
    return '$title : c’est fait !';
  }

  @override
  String get kidUndo => 'Annuler';

  @override
  String get kidSchoolTitle => 'L’école aujourd’hui';

  @override
  String get kidNoSchoolToday => 'Pas d’école aujourd’hui.';

  @override
  String kidHoliday(String name) {
    return 'Vacances : $name';
  }

  @override
  String get kidNoTimetable => 'Ton emploi du temps n’a pas encore été saisi.';

  @override
  String kidRoom(String room) {
    return 'Salle $room';
  }

  @override
  String get kidNow => 'Maintenant';

  @override
  String get kidLessonCancelled => 'annulé';

  @override
  String get kidLessonSubstituted => 'enseignant remplaçant';

  @override
  String get kidLessonRoomChange => 'autre salle';

  @override
  String kidCareUntil(String time) {
    return 'Accueil périscolaire jusqu’à $time';
  }

  @override
  String kidTomorrowNeeds(String items) {
    return 'Demain, tu auras besoin de : $items';
  }

  @override
  String kidMealDinner(String dish) {
    return 'Ce soir, on mange : $dish';
  }

  @override
  String kidMealLunch(String dish) {
    return 'Ce midi, on mange : $dish';
  }

  @override
  String get kidMealNoneDinner => 'Rien n’est encore prévu pour ce soir.';

  @override
  String get kidMealNoneLunch => 'Rien n’est encore prévu pour ce midi.';

  @override
  String get kidMealEatingYou => 'Tu manges avec nous.';

  @override
  String get kidEventsTitle => 'Mes rendez-vous aujourd’hui';

  @override
  String get kidNoEvents => 'Pas de rendez-vous aujourd’hui.';

  @override
  String get kidAllDay => 'toute la journée';

  @override
  String get kidTimetableTitle => 'Mon emploi du temps';

  @override
  String get kidTodayMarker => 'Aujourd’hui';

  @override
  String get kidYourPoints => 'Tes points';

  @override
  String get kidRewardsTitle => 'Récompenses';

  @override
  String get kidRedeem => 'Échanger mes points';

  @override
  String kidNeedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count points',
      one: 'Encore 1 point',
    );
    return '$_temp0';
  }

  @override
  String get kidWaitsApproval => 'en attente d’approbation';

  @override
  String get kidRequestSent => 'Ta récompense attend l’accord d’un adulte.';

  @override
  String get kidRedeemed => 'Points échangés !';

  @override
  String get kidSoldOut => 'Épuisé pour le moment';

  @override
  String get kidBadgesTitle => 'Mes badges';

  @override
  String get kidBadgeEarned => 'Obtenu';

  @override
  String get kidBadgeNotYet => 'Pas encore obtenu';

  @override
  String get kidStreaksTitle => 'Mes séries';

  @override
  String kidStreak(int days, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours : $title',
      one: '1 jour : $title',
    );
    return '$_temp0';
  }

  @override
  String get kidFamilyTitle => 'La famille aujourd’hui';

  @override
  String kidOpenTasks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches à faire',
      one: '1 tâche à faire',
      zero: 'Aucune tâche à faire',
    );
    return '$_temp0';
  }

  @override
  String get kidNoPlanToday => 'Rien de prévu aujourd’hui';

  @override
  String get schoolsUiAddSchool => 'Une autre école';

  @override
  String get schoolsUiNewSchool => 'Nouvelle école';

  @override
  String get schoolsUiPickSchool => 'Choisir l’école';

  @override
  String get schoolsUiAskSchool => 'Quelle école ?';

  @override
  String schoolsUiSchoolOf(String name) {
    return 'École : $name';
  }

  @override
  String get schoolsUiDayMenu => 'Actions pour la journée';

  @override
  String get schoolsUiCopyDay => 'Copier la journée vers…';

  @override
  String schoolsUiCopyDayTitle(String day) {
    return 'Copier $day vers';
  }

  @override
  String get schoolsUiCopyDayApply => 'Copier';

  @override
  String get schoolsUiSwapDay => 'Échanger avec…';

  @override
  String schoolsUiSwapDayTitle(String day) {
    return 'Échanger $day avec';
  }

  @override
  String get schoolsUiDayCleared => 'Journée vidée';

  @override
  String get schoolsUiDayCopied => 'Journée copiée';

  @override
  String get schoolsUiDaySwapped => 'Journées échangées';

  @override
  String get schoolsUiUndo => 'Annuler';

  @override
  String get mealsUxSuggestOften => 'Les favoris de la famille';

  @override
  String get mealsUxSuggestRare => 'Pas mangé depuis un moment';

  @override
  String mealsUxClearedSnack(String title) {
    return '$title retiré';
  }

  @override
  String get mealsUxUndo => 'Annuler';

  @override
  String get mealsUxFromMealPlan => 'Issu du planning des repas';

  @override
  String mealsUxForMeal(String meal, String day) {
    return 'Pour : $meal · $day';
  }

  @override
  String get todayTitle => 'Aujourd’hui';

  @override
  String get todayEmpty =>
      'Rien n’est encore prévu aujourd’hui. Profite du calme.';

  @override
  String get todayAgendaTitle => 'Rendez-vous';

  @override
  String get todayAllDay => 'toute la journée';

  @override
  String get todayTasksTitle => 'Tes tâches du jour';

  @override
  String get todayMealTitle => 'Repas chaud';

  @override
  String todayMealLine(String slot, String dish) {
    return '$slot : $dish';
  }

  @override
  String get todayShoppingTitle => 'Liste de courses';

  @override
  String todayShoppingOpen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles encore à acheter',
      one: '1 article encore à acheter',
    );
    return '$_temp0';
  }

  @override
  String todayNoticeJoined(String name) {
    return '$name a rejoint la famille';
  }

  @override
  String todayNoticeSignIn(String device) {
    return 'Nouvelle connexion : $device';
  }

  @override
  String get todayNoticeDismiss => 'Compris';

  @override
  String get todayNoticeMembers => 'Membres';

  @override
  String get todayNoticeDevices => 'Appareils';

  @override
  String get todayApprovalsTitle => 'En attente de ton approbation';

  @override
  String todayApprovalsChecks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches à vérifier',
      one: '1 tâche à vérifier',
    );
    return '$_temp0';
  }

  @override
  String todayApprovalsRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes de récompense',
      one: '1 demande de récompense',
    );
    return '$_temp0';
  }

  @override
  String get todayStartTitle => 'Premiers pas';

  @override
  String todayStartProgress(int done, int total) {
    return '$done sur $total';
  }

  @override
  String get todayStartNotNeeded => 'Pas nécessaire';

  @override
  String get todayStartInvitePartner => 'Inviter ton ou ta partenaire';

  @override
  String get todayStartConnectTablet => 'Connecter la tablette familiale';

  @override
  String get todayStartWallDisplay => 'Configurer l’écran mural';

  @override
  String get todayStartSetPin => 'Définir ton code PIN';

  @override
  String get todayStartSubscribeFeed => 'S’abonner au calendrier';

  @override
  String get todayStartSchool => 'Ajouter l’emploi du temps';

  @override
  String get settingsGettingStarted => 'Premiers pas';

  @override
  String get settingsGettingStartedSubtitle =>
      'Réafficher la carte de configuration dans l’onglet Aujourd’hui';

  @override
  String get settingsLicenses => 'Licences open source';

  @override
  String get settingsLicensesSubtitle =>
      'Les licences des logiciels et des polices utilisés par WuselWall';

  @override
  String get exportFamilyTitle => 'Famille';

  @override
  String get exportAction => 'Exporter les données';

  @override
  String get exportExplanation =>
      'Toutes les données de votre famille dans un fichier, par exemple pour passer sur un autre serveur.';

  @override
  String get exportInProgress => 'Exportation des données';

  @override
  String get exportPersonalDeviceRequired =>
      'L’exportation fonctionne uniquement depuis ton téléphone personnel.';

  @override
  String boardHolidayLabel(String name) {
    return 'Jour férié · $name';
  }

  @override
  String get regionSettingTitle => 'Région';

  @override
  String get regionSettingHelp =>
      'Détermine les jours fériés applicables et les vacances scolaires que tu peux importer. Choisis le canton, l’État ou la commune.';

  @override
  String get regionFieldLabel => 'Région';

  @override
  String get regionFieldEmpty => 'Aucune région choisie';

  @override
  String get regionFieldClear => 'Retirer la région';

  @override
  String get regionCountryDE => 'Allemagne';

  @override
  String get regionCountryAT => 'Autriche';

  @override
  String get regionCountryCH => 'Suisse';

  @override
  String get regionCountryLI => 'Liechtenstein';

  @override
  String get regionCountryOther => 'Autre pays (sans région)';

  @override
  String get regionPickCountryTitle => 'Pays';

  @override
  String get regionPickRegionTitle => 'Canton ou État';

  @override
  String get regionPickSearch => 'Rechercher';

  @override
  String regionPickWholeRegion(String name) {
    return 'Toute la région : $name';
  }

  @override
  String get regionPickDeeperTitle => 'Préciser le choix (district ou commune)';

  @override
  String get regionPickDeeperSearch => 'Saisis une commune ou un district';

  @override
  String get regionPickNoMatch => 'Aucun résultat';

  @override
  String get regionPickLoading => 'Chargement des régions…';

  @override
  String get regionPickRetry => 'Réessayer';

  @override
  String get regionPickSkip => 'Continuer sans région';

  @override
  String get regionPickEmpty => 'Aucune région pour ce pays.';

  @override
  String get regionUnavailable =>
      'La liste des régions n’est pas disponible pour le moment. Vérifie la connexion et réessaie.';

  @override
  String get regionCategoryCanton => 'Canton';

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
  String get regionImportAction => 'Importer les vacances scolaires';

  @override
  String get regionImportNeedsRegion =>
      'Choisis d’abord une région pour l’école.';

  @override
  String get regionImportTitle => 'Vacances scolaires';

  @override
  String get regionImportIntro =>
      'Les jours fériés de la région s’appliquent automatiquement. Ici, tu peux importer les vacances scolaires.';

  @override
  String get regionImportSwissHint =>
      'En Suisse, les vacances scolaires peuvent varier d’une commune à l’autre. Vérifie les dates.';

  @override
  String get regionImportNone =>
      'Aucune période de vacances scolaires trouvée pour les 18 prochains mois.';

  @override
  String get regionImportAlready => 'déjà importé';

  @override
  String get regionImportOverlaps => 'chevauche une de tes entrées';

  @override
  String get regionImportButton => 'Importer';

  @override
  String regionImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count périodes de vacances importées',
      one: '1 période de vacances importée',
      zero: 'Aucune période de vacances importée',
    );
    return '$_temp0';
  }

  @override
  String get regionImportAttribution => 'Données : OpenHolidays API · ODbL';

  @override
  String get regionImported => 'importé';

  @override
  String get extCalTitle => 'Ajouter des calendriers externes';

  @override
  String get extCalSettingsSubtitle =>
      'Matchs du club, collecte des déchets et plus dans le calendrier familial';

  @override
  String get extCalEmpty =>
      'Aucun abonnement à un calendrier pour le moment. Un abonnement ajoute des rendez-vous externes au calendrier familial, comme les matchs d’un club.';

  @override
  String get extCalNew => 'S’abonner à un calendrier';

  @override
  String get extCalNewTitle => 'Nouveau calendrier';

  @override
  String get extCalEditTitle => 'Modifier le calendrier';

  @override
  String get extCalEdit => 'Modifier';

  @override
  String get extCalNameLabel => 'Nom';

  @override
  String get extCalNameHint => 'par exemple Matchs du club de foot';

  @override
  String get extCalNameRequired => 'Donne un nom au calendrier.';

  @override
  String get extCalUrlLabel => 'Adresse (ICS)';

  @override
  String get extCalUrlHelp =>
      'L’adresse de publication du calendrier, qui se termine souvent par .ics. Exemples : calendrier de collecte des déchets de ta commune, matchs d’un club. Les adresses webcal:// fonctionnent aussi.';

  @override
  String get extCalUrlInvalid =>
      'Cela ne ressemble pas à une adresse web (https://…).';

  @override
  String get extCalColourLabel => 'Couleur';

  @override
  String extCalColourOption(int number) {
    return 'Couleur $number';
  }

  @override
  String get extCalMembersLabel => 'Pour qui ?';

  @override
  String get extCalMembersHelp =>
      'Sans sélection, le calendrier concerne toute la famille.';

  @override
  String get extCalMembersWhole => 'Toute la famille';

  @override
  String get extCalShowOnBoard => 'Afficher sur l’écran de la cuisine';

  @override
  String get extCalShowOnBoardHelp =>
      'Ses rendez-vous apparaissent parmi les rendez-vous importants dans la vue hebdomadaire de l’écran de la cuisine.';

  @override
  String extCalDeleteConfirm(String name) {
    return '« $name » et tous ses rendez-vous seront supprimés.';
  }

  @override
  String get extCalDeleted => 'Calendrier retiré.';

  @override
  String get extCalRefreshNow => 'Actualiser maintenant';

  @override
  String extCalRefreshed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rendez-vous chargés',
      one: '1 rendez-vous chargé',
      zero: 'Aucun rendez-vous trouvé',
    );
    return '$_temp0';
  }

  @override
  String get extCalNotModified =>
      'Aucun changement depuis la dernière récupération.';

  @override
  String get extCalRecent =>
      'Récupéré à l’instant. Réessaie dans quelques minutes.';

  @override
  String extCalRefreshFailed(String reason) {
    return 'Le calendrier n’a pas pu être chargé : $reason';
  }

  @override
  String get extCalStatusPaused => 'En pause';

  @override
  String get extCalStatusNever => 'Premier chargement…';

  @override
  String extCalStatusUpdated(String when) {
    return 'Mis à jour $when';
  }

  @override
  String get extCalReadOnlyHint =>
      'Seuls les responsables parentaux peuvent s’abonner à des calendriers ou les modifier.';

  @override
  String get extCalErrUnreachable =>
      'L’adresse n’est pas accessible pour le moment.';

  @override
  String get extCalErrTimeout => 'L’adresse met trop de temps à répondre.';

  @override
  String get extCalErrForbiddenHost => 'Cette adresse n’est pas autorisée.';

  @override
  String get extCalErrTooLarge =>
      'Le calendrier est trop volumineux (plus de 2 Mo).';

  @override
  String get extCalErrNotIcs => 'Ce n’est pas un calendrier (ICS).';

  @override
  String get extCalErrHttp404 => 'Adresse introuvable (404).';

  @override
  String extCalErrHttp(int status) {
    return 'L’adresse renvoie l’erreur $status.';
  }

  @override
  String get extCalErrInternal =>
      'Un problème est survenu sur le serveur. Réessaie plus tard.';

  @override
  String get extCalErrDb => 'Les rendez-vous n’ont pas pu être enregistrés.';

  @override
  String get extCalErrUnknown => 'La récupération a échoué.';

  @override
  String get extCalErrInvalid =>
      'Le calendrier n’est pas valide : vérifie son nom et sa couleur.';

  @override
  String get extCalErrUrlInvalid =>
      'Cette adresse ne peut pas être enregistrée. Elle doit commencer par https://.';

  @override
  String get extCalErrNotFound => 'Ce calendrier n’existe plus.';

  @override
  String get extCalImportedNote =>
      'Calendrier avec abonnement — les modifications viennent de la source';

  @override
  String extCalFromCalendar(String name) {
    return 'De $name';
  }

  @override
  String get extCalAllDay => 'Toute la journée';

  @override
  String get extCalSheetTitle => 'Rendez-vous issu d’un abonnement';

  @override
  String get extCalSettingsRefreshHint =>
      'Le serveur récupère chaque calendrier environ une fois par heure.';

  @override
  String get extCalActive => 'Actif';

  @override
  String get extCalUrlLoading => 'Chargement de l’adresse';

  @override
  String get shoppingNavLabel => 'Courses';

  @override
  String get scanHint =>
      'Dirige l’appareil photo vers le code QR affiché sur l’autre appareil.';

  @override
  String get scanCameraDenied =>
      'WuselWall n’a pas accès à l’appareil photo et ne peut donc pas scanner le code. Autorise cet accès dans les paramètres du système ou saisis le code à la main.';

  @override
  String get scanCameraUnavailable =>
      'Cet appareil ne dispose pas d’un appareil photo utilisable par WuselWall. Saisis le code à la main.';

  @override
  String get scanWebUnsupported =>
      'Ce navigateur ne peut pas scanner de codes QR. Saisis le code à la main.';

  @override
  String get scanTypeCode => 'Saisir le code';

  @override
  String get feedSubTitle => 'Inclure les calendriers externes';

  @override
  String get feedSubHelp =>
      'Les événements des calendriers importés (par exemple un club ou la collecte des déchets) apparaissent aussi dans cet abonnement.';

  @override
  String get feedSubSummary => 'Calendriers externes';

  @override
  String get boardAllEvents => 'Tous les événements';

  @override
  String get boardNextWeek => 'Semaine prochaine';

  @override
  String get boardThisWeek => 'Cette semaine';

  @override
  String get boardNextWeekUnavailable =>
      'Impossible de charger la semaine prochaine pour l’instant';

  @override
  String boardMemberDay(String name, String date) {
    return '$name, $date';
  }

  @override
  String get reminderChannelName => 'Rappels';

  @override
  String get reminderStartLabel => 'Activer les rappels';

  @override
  String reminderMorningEventsAndTasks(int events, int tasks) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events rendez-vous',
      one: '1 rendez-vous',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks tâches',
      one: '1 tâche',
    );
    return 'Aujourd’hui : $_temp0, $_temp1';
  }

  @override
  String reminderMorningEventsOnly(int events) {
    String _temp0 = intl.Intl.pluralLogic(
      events,
      locale: localeName,
      other: '$events rendez-vous',
      one: '1 rendez-vous',
    );
    return 'Aujourd’hui : $_temp0';
  }

  @override
  String reminderMorningTasksOnly(int tasks) {
    String _temp0 = intl.Intl.pluralLogic(
      tasks,
      locale: localeName,
      other: '$tasks tâches',
      one: '1 tâche',
    );
    return 'Aujourd’hui : $_temp0';
  }

  @override
  String reminderMorningApprovals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count approbations en attente',
      one: '1 approbation en attente',
    );
    return '$_temp0';
  }

  @override
  String get reminderMorningNoEvents => 'Rien n’est prévu aujourd’hui.';

  @override
  String reminderMorningFirst(String time, String title) {
    return 'D’abord, à $time : $title';
  }

  @override
  String reminderMorningAllDay(String title) {
    return 'Toute la journée : $title';
  }

  @override
  String reminderEventBody(String time) {
    return 'Commence à $time';
  }

  @override
  String get reminderSettingsTitle => 'Rappels';

  @override
  String get reminderSettingsSubtitle => 'Sur ce téléphone';

  @override
  String get reminderSettingsSection => 'Ce que tu souhaites te faire rappeler';

  @override
  String get reminderStatusOn => 'Les rappels sont activés sur ce téléphone.';

  @override
  String get reminderStatusOff =>
      'Les rappels sont désactivés sur ce téléphone.';

  @override
  String get reminderStatusUnavailable =>
      'Cet appareil ne peut pas afficher de rappels.';

  @override
  String get reminderEnableAction => 'Activer les rappels';

  @override
  String get reminderDeniedNote =>
      'Sans autorisation, les rappels ne sont pas possibles. Tu peux modifier l’autorisation dans les paramètres du système.';

  @override
  String get reminderLocalNote =>
      'Les rappels sont créés sur ce téléphone. Rien n’est envoyé à un serveur ni à qui que ce soit.';

  @override
  String get reminderOnlyPersonal =>
      'Les rappels sont disponibles uniquement sur l’appareil personnel d’un membre de la famille.';

  @override
  String get pairFrontDoorAction =>
      'Connecter une tablette familiale ou un écran mural';

  @override
  String get pairTitle => 'Connecter cet appareil';

  @override
  String get pairScanHint =>
      'Ouvre WuselWall sur ton téléphone et scanne ce code.';

  @override
  String get pairCodeHint =>
      'Ou sur le téléphone : Paramètres → Appareils → Connecter un appareil, puis saisis le code.';

  @override
  String get pairQrLabel => 'Code QR pour connecter cet appareil';

  @override
  String get pairWaiting => 'En attente d’approbation…';

  @override
  String pairConnected(String household) {
    return 'Connecté à $household';
  }

  @override
  String get pairOldCodeLink =>
      'J’ai un code provenant d’un téléphone (ancienne version)';

  @override
  String get pairConnectAction => 'Connecter un appareil';

  @override
  String get pairOldCodeAction => 'Créer un code pour un ancien appareil';

  @override
  String get pairEntryBody =>
      'Scanne le code affiché sur le nouvel appareil ou saisis-le à la main.';

  @override
  String get pairCodeField => 'Code du nouvel appareil';

  @override
  String get pairNext => 'Suivant';

  @override
  String get pairReviewBody => 'Voici le code de l’appareil à connecter.';

  @override
  String get pairConfirmHint =>
      'Ne confirme que si cet appareil est bien devant toi.';

  @override
  String get pairKindLabel => 'De quel type d’appareil s’agit-il ?';

  @override
  String get pairKindWall => 'Écran mural';

  @override
  String get pairKindKid => 'Tablette des enfants';

  @override
  String get pairKindFamily => 'Tablette partagée';

  @override
  String get pairKindChild => 'Téléphone d’un enfant';

  @override
  String get pairChildLabel => 'Quel enfant ?';

  @override
  String get pairNameLabel => 'Nom de l’appareil';

  @override
  String get pairDefaultWall => 'Écran mural';

  @override
  String get pairDefaultKid => 'Tablette des enfants';

  @override
  String get pairDefaultFamily => 'Tablette';

  @override
  String pairDefaultChild(String name) {
    return 'Téléphone de $name';
  }

  @override
  String get pairApproveAction => 'Connecter';

  @override
  String get pairApproved => 'Appareil connecté';

  @override
  String get pairOnlyOnPersonal =>
      'Cela fonctionne uniquement sur ton téléphone personnel.';

  @override
  String get pairPinTitle => 'Définir le code PIN parental';

  @override
  String get pairPinBody =>
      'Le code PIN sert à confirmer les modifications sur les appareils partagés. Définis-le une seule fois.';

  @override
  String get pairPinConfirm => 'Saisis à nouveau le code PIN';

  @override
  String get pairPinMismatch => 'Les codes PIN ne correspondent pas. Réessaie.';

  @override
  String get firstRunKioskTitle => 'Configurer l’écran mural';

  @override
  String get firstRunKioskBody =>
      'Trois étapes à faire une seule fois sur cet appareil. Ensuite, il affichera la semaine.';

  @override
  String get firstRunPinTitle => 'Garder l’application ouverte';

  @override
  String get firstRunPinIos =>
      'Réglages → Accessibilité → Accès guidé : active-le. Ouvre WuselWall et appuie trois fois rapidement sur le bouton supérieur.';

  @override
  String get firstRunPinAndroid =>
      'Paramètres → Sécurité → Épinglage d’application (ou « Épinglage d’écran » selon l’appareil). Ouvre WuselWall, affiche les applications récentes et appuie sur l’épingle.';

  @override
  String get firstRunAwakeTitle => 'Garder l’écran allumé';

  @override
  String get firstRunAwakeIos =>
      'Réglages → Luminosité et affichage → Verrouillage automatique → Jamais.';

  @override
  String get firstRunAwakeAndroid =>
      'Paramètres → Écran → Délai de mise en veille : choisis la durée la plus longue.';

  @override
  String get firstRunPowerTitle => 'Le laisser branché';

  @override
  String get firstRunPowerBody =>
      'Laisse-le branché sur le secteur pour qu’il soit de nouveau prêt après une coupure de courant.';

  @override
  String get firstRunDone => 'Terminé';

  @override
  String get firstRunKidTitle => 'Bienvenue';

  @override
  String get firstRunKidBody =>
      'Appuie sur ton image pour que WuselWall sache qui tu es.';

  @override
  String get firstRunKidStart => 'C’est parti';

  @override
  String get householdNewTitle => 'Nouvelle famille';

  @override
  String get householdNewFamilyName => 'Nom de la famille';

  @override
  String get householdNewYourName => 'Ton prénom';

  @override
  String get householdNewColour => 'Ta couleur';

  @override
  String householdNewColourOption(String number) {
    return 'Couleur $number';
  }

  @override
  String householdNewFamilyPrefill(String name) {
    return 'Famille $name';
  }

  @override
  String householdNewDefaults(String timezone, String language) {
    return 'Fuseau horaire $timezone · Langue $language — selon ton appareil';
  }

  @override
  String get householdLanguageDe => 'Allemand';

  @override
  String get householdLanguageEn => 'Anglais';

  @override
  String get householdLanguageFr => 'Français';

  @override
  String get householdLanguageEs => 'Espagnol';

  @override
  String get householdNewFounderCode => 'Code de configuration';

  @override
  String get householdNewFounderHelp =>
      'Utilise le code de configuration affiché lors de l’installation du serveur ou demande-le à la personne qui le gère. Ce n’est pas le code de ton e-mail de connexion.';

  @override
  String get householdNewCodeSaved =>
      'Le code de configuration de ton lien de configuration a été enregistré. Tu n’as pas besoin de le saisir à nouveau.';

  @override
  String get householdSeedExamples =>
      'Commencer avec des exemples — 5 tâches, 3 récompenses';

  @override
  String get householdNewCreate => 'Créer la famille';

  @override
  String get householdNewInvited => 'J’ai reçu une invitation';

  @override
  String get householdInvitedNote =>
      'Les invitations arriveront avec la prochaine mise à jour.';

  @override
  String get householdNewSignOut => 'Se déconnecter';

  @override
  String get householdNewErrNoCode =>
      'Ce serveur demande un code de configuration pour créer une famille. Utilise le code fourni à l’installation du serveur, pas celui reçu par e-mail.';

  @override
  String get householdNewErrCodeWrong =>
      'Ce code de configuration n’est pas valide ou a déjà été utilisé. Demande un nouveau lien ou code de configuration à la personne qui gère votre serveur.';

  @override
  String get householdNewErrRateLimited =>
      'Trop de tentatives. Patiente quelques minutes et réessaie.';

  @override
  String get householdNewStalled =>
      'Cela prend plus de temps que d’habitude. Patiente un peu ou déconnecte-toi puis reconnecte-toi. Ne crée pas la famille une deuxième fois.';

  @override
  String get setupPrivacy => 'Politique de confidentialité';

  @override
  String get householdMembersTitle => 'Qui d’autre fait partie de ta famille ?';

  @override
  String householdMembersYou(String name) {
    return '$name (toi)';
  }

  @override
  String get householdKindChild => 'Enfant';

  @override
  String get householdKindAdult => 'Adulte';

  @override
  String get householdMembersName => 'Prénom';

  @override
  String get householdMembersAdd => 'Ajouter une personne';

  @override
  String get householdMembersRemove => 'Retirer';

  @override
  String get householdMembersDone => 'Terminé';

  @override
  String get householdMembersSkip => 'Passer';

  @override
  String get householdMembersHelp =>
      'Tu pourras inviter des adultes plus tard.';

  @override
  String householdDeviceLabel(String owner, String device) {
    return '$owner $device';
  }

  @override
  String get householdDeviceIphone => 'iPhone';

  @override
  String get householdDeviceAndroid => 'Téléphone Android';

  @override
  String get householdDeviceBrowser => 'navigateur';

  @override
  String get householdDeviceComputer => 'ordinateur';

  @override
  String get emailContinue => 'Continuer';

  @override
  String get emailHavePassword => 'J’ai un mot de passe';

  @override
  String get emailWrongCredentials =>
      'L’adresse e-mail ou le mot de passe est incorrect.';

  @override
  String get emailUseCodeInstead => 'Utiliser plutôt un code par e-mail';

  @override
  String get emailOffline =>
      'Pas de connexion : une connexion est nécessaire pour se connecter par e-mail.';

  @override
  String get emailRequired => 'Saisissez votre adresse e-mail.';

  @override
  String get emailInvalid => 'Saisissez une adresse e-mail valide.';

  @override
  String get passwordRequired => 'Saisissez votre mot de passe.';

  @override
  String get emailSendingCode => 'Envoi du code…';

  @override
  String get signInProgress => 'Connexion en cours…';

  @override
  String get emailCodeTitle => 'Code reçu par e-mail';

  @override
  String emailCodeSent(String email) {
    return 'Nous avons envoyé un code à 6 chiffres à $email. Il est valable 10 minutes.';
  }

  @override
  String get emailCodeFieldLabel => 'Code à six chiffres';

  @override
  String get emailCodeWrong =>
      'Ce code est incorrect ou a expiré. Réessaie ou demande un nouveau code.';

  @override
  String emailCodeResendIn(int seconds) {
    return 'Pas de code ? Renvoyer (dans $seconds s)';
  }

  @override
  String get emailCodeResend => 'Pas de code ? Renvoyer';

  @override
  String get emailCodeSpam => 'Regarde dans tes courriers indésirables.';

  @override
  String get emailCodeResent => 'Un nouveau code est en route.';

  @override
  String get emailCodeOtherMethod => 'Choisir une autre méthode';

  @override
  String get emailCodeOtherAddress => 'Une autre adresse e-mail';

  @override
  String get signInMethodTitle =>
      'Comment souhaites-tu te connecter la prochaine fois ?';

  @override
  String get signInMethodCode => 'Avec un code par e-mail — rien à retenir';

  @override
  String get signInMethodPassword => 'Avec un mot de passe';

  @override
  String get passwordStrengthShort => 'Encore trop court';

  @override
  String get passwordStrengthWeak => 'Faible';

  @override
  String get passwordStrengthFair => 'Moyen';

  @override
  String get passwordStrengthStrong => 'Fort';

  @override
  String get settingsPasswordTitle => 'Mot de passe';

  @override
  String get settingsPasswordSet =>
      'Défini. Tu peux aussi te connecter avec ton adresse e-mail et ton mot de passe.';

  @override
  String get settingsPasswordNotSet =>
      'Non défini. Tu peux toujours te connecter avec un code par e-mail.';

  @override
  String get passwordSetAction => 'Définir un mot de passe';

  @override
  String get passwordChangeAction => 'Modifier le mot de passe';

  @override
  String get passwordSaved => 'Ton mot de passe est enregistré.';

  @override
  String get passwordDialogBody =>
      'Au moins 10 caractères. Le code par e-mail reste toujours disponible.';

  @override
  String signInMethodEmailSubtitle(String email) {
    return '$email — toujours disponible';
  }

  @override
  String get signInMethodAlwaysAvailable => 'Toujours disponible';

  @override
  String get leaveLeaveTile => 'Quitter la famille';

  @override
  String get leaveLeaveExplain =>
      'Ton compte quitte la famille. Tes appareils sont déconnectés. Les données restent dans la famille ; tu pourras ensuite créer une autre famille ou en rejoindre une.';

  @override
  String get leaveLeaveBlocked =>
      'Invite d’abord un deuxième adulte ou supprime la famille.';

  @override
  String get leaveLeaveDialogTitle => 'Quitter la famille ?';

  @override
  String get leaveLeaveDialogBody =>
      'Tu perdras l’accès à cette famille. Elle continuera d’exister et les autres membres y resteront.';

  @override
  String get leaveLeaveConfirm => 'Quitter';

  @override
  String get leaveCancel => 'Annuler';

  @override
  String get leaveDeleteTile => 'Supprimer la famille';

  @override
  String get leaveDeleteExplain =>
      'La famille et toutes ses données sont supprimées immédiatement et définitivement. Tous les appareils sont déconnectés. Cette action est irréversible.';

  @override
  String get leaveDeleteDialogTitle => 'Supprimer la famille ?';

  @override
  String get leaveDeleteDialogBody =>
      'Tous les appareils sont déconnectés et la famille est définitivement supprimée avec toutes ses données.';

  @override
  String leaveDeleteNameLabel(String name) {
    return 'Saisis « $name » pour confirmer';
  }

  @override
  String get leaveDeleteNext => 'Suivant';

  @override
  String get leaveDeleteWordTitle => 'Supprimer définitivement ?';

  @override
  String get leaveDeleteWordBody =>
      'La famille et toutes ses données sont supprimées immédiatement et définitivement. Personne ne peut les restaurer, pas même un responsable. Exportez d’abord les données si vous souhaitez les conserver.';

  @override
  String get leaveDeleteWord => 'SUPPRIMER';

  @override
  String leaveDeleteWordLabel(String word) {
    return 'Saisissez $word pour supprimer définitivement la famille';
  }

  @override
  String get leaveDeleteConfirm => 'Supprimer la famille';

  @override
  String leaveDeletedTitle(String family, String date) {
    return '$family sera définitivement supprimée le $date';
  }

  @override
  String get leaveDeletedBodyGuardian =>
      'Tu peux restaurer la famille. Toutes les données sont encore là. Ce téléphone redeviendra le téléphone de la famille ; les autres appareils devront se reconnecter.';

  @override
  String get leaveDeletedBodyMember =>
      'Seul un responsable parental peut restaurer la famille. Tu peux aussi repartir de zéro ; ton compte quittera alors cette famille.';

  @override
  String get leaveRestore => 'Restaurer';

  @override
  String get leaveStartAfresh => 'Repartir de zéro';

  @override
  String get leaveStartAfreshHint =>
      'Ton compte quitte la famille supprimée et tu en crées une nouvelle.';

  @override
  String get leaveErrConfirmName => 'Le nom ne correspond pas.';

  @override
  String get leaveErrHouseholdDeleted => 'Cette famille a été supprimée.';

  @override
  String get leaveErrRestoreExpired =>
      'Cette famille ne peut plus être restaurée.';

  @override
  String get leaveErrNotDeleted => 'Cette famille n’est pas supprimée.';

  @override
  String get leaveErrAdultRequired =>
      'Seuls les adultes ont leur propre compte.';

  @override
  String get leaveErrAlreadyInHousehold =>
      'Ce compte appartient déjà à une famille.';

  @override
  String get inviteDoorAction => 'J’ai un code d’invitation';

  @override
  String get inviteCodeTitle => 'Invitation';

  @override
  String get inviteCodeBody =>
      'Saisis le code ou colle le lien que tu as reçu.';

  @override
  String get inviteCodeLabel => 'Code ou lien';

  @override
  String get inviteCheckAction => 'Vérifier l’invitation';

  @override
  String get inviteCodeInvalidFormat =>
      'Ce n’est ni un code d’invitation ni un lien WuselWall.';

  @override
  String get inviteNoLonger =>
      'Cette invitation n’est plus valable. Demande une nouvelle invitation à la personne qui t’a invité.';

  @override
  String get inviteRateLimited =>
      'Trop de tentatives. Patiente quelques minutes et réessaie.';

  @override
  String inviteBanner(String inviter, String household) {
    return '$inviter t’invite à rejoindre $household';
  }

  @override
  String inviteBannerNoInviter(String household) {
    return 'Tu as une invitation pour rejoindre $household';
  }

  @override
  String get inviteRoleLineGuardian =>
      'En tant que responsable parental, tu vois tout et tu approuves les récompenses.';

  @override
  String get inviteRoleLineMember =>
      'En tant que membre, tu coches tes tâches, sans approuver les récompenses.';

  @override
  String get inviteContinue => 'Continuer vers la connexion';

  @override
  String get inviteJoin => 'Rejoindre';

  @override
  String get inviteNewFamilyInstead => 'Créer ma propre famille';

  @override
  String inviteJoinTitle(String name, String household) {
    return 'Tu es $name dans $household';
  }

  @override
  String get inviteJoinHint =>
      'Ton prénom et ta couleur, tels que la famille les voit. Tu pourras les modifier plus tard dans les paramètres.';

  @override
  String get inviteJoinDecline => 'Ne pas rejoindre';

  @override
  String inviteAlreadyIn(String household) {
    return 'Tu fais déjà partie de $household.';
  }

  @override
  String inviteAlreadyInTitle(String household) {
    return 'Tu fais déjà partie de $household';
  }

  @override
  String inviteAlreadyInSame(String household) {
    return 'Cette invitation concerne $household, dont tu fais déjà partie. Tu n’as rien d’autre à faire.';
  }

  @override
  String get inviteAlreadyInLeaveHint =>
      'Un compte n’appartient qu’à une seule famille. Pour la rejoindre, quitte d’abord ta famille actuelle ; l’invitation se poursuit ensuite.';

  @override
  String get inviteAlreadyInLeaveHintUnknown =>
      'Un compte n’appartient qu’à une seule famille. Pour en rejoindre une autre, quitte d’abord ta famille actuelle, puis ouvre de nouveau l’invitation.';

  @override
  String get inviteAlreadyInDevice =>
      'Cet appareil appartient déjà à une famille. Ouvre l’invitation sur le téléphone de la personne invitée.';

  @override
  String get invitePartnerPickTitle => 'Qui veux-tu inviter ?';

  @override
  String get invitePartnerExisting =>
      'Déjà dans la famille, sans compte pour l’instant';

  @override
  String get invitePartnerSomeoneElse => 'Quelqu’un d’autre';

  @override
  String get invitePartnerSomeoneElseHint =>
      'Ajoute un nouvel adulte à la famille';

  @override
  String get inviteNothingKept => 'Il n’y a plus d’invitation à accepter.';

  @override
  String inviteResultTitle(String name) {
    return 'Invitation pour $name';
  }

  @override
  String get inviteResultHint =>
      'La personne saisit le code dans WuselWall ou scanne le code QR.';

  @override
  String inviteValidUntil(String date) {
    return 'Valable jusqu’au $date';
  }

  @override
  String get inviteQrLabel => 'Code QR de l’invitation';

  @override
  String get inviteShare => 'Partager';

  @override
  String get inviteDone => 'Terminé';

  @override
  String inviteShareMessage(
    String household,
    String link,
    String code,
    String server,
  ) {
    return 'Rejoins $household sur WuselWall : $link — ou saisis le code $code dans l’application, sur le serveur $server.';
  }

  @override
  String get inviteAdultTitle => 'Inviter un adulte';

  @override
  String get inviteAdultName => 'Prénom';

  @override
  String get inviteAdultRole => 'Rôle';

  @override
  String get inviteRoleGuardian => 'Responsable parental';

  @override
  String get inviteRoleMember => 'Membre';

  @override
  String get inviteRoleGuardianHelp => 'Voit tout et approuve les récompenses.';

  @override
  String get inviteRoleMemberHelp =>
      'Coche les tâches mais n’approuve pas les récompenses. Pour une personne au pair ou les grands-parents, par exemple.';

  @override
  String get inviteAdultEmail => 'E-mail (facultatif)';

  @override
  String get inviteAdultEmailHelp =>
      'Grâce à cette adresse, la personne retrouve automatiquement l’invitation en se connectant.';

  @override
  String get inviteEmailInvalid =>
      'Cela ne ressemble pas à une adresse e-mail.';

  @override
  String get inviteCreate => 'Créer l’invitation';

  @override
  String get inviteInviteAction => 'Inviter';

  @override
  String inviteOpenUntil(String date) {
    return 'Invitation envoyée · jusqu’au $date';
  }

  @override
  String get inviteShareAgain => 'Partager à nouveau';

  @override
  String get inviteWithdraw => 'Retirer';

  @override
  String get inviteWithdrawn => 'Invitation retirée.';

  @override
  String get inviteScanTitle => 'Scanner une invitation';

  @override
  String get accountDeleteTile => 'Supprimer le compte';

  @override
  String get accountDeleteExplain =>
      'Ton compte et ses méthodes de connexion seront supprimés, et tu seras déconnecté partout. Ton profil et son historique resteront dans la famille.';

  @override
  String get accountDeleteBlocked =>
      'Tu es le dernier responsable parental avec un compte dans cette famille. Invite d’abord un deuxième adulte ou supprime la famille.';

  @override
  String get accountDeleteDialogTitle => 'Supprimer le compte ?';

  @override
  String get accountDeleteDialogBody =>
      'Cette action est irréversible. Tes accès de connexion seront supprimés et ton profil restera dans la famille.';

  @override
  String get accountDeleteConfirm => 'Supprimer le compte';

  @override
  String get accountDeleteRefused =>
      'Le compte n’a pas pu être supprimé. Réessaie plus tard.';

  @override
  String get accountDeleteReauthTitle => 'Confirme que c’est bien toi';

  @override
  String accountDeleteReauthBody(String email) {
    return 'La suppression d’un compte nécessite une nouvelle connexion. Nous envoyons un code à $email.';
  }

  @override
  String get accountDeleteReauthSend => 'Envoyer le code';

  @override
  String get accountDeleteReauthCodeLabel => 'Code reçu par e-mail';

  @override
  String get accountDeleteReauthConfirm => 'Confirmer';

  @override
  String get accountDeleteReauthSignInAgain =>
      'Reconnecte-toi d’abord pour pouvoir supprimer le compte.';

  @override
  String get mfaResetAction =>
      'Réinitialiser l’authentification à deux facteurs';

  @override
  String get mfaResetConfirmTitle =>
      'Réinitialiser l’authentification à deux facteurs ?';

  @override
  String mfaResetConfirmBody(String name) {
    return '$name pourra ensuite se connecter sans second facteur et le configurer à nouveau.';
  }

  @override
  String get mfaResetConfirm => 'Réinitialiser';

  @override
  String mfaResetDone(String name) {
    return 'Le second facteur de $name a été réinitialisé.';
  }

  @override
  String get serverTitle => 'Quel serveur ?';

  @override
  String get serverLead =>
      'WuselWall conserve les données de votre famille sur votre propre serveur. Saisis son adresse ou scanne son code QR. Tu as une invitation ? Colle le lien ou le code accompagné du serveur, par exemple K7QM3XRP@api.example.org.';

  @override
  String get serverAddressLabel => 'Adresse du serveur';

  @override
  String get serverAddressHint => 'par exemple api.example.org';

  @override
  String get serverConnect => 'Connecter';

  @override
  String get serverScan => 'Scanner un code QR';

  @override
  String get serverScanTitle => 'Scanner le code QR du serveur';

  @override
  String get serverDemo => 'Essayer sans serveur';

  @override
  String get serverDemoHint =>
      'Avec une famille d’exemple. Rien ne quitte cet appareil.';

  @override
  String get serverHelp =>
      'Pas encore de serveur ? Le guide sur wuselwall.app/docs explique comment en installer un.';

  @override
  String get serverInvalid => 'Ce n’est pas une adresse de serveur.';

  @override
  String get serverUnreachable =>
      'Le serveur ne répond pas. L’adresse est-elle correcte et es-tu en ligne ?';

  @override
  String get serverNotWuselwall =>
      'Il n’y a pas de serveur WuselWall à cette adresse.';

  @override
  String get serverTooOld =>
      'Ce serveur doit être mis à jour. Demande à la personne qui le gère de mettre WuselWall à jour.';

  @override
  String get serverAppTooOld =>
      'Ce serveur nécessite une version plus récente de l’application. Mets WuselWall à jour.';

  @override
  String get serverLinkWithoutServer =>
      'Ce lien n’indique pas à quel serveur il appartient. Saisis l’adresse du serveur ci-dessus, puis le code.';

  @override
  String inviteResultServer(String server) {
    return 'Serveur : $server';
  }

  @override
  String get linkOtherServerTitle => 'Ce lien appartient à un autre serveur';

  @override
  String linkSwitchBody(String host, String current) {
    return 'Le lien pointe vers $host, mais cette application est connectée à $current. Passer à $host ?';
  }

  @override
  String get linkSwitchAction => 'Changer de serveur';

  @override
  String linkOtherServerBody(String host, String current) {
    return 'Le lien pointe vers $host, mais tu es connecté à $current. Déconnecte-toi d’abord (Paramètres → Changer de serveur), puis ouvre à nouveau le lien.';
  }

  @override
  String get serverIncompatibleTitle =>
      'Le serveur et l’application ne sont pas compatibles';

  @override
  String get serverChooseOther => 'Choisir un autre serveur';

  @override
  String get demoBanner => 'Famille d’exemple : rien n’est enregistré';

  @override
  String get demoExit => 'Quitter';

  @override
  String get settingsServer => 'Serveur';

  @override
  String settingsServerBody(String address) {
    return 'Cette application communique avec $address. Scanne ce code avec l’application WuselWall sur un autre appareil pour le connecter au même serveur.';
  }

  @override
  String get settingsServerSwitch => 'Changer de serveur';

  @override
  String get settingsServerSwitchConfirm =>
      'Cet appareil sera déconnecté et toutes les données qui y sont stockées seront effacées. Tu pourras ensuite choisir un autre serveur.';

  @override
  String get setupPhoneTitle => 'Continuer sur ton téléphone';

  @override
  String get setupPhoneBody =>
      'Ouvre l’application WuselWall sur ton téléphone, choisis ce serveur en scannant le code, puis connecte-toi dessus.';

  @override
  String get shortcutTitle => 'Apps et automatisations';

  @override
  String get shortcutIntro =>
      'Une clé permet à une autre application d’utiliser WuselWall au nom d’une personne. Une clé d’automatisation, par exemple pour un raccourci Siri sur iPhone ou toute application pouvant appeler une adresse web, permet de lire et d’ajouter : elle ajoute des articles à la liste de courses et indique le programme du jour, le repas ou qui a sport demain. Elle ne permet ni de supprimer ni de gérer les données.';

  @override
  String get shortcutEmpty => 'Pas encore de clés.';

  @override
  String get shortcutKioskNote =>
      'Les clés se créent sur un téléphone personnel, pas sur l’écran mural.';

  @override
  String get shortcutNew => 'Nouvelle clé';

  @override
  String get shortcutLabelField => 'Nom';

  @override
  String get shortcutLabelHint => 'par exemple iPhone';

  @override
  String get shortcutForWhom => 'Pour qui ?';

  @override
  String get shortcutForWhomHelp =>
      'Le raccourci agit au nom de cette personne : il coche ses tâches et annonce ses points.';

  @override
  String get shortcutCreate => 'Créer la clé';

  @override
  String shortcutKeyTitle(String name) {
    return 'Clé pour $name';
  }

  @override
  String shortcutKeyOnce(String name) {
    return 'Cette clé n’est affichée que maintenant. Quiconque la possède peut lire et ajouter au nom de $name : traitez-la comme un mot de passe. Dans l’application Raccourcis d’Apple, elle est synchronisée via iCloud.';
  }

  @override
  String get shortcutCopyKey => 'Copier la clé';

  @override
  String get shortcutAddressLabel => 'Adresse';

  @override
  String get shortcutCopyAddress => 'Copier l’adresse';

  @override
  String get shortcutCopied => 'Copié.';

  @override
  String get shortcutHowTitle => 'Comment faire';

  @override
  String get shortcutHowSteps =>
      'Toute application envoie la même requête. Avec Raccourcis d’Apple, créez un raccourci avec l’action « Obtenir le contenu de l’URL » : l’adresse se terminant par /today et un en-tête « Authorization » contenant « Bearer », un espace et la clé. Ajoutez ensuite « Afficher le résultat » ou « Énoncer le texte ». Le guide sur wuselwall.app/docs/en/settings/shortcuts présente chaque raccourci.';

  @override
  String shortcutLastUsed(String when) {
    return 'Dernière utilisation : $when';
  }

  @override
  String get shortcutNeverUsed => 'Jamais utilisé';

  @override
  String shortcutUseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requêtes',
      one: '1 requête',
    );
    return '$_temp0';
  }

  @override
  String get shortcutRevoked => 'Révoqué';

  @override
  String get shortcutRevokeAction => 'Révoquer';

  @override
  String shortcutRevokeConfirm(String label) {
    return 'Révoquer « $label » ? Le raccourci cessera immédiatement de fonctionner.';
  }

  @override
  String get shortcutErrLabel => 'Saisis un nom de 60 caractères maximum.';

  @override
  String get shortcutErrLimit =>
      'Cette personne possède déjà dix clés. Révoque d’abord l’une d’elles.';

  @override
  String get shortcutSectionAutomations => 'Automatisations';

  @override
  String get shortcutSectionAssistants => 'Assistants IA';

  @override
  String get shortcutKindShortcut => 'Automatisation';

  @override
  String get shortcutKindAssistant => 'Assistant IA';

  @override
  String get shortcutKindShortcutHelp =>
      'Pour Siri et Raccourcis d’Apple, ou toute application pouvant appeler une adresse web : permet de lire et d’ajouter, par exemple à la liste de courses.';

  @override
  String get shortcutKindAssistantHelp =>
      'Pour un assistant IA compatible MCP, comme Claude : il lit uniquement, et seuls les adultes peuvent avoir une clé.';

  @override
  String get shortcutAssistantLabelHint =>
      'par exemple Claude sur l’ordinateur portable';

  @override
  String shortcutAssistantKeyOnce(String name) {
    return 'Cette clé n’est affichée que maintenant. Avec elle, un assistant lit toute la semaine de la famille au nom de $name : rendez-vous, absences, emplois du temps des enfants, tâches, repas et liste de courses. Ce qu’il lit est transmis au fournisseur de l’assistant. Protège la clé comme un mot de passe.';
  }

  @override
  String get shortcutAssistantHowSteps =>
      'Ajoute l’adresse comme serveur MCP dans ton assistant et envoie la clé dans l’en-tête « Authorization » avec « Bearer », une espace et la clé. Le guide sur wuselwall.app/docs/en/settings/shortcuts explique comment faire pour certains assistants.';

  @override
  String get shortcutErrAdultOnly =>
      'Seuls les adultes peuvent obtenir une clé pour un assistant.';

  @override
  String get reminderPackTitle => 'Préparer les affaires pour demain';

  @override
  String reminderPackChild(String name, String items) {
    return '$name : $items';
  }

  @override
  String get settingNotifyPackingTitle =>
      'Rappel pour préparer les affaires la veille au soir';

  @override
  String get settingNotifyPackingHelp =>
      'À cette heure, ton téléphone indique les affaires à mettre dans le cartable pour demain, selon les emplois du temps (par exemple la tenue de sport). Uniquement s’il y a quelque chose à préparer.';

  @override
  String get appearanceTitle => 'Apparence';

  @override
  String get appearanceSystem => 'Automatique';

  @override
  String get appearanceSystemHelp =>
      'Clair ou sombre, selon le réglage de cet appareil';

  @override
  String get appearanceLight => 'Clair';

  @override
  String get appearanceDark => 'Sombre';

  @override
  String get appearanceNightNote =>
      'La nuit, l’écran mural affiche toujours sa vue de nuit.';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageSystem => 'Automatique';

  @override
  String languageSystemCurrent(String name) {
    return 'Automatique : $name';
  }

  @override
  String get languageSystemHelp =>
      'La langue de cet appareil ; l’allemand si l’app ne la propose pas. L’allemand tel qu’on l’écrit dans le pays de votre famille.';

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
  String get settingsViewLabel => 'Paramètres à afficher';

  @override
  String get settingsViewAdvanced => 'Avancés';

  @override
  String get settingsViewMoreHint =>
      'D’autres paramètres se trouvent dans Avancés. Les paramètres masqués restent actifs.';

  @override
  String get settingsViewShowAll => 'Afficher tous les paramètres';

  @override
  String get schoolTimetableNeedsTerm =>
      'La semaine affichée n’appartient encore à aucune période. Ajoutez la période à laquelle elle appartient, puis saisissez les cours.';

  @override
  String get schoolTermContinue => 'Enregistrer la période et continuer';

  @override
  String get schoolSetupFirstHint =>
      'Des horaires de cours (dès 8h00, 45 minutes) et une liste de matières sont proposés. Tu pourras les adapter ensuite.';

  @override
  String get schoolSetupCreate => 'Créer l’école';

  @override
  String get schoolNextSteps => 'Prochaines étapes';

  @override
  String schoolNextStepEnter(String name) {
    return 'Saisir l’emploi du temps de $name';
  }

  @override
  String get schoolTermProposedHint =>
      'Proposé : l’année scolaire en cours. Adapte le nom et les dates si ton école compte autrement.';

  @override
  String schoolYearName(String from, String to) {
    return 'Année scolaire $from/$to';
  }

  @override
  String schoolCreateSubject(String name) {
    return 'Créer la matière « $name »';
  }

  @override
  String get schoolImportAction => 'Importer…';

  @override
  String get schoolImportFromText => 'Coller du texte';

  @override
  String get schoolImportFromPhoto => 'Scanner une photo';

  @override
  String get schoolImportTitle => 'Importer un emploi du temps';

  @override
  String schoolImportProposedBy(String assistant) {
    return 'Proposition de $assistant';
  }

  @override
  String schoolImportLessons(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cours',
      one: '1 cours',
    );
    return '$_temp0';
  }

  @override
  String schoolImportTermNew(String name) {
    return 'Période : $name (sera créée)';
  }

  @override
  String schoolImportTermExisting(String name) {
    return 'Période : $name';
  }

  @override
  String schoolImportReplaces(String name, int count) {
    return 'Remplace l’emploi du temps existant de $name ($count cours).';
  }

  @override
  String get schoolImportNewSubjects => 'Nouvelles matières';

  @override
  String get schoolImportCreateSubjects => 'Créer les nouvelles matières';

  @override
  String get schoolImportSkipNewSubjects =>
      'Les cours avec de nouvelles matières sont omis.';

  @override
  String get schoolImportCreateNew => 'Créer';

  @override
  String get schoolImportMergeHint =>
      'La matière existe déjà ? Choisis-la, et WuselWall retient le mot de la feuille.';

  @override
  String schoolImportWarnUnmatchedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count cours ne correspondent à aucun horaire de cours et sont omis.',
      one: '1 cours ne correspond à aucun horaire de cours et est omis.',
    );
    return '$_temp0';
  }

  @override
  String schoolImportWarnPeriodsExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les horaires de cours reçoivent $count cours de plus.',
      one: 'Les horaires de cours reçoivent 1 cours de plus.',
    );
    return '$_temp0';
  }

  @override
  String get schoolImportWarnPeriodsDiffer =>
      'Les horaires de la feuille diffèrent de ceux de l’école ; ceux de l’école sont conservés.';

  @override
  String schoolImportWarnSchoolDiffers(String name) {
    return 'La feuille indique une autre école : $name.';
  }

  @override
  String get schoolImportApply => 'Appliquer';

  @override
  String get schoolImportDiscard => 'Rejeter';

  @override
  String get schoolImportApplied => 'Emploi du temps appliqué.';

  @override
  String get schoolImportDiscarded => 'Proposition rejetée.';

  @override
  String get schoolImportNoChild => 'Ajoute d’abord un enfant sous Membres.';

  @override
  String get schoolImportPasteTitle => 'Importer du texte';

  @override
  String get schoolImportPasteIntro =>
      'Colle un emploi du temps en JSON au format WuselWall. Tu verras un aperçu avant d’enregistrer.';

  @override
  String get schoolImportCopyPrompt =>
      'Copier les instructions pour l’assistant';

  @override
  String get schoolImportPromptCopied => 'Instructions copiées.';

  @override
  String get schoolImportPrompt =>
      'Lis l’emploi du temps sur la photo et renvoie-le en JSON dans le format ci-dessous, sans autre texte. Jours en lun, mar, mer, jeu, ven ; cours par numéro (1 = premier cours) ou avec heure de début et de fin ; matières avec l’abréviation de la feuille et, si tu la connais, le nom complet. Omets les cases vides. Pour les semaines A et B, indique week: a ou b. La garderie va sous care.';

  @override
  String get schoolImportPasteHint => 'Colle ici l’emploi du temps en JSON';

  @override
  String get schoolImportRead => 'Importer';

  @override
  String get schoolImportErrNotJson =>
      'Ce n’est pas un emploi du temps au format WuselWall. Colle le texte JSON complet.';

  @override
  String get schoolImportErrNoLessons => 'Le texte ne contient aucun cours.';

  @override
  String get schoolImportErrTooMany =>
      'C’est plus d’entrées qu’un emploi du temps ne peut en avoir.';

  @override
  String get schoolImportErrBadLesson =>
      'Un cours n’a pas de jour, de numéro ou de matière.';

  @override
  String schoolImportErrBadDay(String value) {
    return '« $value » n’est pas un jour de la semaine.';
  }

  @override
  String schoolImportErrBadTime(String value) {
    return '« $value » n’est pas une heure.';
  }

  @override
  String schoolProposalTitle(String assistant) {
    return 'Proposition de $assistant';
  }

  @override
  String schoolProposalSummary(String name, int count) {
    return 'Emploi du temps de $name, $count cours';
  }

  @override
  String get schoolProposalReview => 'Vérifier';

  @override
  String get schoolProposalUnreadable =>
      'Cette proposition a un format que cette version de l’app ne peut pas lire.';

  @override
  String get schoolProposalErrInvalid =>
      'La proposition a un format non valide.';

  @override
  String get schoolProposalErrLimit =>
      'Cinq propositions sont déjà en attente. Vérifie-les ou rejette-les d’abord.';

  @override
  String get schoolProposalErrGone =>
      'Cette proposition est déjà traitée ou a expiré.';

  @override
  String get schoolScanIntro =>
      'Ton serveur lit la photo ou le PDF ; rien ne quitte la maison. Une photo droite et lumineuse de toute la feuille donne le meilleur résultat ; le PDF de l’école est le plus précis.';

  @override
  String get schoolScanCamera => 'Prendre une photo';

  @override
  String get schoolScanPick => 'Choisir une photo';

  @override
  String get schoolScanBusy => 'Lecture de la feuille…';

  @override
  String get schoolScanNotConfigured =>
      'Ton serveur n’a pas de reconnaissance de texte. Le guide « Extras pour le serveur » explique comment l’ajouter. En attendant : importer du texte.';

  @override
  String get schoolScanNothingFound =>
      'Aucun emploi du temps reconnu sur la photo. Essaie une photo plus droite et plus lumineuse, ou importe du texte.';

  @override
  String get schoolScanTooLarge =>
      'La photo est trop grande (6 Mo au maximum).';

  @override
  String get schoolScanFailed =>
      'La reconnaissance de texte du serveur n’a pas répondu. Réessaie plus tard.';

  @override
  String schoolScanWarnUnplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fragments de texte n’ont pu être placés dans aucune case. Compare l’aperçu avec la feuille.',
      one: '1 fragment de texte n’a pu être placé dans aucune case. Compare l’aperçu avec la feuille.',
    );
    return '$_temp0';
  }

  @override
  String get savedMessage => 'Enregistré.';

  @override
  String get settingsSectionThisDevice => 'Cet appareil';

  @override
  String get settingsSectionConnect => 'Partage et connexions';

  @override
  String get settingsMembersHint =>
      'Touchez une personne pour changer son nom, sa couleur, son image ou son rôle. Faites glisser la poignée pour changer l’ordre sur le mur.';

  @override
  String get familyTitle => 'Famille';

  @override
  String get familySettingsSubtitle =>
      'Nom, fuseau horaire, export des données, suppression';

  @override
  String get familyTimezone => 'Fuseau horaire';

  @override
  String get familyTimezoneHelp => 'Le mur et les rappels suivent ce fuseau.';

  @override
  String get familyTimezoneSearch => 'Rechercher un fuseau horaire';

  @override
  String get familyLocale => 'Langue sur le mur';

  @override
  String get familyLocaleHelp =>
      'Les jours fériés sur l’écran mural sont nommés dans cette langue.';

  @override
  String get familyErrTimezone => 'Fuseau horaire inconnu.';

  @override
  String get memberColour => 'Couleur';

  @override
  String get memberAvatar => 'Image';

  @override
  String get memberAvatarInitial => 'Initiale';

  @override
  String get memberKind => 'Enfant ou adulte';

  @override
  String get memberRole => 'Rôle';

  @override
  String get memberRoleHelp =>
      'Les parents voient tout et approuvent les récompenses. Les membres cochent les tâches.';

  @override
  String get memberReadOnlyHint =>
      'Seuls les parents modifient les autres personnes. Vous pouvez changer votre propre nom, couleur et image.';

  @override
  String get memberKioskReadOnly =>
      'On ne modifie personne sur l’écran mural. Changez les noms, les couleurs, les images et les anniversaires dans l’app sur un téléphone ou une tablette.';

  @override
  String get memberInactive => 'Ne fait plus partie du foyer';

  @override
  String get memberInactiveBody =>
      'Retiré du mur, des rangées d’avatars et des nouvelles tâches. L’historique et les points restent.';

  @override
  String get memberDeactivate => 'Ne fait plus partie du foyer';

  @override
  String memberDeactivateBody(String name) {
    return '$name disparaît du mur, des rangées d’avatars et des nouvelles tâches. L’historique et les points restent, et vous pouvez ramener la personne ici.';
  }

  @override
  String memberDeactivateConfirm(String name) {
    return 'Retirer $name des écrans de la famille ? L’historique et les points restent.';
  }

  @override
  String get memberReactivate => 'De retour';

  @override
  String memberHasAccountHint(String name) {
    return '$name a un compte et quitte la famille depuis son propre téléphone (Paramètres → Quitter la famille).';
  }

  @override
  String get memberReorderHandle => 'Changer l’ordre';

  @override
  String get memberErrKindAdult =>
      'Un parent, ou une personne avec un compte, est un adulte.';

  @override
  String get memberErrRoleChild =>
      'Un enfant ne peut pas être parent. Faites-en d’abord un adulte.';

  @override
  String get memberErrSelf =>
      'Vous ne pouvez pas vous retirer vous-même. Un autre parent peut le faire.';

  @override
  String get memberErrHasAccount =>
      'Cette personne a un compte et quitte la famille depuis son propre téléphone.';

  @override
  String get deviceRename => 'Renommer l’appareil';

  @override
  String deviceLastSeen(String ago) {
    return 'actif pour la dernière fois $ago';
  }

  @override
  String get deviceNeverSeen => 'pas encore actif';

  @override
  String get shoppingEditList => 'Modifier la liste';

  @override
  String get shoppingListDefault => 'Liste par défaut';

  @override
  String get shoppingListDefaultHelp =>
      'L’écran mural ajoute à la liste par défaut.';

  @override
  String get shoppingCategories => 'Catégories';

  @override
  String get shoppingCategoriesHelp =>
      'Dans l’ordre des rayons. Faites glisser la poignée pour les réordonner.';

  @override
  String get shoppingCategoryAdd => 'Ajouter une catégorie';

  @override
  String get shoppingCategoryRename => 'Renommer la catégorie';

  @override
  String get shoppingCategoryName => 'Nom de la catégorie';

  @override
  String shoppingCategoryDeleteConfirm(String name) {
    return 'Retirer « $name » ? Ses articles restent sur la liste sans catégorie.';
  }

  @override
  String get shoppingListDelete => 'Supprimer la liste';

  @override
  String shoppingListDeleteConfirm(String name) {
    return 'Supprimer « $name » ? Les articles ouverts passent sur la liste par défaut ; son historique et ses tuiles disparaissent.';
  }

  @override
  String get shoppingErrListDefault =>
      'La liste par défaut ne peut pas être supprimée. Choisissez d’abord une autre liste par défaut.';

  @override
  String get shoppingErrTileExists => 'Une tuile porte déjà ce nom.';

  @override
  String get shoppingTileAddEdit => 'Ajouter et modifier';

  @override
  String get shoppingTileRename => 'Renommer la tuile';

  @override
  String get shoppingTileForget => 'Ne plus proposer';

  @override
  String get shoppingTileForgetHelp =>
      'La tuile disparaît ; l’historique la garde.';

  @override
  String shoppingTileForgetConfirm(String name) {
    return 'Retirer la tuile « $name » ? Le prochain achat la fera revenir.';
  }

  @override
  String get schoolScanFile => 'Choisir un fichier (PDF ou image)';

  @override
  String get schoolImportPhotoUnavailable =>
      'Ton serveur ne lit pas encore les photos.';

  @override
  String get settingsVersions => 'Versions';

  @override
  String settingsVersionsLine(String app, String server, String api) {
    return 'App $app · Serveur $server · API $api';
  }

  @override
  String get settingsVersionUnknown => 'inconnue';

  @override
  String get settingMemberWuselTitle => 'Wusel';

  @override
  String get settingMemberWuselHelp =>
      'La présence de Wusel pour toi. Automatique : vif pour les enfants, discret pour les adultes.';

  @override
  String get settingMemberWuselOutfitTitle => 'La tenue de Wusel';

  @override
  String get settingMemberWuselOutfitHelp =>
      'Ce que Wusel porte en te parlant. Toutes les tenues sont là dès le début.';

  @override
  String get settingDeviceWuselTitle => 'Wusel sur cet appareil';

  @override
  String get settingDeviceWuselHelp =>
      'La vivacité de Wusel ici quand personne n’est choisi. Le réglage d’une personne s’applique quand elle est choisie.';

  @override
  String get settingDeviceSoundsTitle => 'Sons sur cet appareil';

  @override
  String get settingDeviceSoundsHelp =>
      'Automatique : coupés sur l’écran mural, actifs ailleurs. Jamais la nuit.';

  @override
  String get settingDeviceSkyTitle => 'Ciel dans l’en-tête';

  @override
  String get settingDeviceSkyHelp =>
      'L’en-tête montre un ciel qui change avec l’heure.';

  @override
  String get settingDevicePixelShiftTitle => 'Protéger l’écran du marquage';

  @override
  String get settingDevicePixelShiftHelp =>
      'Déplace tout de 2 pixels au plus toutes les 10 minutes, pour les écrans OLED toujours allumés. Automatique : actif sur l’écran mural.';

  @override
  String get settingAmbienceSeasonTitle => 'Saisons';

  @override
  String get settingAmbienceSeasonHelp =>
      'Fleurs, soleil, feuilles ou flocons dans le ciel.';

  @override
  String get settingAmbienceBirthdaysTitle => 'Anniversaires';

  @override
  String get settingAmbienceBirthdaysHelp =>
      'Des fanions à la couleur de la personne et un chapeau de fête pour Wusel le jour de son anniversaire.';

  @override
  String get settingAmbienceFerienTitle => 'Vacances scolaires';

  @override
  String get settingAmbienceFerienHelp =>
      'Un ruban le premier et le dernier jour des vacances.';

  @override
  String get settingAmbienceAdventTitle => 'Avent';

  @override
  String get settingAmbienceAdventHelp =>
      'Des bougies dans l’en-tête, une de plus chacun des quatre dimanches avant Noël. Automatique : selon votre région.';

  @override
  String get settingAmbienceEasterWesternTitle => 'Pâques';

  @override
  String get settingAmbienceEasterWesternHelp =>
      'Des œufs dans les collines, deux jours avant et après le dimanche de Pâques. Automatique : selon votre région.';

  @override
  String get settingAmbienceEasterOrthodoxTitle => 'Pâques orthodoxes';

  @override
  String get settingAmbienceEasterOrthodoxHelp =>
      'Les mêmes œufs à la date orthodoxe, calculée pour chaque année. Automatique : selon votre région.';

  @override
  String get settingAmbienceNewYearTitle => 'Nouvel An';

  @override
  String get settingAmbienceNewYearHelp =>
      'Un petit feu d’artifice dans le ciel de nuit les 31 décembre et 1er janvier.';

  @override
  String get settingRitualsCountdownDaysTitle => 'Le compte à rebours commence';

  @override
  String get settingRitualsCountdownDaysHelp =>
      'Combien de jours avant un anniversaire, les vacances ou un évènement marqué le compte à rebours apparaît.';

  @override
  String get settingRitualsCountdownReturnTitle =>
      'Compte à rebours avant un retour';

  @override
  String get settingRitualsCountdownReturnHelp =>
      '« De retour dans 2 dodos » quand un adulte part deux nuits ou plus.';

  @override
  String get settingMealsWishesTitle => 'Repas souhaités';

  @override
  String get settingMealsWishesHelp =>
      'Qui peut souhaiter un repas. L’appli ne refuse jamais un souhait ; il attend d’être planifié.';

  @override
  String get settingMealsWishesPerWeekTitle => 'Souhaits ouverts par personne';

  @override
  String get settingMealsWishesPerWeekHelp =>
      'Combien de souhaits chaque personne peut avoir en attente à la fois.';

  @override
  String get settingTableQuestionTitle => 'Question à table';

  @override
  String get settingTableQuestionHelp =>
      'Une question pour discuter, sur l’écran mural et dans l’appli pendant le repas. On y répond à voix haute, rien n’est enregistré.';

  @override
  String get settingTableQuestionLunchTitle => 'Question au déjeuner';

  @override
  String get settingTableQuestionLunchHelp =>
      'Quand la question apparaît au déjeuner.';

  @override
  String get settingTableQuestionDinnerTitle => 'Question au dîner';

  @override
  String get settingTableQuestionDinnerHelp =>
      'Quand la question apparaît au dîner.';

  @override
  String get settingTableQuestionDeckTitle => 'Questions pour';

  @override
  String get settingTableQuestionDeckHelp =>
      'Tous les âges convient dès 5 ans ; enfants plus grands ajoute des questions plus profondes dès 8 ans.';

  @override
  String get settingWeekReviewTitle => 'Notre semaine';

  @override
  String get settingWeekReviewHelp =>
      'Quand le retour sur la semaine apparaît. Il reste jusqu’au lendemain matin.';

  @override
  String get settingValueAuto => 'Automatique';

  @override
  String get settingValueLively => 'Vif';

  @override
  String get settingValueQuiet => 'Discret';

  @override
  String get settingValueOn => 'Activé';

  @override
  String get settingValueOff => 'Désactivé';

  @override
  String get settingValueChildren => 'Enfants';

  @override
  String get settingValueEveryone => 'Tout le monde';

  @override
  String get settingValueWarmMeal => 'Repas chaud';

  @override
  String get settingValueMainMeals => 'Déjeuner et dîner';

  @override
  String get settingValueAllAges => 'Tous les âges';

  @override
  String get settingValueOlderChildren => 'Aussi les plus grands';

  @override
  String settingUnitDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get wuselOutfitNone => 'Rien';

  @override
  String get wuselOutfitParty => 'Chapeau de fête';

  @override
  String get wuselOutfitCrown => 'Couronne';

  @override
  String get wuselOutfitWizard => 'Chapeau de magicien';

  @override
  String get wuselOutfitWreath => 'Couronne de fleurs';

  @override
  String get wuselOutfitSunglasses => 'Lunettes de soleil';

  @override
  String get wuselOutfitScarf => 'Écharpe';

  @override
  String get wuselOutfitHeadphones => 'Casque';

  @override
  String get wuselOutfitBow => 'Nœud';

  @override
  String wuselHelloMorning1(String name) {
    return 'Bonjour, $name !';
  }

  @override
  String wuselHelloMorning2(String name) {
    return 'Coucou $name ! Une nouvelle journée.';
  }

  @override
  String wuselHelloMorning3(String name) {
    return 'Salut $name, ça fait plaisir de te voir.';
  }

  @override
  String wuselHelloDay1(String name) {
    return 'Salut $name !';
  }

  @override
  String wuselHelloDay2(String name) {
    return 'Te voilà, $name !';
  }

  @override
  String wuselHelloDay3(String name) {
    return 'Ça me fait plaisir de te voir, $name.';
  }

  @override
  String wuselHelloEvening1(String name) {
    return 'Bonsoir, $name !';
  }

  @override
  String wuselHelloEvening2(String name) {
    return 'Bonsoir $name ! Quelle journée.';
  }

  @override
  String wuselHelloEvening3(String name) {
    return 'Salut $name ! Bientôt l’heure de se reposer.';
  }

  @override
  String wuselHelloNight(String name) {
    return 'Dors bien, $name.';
  }

  @override
  String get wuselFactBirthdayYou => 'Joyeux anniversaire !';

  @override
  String wuselFactBirthday(String name) {
    return 'C’est l’anniversaire de $name !';
  }

  @override
  String wuselFactFirstLesson(String subject) {
    return 'Aujourd’hui, tu commences par $subject.';
  }

  @override
  String wuselFactTradition(String tradition) {
    return 'Aujourd’hui, c’est $tradition !';
  }

  @override
  String wuselFactMealDinner(String dish) {
    return 'Ce soir, il y a $dish.';
  }

  @override
  String wuselFactMealLunch(String dish) {
    return 'Ce midi, il y a $dish.';
  }

  @override
  String wuselFactCountdown(String what, String when) {
    return '$what : $when';
  }

  @override
  String wuselBirthdayCheer(String name) {
    return 'Joyeux anniversaire, $name !';
  }

  @override
  String get wuselAllDone1 => 'Tout est fait. Ça s’est bien passé !';

  @override
  String get wuselAllDone2 => 'Tout est coché. Merci !';

  @override
  String get wuselAllDone3 => 'Fini pour aujourd’hui. La maison te dit merci !';

  @override
  String get wuselAllDone4 => 'Ta liste est vide. Place au jeu !';

  @override
  String get wuselRewardSent1 => 'Envoyé ! Un adulte va décider.';

  @override
  String get wuselRewardSent2 => 'Ta demande est partie.';

  @override
  String get wuselRewardSent3 => 'Souhait envoyé ! Un adulte va le regarder.';

  @override
  String wuselBadge(String badge) {
    return 'Un nouveau badge : $badge !';
  }

  @override
  String get wuselWaiting => 'Un instant…';

  @override
  String get wuselOffline => 'Attends, je cherche Internet…';

  @override
  String get wuselWallMorning1 => 'Bonjour tout le monde !';

  @override
  String get wuselWallMorning2 => 'Debout, la famille !';

  @override
  String get wuselWallMorning3 => 'Une nouvelle journée pour nous tous.';

  @override
  String wuselWallMemberDone1(String name) {
    return '$name a tout fait pour aujourd’hui !';
  }

  @override
  String wuselWallMemberDone2(String name) {
    return 'Tout est coché, $name. Merci !';
  }

  @override
  String wuselWallMemberDone3(String name) {
    return 'Les tâches de $name sont toutes faites !';
  }

  @override
  String wuselWallTradition1(String name) {
    return 'Aujourd’hui, c’est $name !';
  }

  @override
  String wuselWallTradition2(String name) {
    return 'Youpi, c’est $name aujourd’hui !';
  }

  @override
  String wuselWallTradition3(String name) {
    return 'Bonjour ! Aujourd’hui, c’est $name.';
  }

  @override
  String get wuselSetupDone => 'Tout est prêt. Bienvenue chez vous !';

  @override
  String get wuselHideLine => 'Masquer ce que dit Wusel';

  @override
  String get wuselFerienFirst1 =>
      'Les vacances commencent. Bonnes journées libres !';

  @override
  String get wuselFerienFirst2 =>
      'Vacances ! Le temps libre commence aujourd’hui.';

  @override
  String get wuselFerienFirst3 =>
      'Premier jour de vacances. Profitez-en ensemble !';

  @override
  String get ambienceFerienFirst => 'Vacances !';

  @override
  String get ambienceFerienLast => 'Demain, c’est l’école';

  @override
  String get shoppingEmptyTapTile => 'La liste est vide. Touche une vignette.';

  @override
  String get memberBirthday => 'Anniversaire';

  @override
  String get memberBirthdayHelp =>
      'Affiché sur l’écran mural le jour même, avec un compte à rebours avant.';

  @override
  String get memberBirthdayPick => 'Choisir une date';

  @override
  String get memberBirthdayClear => 'Supprimer l’anniversaire';

  @override
  String countdownBirthdayOf(String name) {
    return 'Anniversaire de $name';
  }

  @override
  String countdownBirthdayTurns(String name, int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'Les $age ans de $name',
      one: 'Le premier anniversaire de $name',
    );
    return '$_temp0';
  }

  @override
  String countdownHomecoming(String name) {
    return '$name rentre à la maison';
  }

  @override
  String countdownSleeps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'encore $count dodos',
      one: 'encore 1 dodo',
    );
    return '$_temp0';
  }

  @override
  String countdownDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'encore $count jours',
      one: 'encore 1 jour',
    );
    return '$_temp0';
  }

  @override
  String countdownInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count jours',
      one: 'dans 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get countdownTomorrow => 'Demain !';

  @override
  String get countdownToday => 'Aujourd’hui !';

  @override
  String get kidLookingForward => 'Ce qui m’attend';

  @override
  String get todayLookingForward => 'On a hâte';

  @override
  String get eventIconNone => 'Pas d’image';

  @override
  String get eventIconLabel => 'Image';

  @override
  String get eventCountdownTitle => 'On a hâte';

  @override
  String get eventCountdownHelp =>
      'Compte à rebours sur l’écran mural et la tablette des enfants.';

  @override
  String get eventTraditionTitle => 'Tradition familiale';

  @override
  String get eventTraditionHelp =>
      'Ce que la famille fait encore et encore. Toujours sur l’écran mural, avec un ruban.';

  @override
  String get eventTraditionMeal => 'Avec un repas';

  @override
  String get eventTraditionMealHint => 'p. ex. pizza';

  @override
  String get calendarNewTradition => 'Nouvelle tradition';

  @override
  String get traditionStartersHelp =>
      'Choisis un modèle. Tu changeras le jour et l’heure juste après.';

  @override
  String get traditionStarterGameNight => 'Soirée jeux';

  @override
  String get traditionStarterPizzaFriday => 'Vendredi pizza';

  @override
  String get traditionStarterFilmNight => 'Soirée cinéma';

  @override
  String get traditionStarterSundayBreakfast => 'Petit-déjeuner du dimanche';

  @override
  String get traditionStarterStoryTime => 'Heure des histoires';

  @override
  String get traditionStarterDayOut => 'Journée sortie';

  @override
  String get traditionStarterPizzaMeal => 'Pizza';

  @override
  String get traditionStarterOwn => 'Ta propre tradition';

  @override
  String get traditionStarterOwnHelp =>
      'Tu choisis le nom, l’image et le jour.';

  @override
  String traditionStarterWhen(String weekday, String time) {
    return 'Chaque $weekday, $time';
  }

  @override
  String traditionStarterWhenAllDay(String weekday) {
    return 'Chaque $weekday, toute la journée';
  }

  @override
  String get eventIcon_cake => 'Gâteau d’anniversaire';

  @override
  String get eventIcon_game_die => 'Jeu';

  @override
  String get eventIcon_pizza => 'Pizza';

  @override
  String get eventIcon_cinema => 'Film';

  @override
  String get eventIcon_croissant => 'Petit-déjeuner';

  @override
  String get eventIcon_book => 'Lecture';

  @override
  String get eventIcon_hiking => 'Randonnée';

  @override
  String get eventIcon_beach => 'Vacances';

  @override
  String get eventIcon_plane => 'Voyage';

  @override
  String get eventIcon_zoo => 'Zoo';

  @override
  String get eventIcon_tent => 'Camping';

  @override
  String get eventIcon_football => 'Sport';

  @override
  String get eventIcon_music => 'Musique';

  @override
  String get eventIcon_gift => 'Cadeau';

  @override
  String get eventIcon_balloon => 'Fête';

  @override
  String get eventIcon_backpack => 'École';

  @override
  String get eventIcon_swim => 'Piscine';

  @override
  String get eventIcon_ferris => 'Fête foraine';

  @override
  String get eventIcon_house => 'Maison';

  @override
  String get eventIcon_star => 'Spécial';

  @override
  String get kidWishTitle => 'Ton repas préféré';

  @override
  String get kidWishInvite => 'Qu’aimerais-tu manger cette semaine ?';

  @override
  String kidWishWaiting(String title) {
    return 'Tu as choisi $title. Un adulte va trouver un jour.';
  }

  @override
  String kidWishPlanned(String title, String day) {
    return 'Ton souhait $title, c’est pour le $day !';
  }

  @override
  String get kidWishMake => 'Choisir';

  @override
  String get kidWishChange => 'Changer';

  @override
  String get kidWishSent => 'Ton souhait est parti.';

  @override
  String get wishPickerTitle => 'Qu’aimerais-tu manger ?';

  @override
  String get wishPickerOwn => 'Autre chose';

  @override
  String get wishPickerOwnHint => 'p. ex. des crêpes';

  @override
  String get wishPickerSend => 'Je choisis ça';

  @override
  String get wishPickerRecipes => 'Nos recettes';

  @override
  String get wishPickerSearch => 'Chercher une recette';

  @override
  String get wishPickerNoMatch =>
      'Aucune recette de ce nom. Choisis-la plus bas.';

  @override
  String get wishPickerIcon => 'Choisis une image';

  @override
  String get mealsWishEarlier => 'de la semaine dernière';

  @override
  String get mealsWishOlder => 'd’il y a quelques semaines';

  @override
  String get mealsWishMine => 'Faire un souhait';

  @override
  String get mealsWishMineChange => 'Changer mon souhait';

  @override
  String get mealIcon_pizza => 'Pizza';

  @override
  String get mealIcon_pasta => 'Pâtes';

  @override
  String get mealIcon_pancakes => 'Crêpes';

  @override
  String get mealIcon_waffle => 'Gaufres';

  @override
  String get mealIcon_burger => 'Burger';

  @override
  String get mealIcon_fries => 'Frites';

  @override
  String get mealIcon_hotdog => 'Hot-dog';

  @override
  String get mealIcon_sandwich => 'Sandwich';

  @override
  String get mealIcon_taco => 'Tacos';

  @override
  String get mealIcon_burrito => 'Wrap';

  @override
  String get mealIcon_kebab => 'Kebab';

  @override
  String get mealIcon_curry => 'Curry';

  @override
  String get mealIcon_rice => 'Riz';

  @override
  String get mealIcon_noodles => 'Soupe de nouilles';

  @override
  String get mealIcon_soup => 'Soupe ou ragoût';

  @override
  String get mealIcon_paella => 'Paella';

  @override
  String get mealIcon_salad => 'Salade';

  @override
  String get mealIcon_sushi => 'Sushis';

  @override
  String get mealIcon_dumpling => 'Raviolis';

  @override
  String get mealIcon_chicken => 'Poulet';

  @override
  String get mealIcon_fish => 'Poisson';

  @override
  String get mealIcon_meat => 'Viande';

  @override
  String get mealIcon_egg => 'Œufs';

  @override
  String get mealIcon_falafel => 'Falafels';

  @override
  String get mealIcon_fondue => 'Fondue';

  @override
  String get mealIcon_pie => 'Tarte ou quiche';

  @override
  String get mealIcon_cake => 'Gâteau';

  @override
  String get mealIcon_ice_cream => 'Glace';

  @override
  String get mealIcon_bread => 'Pain';

  @override
  String get mealIcon_pretzel => 'Bretzel';

  @override
  String get mealIcon_croissant => 'Croissant';

  @override
  String get mealIcon_potato => 'Pommes de terre';

  @override
  String get mealIcon_cheese => 'Fromage';

  @override
  String get mealIcon_porridge => 'Porridge';

  @override
  String get mealIcon_vegetables => 'Légumes';

  @override
  String get mealsWishesTray => 'Souhaits';

  @override
  String mealsWishChip(String name, String title) {
    return '$name : $title';
  }

  @override
  String get mealsWishPlan => 'Planifier';

  @override
  String mealsWishPlanTitle(String dish) {
    return 'Planifier : $dish';
  }

  @override
  String get mealsWishRemove => 'Retirer le souhait';

  @override
  String mealsWishedBy(String name) {
    return 'Souhait de $name';
  }

  @override
  String mealsTraditionSuggestion(String meal, String tradition) {
    return 'Prévoir $meal ($tradition)';
  }

  @override
  String get tableQuestionTitle => 'Question à table';

  @override
  String get tableQuestionNext => 'Autre question';

  @override
  String get tableQuestionAnswer => 'Voir la réponse';

  @override
  String tableQuestionFrom(String name) {
    return 'Question de $name';
  }

  @override
  String get tableQuestionsManage => 'Nos questions';

  @override
  String get tableQuestionAdd => 'Ajouter une question';

  @override
  String get tableQuestionAddHint => 'Que veux-tu demander à table ?';

  @override
  String get tableQuestionHide => 'Ne plus poser cette question';

  @override
  String get tableQuestionRemove => 'Supprimer la question';

  @override
  String get tableQuestionsHidden => 'Questions écartées';

  @override
  String get tableQuestionShowAgain => 'Reposer';

  @override
  String get kidWishWithdraw => 'Retirer';

  @override
  String get kidWishAnother => 'Encore un souhait';

  @override
  String get mealsWishSlotFree => 'Rien de prévu';

  @override
  String get mealsWishReplaceTitle => 'Remplacer le repas ?';

  @override
  String mealsWishReplaceBody(
    String dish,
    String slot,
    String day,
    String wish,
  ) {
    return 'Déjà prévu : $dish ($slot, $day). Planifier le souhait $wish à la place ? Le cuisinier, l’heure et les portions restent.';
  }

  @override
  String get mealsWishReplace => 'Remplacer';

  @override
  String get errSlotTaken => 'Un repas est déjà prévu à ce moment.';

  @override
  String get tableQuestionDismiss => 'Masquer pour ce repas';

  @override
  String get weekReviewTitle => 'Notre semaine';

  @override
  String get weekReviewOpen => 'Revoir notre semaine';

  @override
  String get weekReviewTogether => 'Ce qu’on a fait ensemble';

  @override
  String weekReviewChores(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches faites',
      one: '1 tâche faite',
      zero: 'Une semaine pour souffler',
    );
    return '$_temp0';
  }

  @override
  String get weekReviewMoments => 'Chacun a eu son moment';

  @override
  String get weekReviewMeals => 'Miam';

  @override
  String get weekReviewNewRecipe => 'nouveau';

  @override
  String get weekReviewTraditions => 'Nos traditions';

  @override
  String get weekReviewNext => 'La semaine prochaine, on a hâte de';

  @override
  String get weekReviewCalmAhead => 'Une semaine tranquille s’annonce.';

  @override
  String weekReviewCardOf(int index, int count) {
    return 'Carte $index sur $count';
  }

  @override
  String get weekReviewNextCard => 'Carte suivante';

  @override
  String get weekReviewPreviousCard => 'Carte précédente';

  @override
  String weekHighlightBadge(String title) {
    return 'Nouveau badge : $title';
  }

  @override
  String weekHighlightStreak(String title) {
    return '$title, chaque jour';
  }

  @override
  String get weekHighlightAllDone => 'a eu une journée où tout était fait';

  @override
  String weekHighlightReward(String title) {
    return 'Récompense : $title';
  }

  @override
  String weekHighlightWish(String title) {
    return 'Souhait servi : $title';
  }

  @override
  String weekHighlightCooked(String title) {
    return 'a cuisiné : $title';
  }

  @override
  String weekHighlightAttended(String title) {
    return 'était là pour : $title';
  }

  @override
  String get weekHighlightHelped => 'a aidé aux tâches';

  @override
  String get weekHighlightHere => 'était de la partie cette semaine';

  @override
  String settingsOwnTitle(String name) {
    return 'Paramètres de $name';
  }

  @override
  String get settingsGroupPersonalTitle => 'Personnel';

  @override
  String get settingsGroupPersonalSubtitle => 'Wusel, sons et rappels pour toi';

  @override
  String get settingsGroupFamilyTitle => 'Famille';

  @override
  String get settingsGroupFamilySubtitle =>
      'Nom, fuseau horaire, membres et semaine habituelle';

  @override
  String get settingsGroupTasksTitle => 'Tâches et récompenses';

  @override
  String get settingsGroupTasksSubtitle =>
      'Points, jokers de série et approbations';

  @override
  String get settingsGroupCalendarTitle => 'Calendrier et école';

  @override
  String get settingsGroupCalendarSubtitle =>
      'Événements, changements d’emploi du temps et partage';

  @override
  String get settingsGroupMealsTitle => 'Repas';

  @override
  String get settingsGroupMealsSubtitle =>
      'Repas chaud, repas souhaités et déjeuner en garde';

  @override
  String get settingsGroupRitualsTitle => 'Rituels';

  @override
  String get settingsGroupRitualsSubtitle =>
      'Question à table, notre semaine, comptes à rebours';

  @override
  String get settingsGroupCelebrationsTitle => 'Fêtes et saisons';

  @override
  String get settingsGroupCelebrationsSubtitle =>
      'Avent, Pâques, Nouvel An, anniversaires et saisons';

  @override
  String get settingsGroupKitchenTitle => 'Écran de la cuisine';

  @override
  String get settingsGroupKitchenSubtitle =>
      'Prénoms, changement de semaine et moments de la journée';

  @override
  String get settingsGroupDevicesTitle => 'Appareils';

  @override
  String get settingsGroupDevicesSubtitle =>
      'Cet appareil et tous ceux de la famille';

  @override
  String get settingsGroupAccountTitle => 'Compte et sécurité';

  @override
  String get settingsGroupAccountSubtitle =>
      'Connexion, mot de passe, double authentification, quitter la famille';

  @override
  String get settingsGroupServerTitle => 'Serveur';

  @override
  String get settingsGroupServerSubtitle =>
      'Adresse, code QR et changement de serveur';

  @override
  String get settingsGroupHelpTitle => 'Aide et infos';

  @override
  String get settingsGroupHelpSubtitle => 'Premiers pas, versions, licences';

  @override
  String get settingsSectionWusel => 'Wusel';

  @override
  String get settingsSectionSound => 'Son';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsSectionTableQuestion => 'Question à table';

  @override
  String get settingsSectionWeekReview => 'Bilan de la semaine';

  @override
  String get settingsSectionCountdowns => 'Comptes à rebours';

  @override
  String get settingsSectionHolidays => 'Jours de fête';

  @override
  String get settingsSectionThroughYear => 'Au fil de l’année';

  @override
  String get settingsSectionAllDevices => 'Tous les appareils';

  @override
  String get settingsSectionLeave => 'Quitter ou supprimer';

  @override
  String get settingsSectionOther => 'Autres paramètres';

  @override
  String get familyProfileTitle => 'Profil de la famille';

  @override
  String get settingsMembersSubtitle =>
      'Prénoms, couleurs, rôles et ordre sur le mur';

  @override
  String get calendarMonth => 'Mois';

  @override
  String get calendarWeekNumberShort => 'Sem';

  @override
  String calendarWeekNumberLabel(int week) {
    return 'Semaine $week';
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
      other: '$count autres rendez-vous',
      one: '1 autre rendez-vous',
    );
    return '$_temp0';
  }

  @override
  String calendarMonthFerien(String name) {
    return 'Vacances scolaires : $name';
  }

  @override
  String get calendarMonthOpenDay => 'Ouvrir la journée';

  @override
  String get eventRepeatYearly => 'Tous les ans';

  @override
  String get eventTemplatesIntro =>
      'Choisis un point de départ. Tu pourras tout modifier ensuite.';

  @override
  String get eventTemplatesSuggested => 'Souvent chez vous';

  @override
  String get eventTemplatesSaved => 'Vos modèles';

  @override
  String get eventTemplatesBuiltIn => 'Modèles';

  @override
  String get eventTemplatesBuiltInMore => 'Autres modèles';

  @override
  String get eventTemplateBlank => 'Sans modèle';

  @override
  String get eventTemplateBlankHelp => 'Tout saisir toi-même';

  @override
  String get eventStarterBirthday => 'Anniversaire';

  @override
  String get eventStarterGuestDinner => 'Invités à dîner';

  @override
  String get eventStarterKidsParty => 'Goûter d’anniversaire';

  @override
  String get eventStarterSportsEvent => 'Événement sportif';

  @override
  String get eventStarterDoctor => 'Rendez-vous médical';

  @override
  String get eventStarterPerformance => 'Spectacle';

  @override
  String get eventStarterDayOut => 'Sortie';

  @override
  String get eventStarterHoliday => 'Vacances / voyage';

  @override
  String get eventTemplateAllDay => 'Toute la journée';

  @override
  String eventTemplateDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String eventTemplateHours(int count) {
    return '$count h';
  }

  @override
  String eventTemplateHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes';
  }

  @override
  String eventTemplateMinutes(int count) {
    return '$count min';
  }

  @override
  String eventTemplateCount(int count) {
    return 'Utilisé $count fois';
  }

  @override
  String eventTemplateMenu(String name) {
    return 'Plus pour $name';
  }

  @override
  String get eventTemplateKeep => 'Garder comme modèle';

  @override
  String get eventTemplateHide => 'Ne plus proposer';

  @override
  String get eventTemplateHidden => 'Ne sera plus proposé.';

  @override
  String get eventTemplateDelete => 'Supprimer le modèle';

  @override
  String get eventTemplateDeleted => 'Modèle supprimé.';

  @override
  String get eventSaveAsTemplate => 'Enregistrer comme modèle';

  @override
  String get eventTemplateSavedNote => 'Enregistré comme modèle.';

  @override
  String get eventTemplateErrLimit =>
      'Votre famille a déjà 50 modèles. Supprimez-en un d’abord.';

  @override
  String get passwordSignUpTab => 'Nouveau compte';

  @override
  String get passwordSignInTab => 'Se connecter';

  @override
  String get passwordSignUpAction => 'Créer le compte';

  @override
  String get passwordNoMailHint =>
      'Ce serveur n’envoie pas d’e-mails. Choisis un mot de passe dont tu te souviendras : si tu l’oublies, un responsable de ta famille peut te donner un code pour en choisir un nouveau.';

  @override
  String get passwordAccountExists =>
      'Un compte existe déjà avec cette adresse. Connecte-toi avec son mot de passe.';

  @override
  String get passwordForgot => 'Mot de passe oublié ?';

  @override
  String get passwordResetTitle => 'Nouveau mot de passe';

  @override
  String get passwordResetIntro =>
      'Demande un code à un responsable de ta famille : dans l’app, sous Membres, à ton nom, « Réinitialiser le mot de passe ». Il fonctionne une fois, pendant 10 minutes.';

  @override
  String get passwordResetCodeLabel => 'Code de réinitialisation';

  @override
  String get passwordResetSave => 'Enregistrer et se connecter';

  @override
  String get errResetCodeExpired => 'Ce code a expiré. Demandes-en un nouveau.';

  @override
  String get passwordResetMemberAction => 'Réinitialiser le mot de passe';

  @override
  String passwordResetConfirmTitle(String name) {
    return 'Nouveau mot de passe pour $name ?';
  }

  @override
  String passwordResetConfirmBody(String name) {
    return 'Tu reçois un code que $name saisit sur son propre appareil pour choisir un nouveau mot de passe. Il fonctionne une fois, pendant 10 minutes. Remets-le en personne.';
  }

  @override
  String get passwordResetConfirm => 'Créer le code';

  @override
  String passwordResetCodeTitle(String name) {
    return 'Code pour $name';
  }

  @override
  String passwordResetCodeHint(String name, String time) {
    return 'Sur l’appareil de $name : Continuer par e-mail → Mot de passe oublié ? Puis l’adresse e-mail, ce code et un nouveau mot de passe. Valable jusqu’à $time.';
  }

  @override
  String get settingsPasswordNoMail =>
      'Le serveur de ta famille n’envoie pas d’e-mails : tu te connectes avec ton adresse et ce mot de passe.';

  @override
  String get passwordDialogBodyNoMail =>
      'Au moins 10 caractères. Si tu l’oublies, un responsable de ta famille peut te donner un code pour en choisir un nouveau.';

  @override
  String get errEmailNotConfirmed =>
      'Ce serveur veut confirmer l’adresse par e-mail mais n’en envoie aucun. Demande à la personne qui le gère.';

  @override
  String accountDeleteReauthPasswordBody(String email) {
    return 'Supprimer un compte demande une connexion récente. Saisis le mot de passe de $email.';
  }
}
