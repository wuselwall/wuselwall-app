# Emploi du temps

Les adultes saisissent l’emploi du temps ; chaque enfant consulte sa semaine et les changements. L’écran de cuisine les affiche aussi.

<Shot name="school-week" alt="L’emploi du temps d’un enfant avec un cours annulé et un remplacement" wide />

## Configurer l’école {#setting-up}

La première fois, touche **Configurer l’école**. La première école ne demande que deux choses : le **nom de l’école** et la **région**. Touche ensuite **Créer l’école**.

<Shot name="school-first" alt="La première école : seulement le nom et la région, avec Créer l’école en dessous" />

C’est tout. Des horaires et une liste de matières sont proposés : des cours de 45 minutes dès 8h00, une pause de 20 minutes après le 2e et le 4e cours, 5 minutes sinon. Si votre foyer n’a pas encore de région, il prend celle de la première école. **Prochaines étapes** liste ensuite chaque enfant dont l’emploi du temps manque. Touche la ligne pour le saisir, ou **Importer…** pour le lire sur la feuille.

La page de l’école contient ensuite :

- le **nom de l’école** et sa **région** : pays, puis canton ou État, et si tu veux district ou commune. La région décide des jours fériés, des vacances et des matières proposées, voir plus bas ;
- les **horaires des cours et des pauses**, avec début et fin ;
- les **périodes**, avec leurs dates ; si l’emploi du temps alterne d’une semaine à l’autre, active **Semaines A et B** et indique le **numéro d’une semaine A** ;
- les **matières**, leur abréviation, couleur, matériel à apporter et affichage sur le mur ;
- les **vacances et jours sans cours**.

**Enregistrer**, en haut à droite, apparaît quand le nom, la région ou les horaires ont changé et enregistre ces sections ensemble. Les cours suivent l’ordre chronologique, avec les pauses entre eux.

### Les matières proposées {#proposed-subjects}

La liste de matières suit la région de l’école. Elle reprend les noms et abréviations imprimés sur les emplois du temps de cette région. Ainsi, l’import les reconnaît sur la feuille.

- **Allemagne** : par exemple Deutsch (D), Mathematik (Ma), Sachunterricht (SU), Sport (Sp) et Schwimmen (Sw) ;
- **Autriche** : les noms du programme 2023/24, par exemple Kunst und Gestaltung (KuG) et Bewegung und Sport (BS) ;
- **Suisse alémanique et Liechtenstein** : les domaines du Lehrplan 21, par exemple Natur, Mensch, Gesellschaft (NMG) et Textiles und Technisches Gestalten (TTG) ;
- **Romandie** (Genève, Vaud, Neuchâtel, Jura) : en français, selon le PER, par exemple Français (FRA) et Sciences de la nature (SCN) ;
- **Tessin** : en italien, par exemple Italiano (ITA) et Studio d’ambiente (AMB).

Dans un canton bilingue, par exemple Fribourg ou le Valais, la langue de l’app décide : en français vient la liste romande, en italien celle du Tessin, sinon celle de Suisse alémanique. Si tu choisis **Autre pays (sans région)**, la langue de l’app décide aussi : en français la liste pour la France, en espagnol celle pour l’Espagne, sinon la liste allemande.

La liste n’arrive que tant que vous n’avez aucune matière. Ensuite, elle vous appartient : renomme des matières, supprime-les ou ajoutes-en.

## Jours fériés et vacances scolaires {#public-and-school-holidays}

Choisissez le pays (**Allemagne, Autriche, Suisse ou Liechtenstein**), le canton ou l’État, puis éventuellement le district ou la commune.

<Shot name="region-picker" alt="Le choix du pays, puis du canton ou de l’État" />

Les régions sont classées de Z à A dans la langue de l’app. Les cantons suisses affichent aussi leur abréviation, par exemple AG. La recherche accepte le nom ou l’abréviation.

Vous pouvez continuer sans région ; il n’y a alors aucun jour férié automatique et les vacances se saisissent manuellement. La région du foyer se règle aussi sous [Paramètres → Famille](/fr/settings/household).

Les **jours fériés** s’appliquent automatiquement. Le jour est sans cours, son nom apparaît dans l’en-tête et les repas le traitent comme un jour libre.

Pour les **vacances scolaires**, touchez **Importer les vacances scolaires** dans les vacances et jours libres. L’aperçu couvre les **18 prochains mois**.

<Shot name="holiday-import" alt="L’aperçu des vacances à importer et des périodes déjà importées" />

Choisissez les périodes. Les périodes déjà importées et les chevauchements sont signalés. Après import, vous pouvez les modifier, les supprimer ou en ajouter.

