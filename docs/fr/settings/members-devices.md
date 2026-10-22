# Membres et appareils

Les **parents** administrent le foyer depuis l’engrenage **Paramètres** de leur téléphone.

<Shot name="settings-phone" alt="Les paramètres avec les membres et les appareils" />

## Vue de base ou avancée {#view}

La vue **Essentiels** montre les paramètres du foyer, la semaine habituelle, les rappels, l’apparence, les premiers pas, les membres et appareils, et la suppression du compte sur votre téléphone. **Avancés** ajoute les calendriers, assistants, serveur, export, connexion, sécurité et départ du foyer.

Les réglages masqués restent actifs. L’app mémorise la vue pour chaque appareil ; les paramètres du foyer possèdent aussi ces deux vues.

## Inviter un adulte {#invite-an-adult}

Sous les membres, touchez **Inviter un adulte** :

1. Saisissez son prénom et choisissez le rôle : **Responsable parental** pour administrer et approuver, **Membre** pour participer sans ces droits, par exemple un grand-parent.
2. Ajoutez éventuellement son adresse e-mail. Avec cette adresse exacte, l’invitation se présente automatiquement après connexion.
3. Touchez **Créer l’invitation**.

<Shot name="invite-sheet" alt="L’invitation de Mamie Ruth, son code QR et le partage" />

Partagez le code, le serveur, le lien ou le code QR dans un message. Le lien et le QR contiennent le serveur et ouvrent directement l’invitation dans l’app. Avec le code seul, la personne saisit aussi le serveur si nécessaire ([Rejoindre la famille](/fr/guide/setup#_3-joining-a-family)).

Une invitation dure **7 jours** et sert **une seule fois**. Les invitations ouvertes affichent leur échéance ; vous pouvez les repartager ou les retirer. Un membre sans compte peut être invité depuis sa ligne. Sans adresse e-mail, la personne doit saisir le code.

Quand quelqu’un rejoint la famille, chaque parent reçoit un avis dans **Aujourd’hui**. Il peut l’acquitter ou ouvrir les membres ; l’avis disparaît après 14 jours.

Les enfants n’ont pas besoin de compte ni d’invitation : ajoutez leur prénom et connectez leur appareil.

## Ajouter un membre {#add-member}

L’icône près des membres ajoute une personne par son prénom. L’app attribue la prochaine couleur disponible.

## Réinitialiser la double authentification {#reset-two-factor}

Si un autre parent a perdu son deuxième facteur, utilisez l’action près de son nom. Il pourra se connecter et la [configurer à nouveau](/fr/settings/security#two-factor-sign-in).

## Connecter un appareil {#connect-a-device}

Sous les appareils, touchez **Connecter un appareil**. Scannez le QR ou saisissez le code affiché par le nouvel appareil, puis choisissez son type et son nom. La [procédure complète](/fr/guide/setup#_4-connecting-a-family-tablet-or-wall-display) décrit les étapes.

<Shot name="pair-approve" alt="La vérification et l’approbation du nouvel appareil" />

Le QR peut être ouvert avec la caméra du téléphone : il contient le serveur. Si le lien vise un autre serveur que celui où vous êtes connecté, l’app vous le signale et ne bascule pas automatiquement. Une ancienne version peut encore utiliser l’option de création de code pour ancien appareil.

## Bloquer un appareil {#blocking-a-device}

Bloquez immédiatement un téléphone perdu ou une tablette cédée. L’accès cesse même si l’app est ouverte ; la ligne reste visible pour comprendre ce qui s’est passé.

Une connexion de votre compte sur un nouveau téléphone produit un avis sur vos autres téléphones, dans **Aujourd’hui**. Ouvrez les appareils et bloquez celui qui ne vous appartient pas. Sur votre téléphone, vous pouvez aussi simplement déconnecter cet appareil.

## Serveur {#server}

Dans **Avancés**, l’adresse et le QR du serveur permettent de configurer un autre appareil dès **Quel serveur ?**.

**Changer de serveur** sert au déménagement du foyer. Cela déconnecte l’appareil et efface ses données locales, **y compris les courses non envoyées**. Un appareil partagé demande d’abord le PIN parental.

## Exporter les données {#export-data}

Depuis son téléphone personnel, un parent peut exporter le foyer dans **Avancés → Famille → Exporter les données**.

L’archive zip contient membres, événements, emplois du temps, tâches, recettes, courses, etc. Elle **ne contient pas de mots de passe, PIN ou données de connexion**. Les appareils n’y figurent qu’avec nom et dates.

Le dossier `tables` contient un fichier JSON par type de données ; `export.json` indique le contenu et les nombres d’entrées. Laissez l’app ouverte pendant l’export, qui peut prendre une minute pour un ancien foyer. Un serveur plus ancien fournit un seul fichier JSON.

Pour quitter ou supprimer le foyer, consultez [Compte et famille](/fr/settings/account).

## Calendriers externes {#outside-calendars}

Les abonnements se gèrent dans **Paramètres → Avancés → Ajouter des calendriers externes**. Consultez le [calendrier](/fr/calendar/#outside-calendars).

## Réafficher les premiers pas {#show-getting-started-again}

**Paramètres → Premiers pas** réaffiche la carte sur Aujourd’hui. Elle recense les étapes restantes : invitations, tablette, mur, PIN, calendrier, emploi du temps et rappels.
