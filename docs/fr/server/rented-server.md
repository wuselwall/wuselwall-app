# Serveur loué (Hetzner et autres)

Vous louez un petit serveur Linux chez un hébergeur européen, et WuselWall s’installe tout seul au premier démarrage. Pas de machine allumée chez vous, pas de port à ouvrir sur la box. Les données restent chez l’hébergeur de votre choix en Europe, sur un serveur qui n’appartient qu’à vous.

Techniquement, c’est la même pile Docker qu’[à la maison](/fr/server/home-server). Tout ce qui y figure (connexion de l’app, sauvegardes, mises à jour, langue des e-mails, commandes) s’applique ici. Cette page ne décrit que la mise en route.

## Préparer {#what-you-need}

- Un compte chez un hébergeur proposant **cloud-init** (sélection ci-dessous) ; environ **6 à 25 € par mois** (état octobre 2026).
- Un **domaine**, environ 1 à 2 € par mois.
- Une **clé SSH** sur votre ordinateur (`ssh-keygen` si vous n’en avez pas).
- Facultatif : un **compte e-mail** pour les codes de connexion, un compte Gmail suffit ([E-mails](/fr/server/email)). Sans lui, chacun se connecte avec un mot de passe.

## Hébergeurs {#providers}

Les trois du tableau sont des sociétés européennes avec des centres de données en Europe ; chacune propose un accord de traitement RGPD et, à la création d’un serveur, un champ pour le fichier cloud-init. WuselWall a besoin de **2 vCPU et 4 Go de mémoire**, 8 Go avec la [reconnaissance de texte](/fr/server/extras#text-recognition).

::: info Indépendant, prix indicatifs
WuselWall n’est lié à aucune des sociétés citées sur cette page, n’est ni sponsorisé ni soutenu par elles et ne reçoit rien pour les mentionner ; les liens sont de simples liens, pas des liens d’affiliation. La liste est une sélection sans ordre particulier : ce n’est ni un classement ni une liste complète. La fourchette de prix est un ordre de grandeur indicatif, état octobre 2026, et non une offre ; les prix changent et sont affichés TTC ou HT selon l’hébergeur. Seuls la grille tarifaire et les conditions de l’hébergeur font foi. Les noms de produits et de sociétés sont des marques de leurs titulaires.
:::

| Hébergeur | Siège, centres de données | Taille adaptée | Champ pour le fichier |
|---|---|---|---|
| [Hetzner Cloud](https://www.hetzner.com/cloud) | Allemagne ; Falkenstein, Nuremberg, Helsinki | CX23 (2 vCPU, 4 Go) ; en rupture, CPX22 | **Cloud config** ; guide ci-dessous |
| [Scaleway](https://www.scaleway.com/) | France ; Paris, Amsterdam, Varsovie | DEV1-M (3 vCPU, 4 Go), IPv4 publique en sus | **Cloud-init** ; pratique si vos e-mails passent déjà par Scaleway |
| [IONOS](https://www.ionos.fr/) | Allemagne ; choisir un centre de données dans l’UE | Cloud Server 4 Go | **Cloud-Init User Data** dans les options avancées ; documenté pour le Cloud Server, pas pour le VPS |

**Coût :** environ **6 à 25 € par mois** pour un serveur adapté, selon l’hébergeur, la taille et la TVA, plus le domaine (état octobre 2026). Les plus petites tailles sont parfois en rupture (chez Hetzner, toute la gamme la moins chère le 25 octobre 2026) ; la taille suivante coûte environ trois fois plus. Seule la grille de l’hébergeur fait foi.

**Sans champ cloud-init :** [netcup](https://www.netcup.com/), [OVHcloud](https://www.ovhcloud.com/) et [Infomaniak](https://www.infomaniak.com/) (Suisse, Genève ; droit suisse de la protection des données) louent aussi des serveurs adaptés en Europe, mais ne documentent pas un tel champ. Créez-y un serveur Ubuntu et installez par SSH comme [à la maison](/fr/server/home-server).

**Où sont les données ?** Sur votre propre serveur chez l’hébergeur. Il fournit matériel, électricité et réseau ; comme tout hébergeur, il pourrait techniquement accéder à la machine, et son accord de traitement lui interdit d’utiliser vos données. Les connexions avec vos appareils sont chiffrées, et seul WuselWall lit votre base. L’hébergeur est une société européenne soumise au droit européen, au droit suisse pour Infomaniak.

## Chez Hetzner, pas à pas {#hetzner-step-by-step}

Ce guide prend Hetzner parce que sa console offre un simple champ cloud-config ; ce n’est pas une recommandation face aux autres. Écrans et noms de boutons : état octobre 2026, ils peuvent changer.

1. **Préparer le fichier.** Ouvrez [`server/cloud-init.yaml`](https://github.com/wuselwall/wuselwall-app/blob/main/server/cloud-init.yaml) sur GitHub, copiez son contenu dans un éditeur de texte et modifiez la seule ligne marquée `CHANGE` : la version depuis les [publications](https://github.com/wuselwall/wuselwall-app/releases), vos deux adresses et la langue des e-mails (`de`, `en`, `fr` ou `es`).
2. **Projet et clé.** Dans la [console Hetzner Cloud](https://console.hetzner.cloud/), créez un projet, par exemple « WuselWall », et ajoutez votre clé SSH publique sous **Security → SSH keys**.
3. **Créer le serveur.** **Add server** : emplacement Falkenstein, Nuremberg ou Helsinki ; image **Ubuntu 24.04** ; type **CX23** (2 vCPU, 4 Go) sous Cost-Optimized, ou **CPX22** sous Regular Performance s’il est en rupture ; réseau IPv4 et IPv6 ; votre clé SSH ; un pare-feu Hetzner est facultatif, le fichier en configure un sur le serveur ; en bas, collez le contenu préparé dans **Cloud config**. Nommez-le `wuselwall`, puis **Create & Buy now**.
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