::: warning Suisse
Les vacances scolaires dépendent souvent de la commune. Vérifiez les dates avec le calendrier de l’école et corrigez les différences.
:::

Les données viennent d’[OpenHolidays](https://www.openholidaysapi.org), consulté par votre serveur, pas par l’app.

## Plusieurs écoles {#several-schools}

Ajoutez une autre école si nécessaire, puis choisissez en haut celle à modifier. Lors de la saisie d’un emploi du temps, indiquez son école.

## Saisir un emploi du temps {#entering-a-timetable}

Pour chaque enfant, saisissez les cours d’une période. Si aucune période ne couvre la semaine affichée, l’app propose l’année scolaire en cours, du 1er août au 31 juillet, nom et dates déjà remplis. Si cela convient, touche **Enregistrer la période et continuer** ; si ton école compte autrement, change d’abord le nom ou les dates. Les dates doivent inclure la semaine affichée ; sinon, le dialogue le signale à côté de la date.

L’en-tête indique l’enfant, l’école, la période et ses dates. Touchez une cellule pour choisir une matière. S’il manque une matière, tape son abréviation dans la recherche et choisis **Créer la matière « … »** : la matière existe aussitôt et remplit la case ; couleur, icône et affaires à emporter viennent plus tard sous **Modifier l’école**. Le bouton d’enregistrement reste visible en bas pendant le défilement.

Si aucun emploi du temps n’existe encore, la vue affiche un message concernant l’enfant sélectionné et le bouton **Saisir l’emploi du temps**.

<Shot name="school-editor" alt="L’éditeur avec l’école, la période et le bouton d’enregistrement visible" />

Choisissez un rythme hebdomadaire ou des semaines A/B, saisies séparément. Ajoutez la garde après l’école avec les jours et horaires. Copiez un emploi du temps d’un frère, d’une sœur ou de la période précédente pour éviter de tout ressaisir. Enregistrez la grille.

## Importer un emploi du temps {#reading-in}

Au lieu de taper chaque cours, tu peux faire lire la feuille. Il y a deux façons. Toutes aboutissent au même [aperçu](#preview), et seul **Appliquer** écrit quelque chose. Sur un téléphone, les deux façons sont directement dans le menu aux trois points au-dessus de l’emploi du temps.

**Depuis du texte structuré.** Touche **Importer…**, puis **Coller du texte**. Colle un emploi du temps en JSON au format WuselWall, puis touche **Importer** pour ouvrir l’aperçu. Un texte ordinaire n’est pas automatiquement converti en emploi du temps.

**Comme photo ou PDF, lu par votre serveur.** Si votre serveur a la reconnaissance de texte ([Extras pour le serveur](/fr/server/extras#text-recognition)), touche **Importer…** et **Scanner une photo**. Choisis ensuite **Prendre une photo**, **Choisir une photo** ou **Choisir un fichier (PDF ou image)**, par exemple pour le PDF envoyé par l’école.

<Shot name="timetable-scan" alt="Scanner une photo : la remarque que le fichier reste à la maison, et les trois choix Prendre une photo, Choisir une photo et Choisir un fichier" />

Le fichier va à votre propre serveur et nulle part ailleurs. Le serveur ne le garde pas. Il lit la feuille et montre l’aperçu. Pour qu’il reconnaisse vos matières, l’app envoie aussi sa langue ainsi que les noms et abréviations de vos matières.

Ce que le serveur lit sur la feuille :

- les jours, les cours et leurs horaires, s’ils figurent dans la marge ;
- dans chaque case la matière, la salle et l’enseignant. Un mot que la feuille coupe en fin de ligne est recollé ;
- la **légende** sous ou à côté de la grille, c’est-à-dire les abréviations avec leur nom, par exemple « NMG Natur, Mensch, Gesellschaft » ;
- les **semaines A et B**, quand une case porte un « A » ou un « B » ;
- les lignes d’**accueil** avec leurs horaires, comme les imprime une feuille allemande, française ou espagnole (Hort, Mittagstisch, cantine, comedor). Elles deviennent des lignes d’accueil, pas des cours.

Ce qui marche le mieux :

- Le **PDF de l’école** est le plus précis, car le serveur lit son texte directement. Un PDF scanné est lu comme une photo.
- Pour une **photo** : droite, lumineuse, la feuille entière. Le serveur redresse lui-même une photo penchée ou prise de travers. Les photos d’iPhone (HEIC) fonctionnent aussi.
- Le fichier fait au plus 6 Mo.

La reconnaissance de texte lit mal l’**écriture manuscrite**. D’un emploi du temps écrit à la main, seule une partie des cases arrive ; tu complètes le reste ensuite dans l’éditeur. Si le serveur ne trouve aucun emploi du temps, l’app le dit. Essaie alors une photo plus droite et plus lumineuse, ou importe le texte. Si votre serveur n’a pas de reconnaissance de texte, l’app le dit aussi et renvoie à l’import de texte.

### L’aperçu {#preview}

L’aperçu montre ce qui serait enregistré. Rien n’a encore changé.

<Shot name="timetable-import" alt="L’aperçu : l’enfant, l’école, la période et la grille avec le nom de chaque matière sous son abréviation" wide />

- en haut l’**enfant** et, s’il y en a plusieurs, l’**école**. Tu peux changer les deux ;
- le nombre de cours, la classe, le rythme et la **période**. Si elle n’existe pas encore, « (sera créée) » est indiqué. Si l’enfant a déjà un emploi du temps dans cette période, l’aperçu dit qu’il sera remplacé ;
- la **grille** : chaque cours avec ses horaires, dans chaque case l’abréviation et en dessous le nom de la matière. Sur un téléphone, il n’y a pas la place : appuie longuement sur une case pour voir le nom. Un cours seulement en semaine A ou B porte un A ou un B ;
- l’**accueil périscolaire**, si la feuille en a ;
- chaque **remarque** : un cours ne correspond à aucun horaire, la feuille a plus de cours que vos horaires (des cours sont alors ajoutés), d’autres horaires (les vôtres restent) ou nomme une autre école. Après un scan, l’aperçu nomme aussi les fragments de texte qui ne vont dans aucune case. Compare alors avec la feuille.

<Shot name="timetable-import-subjects" alt="Nouvelles matières dans l’aperçu : QLM est reprise comme Découverte du monde existante, Anglais est créée" />

Sous **Nouvelles matières** figure chaque matière de la feuille que vous n’avez pas encore. À côté, tu choisis :

- **Créer** : la matière est créée avec l’abréviation et le nom de la feuille ;
- une **matière existante**, si vous l’avez déjà sous un autre mot, par exemple « QLM » pour votre Découverte du monde. WuselWall retient le mot de la feuille pour cette matière et le reconnaît tout seul la prochaine fois. Si le scan trouve exactement une matière qui correspond, elle est déjà choisie.

Si tu désactives **Créer les nouvelles matières**, les cours avec de nouvelles matières sont laissés de côté ; la grille les montre barrés.

**Appliquer** crée la période si elle manque, complète les horaires, crée les nouvelles matières et enregistre l’emploi du temps. La flèche de retour quitte l’aperçu sans enregistrer.

## Modifier des journées entières {#editing-whole-days}

Le menu d’un jour permet de **vider la journée**, de la **copier** sur d’autres jours ou de l’**échanger** avec un autre jour. Ces opérations modifient le brouillon seulement. Vous pouvez annuler la dernière opération ; enregistrez pour appliquer.

## La semaine {#the-week}

Le choix de l’enfant, le retour à cette semaine et les actions de modification partagent une barre. Sur un téléphone, tout tient sur une ligne pour que l’emploi du temps commence en haut de l’écran : **Cette semaine** est une icône de calendrier, et **Modifier l’école**, **Modifier l’emploi du temps**, **Coller du texte** et **Scanner une photo** sont dans le menu aux trois points. La barre du bas y affiche aussi la rubrique sous son nom court, **École**. L’action de l’école utilise une icône d’école ; l’engrenage ouvre les paramètres généraux.

Les flèches de semaine se trouvent près du lundi et du vendredi ; sur téléphone ou tablette, un balayage vers la gauche ou la droite change aussi de semaine. Sur la tablette des enfants, l’enfant passe ainsi d’un jour à l’autre de sa semaine, du lundi au vendredi. L’enfant choisi a un fond teinté, une bordure et une coche. Les vacances sont affichées au-dessus de la semaine ; les jours fériés, dans l’en-tête du jour.

Touchez un cours pour le signaler **annulé**, **remplacé** (enseignant et note) ou dans une **autre salle**. Réinitialiser remet le cours prévu.

## Préparer le cartable {#pack-for-tomorrow}

Le mur et la journée de l’enfant indiquent le matériel pour le lendemain, par exemple les affaires de sport. Le téléphone peut envoyer un [rappel la veille](/fr/settings/reminders). Désactiver l’indication dans les paramètres du foyer la retire partout.

## Les enfants signalent un changement {#children-report-changes}

Seuls les parents gèrent l’emploi du temps. Vous pouvez autoriser les membres à signaler une annulation, à confirmer ensuite par un parent, dans [Paramètres → Calendrier et école](/fr/settings/household).
