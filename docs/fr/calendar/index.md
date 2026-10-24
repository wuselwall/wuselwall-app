# Calendrier

Le calendrier réunit les rendez-vous et les présences de toute la famille.

<Shot name="calendar-week" alt="La semaine avec les présences et les rendez-vous" wide />

## Les vues {#views}

La date, les flèches, le choix de vue et les paramètres partagent une barre compacte. Sur téléphone, le calendrier s’ouvre en vue **Jour** pour garder les rendez-vous lisibles. Le menu permet de choisir **Jour**, **3 jours** ou **Semaine**. Sur un grand écran, il s’ouvre en vue Semaine. Votre choix reste en place lorsque vous changez d’onglet ou faites pivoter l’appareil. L’icône de calendrier revient à **Aujourd’hui**.

<Shot name="calendar-phone" alt="Le calendrier sur téléphone et son menu de vue" />

Les **présences**, une ligne par personne, et les événements de **toute la journée** restent au-dessus des rendez-vous classés par heure. Utilisez les flèches et **Aujourd’hui** pour naviguer.

## Créer un rendez-vous {#creating-an-appointment}

Touchez **Nouvel événement** : il commence le jour affiché par le calendrier (aujourd’hui tant qu’aujourd’hui est visible), à la prochaine heure pleine. Indiquez ensuite :

- le **titre**, le **lieu** et les **notes** ;
- **Rendez-vous** ou **Présence** : travail, télétravail, déplacement, absence, repos ou garde ;
- toute la journée, ou les heures de début et de fin ;
- les personnes concernées, ou personne pour toute la famille ;
- juste en dessous, l’affichage sur l’écran de la cuisine : une ligne indique si l’événement y apparaîtra et change dès que vous choisissez des personnes. Par défaut, seuls les événements de toute la famille y apparaissent ;
- une éventuelle incertitude ;
- une **image**, et si l’événement est attendu avec impatience (**On a hâte**) ou une **Tradition familiale** (voir [plus bas](#picture-countdown-tradition)).

<Shot name="calendar-editor" alt="La création d’un événement avec les participants et la répétition" />

Le comportement par défaut des nouveaux événements se règle dans les [paramètres du foyer](/fr/settings/household).

### Répéter {#repeating}

Choisissez chaque jour, chaque semaine, toutes les deux semaines ou chaque mois. Le mode de jours précis permet de toucher les dates dans un calendrier pour les horaires de travail. La fin de répétition se définit par date ou par nombre d’occurrences.

Pour modifier ou supprimer une série, choisissez entre cette occurrence seule et toute la série.

### Image, compte à rebours et tradition {#picture-countdown-tradition}

En bas de l’éditeur, trois réglages rendent le quotidien plus léger (voir [Rituels](/fr/guide/rituals)) :

- **Image** : une des 20 images, comme un gâteau, une pizza, le zoo ou une tente. Elle accompagne l’événement sur le mur et son compte à rebours. **Pas d’image** par défaut.
- **On a hâte** : l’événement a un compte à rebours sur l’écran mural et la tablette des enfants, par exemple « Sortie au zoo : encore 3 dodos ».
- **Tradition familiale** : ce que la famille fait encore et encore, comme la soirée jeux. Une tradition est toujours sur le mur, avec un ruban. **Avec un repas** indique le plat qui l’accompagne, au **Déjeuner** ou au **Dîner**.

<Shot name="calendar-rituals" alt="Le bas de l’éditeur d’événement avec l’image, On a hâte et une tradition familiale avec un repas" />

## Réunions jusqu’à… {#meetings-until}

Touchez l’en-tête d’un jour pour indiquer jusqu’à quelle heure vous êtes en réunion. Le mur affiche seulement cette heure, sans détails des rendez-vous. Vous pouvez l’appliquer aux cinq jours ouvrables de la semaine.

## Semaine habituelle {#usual-week}

Dans **Paramètres → Semaine habituelle**, choisissez votre lieu habituel pour chaque jour : bureau, télétravail, etc. Touchez un jour, choisissez le lieu et appliquez-le. Vous pouvez reprendre le lundi du mardi au vendredi. Un jour non défini reste vide. Enregistrez à la fin.

Avec les **créneaux horaires**, saisissez jusqu’à **trois créneaux par jour**. Pour aujourd’hui, le mur affiche le créneau en cours ; pour les autres jours, le premier, avec **+1** si un autre suit.

Activez les **semaines alternées A/B** pour un cycle de deux semaines. Précisez une fois si la semaine actuelle est A ou B, puis saisissez chacune. Désactiver l’alternance conserve la semaine B pour plus tard.

Ensuite, saisissez seulement les exceptions. Les jours fériés, le mur n’affiche pas de lieu habituel.

## Les enfants {#children-and-appointments}

Les [paramètres du foyer](/fr/settings/household) déterminent si les enfants peuvent créer et modifier leurs rendez-vous. Supprimer le rendez-vous d’une autre personne reste réservé aux parents.

## Outlook et iPhone {#appointments-in-outlook-or-on-an-iphone}

Un abonnement permet de consulter le calendrier familial en lecture seule dans une autre app : [Partager le calendrier](/fr/calendar/feeds).

## Calendriers externes {#outside-calendars}

Un parent ajoute les calendriers du club, de l’école ou des collectes dans **Paramètres → Avancés → Ajouter des calendriers externes**. Indiquez le nom, l’adresse **.ics**, la couleur, les personnes et l’affichage sur le mur. Sans personne sélectionnée, le calendrier concerne toute la famille.

Les événements portent la couleur et la marque de l’abonnement. Ils sont **en lecture seule** : modifiez-les à la source. Votre serveur les récupère environ une fois par heure ; une actualisation immédiate est possible. En cas d’erreur, sa raison apparaît.

- Les adresses doivent utiliser **HTTPS** ; les liens **webcal://** sont également reconnus.
- Les adresses pointant vers des machines du réseau privé sont refusées.
- Le fichier est limité à **2 Mo** ; une requête s’arrête après **15 secondes**.
- Seuls les parents voient l’adresse complète ; les autres appareils voient le nom d’hôte. Une clé dans l’adresse doit rester secrète.
- Pour exporter ces événements vers Outlook ou iPhone, activez leur inclusion dans l’[abonnement de partage](/fr/calendar/feeds).
