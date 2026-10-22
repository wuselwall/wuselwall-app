# Installer un serveur à la maison

Une **version serveur** contient la pile Docker Supabase, WuselWall, l’app web et l’outil `wuselwall` pour installer, mettre à jour et sauvegarder.

Les exemples utilisent `api.example.org` pour l’API et `web.example.org` pour l’app web. Remplacez-les par vos adresses.

## Préparer {#what-you-need}

- Une machine Linux toujours allumée avec **Docker et Docker Compose v2**, accessible en SSH par un utilisateur autorisé à lancer Docker.
- **4 Go de mémoire** pour WuselWall et **10 Go d’espace libre**. x86-64 est testé ; ARM, dont Raspberry Pi 5, reste non testé.
- Un domaine avec les noms `api.` et `web.` pointant vers votre IP publique. Si elle change, prévoyez du DNS dynamique.
- Une redirection des ports **TCP 80 et 443** vers le serveur.

Sans ports ouverts, un tunnel Cloudflare peut transporter le trafic, mais Cloudflare le déchiffre et peut le voir. Installez alors sans `--caddy` et utilisez les destinations du proxy décrites ci-dessous. Un VPN tel que WireGuard ou Tailscale garde le serveur privé, mais tous les appareils doivent l’utiliser et les abonnements calendaires externes peuvent ne pas fonctionner.

## 1. Installer {#_1-installing}

Choisissez une version dans les [publications](https://github.com/wuselwall/wuselwall-app/releases). `1.0.0` est un exemple de numéro, pas une promesse de disponibilité. Sur le serveur :

```bash
curl -fsSL https://github.com/wuselwall/wuselwall-app/releases/download/server-v1.0.0/wuselwall-server-1.0.0.tar.gz | tar xz
cd wuselwall
./wuselwall install --api https://api.example.org --web https://web.example.org --language fr --caddy
```

`--language` choisit la langue des **e-mails** (`de`, `en`, `fr`, `es`, allemand par défaut), pas celle de l’app. Docker télécharge plusieurs gigaoctets. L’outil crée les clés dans `stack/.env`, lance Caddy et ses certificats Let’s Encrypt, prépare la base et les tâches planifiées, puis affiche un **lien de configuration et son QR**, contenant un code à usage unique. Aucun Node.js ni serveur web supplémentaire n’est requis.

::: danger Conservez immédiatement stack/.env
Copiez ce fichier dans votre gestionnaire de mots de passe. Il contient les clés nécessaires pour que les appareils restent connectés après restauration. **Ne le régénérez jamais sur un serveur existant.**
:::

S’il n’existe pas encore de version publiée, construisez-la sur un ordinateur avec Git, rsync et Flutter :

```bash
git clone https://github.com/wuselwall/wuselwall-app.git && cd wuselwall-app
scripts/build-server-release.sh 0.1.0
scp dist/wuselwall-server-0.1.0.tar.gz server:
```

Décompressez ensuite sur le serveur. `--skip-web` permet de construire sans Flutter, sans inclure l’app web.

## 2. Connecter l’app {#_2-connecting-the-app}

L’app web lit la configuration de l’installation à chaque chargement, même si une ancienne adresse est mémorisée. Hors ligne, elle utilise la dernière configuration. Un changement d’adresse demande une nouvelle connexion.

Ouvrez le lien de configuration ou scannez son QR. Il contient serveur et code ; l’app conserve ce dernier pendant la connexion par e-mail et ne le redemande pas pour la [nouvelle famille](/fr/guide/setup#_2-creating-a-new-family).

Vous pouvez aussi saisir `api.example.org` dans le choix du serveur. Un ancien QR contenant seulement l’adresse ne transporte pas le code de configuration : saisissez-le alors une fois. `./wuselwall setup-token` en génère un nouveau tant qu’aucun foyer n’existe. Ne publiez ni code ni lien.

## 3. Sauvegarder {#_3-backups}

Ajoutez une ligne au crontab du serveur ou au planificateur du NAS :

```txt
30 3 * * * BACKUP_DIR=/srv/backups/wuselwall /path/to/wuselwall/wuselwall backup nightly
```

Les sauvegardes sont vérifiées et conservées 14 jours. Sans `BACKUP_DIR`, elles vont dans `backups/` près de l’outil. Préférez un autre disque et une [copie hors site](/fr/server/extras#off-site-backup). Testez la [restauration](/fr/server/restore).

## Langue des e-mails {#email-language}

```bash
./wuselwall language fr
```

Les quatre codes de langue sont acceptés. L’outil écrit `MAIL_LANGUAGE`, choisit sujets et modèles, puis redémarre seulement authentification et fonctions. Les clés sont conservées et les mises à jour gardent le choix. Sans valeur, une ancienne installation utilise l’allemand. Depuis un dépôt source, utilisez `scripts/remote-stack.sh language fr` après déploiement.

## Mettre à jour {#updates}

```bash
./wuselwall update 1.1.0
```

L’outil sauvegarde avant de télécharger et d’appliquer la nouvelle version, y compris la base, l’app web et les tâches planifiées. Si vous utilisiez Apple ou Google pour la connexion, lisez d’abord la [migration](/fr/server/extras#retiring-social-sign-in).

::: warning Mises à jour coordonnées
N’utilisez pas Watchtower ni les mises à jour automatiques de conteneurs du NAS pour cette pile. Passez par `wuselwall update` pour conserver un ensemble compatible.
:::

## Commandes utiles {#useful-commands}

| Commande | Fonction |
|---|---|
| `./wuselwall status` | État des services |
| `./wuselwall logs auth` | Journaux de `auth` ; aussi `db`, `rest`, `realtime`, `functions`, `caddy` |
| `./wuselwall backup` | Sauvegarde immédiate |
| `./wuselwall setup-token` | Nouveau code avant création du foyer |
| `./wuselwall compose …` | Commande Docker Compose pour la pile |

Studio est désactivé. Avec `--studio`, accédez-y par tunnel SSH : `ssh -L 54421:172.17.0.1:54421 server`, puis `http://127.0.0.1:54421`. Les identifiants sont dans `DASHBOARD_USERNAME` et `DASHBOARD_PASSWORD` de `stack/.env`.

## Votre proxy à la place de Caddy {#your-own-web-server-instead-of-caddy}

Installez sans `--caddy` si vous possédez déjà nginx, Traefik ou un autre proxy. La pile écoute alors sur `172.17.0.1:54421`.

- Pour l’API, transmettez `/auth/v1/`, `/rest/v1/`, `/realtime/v1/` avec WebSockets et `/functions/v1/` vers `http://172.17.0.1:54421`. Transmettez `/.well-known/wuselwall.json` vers `/functions/v1/server-info` de cette destination. Les autres chemins, y compris `/rest/v1/` sans suite, renvoient 404.
- Pour le web, servez `stack/volumes/web`, renvoyez les chemins inconnus vers `index.html` et transmettez le même fichier de découverte.

`stack/volumes/caddy/Caddyfile` sert de modèle. Si le proxy est sur une autre machine, réglez `GATEWAY_BIND` sur une adresse accessible puis lancez `./wuselwall compose up -d`.
