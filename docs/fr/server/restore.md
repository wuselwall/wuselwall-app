# Restaurer une sauvegarde

Testez la restauration sur une seconde machine ou une machine virtuelle avant d’en avoir besoin. Une copie n’est utile que si elle se restaure.

## À la maison {#at-home}

L’outil restaure une sauvegarde `db-….dump` sur un serveur **fraîchement installé**. Gardez également l’ancien **`stack/.env`**, pour préserver les clés et les connexions des appareils.

1. Faites pointer les noms `api.` et `web.` vers la nouvelle machine.
2. Décompressez la même version serveur ou une plus récente, puis installez avec l’ancien fichier :

   ```bash
   ./wuselwall install --env /path/to/old.env
   ```

3. Restaurez :

   ```bash
   ./wuselwall restore /path/to/db-2026-10-14-0330-nightly.dump
   ```

4. Vérifiez l’app sur un téléphone : avec les anciennes clés, elle doit retrouver sa connexion.

L’outil arrête les autres services, remplace la base, redémarre, applique les migrations nécessaires et reprogramme les tâches. Il compte ensuite foyers, membres, appareils et comptes.

::: warning Serveur contenant déjà des données
La restauration est refusée par défaut. Pour revenir volontairement à un état antérieur, préfixez la commande par `WW_RESTORE_OVER_DATA=yes`.
:::

Avant de remplacer quoi que ce soit, l’outil sauvegarde toujours l’état actuel (`db-…-before-restore.dump`), même sur un serveur vide. S’il ne peut pas savoir si une famille existe, ou si cette sauvegarde échoue, il s’arrête sans rien changer.

Sans ancien `.env`, installez normalement avec `--api` et `--web`, puis restaurez. Les données reviennent, mais il faut reconnecter les appareils.

### Sauvegardes chiffrées {#encrypted}

Une sauvegarde contient tout, y compris les empreintes des mots de passe et les secrets des codes à deux facteurs. L’outil la rend lisible par son seul propriétaire, dans un répertoire que lui seul peut ouvrir. Si les sauvegardes se trouvent sur un partage lisible par d’autres sur le réseau, ou si vous voulez les protéger de toute façon, il chiffre chaque fichier quand le `backup.env` à côté de l’outil (`chmod 600`) contient l’une de ces lignes :

```bash
# Recommandé : avec age (apt install age). Le serveur ne connaît que la clé publique.
BACKUP_AGE_RECIPIENT=age1…
# Ou avec une longue phrase secrète (openssl, déjà présent) :
BACKUP_PASSPHRASE='…'
```

Créez la clé age une fois sur votre ordinateur avec `age-keygen -o wuselwall-backup.key` ; la ligne `public key: age1…` va dans `backup.env`, le fichier `wuselwall-backup.key` dans le gestionnaire de mots de passe et **pas** sur le serveur. La phrase secrète va elle aussi dans le gestionnaire de mots de passe. Sans la clé ou la phrase, une sauvegarde chiffrée ne vaut rien.

Les sauvegardes s’appellent alors `db-….dump.age` ou `db-….dump.enc`. Pour en restaurer une, déchiffrez-la d’abord et donnez à `restore` le fichier déchiffré :

```bash
age -d -i /path/to/wuselwall-backup.key -o db-2026-10-14-0330-nightly.dump db-2026-10-14-0330-nightly.dump.age
# ou, avec la phrase secrète (openssl la demande) :
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in db-2026-10-14-0330-nightly.dump.enc -out db-2026-10-14-0330-nightly.dump
```

Supprimez ensuite le fichier déchiffré. L’exercice de restauration (`infra/backup/restore-drill.sh`) lit directement les sauvegardes chiffrées, avec `BACKUP_PASSPHRASE` ou avec `BACKUP_AGE_IDENTITY=/path/to/wuselwall-backup.key`.

## Chez Supabase {#at-supabase}

Utilisez **Database → Backups** selon votre offre ; le projet peut être indisponible pendant la restauration. Pour une copie indépendante, suivez la [procédure officielle avec la CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore). Chiffrez les fichiers : ils contiennent les données du foyer.

Ces copies permettent aussi un déménagement entre Supabase et un serveur personnel, mais le parcours complet n’est pas encore documenté étape par étape.
