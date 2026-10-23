# Emploi du temps

Les adultes saisissent l’emploi du temps ; chaque enfant consulte sa semaine et les changements. L’écran de cuisine les affiche aussi.

<Shot name="school-week" alt="L’emploi du temps d’un enfant avec un cours annulé et un remplacement" wide />

## Configurer l’école {#setting-up}

Lors de la première utilisation, touche **Configurer l’école**, saisis le nom et la **région** de l’école et touche **Créer l’école**. C’est tout : les horaires de cours et une liste de matières sont proposés, et **Prochaines étapes** liste chaque enfant dont l’emploi du temps manque encore, avec un bouton pour le saisir ou l’importer. La page de l’école contient ensuite :

- le **nom de l’école** et sa **région** ;
- les **horaires des cours et des pauses**, avec début et fin ;
- les **périodes**, avec leurs dates ; si l’emploi du temps alterne d’une semaine à l’autre, activez **Semaines A et B** et indiquez le **numéro d’une semaine A** ;
- les **matières**, leur abréviation, couleur, matériel à apporter et affichage sur le mur ; les suggestions adaptées au pays sont modifiables ;
- les **vacances et jours sans cours**.

**Enregistrer**, en haut à droite, apparaît quand le nom, la région ou les horaires ont changé et enregistre ces sections ensemble. Les cours suivent l’ordre chronologique, avec les pauses entre eux.

## Jours fériés et vacances scolaires {#public-and-school-holidays}

Choisissez le pays (**Allemagne, Autriche, Suisse ou Liechtenstein**), le canton ou l’État, puis éventuellement le district ou la commune.

<Shot name="region-picker" alt="Le choix du pays, puis du canton ou de l’État" />

Les régions sont classées de Z à A dans la langue de l’app. Les cantons suisses affichent aussi leur abréviation, par exemple AG. La recherche accepte le nom ou l’abréviation.

Vous pouvez continuer sans région ; il n’y a alors aucun jour férié automatique et les vacances se saisissent manuellement. La région du foyer se règle aussi dans les [paramètres](/fr/settings/household).

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

Au lieu de taper chaque cours, tu peux faire lire la feuille. Les trois façons aboutissent au même **aperçu** : l’enfant, l’école, la période, la grille telle qu’elle serait enregistrée, les matières qui seront créées et chaque remarque, par exemple quand un emploi du temps est remplacé ou compte plus de cours que les horaires. Seul **Appliquer** écrit quelque chose ; **Rejeter** laisse tout en l’état.

**Depuis du texte, avec votre assistant IA.** Pour un enfant sans emploi du temps, touche **Importer…** puis **Coller du texte** (ou **Importer…** en haut de l’emploi du temps). **Copier les instructions pour l’assistant** place un texte dans le presse-papiers : donne-le, avec une photo de l’emploi du temps, à l’assistant de confiance, par exemple dans son app sur le téléphone. Il répond dans un format fixe que WuselWall sait lire. Colle la réponse dans le champ et touche **Importer**. La photo ne va qu’à l’assistant de votre choix ; WuselWall n’envoie rien à personne.

**Comme proposition d’un assistant.** Un assistant connecté à WuselWall ([Apps et assistants IA](/fr/settings/shortcuts)) peut déposer un emploi du temps comme **proposition**. Il ne change rien : une carte « Proposition de Claude » avec **Vérifier** et **Rejeter** apparaît sur **Aujourd’hui** et au-dessus de l’emploi du temps. **Vérifier** ouvre l’aperçu. Les propositions expirent après 14 jours.

**Comme photo, lue par votre serveur.** Si votre serveur a la reconnaissance de texte ([Extras pour le serveur](/fr/server/extras#text-recognition)), touche **Importer…** et **Scanner une photo**, prends la feuille en photo ou choisis-en une. La photo va à votre propre serveur et nulle part ailleurs ; le serveur reconnaît les jours, les cours et les matières et montre l’aperçu. Une photo droite et lumineuse de toute la feuille donne le meilleur résultat. L’aperçu nomme les fragments de texte qui ne correspondent à aucune case, pour comparer avec la feuille. Sans reconnaissance de texte, l’app le dit et renvoie à l’import de texte.

## Modifier des journées entières {#editing-whole-days}

Le menu d’un jour permet de **vider la journée**, de la **copier** sur d’autres jours ou de l’**échanger** avec un autre jour. Ces opérations modifient le brouillon seulement. Vous pouvez annuler la dernière opération ; enregistrez pour appliquer.

## La semaine {#the-week}

Le choix de l’enfant, le retour à cette semaine et les actions de modification partagent une barre. Sur petit écran, le retour à cette semaine est centré sur sa propre ligne et les actions passent dessous. L’action de l’école utilise une icône d’école ; l’engrenage ouvre les paramètres généraux.

Les flèches de semaine se trouvent près du lundi et du vendredi. L’enfant choisi a un fond teinté, une bordure et une coche. Les vacances sont affichées au-dessus de la semaine ; les jours fériés, dans l’en-tête du jour.

Touchez un cours pour le signaler **annulé**, **remplacé** (enseignant et note) ou dans une **autre salle**. Réinitialiser remet le cours prévu.

## Préparer le cartable {#pack-for-tomorrow}

Le mur et la journée de l’enfant indiquent le matériel pour le lendemain, par exemple les affaires de sport. Le téléphone peut envoyer un [rappel la veille](/fr/settings/reminders). Désactiver l’indication dans les paramètres du foyer la retire partout.

## Les enfants signalent un changement {#children-report-changes}

Seuls les parents gèrent l’emploi du temps. Vous pouvez autoriser les membres à signaler une annulation, à confirmer ensuite par un parent, dans les [paramètres du foyer](/fr/settings/household).
