# Serveur loué (Hetzner et autres)

Entre Supabase et la machine à la maison : vous louez un petit serveur Linux chez un hébergeur européen, et WuselWall s’installe tout seul au premier démarrage. Pas de machine allumée chez vous, pas de port à ouvrir sur la box, pas de compte GitHub ni Supabase. Les données restent chez l’hébergeur de votre choix en Europe, sur un serveur qui n’appartient qu’à vous.

Techniquement, c’est la même pile Docker qu’[à la maison](/fr/server/home-server). Tout ce qui y figure (connexion de l’app, sauvegardes, mises à jour, langue des e-mails, commandes) s’applique ici. Cette page ne décrit que la mise en route.

## Préparer {#what-you-need}

- Un compte chez un hébergeur proposant **cloud-init** (sélection ci-dessous) ; environ **4 à 8 € par mois**.
- Un **domaine** avec deux noms, `api.` et `web.`, environ 1 à 2 € par mois.
- Une **clé SSH** sur votre ordinateur (`ssh-keygen` si vous n’en avez pas).
- Un **fournisseur d’e-mails** pour les codes de connexion, comme pour tout serveur WuselWall ([Options](/fr/server/extras#email)).

## Hébergeurs {#providers}

Tous sont des sociétés européennes avec des centres de données en Europe et un accord de traitement RGPD dans leurs documents contractuels. Les prix et la disponibilité changent ; vérifiez chez l’hébergeur. WuselWall a besoin de **2 vCPU et 4 Go de mémoire**, 8 Go avec la [reconnaissance de texte](/fr/server/extras#text-recognition).

| Hébergeur | Siège, centres de données | Taille adaptée | Remarque |
|---|---|---|---|
| [Hetzner Cloud](https://www.hetzner.com/cloud) | Allemagne ; Falkenstein, Nuremberg, Helsinki | 2 vCPU, 4 Go, à partir d’environ 4 à 6 €, plus 0,50 € pour une adresse IPv4 | Guide ci-dessous. Les petites tailles sont parfois en rupture |
| [netcup](https://www.netcup.com/) | Allemagne ; Nuremberg, Vienne | VPS 4 Go, environ 4 à 6 € | Bon marché ; attention à la durée d’engagement |
| [IONOS](https://www.ionos.fr/) | Allemagne | VPS 4 Go, environ 5 à 8 € | |
| [Scaleway](https://www.scaleway.com/) | France ; Paris, Amsterdam, Varsovie | DEV1-M ou équivalent, environ 8 € | Pratique si vos e-mails passent déjà par Scaleway |
| [OVHcloud](https://www.ovhcloud.com/) | France ; Gravelines, Strasbourg, etc. | VPS 4 Go, environ 5 à 7 € | |
| [Infomaniak](https://www.infomaniak.com/) | Suisse ; Genève | VPS ou Public Cloud 4 Go, environ 6 à 10 € | Droit suisse de la protection des données |

**Où sont les données ?** Sur votre propre serveur chez l’hébergeur. Il fournit matériel, électricité et réseau et voit la connexion chiffrée, pas son contenu ; seul WuselWall lit votre base. Contrairement à Supabase, l’hébergeur est européen et seul le droit européen s’applique.

## Chez Hetzner, pas à pas {#hetzner-step-by-step}

1. **Préparer le fichier.** Ouvrez [`server/cloud-init.yaml`](https://github.com/wuselwall/wuselwall-app/blob/main/server/cloud-init.yaml) sur GitHub, copiez son contenu dans un éditeur de texte et modifiez la seule ligne marquée `CHANGE` : la version depuis les [publications](https://github.com/wuselwall/wuselwall-app/releases), vos deux adresses et la langue des e-mails (`de`, `en`, `fr` ou `es`).
2. **Projet et clé.** Dans la [console Hetzner Cloud](https://console.hetzner.cloud/), créez un projet, par exemple « WuselWall », et ajoutez votre clé SSH publique sous **Security → SSH keys**.
3. **Créer le serveur.** **Add server** : emplacement Falkenstein, Nuremberg ou Helsinki ; image **Ubuntu 24.04** ; type partagé avec **4 Go** ; réseau IPv4 et IPv6 ; votre clé SSH ; un pare-feu Hetzner est facultatif, le fichier en configure un sur le serveur ; en bas, collez le contenu préparé dans **Cloud config**. Nommez-le `wuselwall`, puis **Create & Buy now**.
4. **DNS.** La console affiche aussitôt l’adresse IPv4. Chez votre registrar, créez deux enregistrements A, `api` et `web`, vers cette adresse (et des AAAA avec l’IPv6 si vous le souhaitez). Caddy réessaie jusqu’à ce que les noms répondent.
5. **Lire le résultat.** Après 5 à 10 minutes :

   ```bash
   ssh root@<ip> cat /srv/wuselwall/install.log
   ```

   Vous y trouvez l’adresse du serveur, le lien de configuration avec son QR et le code à usage unique. Copiez tout de suite `/srv/wuselwall/stack/.env` dans votre gestionnaire de mots de passe ([pourquoi](/fr/server/home-server#_1-installing)).
6. **Poursuivre comme à la maison :** [connecter l’app](/fr/server/home-server#_2-connecting-the-app), configurer la [sauvegarde](/fr/server/home-server#_3-backups) et, dès le début, une [sauvegarde hors site](/fr/server/extras#off-site-backup), car un serveur loué n’a qu’un disque. Les sauvegardes Hetzner (environ 20 % de plus) copient tout le disque : un bon complément, pas un remplacement.

Chez les autres hébergeurs, le champ s’appelle **User data**, **Cloud-init** ou **Script de démarrage** ; les étapes sont les mêmes.

## Au quotidien {#day-to-day}

Les commandes s’exécutent en SSH dans `/srv/wuselwall`, comme [à la maison](/fr/server/home-server#useful-commands) :

| | Commande |
|---|---|
| Mettre à jour | `./wuselwall update 1.1.0` |
| Sauvegarder maintenant | `./wuselwall backup` |
| Tout fonctionne ? | `./wuselwall status` |

Ubuntu installe seul les mises à jour de sécurité. Après une mise à jour du noyau, redémarrez une fois (`reboot`) ; la pile repart d’elle-même.

## Déménager {#moving}

Du serveur loué vers la maison ou l’inverse : sauvegarde, installation au nouvel endroit avec l’ancien `stack/.env`, restauration ([Restaurer une sauvegarde](/fr/server/restore)). Si les adresses ne changent pas, les appareils restent connectés.
