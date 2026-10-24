# Apps et automatisations

Avec une **clé** WuselWall, une autre app utilise les données familiales au nom d’une personne. Siri, Raccourcis et les autres apps d’automatisation peuvent lire et ajouter des éléments. Les exemples utilisent Raccourcis d’Apple ; les autres apps envoient les mêmes requêtes.

Avec Siri : « Liste de courses » → « De quoi avez-vous besoin ? » → « Du lait et deux concombres ». Une clé WuselWall et l’app Raccourcis suffisent.

<Shot name="shortcuts" alt="Les clés d’automatisation dans les paramètres" />

## Droits d’une clé {#what-a-key-may-do}

La clé appartient à **une personne** : elle lit la journée, les repas, l’école, les présences et les points ; elle ajoute des courses et coche les tâches de cette personne. Elle ne supprime ni n’administre rien, même si elle appartient à un parent. La limite est de **100 ajouts par jour**, pour arrêter une automatisation qui boucle.

## Créer une clé {#creating-a-key}

Dans **Paramètres → Avancés → Apps et automatisations**, créez une clé et donnez-lui un nom. Un parent peut choisir la personne ; les autres créent leur propre clé sur leur téléphone. Copiez **la clé et l’adresse du serveur**, affichées une seule fois.

Gardez la clé comme un mot de passe. Raccourcis la synchronise entre vos appareils Apple par iCloud.

## Premier raccourci : les courses {#the-first-shortcut-shopping-list}

1. Dans **Raccourcis**, touchez **+** et ajoutez une demande de saisie : « De quoi avez-vous besoin ? ».
2. Ajoutez **Obtenir le contenu de l’URL** :
   - URL : l’adresse fournie par WuselWall, terminée par `/shopping`, par exemple `https://api.example.org/functions/v1/shortcuts/shopping`.
   - Méthode : **POST**.
   - En-tête : `Authorization`, valeur `Bearer ` suivie de la clé, avec l’espace.
   - Corps : **JSON**, champ `text` contenant la saisie fournie.
3. Affichez le résultat ou faites-le lire à voix haute.
4. Nommez le raccourci « Liste de courses » pour l’appeler avec Siri.

Les quantités sont reconnues : « 2 litres de lait », « 3 pommes ». Séparez les produits par une virgule ou « et ». Un article déjà présent voit sa quantité augmenter.

## Tous les raccourcis {#every-shortcut}

Utilisez toujours POST, l’en-tête `Authorization` et un corps JSON :

| Fonction | Fin de l’adresse | Champs JSON |
|---|---|---|
| Courses | `/shopping` | `text` ; `list` facultatif pour une autre liste |
| Journée | `/today` | `day` facultatif : demain, jour ou date |
| Repas | `/meals` | `day` facultatif |
| Points | `/points` | Aucun |
| Tâche terminée | `/chore` | `text` : nom de la tâche |
| École | `/school` | `text` : question, par exemple « Emma a-t-elle sport demain ? » |
| Présences | `/presence` | `text` : question, par exemple « Quand Julie revient-elle ? » |

Pour l’école et les présences, demandez une saisie et envoyez toute la question dans `text`. L’app reconnaît la personne, le jour et le nom de matière enregistré dans l’emploi du temps. Sans jour, l’école vise le lendemain ; sans prénom, la question vous concerne.

Les tâches terminées ne concernent que vos tâches et les tâches ouvertes. Si plusieurs correspondent, l’app demande une précision. Sans `text`, elle énumère les tâches ouvertes.

Les réponses suivent la langue prise en charge du téléphone, sinon celle du foyer. Le champ `lang` force `de`, `en`, `fr` ou `es`.

## Révoquer une clé {#revoking-a-key}

Révoquez-la si le téléphone est perdu ou si elle n’est plus utile. L’effet est immédiat. La liste indique la dernière utilisation. Quitter le foyer révoque automatiquement vos clés. Les parents gèrent toutes les clés ; les membres, les leurs. L’[export](/fr/settings/members-devices#export-data) montre noms et dates, jamais les secrets.
