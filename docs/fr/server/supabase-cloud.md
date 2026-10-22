# Installer un serveur chez Supabase

Votre projet [Supabase](https://supabase.com/) vous appartient : votre compte, vos données, aucun accès pour nous. Pas besoin de machine ni de domaine. Supabase Inc. est une société américaine ; choisissez la région d’hébergement lors de la création, par exemple un centre européen.

::: warning Validation encore incomplète
L’installation hébergée n’a pas encore été entièrement validée pour WuselWall. Signalez un problème sur [GitHub](https://github.com/wuselwall/wuselwall-app/issues), sans y joindre les données de votre famille.
:::

## Gratuit ou payant ? {#free-or-pro}

L’offre gratuite convient à un essai, mais peut mettre un projet inactif en pause et ne fournit pas les mêmes sauvegardes qu’une offre payante. Vérifiez les limites, la conservation des sauvegardes et les [tarifs actuels](https://supabase.com/pricing) avant l’utilisation quotidienne. Un serveur en pause ne sert plus l’écran mural.

## 1. Créer le projet {#_1-creating-the-project}

Dans le [tableau de bord](https://supabase.com/dashboard), créez un projet, choisissez la région et conservez son mot de passe de base de données dans un gestionnaire de mots de passe. L’**identifiant du projet**, visible dans `https://<project-id>.supabase.co`, suffit ensuite pour connecter l’app.

## 2. Installer WuselWall {#_2-putting-wuselwall-onto-the-project}

1. Créez un compte GitHub, puis un **fork** de [wuselwall-app](https://github.com/wuselwall/wuselwall-app).
2. Dans les préférences du compte Supabase, créez un **Access Token**.
3. Dans votre dépôt GitHub, **Settings → Secrets and variables → Actions**, ajoutez :

   | Secret | Valeur |
   |---|---|
   | `SUPABASE_ACCESS_TOKEN` | Jeton du compte Supabase |
   | `SUPABASE_PROJECT_ID` | Identifiant du projet |
   | `SUPABASE_DB_PASSWORD` | Mot de passe de la base |
   | `WUSELWALL_SETUP_TOKEN` | Phrase alphanumérique choisie pour créer une fois la famille |

4. Activez les workflows dans **Actions**, puis lancez **deploy-supabase → Run workflow**. Choisissez `fr` dans **language** pour les e-mails, et cochez **web** si vous souhaitez publier l’app web.

Le résumé du workflow fournit l’adresse. Il prépare base, accès, authentification, fonctions, modèles d’e-mails et tâches planifiées. Les secrets sont masqués dans les journaux ; ne les affichez pas vous-même. Le jeton du compte Supabase est puissant : vous pouvez le révoquer après l’installation et en créer un pour la prochaine mise à jour. Le serveur ne conserve qu’une empreinte du code de création du foyer.

## 3. Connecter l’app {#_3-connecting-the-app}

Dans **Quel serveur ?**, saisissez l’identifiant du projet, puis créez la famille avec la phrase `WUSELWALL_SETUP_TOKEN` ([Connexion](/fr/guide/setup)).

<Shot name="setup-server" alt="Le choix du serveur dans l’app" />

## 4. L’app web {#_4-the-web-app}

Si **web** est coché, le workflow publie à `https://<your-github-name>.github.io/wuselwall-app/`. Réglez une fois **Settings → Pages → Source → GitHub Actions** dans votre fork. Au premier démarrage, choisissez le serveur.

GitHub reçoit les requêtes de visite du site web ; les données familiales circulent directement entre le navigateur et Supabase. Vous pouvez aussi héberger l’app web d’une version serveur sur votre propre espace web.

## Mises à jour {#updates}

Faites **Sync fork → Update branch**, puis relancez le workflow. **Sauvegardez votre base avant toute migration**. Supabase entretient Postgres, HTTPS et sa plateforme. Pour une ancienne connexion Apple ou Google, consultez la [migration](/fr/server/extras#retiring-social-sign-in).

## Sauvegardes {#backups}

Utilisez les sauvegardes proposées par votre offre dans **Database → Backups** et vérifiez leur conservation. Gardez aussi une copie chiffrée indépendante ; voir [Restaurer](/fr/server/restore#at-supabase).

Si vous préférez la ligne de commande, `.github/workflows/deploy-supabase.yml` détaille `supabase link`, `supabase db push`, les appels d’administration, les secrets, les fonctions et `infra/jobs/schedule.sql`.
