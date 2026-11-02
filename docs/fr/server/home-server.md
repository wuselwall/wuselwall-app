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
v=1.0.0
for f in wuselwall-server-$v.tar.gz SHA256SUMS SHA256SUMS.minisig; do
  curl -fsSLO "https://github.com/wuselwall/wuselwall-app/releases/download/server-v$v/$f"
done
minisign -Vm SHA256SUMS -P REPLACE-WITH-THE-RELEASE-PUBLIC-KEY
sha256sum -c --ignore-missing SHA256SUMS
tar xzf wuselwall-server-$v.tar.gz
cd wuselwall
./wuselwall install --api https://api.example.org --web https://web.example.org --language fr --caddy
```

Les deux vérifications (signature et somme de contrôle) doivent réussir avant de décompresser ; ce qu'elles doivent afficher et d'où vient `minisign` est expliqué sous [Vérifier un téléchargement](/fr/server/rented-server#checking-a-download).

`--language` choisit la langue des **e-mails** (`de`, `en`, `fr`, `es`, allemand par défaut), pas celle de l’app. Docker télécharge plusieurs gigaoctets. L’outil crée les clés dans `stack/.env`, lance Caddy et ses certificats Let’s Encrypt, prépare la base et les tâches planifiées, puis affiche un **lien de configuration et son QR**, contenant une clé de configuration à usage unique. Aucun Node.js ni serveur web supplémentaire n’est requis.

Le serveur démarre **sans e-mails** : chacun se connecte avec adresse et mot de passe. `./wuselwall mail smtp` ajoute les codes par e-mail à tout moment ([E-mails](/fr/server/email)).

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

## Serveur loué {#vps}

Si vous louez le serveur chez un hébergeur comme Hetzner, un fichier **cloud-init** l’installe au premier démarrage, sans SSH pour l’installation. La page [Serveur loué](/fr/server/rented-server) l’explique. Tout le reste de cette page s’y applique aussi.

## 2. Connecter l’app {#_2-connecting-the-app}

L’app web lit la configuration de l’installation à chaque chargement, même si une ancienne adresse est mémorisée. Hors ligne, elle utilise la dernière configuration. Un changement d’adresse demande une nouvelle connexion.

Ouvrez le lien de configuration ou scannez son QR. Il contient le serveur et la clé de configuration et ouvre **Configurer ton serveur** : vous y saisissez l’adresse e-mail du premier compte, et le serveur ne laisse que cette adresse se connecter ([La clé de configuration](/fr/guide/setup#setup-key)). **Nouvelle famille** ne demande ensuite aucune clé.

Vous pouvez aussi saisir `api.example.org` dans le choix du serveur : l’écran d’accueil indique que le serveur n’a pas encore de famille, touchez **J’ai la clé de configuration** et saisissez la clé à côté de votre adresse. Un ancien QR contenant seulement l’adresse ne transporte pas la clé non plus. `./wuselwall setup-token` en génère une nouvelle tant qu’aucun foyer n’existe. Ne publiez ni clé ni lien : tant que la famille n’existe pas, seule la personne qui la détient peut créer un compte sur le serveur.

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

L’outil sauvegarde avant de télécharger et d’appliquer la nouvelle version, y compris la base, l’app web et les tâches planifiées. Si vous utilisiez Apple ou Google pour la connexion, lisez d’abord la [migration](/fr/server/extras#retiring-social-sign-in). Un serveur installé sans fournisseur d’e-mails avant que ceux-ci deviennent facultatifs ne peut encore inscrire personne : la mise à jour le signale, lancez alors une fois `./wuselwall mail off`.

### Quelle app avec quel serveur {#compatibilite}

L’app vérifie elle-même, en se connectant, qu’elle va avec ton serveur, et te dit quand l’app ou le serveur a besoin d’une mise à jour. Chaque app comprend l’API de son serveur et celle d’avant ; le serveur indique aussi l’app la plus ancienne avec laquelle il fonctionne encore. Ce qui tourne s’affiche dans l’app sous **Réglages → Versions**, par exemple « App 1.1.0 · Serveur 0.3.0 · API 1 ». À partir du serveur 0.3.0, le serveur y indique sa version ; l’app ne propose la reconnaissance de texte que si le serveur l’a installée.

<CompatTable />

::: warning Mises à jour coordonnées
N’utilisez pas Watchtower ni les mises à jour automatiques de conteneurs du NAS pour cette pile. Passez par `wuselwall update` pour conserver un ensemble compatible.
:::

## Commandes utiles {#useful-commands}

| Commande | Fonction |
|---|---|
| `./wuselwall status` | État des services |
| `./wuselwall logs auth` | Journaux de `auth` ; aussi `db`, `rest`, `realtime`, `functions`, `caddy` |
| `./wuselwall backup` | Sauvegarde immédiate |
| `./wuselwall setup-token` | Nouvelle clé de configuration avant création du foyer |
| `./wuselwall mail` | E-mails activés (`mail smtp`), coupés (`mail off`) ou testés (`mail test`) ([E-mails](/fr/server/email)) |
| `./wuselwall password <adresse>` | Code à usage unique pour choisir un nouveau mot de passe ([E-mails](/fr/server/email#forgotten-password)) |
| `./wuselwall compose …` | Commande Docker Compose pour la pile |

Studio est désactivé. Avec `--studio`, accédez-y par tunnel SSH : `ssh -L 54421:172.17.0.1:54421 server`, puis `http://127.0.0.1:54421`. Les identifiants sont dans `DASHBOARD_USERNAME` et `DASHBOARD_PASSWORD` de `stack/.env`.

