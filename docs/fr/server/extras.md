# Options du serveur

Tout est facultatif ici, **sauf l’envoi d’e-mails**, encore nécessaire. Les commandes s’exécutent près de l’outil `wuselwall`. N’ajoutez que les services dont vous avez besoin.

## E-mails {#email}

Le premier accès vérifie l’adresse par un **code à six chiffres**. Sans service SMTP, personne ne peut créer ou rejoindre la famille. Le mode sans e-mail est prévu, pas encore disponible.

L’installation choisit une langue unique pour **tous les sujets et corps de messages** : `de`, `en`, `fr` ou `es`, allemand par défaut. Elle ne dépend ni du destinataire ni de son appareil. Pour la changer : `./wuselwall language fr` ([Installation](/fr/server/home-server#email-language)).

Choisissez un service d’e-mails transactionnels et configurez les enregistrements SPF, DKIM et DMARC demandés. Ce fournisseur reçoit les adresses et les codes. Vérifiez ses conditions et tarifs.

**À la maison**, indiquez `SMTP_HOST`, `SMTP_PORT` (habituellement `587`), `SMTP_USER`, `SMTP_PASS` et `SMTP_ADMIN_EMAIL` dans `stack/.env`, entre apostrophes comme les autres valeurs. Un serveur avec messagerie utilise `ENABLE_EMAIL_AUTOCONFIRM=false`.

```bash
./wuselwall compose up -d auth
```

**Chez Supabase**, renseignez les mêmes informations dans **Authentication → Emails → SMTP Settings**. La messagerie intégrée sert aux essais et reste limitée.

La version serveur et le workflow configurent le premier e-mail de confirmation et les suivants avec un code, sans hook Scaleway obligatoire. Si vous recevez seulement un lien, mettez le serveur à jour ou relancez le workflow mis à jour, puis demandez un nouveau code. Un ancien message ne change pas.

## Anciennes connexions Apple et Google {#retiring-social-sign-in}

Ces anciens comptes utilisent désormais le code envoyé à leur adresse e-mail, sans changer de famille ni de compte.

**Vérifiez avant la mise à jour** : avec « Masquer mon adresse e-mail » d’Apple, l’adresse se termine par `privaterelay.appleid.com`. L’expéditeur doit être enregistré pour le transfert Apple. Si le code n’arrive pas, différez la mise à jour pour éviter de bloquer la prochaine connexion.

À la maison, `wuselwall update` retire les anciennes valeurs Apple/Google, l’adresse de retour et la fonction `apple-token`, en affichant les noms seulement. Chez Supabase, le workflow désactive ces fournisseurs et la liaison de comptes, conserve les autres URL de retour, retire fonction et secrets `APPLE_…`, puis vérifie. Il s’arrête en cas d’échec.

**Après la mise à jour**, testez un ancien compte sur un **second appareil**, par code e-mail, sans déconnecter le premier. Ensuite seulement :

- retirez les clients OAuth Google utilisés uniquement pour WuselWall, jamais le projet Cloud, Play Console ou les ressources d’autres apps ;
- retirez les identifiants et clés de connexion Apple devenus inutiles, mais gardez les expéditeurs de transfert tant que des comptes utilisent l’adresse relais.

## Jours fériés et vacances {#holidays}

Votre serveur consulte [OpenHolidays](https://www.openholidaysapi.org/) chaque semaine pour les pays choisis. Il transmet les codes de pays, pas les membres ni les écoles ; l’app ne contacte pas ce service. Sans accès Internet du serveur, ces données peuvent manquer, mais les autres fonctions continuent.

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
