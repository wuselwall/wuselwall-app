# Météo et cartes

Pour les [Voyages](/fr/trips/), WuselWall peut interroger des services d’autres entreprises : quelle température il fait typiquement à un endroit, quel temps il fera ces prochains jours, où se trouve un lieu et combien de temps dure le trajet. C’est **entièrement facultatif**. Tout le reste des voyages fonctionne sans ces services, et sans eux votre serveur n’interroge personne.

Les services peuvent ajouter :

- **Climat typique** : à quel point un lieu est chaud, pluvieux et ensoleillé en général pendant un mois, et au bord de la mer la température de l’eau. [Où aller ?](/fr/trips/#discover) l’affiche
- **Prévisions** : le temps à la destination dans les jours avant et pendant le voyage
- **Recherche de lieux** : trouver une destination ou votre domicile par son nom
- **Temps de trajet** : combien de temps dure le trajet en voiture depuis chez vous
- **Image de carte** : une petite image de la destination sur la page du voyage

Vous l’activez sous **Paramètres → Calendrier et école → Partage et connexions → Météo et cartes**. Seuls les parents peuvent le faire. Les autres adultes voient la page et la remarque **Un parent peut modifier cela**.

<Shot name="settings-services" alt="La page Météo et cartes avec le domicile et le fournisseur Open-Meteo, activé, avec le bouton Tester" />

## Trois promesses {#promises}

1. **Tout est désactivé tant qu’un parent ne l’active pas.** Un nouveau serveur n’interroge aucun service météo ni aucun service de cartes. Si vous désactivez de nouveau un fournisseur, tout appel vers lui s’arrête aussitôt.
2. **Seul le serveur de votre famille interroge le fournisseur**, jamais un téléphone et jamais le mur. Votre téléphone ne parle qu’à votre serveur. Le serveur va chercher une image de carte et la transmet.
3. **Un fournisseur ne sait que ce dont la question a besoin :**
   - le lieu que vous regardez ou cherchez : ses coordonnées ou le texte de la recherche
   - pour un temps de trajet, aussi votre domicile, arrondi à environ un kilomètre
   - et, forcément, l’adresse internet de votre serveur

   **Rien sur votre famille** : ni noms, ni compte, ni rendez-vous, ni dates de voyage.

Votre serveur retient les réponses pour ne pas poser deux fois la même question : le climat typique cinq ans, un lieu trouvé 90 jours, un temps de trajet et une image de carte 30 jours, des prévisions 3 heures. Cette mémoire ne contient que des faits publics sur des lieux, rien sur votre famille.

## Les fournisseurs {#providers}

Chaque fournisseur est une offre à part, avec ses propres conditions. La page indique pour chacun ce qu’il sait faire, s’il a besoin d’une clé et ce qu’il reçoit (**Il reçoit : …**).

| Fournisseur | Clé | Sait faire |
|---|---|---|
| **Open-Meteo** | non, gratuit | Climat typique, prévisions, recherche de lieux |
| **MET Norway** | non, gratuit | Prévisions |
| **OpenStreetMap Nominatim** | non, gratuit | Recherche de lieux |
| **OpenWeather** | oui, votre propre clé, offre gratuite possible | Prévisions (pour environ cinq jours), recherche de lieux |
| **Meteostat** | oui, votre propre clé, offre gratuite possible | Climat typique |
| **openrouteservice** | oui, votre propre clé, offre gratuite possible | Temps de trajet, recherche de lieux |
| **Google Maps Platform** | oui, votre propre clé, peut coûter | Recherche de lieux, temps de trajet, image de carte |

- **Sans clé**, vous pouvez commencer tout de suite. Avec **Open-Meteo**, vous avez climat, prévisions et recherche de lieux chez un seul fournisseur.
- **Avec votre propre clé**, vous vous inscrivez chez le fournisseur et saisissez la clé dans WuselWall (voir [plus bas](#keys)). Sur la carte du fournisseur, **Obtenir une clé** mène à la bonne page.
- Un **temps de trajet** n’existe qu’avec **openrouteservice** ou **Google Maps Platform**, une **image de carte** qu’avec **Google Maps Platform** ; les deux demandent une clé. Seul pour le temps de trajet, le fournisseur reçoit aussi votre domicile, arrondi.
- **Les conditions sont à accepter par vous.** Certaines offres gratuites sont réservées à un usage privé ; Open-Meteo, par exemple, selon le fournisseur, n’est destiné qu’à un usage non commercial. Une offre avec clé peut coûter de l’argent ; WuselWall ne promet rien sur les prix. Un petit plafond quotidien protège votre clé contre une boucle, mais ne protège pas contre les coûts.
- Sous chaque image de carte et chaque prévision figure la mention de source du fournisseur.

::: warning Soyons honnêtes
Les fournisseurs avec clé ont été conçus d’après leur documentation, pas essayés avec votre clé. Si l’un ne fonctionne pas avec votre clé, le bouton **Tester** vous le dit (voir [plus bas](#test)).
:::

## Définir le domicile {#home}

En haut de la page figure **Domicile**. Ce lieu sert aux distances dans **Où aller ?** et au temps de trajet. Touchez **Définir**, saisissez le **Nom du lieu** et touchez **Chercher** ; un résultat fixe le lieu. Pour cela, un fournisseur avec **Recherche de lieux** doit être activé. Sans lui, vous saisissez à la main la **Latitude** et la **Longitude**, avec deux décimales.

Le lieu est enregistré arrondi à environ un kilomètre. **Modifier** en définit un nouveau ; **Oublier** fait disparaître les distances jusqu’à ce qu’un nouveau soit défini.

## Saisir une clé {#keys}

Un fournisseur avec clé affiche d’abord **Demande d’abord une clé**. Obtenez la clé chez le fournisseur, saisissez-la dans le champ **Clé** et choisissez **Enregistrer la clé et activer**.

- **Une clé s’écrit, ne se lit jamais.** Elle est saisie une fois et enregistrée sur votre serveur. Ensuite, la page n’affiche plus que ses quatre derniers caractères : **Clé enregistrée …1234**. Aucun appareil ne peut la relire, pas même le vôtre.
- Elle ne figure **pas dans l’export des données** de la famille ni dans aucun journal. Une sauvegarde de votre serveur la contient, comme les autres secrets du serveur.
- **Remplacer** l’échange. **Retirer** la supprime et désactive le fournisseur.

## Ordre et test {#test}

Sous **Activé** se trouve le bouton **Tester**. Il fait un petit appel réel et répond **Fonctionne** ou en donne la raison. Essayez-le juste après avoir saisi une clé.

Dans la vue **Avancés** (en haut à droite), il y a davantage :

- **Utilisé pour** : des cases pour ce que le fournisseur doit faire chez vous. Un fournisseur peut par exemple ne fournir que les prévisions.
- **Interroger plus tôt** et **Interroger plus tard** : quand plusieurs fournisseurs offrent la même chose, **le premier de cet ordre qui répond l’emporte**. S’il ne répond pas, le suivant est interrogé.
- Combien d’**appels aujourd’hui** il y a déjà eu.

## Pourquoi c’est lent la première fois {#slow}

Le service gratuit d’Open-Meteo n’autorise que peu de requêtes de climat : environ **trois lieux par minute**, vingt par heure et quarante-huit par jour. Votre serveur s’y tient. C’est pourquoi la liste de **Où aller ?** se remplit lentement la première fois : en haut, il est écrit « Chargement des valeurs climatiques : encore 12 lieux », et la page redemande toutes les demi-minutes. Si rien de nouveau n’arrive pendant un moment, elle s’arrête et dit « D’autres valeurs suivront plus tard ».

Tout va bien. Regardez de nouveau plus tard. Moins de lieux, c’est plus rapide : avec un ou deux **souhaits** (par exemple **Mer**), il y a moins de lieux à interroger. Ensuite, c’est rapide : les valeurs sont des **moyennes** et restent enregistrées cinq ans, pour toutes les familles de votre serveur.

## Quand le service ne répond pas {#no-answer}

Si un appel n’a pas marché, un fournisseur affiche la raison sous **Dernier appel** :

- **Le fournisseur a refusé la clé.** La clé est fausse ou a expiré. Avec **Remplacer**, vous en saisissez une nouvelle.
- **Le quota chez le fournisseur est épuisé pour l’instant.** Attendez qu’il se renouvelle, ou ajoutez un autre fournisseur.
- **Le fournisseur n’a pas répondu à temps** et **Le fournisseur n’a pas fonctionné cette fois.** Cela arrive. Réessayez plus tard avec **Tester**.
- **Ce fournisseur a besoin d’une clé.** Saisissez-en d’abord une.

Si plusieurs fournisseurs sont activés, le serveur interroge le suivant. La page d’un voyage n’affiche jamais d’erreur : ce qu’un service ne fournit pas manque simplement, et tout le reste continue.