## Votre proxy à la place de Caddy {#your-own-web-server-instead-of-caddy}

Installez sans `--caddy` si vous possédez déjà nginx, Traefik ou un autre proxy. La pile écoute alors seulement sur `172.17.0.1:54421`, l’adresse de Docker, que seul le serveur lui-même atteint.

- Pour l’API, transmettez `/auth/v1/`, `/rest/v1/`, `/realtime/v1/` avec WebSockets et `/functions/v1/` vers `http://172.17.0.1:54421`. Transmettez `/.well-known/wuselwall.json` vers `/functions/v1/server-info` de cette destination. Les autres chemins, y compris `/rest/v1/` sans suite, renvoient 404.
- Pour le web, servez `stack/volumes/web`, renvoyez les chemins inconnus vers `index.html` et transmettez le même fichier de découverte.
- **`X-Forwarded-For` avec l’adresse que votre proxy a vue lui-même** — avec nginx `proxy_set_header X-Forwarded-For $remote_addr;`. Le serveur compte les tentatives échouées par adresse (clé de configuration, codes, invitations). Si votre proxy transmet l’en-tête tel quel, un attaquant choisit son adresse. Derrière un tunnel Cloudflare, utilisez `$http_cf_connecting_ip`.

`stack/volumes/caddy/Caddyfile` sert de modèle. Pour nginx, l’essentiel ressemble à ceci, avec un frein sur les chemins que chacun peut appeler sans se connecter (l’image standard de Caddy n’en a pas ; le serveur freine aussi lui-même par adresse) :

```nginx
# One bucket per address for the paths anyone may call without signing in: the pairing,
# invitation, password-reset and setup-key endpoints. 30 requests a minute is far more
# than a family needs and far less than a guesser wants.
limit_req_zone $binary_remote_addr zone=wuselwall_anon:1m rate=30r/m;
map $http_upgrade $connection_upgrade { default upgrade; '' close; }

server {
    server_name api.example.org;
    # TLS as usual (certbot, acme.sh, ...)

    location ~ ^/rest/v1/rpc/(pairing_start|pairing_poll|invitation_preview|password_reset_redeem|setup_claim|enrol_device)$ {
        limit_req zone=wuselwall_anon burst=20 nodelay;
        proxy_pass http://172.17.0.1:54421;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location ~ ^/(auth|rest|realtime|functions)/v1/ {
        proxy_pass http://172.17.0.1:54421;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;        # Realtime (WebSockets)
        proxy_set_header Connection $connection_upgrade;
    }
    location = /rest/v1/ { return 404; }
    location = /.well-known/wuselwall.json {
        proxy_pass http://172.17.0.1:54421/functions/v1/server-info;
    }
    location / { return 404; }
}
```

Si le proxy est sur une autre machine, laissez quand même la pile sur `172.17.0.1`. Le plus simple : installez finalement avec `--caddy` et redirigez 80 et 443 du routeur vers le serveur ; Caddy chiffre, et votre autre proxy n’est plus nécessaire pour WuselWall. Sinon, ouvrez un tunnel SSH depuis la machine du proxy vers le serveur (`ssh -N -L 54421:172.17.0.1:54421 server`) et transmettez là vers `http://127.0.0.1:54421`. Régler `GATEWAY_BIND` dans `stack/.env` sur une adresse du réseau domestique fonctionne aussi, mais alors **toute la passerelle est en clair sur le réseau domestique** : connexion, API de la base, Realtime et fonctions, et avec `--studio` aussi Studio et `/pg/`. Ne le faites qu’avec une règle de pare-feu sur le serveur qui n’ouvre ce port qu’à l’adresse de votre proxy, puis relancez `./wuselwall compose up -d`.
