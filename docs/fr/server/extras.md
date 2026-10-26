# Options du serveur

Tout est facultatif ici. Les commandes s’exécutent près de l’outil `wuselwall`. N’ajoutez que les services dont vous avez besoin.

## E-mails {#email}

Les e-mails sont facultatifs : sans eux, chacun se connecte avec un mot de passe. Pour envoyer les codes de connexion par e-mail, Gmail compris, voir [E-mails](/fr/server/email).

## Anciennes connexions Apple et Google {#retiring-social-sign-in}

Ces anciens comptes utilisent désormais le code envoyé à leur adresse e-mail, sans changer de famille ni de compte.

**Vérifiez avant la mise à jour** : avec « Masquer mon adresse e-mail » d’Apple, l’adresse se termine par `privaterelay.appleid.com`. L’expéditeur doit être enregistré pour le transfert Apple. Si le code n’arrive pas, différez la mise à jour pour éviter de bloquer la prochaine connexion.

À la maison, `wuselwall update` retire les anciennes valeurs Apple/Google, l’adresse de retour et la fonction `apple-token`, en affichant les noms seulement.

**Après la mise à jour**, testez un ancien compte sur un **second appareil**, par code e-mail, sans déconnecter le premier. Ensuite seulement :

- retirez les clients OAuth Google utilisés uniquement pour WuselWall, jamais le projet Cloud, Play Console ou les ressources d’autres apps ;
- retirez les identifiants et clés de connexion Apple devenus inutiles, mais gardez les expéditeurs de transfert tant que des comptes utilisent l’adresse relais.

## Jours fériés et vacances {#holidays}

Votre serveur consulte [OpenHolidays](https://www.openholidaysapi.org/) chaque semaine pour les pays choisis. Il transmet les codes de pays, pas les membres ni les écoles ; l’app ne contacte pas ce service. Sans accès Internet du serveur, ces données peuvent manquer, mais les autres fonctions continuent.

## Reconnaissance de texte pour les emplois du temps {#text-recognition}

Avec la reconnaissance de texte, l’app peut importer un emploi du temps photographié ou le PDF de l’école ([Importer un emploi du temps](/fr/school/#reading-in)) ; le texte d’un PDF est lu directement, un PDF scanné comme une photo. C’est un conteneur à part dans la pile, qui tourne uniquement sur le processeur de votre serveur : la photo va du téléphone à votre serveur, le conteneur lit le texte, et rien ne quitte la maison. Il n’a besoin ni d’internet ni de carte graphique, et d’environ 1 Go de mémoire ; sur un petit serveur domestique, une feuille prend quelques secondes.

Pour l’installer, dans le dossier de la pile :

1. Ajouter la ligne `OCR_URL=http://ocr:9003/ocr` au fichier `.env`.
2. Construire et démarrer le conteneur : `docker compose --profile ocr up -d --build`. La première construction télécharge les modèles de reconnaissance (environ 20 Mo) ; ensuite il tourne sans internet.
3. Redémarrer les fonctions pour qu’elles connaissent l’adresse : `docker compose restart functions`.

L’app propose alors **Scanner une photo** sous **Importer…**. Sans cette ligne, l’entrée reste, mais l’app indique que le serveur n’a pas de reconnaissance de texte. La reconnaissance utilise RapidOCR avec les modèles PP-OCR de PaddleOCR (tous deux Apache-2.0, la même base que le gestionnaire de photos Immich utilise pour sa reconnaissance de texte).

Avec l’image, l’app envoie sa langue ainsi que les noms et abréviations de vos matières. Ainsi le serveur lit vos mots comme vos matières. La fonction accepte des photos (JPEG, PNG, WebP, HEIC) et des PDF jusqu’à 6 Mo, ne garde rien et n’écrit aucune image dans le journal. Ce que le serveur lit sur une feuille, et ses limites, figure sous [Importer un emploi du temps](/fr/school/#reading-in).

## Sauvegarde hors site {#off-site-backup}

Un autre disque local ne protège pas contre le vol ou l’incendie. L’outil peut envoyer les sauvegardes **chiffrées** avec [restic](https://restic.net/) vers Backblaze B2 ou un stockage S3. Le fournisseur ne voit que le contenu chiffré.

Créez `backup.env` près de l’outil, avec `chmod 600 backup.env` :

```bash
RESTIC_REPOSITORY=b2:<bucket>:wuselwall
RESTIC_PASSWORD=<mot de passe long à conserver aussi dans le gestionnaire>
B2_ACCOUNT_ID=<identifiant de clé>
B2_ACCOUNT_KEY=<clé d’application>
```

Initialisez une fois :

```bash
docker run --rm --env-file backup.env restic/restic:0.18.0 init
```

Les prochaines commandes `wuselwall backup`, y compris nocturnes, y enverront une copie. Gardez **RESTIC_PASSWORD** dans votre gestionnaire, avec `stack/.env` : sans lui, les sauvegardes sont inutilisables.

## Surveillance {#monitoring}

Une alerte évite de découvrir trop tard que les sauvegardes se sont arrêtées. Un contrôle [healthchecks.io](https://healthchecks.io/) peut recevoir les confirmations réussies via `HEALTHCHECK_URL=https://hc-ping.com/…` dans `backup.env` et vous alerter en leur absence.

Un outil de surveillance indépendant peut consulter `https://api.example.org/.well-known/wuselwall.json`. Une réponse vérifie le fonctionnement de la passerelle, de la base et de l’authentification.
