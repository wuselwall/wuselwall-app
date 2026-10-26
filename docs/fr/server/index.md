# Votre propre serveur : vue d’ensemble

Chaque famille possède **son propre serveur**. L’app n’échange qu’avec lui ; nous n’hébergeons pas les rendez-vous, tâches ou courses des familles.

Ces pages s’adressent à la personne qui installe le serveur. Supabase se configure dans le navigateur. Un serveur loué demande un domaine et une connexion SSH pour lire le résultat. À la maison, il faut savoir utiliser SSH et Docker.

::: warning État en octobre 2026
L’installation du serveur et le choix du serveur dans l’app sont développés, ainsi que les invitations et la démonstration sans serveur. La publication dans les boutiques, les notifications push et les validations de lancement restent séparées. En attendant l’App Store et Google Play, utilisez l’app web.
:::

## Un serveur, une famille {#one-server-one-family}

Un serveur appartient à **un seul foyer**. Après sa création, aucune deuxième famille ne peut y être créée. Des amis doivent installer leur propre serveur ou créer un projet Supabase distinct.

## Trois possibilités {#two-ways}

| | [Chez Supabase](/fr/server/supabase-cloud) | [Loué](/fr/server/rented-server) | [À la maison](/fr/server/home-server) |
|---|---|---|---|
| Matériel | Comptes Supabase et GitHub, pas de machine, plus un fournisseur d’e-mails | Compte chez un hébergeur européen comme Hetzner, domaine et fournisseur d’e-mails | NAS ou mini-PC avec Docker, domaine et fournisseur d’e-mails |
| Installation | Dans le navigateur | Un fichier collé à la création du serveur, deux enregistrements DNS | Outil en ligne de commande, DNS et réseau |
| Données | Centre de données choisi chez Supabase Inc. (États-Unis) | Hébergeur européen de votre choix, sur votre propre serveur | Machine sous votre contrôle |
| Coûts | Selon l’offre Supabase ; voir ses tarifs actuels | Environ 6 à 25 € par mois, plus le domaine | Matériel, électricité et domaine |
| Entretien | Supabase entretient sa plateforme ; vous mettez WuselWall à jour | Vous, une commande SSH par mise à jour ; le système se met à jour seul | Vous gérez mises à jour et sauvegardes |

Les prix sont des ordres de grandeur indicatifs, état octobre 2026, pas des offres ; seule la grille actuelle du fournisseur fait foi. WuselWall est indépendant et n’est lié ni à Supabase, ni à GitHub, ni à Hetzner, ni aux autres fournisseurs cités dans ces pages.

Un NAS déjà équipé de Docker peut convenir. Pour des données en Europe sous votre contrôle sans machine chez vous, louez un serveur chez Hetzner ou un hébergeur comparable. Sinon, Supabase évite l’entretien d’une machine. Consultez les conditions et tarifs avant de choisir. Un [déménagement](/fr/server/restore) est possible.

## Ce qui est nécessaire {#what-you-need-and-what-you-dont}

- **Supabase**, hébergé ou sous Docker : base, authentification, mises à jour en direct et fonctions serveur.
- **Envoi d’e-mails SMTP** : les premiers codes de connexion doivent arriver. Le mode sans messagerie est encore prévu ([Options](/fr/server/extras#email)).
- **HTTPS** : intégré chez Supabase, ou géré par Caddy à la maison.
- **Tâches planifiées** : préparation des tâches des 14 prochains jours, clôture de la veille, synchronisation des jours fériés, calendriers externes et purge. L’installation les programme.
- **Sauvegarde** : la base contient vos données irremplaçables.

## Les options

L’app web est fournie à la maison ou publiée par votre workflow GitHub. Les données OpenHolidays nécessitent une connexion du serveur ; les calendriers externes ne sont consultés que si vous vous y abonnez. Le partage du calendrier vers Outlook ou iPhone demande un serveur accessible depuis Internet.

Les clés d’accès ne sont pas disponibles pour tous les serveurs ; le code par e-mail et le mot de passe restent les méthodes de connexion. Sauvegarde hors site et surveillance sont décrites dans les [options](/fr/server/extras). Aucun compte Google, Apple, Firebase, service d’analyse ou captcha n’est nécessaire au fonctionnement de WuselWall.

## Ensuite {#what-comes-next}

Ouvrez l’app, choisissez l’adresse ou l’identifiant du projet et créez la famille avec le code de configuration. Le [guide de connexion](/fr/guide/setup) décrit les invitations et les autres appareils ; leurs codes QR contiennent aussi le serveur.
