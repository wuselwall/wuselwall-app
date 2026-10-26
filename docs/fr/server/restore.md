# Restaurer une sauvegarde

Testez la restauration sur une seconde machine ou une machine virtuelle avant d’en avoir besoin. Une copie n’est utile que si elle se restaure.

## À la maison ou loué {#at-home}

L’outil restaure une sauvegarde `db-….dump` sur un serveur **fraîchement installé**. Gardez également l’ancien **`stack/.env`**, pour préserver les clés et les connexions des appareils.

1. Faites pointer votre domaine vers la nouvelle machine.
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
La restauration est refusée par défaut. Pour revenir volontairement à un état antérieur, préfixez la commande par `WW_RESTORE_OVER_DATA=yes`. L’outil sauvegarde d’abord l’état actuel.
:::

Sans ancien `.env`, installez normalement avec `--api` et `--web`, puis restaurez. Les données reviennent, mais il faut reconnecter les appareils.
