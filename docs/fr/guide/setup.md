# Se connecter et rejoindre la famille

Au premier démarrage, choisissez le serveur ([Installer l’app](/fr/guide/install)). L’écran d’accueil propose ensuite de vous connecter, de rejoindre une famille sur invitation ou de connecter un appareil partagé.

Hors ligne, l’écran d’accueil explique qu’une connexion Internet est nécessaire pour
se connecter, accepter une invitation ou connecter un appareil partagé. Ces options
réapparaissent dès que vous êtes de nouveau en ligne.

<Shot name="setup-start" alt="L’écran d’accueil de WuselWall" />

En bas, **Politique de confidentialité** ouvre la page dans le navigateur. Le lien est désactivé sans connexion ; le texte n’est pas enregistré dans l’app.

## La clé de configuration : un serveur sans famille {#setup-key}

Un serveur fraîchement installé n’a pas de famille. La personne qui l’a installé détient la
**clé de configuration** : l’installation l’affiche, et le lien ou le QR code de configuration
la contient. L’écran d’accueil d’un tel serveur le dit et propose **J’ai la clé de
configuration** ; le lien de configuration ouvre directement **Configurer ton serveur**.

Vous y saisissez votre adresse e-mail à côté de la clé. WuselWall vérifie la clé auprès du
serveur et annonce votre adresse avec elle : tant que la famille n’existe pas, le serveur ne
crée un compte que pour cette adresse, et toute autre personne apprend que le serveur n’a pas
encore de famille. Viennent ensuite le code reçu par e-mail — ou un mot de passe sur un serveur
sans e-mails — puis **Nouvelle famille**, qui ne demande plus de clé. Personne ne saisit la clé
une deuxième fois ; la personne qui gère le serveur en crée une nouvelle avec
`./wuselwall setup-token` tant qu’aucune famille n’existe.

## 1. Se connecter {#_1-signing-in}

Sur votre téléphone personnel, touchez **Continuer par e-mail** et saisissez une adresse valide. L’app vérifie le champ avant tout envoi. Vous recevez un **code à six chiffres**, valable **10 minutes**. Gardez le champ ouvert et saisissez-y le code reçu. Consultez les indésirables si le message n’arrive pas ; un nouvel envoi est possible au plus tôt après une minute.

Ce code vérifie votre adresse. Il est différent de la **clé de configuration du serveur** et ne demande ni lien de connexion ni deuxième connexion.

<Shot name="setup-sign-in" alt="La connexion par e-mail" />

Pour utiliser un mot de passe, choisissez l’option correspondante et saisissez votre adresse e-mail et votre mot de passe, puis touchez **Se connecter**. L’app vérifie les deux champs avant la connexion. Vous pouvez définir votre mot de passe dans **Paramètres → Compte et sécurité → Connexion** : au moins **10 caractères**. Le code par e-mail reste disponible. Lors de la création du compte, l’app demande une fois quelle méthode vous préférez. Si la double authentification est activée, saisissez ensuite le code de l’app d’authentification ([Sécurité](/fr/settings/security)).

**Serveur sans e-mails** ([E-mails](/fr/server/email)) : **Continuer par e-mail** s’ouvre sur **Nouveau compte**. Saisissez votre adresse et un mot de passe d’au moins 10 caractères, puis **Créer le compte** ; aucun code, aucun e-mail de confirmation. Déjà un compte ? **Se connecter**. Mot de passe oublié ? **Mot de passe oublié ?** et demandez un code à un responsable de la famille ([Réinitialiser](/fr/settings/members-devices#reset-password)).

## 2. Créer une famille {#_2-creating-a-new-family}

Si votre compte n’appartient à aucun foyer, la page **Nouvelle famille** s’ouvre. Sur votre téléphone, saisissez :

1. Le **nom de la famille**.
2. **Votre prénom** et **votre couleur**, utilisée pour vos actions.
3. Si vous le souhaitez, les **exemples** de tâches et récompenses, modifiables ensuite.
4. La **clé de configuration**, si le serveur en exige une et si vous ne l’avez pas saisie avant la connexion ([La clé de configuration](#setup-key)). Elle vient de l’installation du serveur ou de son responsable, pas de votre e-mail de connexion.

Si vous avez ouvert le lien ou le QR code de configuration, ou saisi la clé sous **J’ai la clé de configuration**, WuselWall a déjà annoncé votre adresse avec elle : inutile de la saisir à nouveau. Gardez ce lien comme une clé et transmettez-le seulement à la personne qui crée la famille.

<Shot name="new-family" alt="Le formulaire de création d’une famille" />

Touchez **Créer la famille**. Si la confirmation prend plus de 15 secondes, l’app propose de signaler une invitation ou de se déconnecter. La création reste bloquée pour éviter un doublon ; si la confirmation arrive plus tard, l’app continue automatiquement.

La page suivante demande qui fait encore partie de la famille. Ajoutez les enfants et les adultes par leur prénom ; vous inviterez les adultes ensuite. Vous pouvez aussi passer cette étape. Ce téléphone devient votre appareil personnel, avec un nom automatique modifiable dans les paramètres. L’onglet **Aujourd’hui** s’ouvre.

## 3. Rejoindre une famille {#_3-joining-a-family}

L’invitation contient un **lien**, un **code QR** ou un **code**. Le lien et le code QR indiquent aussi le serveur familial. Avec l’app installée, ils ouvrent directement l’invitation. Sinon, installez l’app depuis la page indiquée, puis ouvrez à nouveau le lien.

Avec un code seul :

1. Touchez **J’ai un code d’invitation**. Si l’app demande encore le serveur, saisissez code et serveur ensemble, par exemple `K7QM3XRP@family.example.org`.
2. Collez le code ou le lien complet, puis vérifiez l’invitation.
3. L’app affiche votre nom et la famille. Ajustez votre prénom et votre couleur si nécessaire, puis rejoignez le foyer.

Si l’invitation mentionne votre adresse e-mail, elle s’affiche automatiquement après la connexion avec cette adresse. Une invitation dure **7 jours** et sert **une seule fois**. Voir [Inviter un adulte](/fr/settings/members-devices#invite-an-adult).

Un compte n’appartient qu’à **une seule** famille. Si vous ouvrez une invitation alors que vous faites déjà partie d’une famille, WuselWall affiche **Tu fais déjà partie de ‹famille›** et qui vous invite où. **Quitter la famille** vous guide, avec une confirmation ; l’invitation se poursuit ensuite directement. **Annuler** ne change rien. Si l’invitation concerne la famille dont vous faites déjà partie, WuselWall le dit simplement.

## 4. Connecter une tablette familiale ou un écran mural {#_4-connecting-a-family-tablet-or-wall-display}

Un parent approuve le nouvel appareil sur son téléphone :

1. Sur le nouvel appareil, touchez **Connecter une tablette familiale ou un écran mural**. Un code QR et un code s’affichent.
2. Sur votre téléphone : **Paramètres → Appareils → Connecter un appareil**. La carte **Premiers pas** donne aussi accès à cette étape.
3. Scannez le code QR ou saisissez le code, puis touchez **Suivant**. Les lettres passent automatiquement en majuscules et le tiret est ajouté.
4. Choisissez **Écran mural**, **Tablette des enfants**, **Tablette partagée** ou **Téléphone d’un enfant**. Pour ce dernier, choisissez l’enfant. Nommez l’appareil et connectez-le.
5. La première fois, définissez le **PIN parental**, utilisé pour les actions protégées sur les appareils partagés ([Qui êtes-vous ?](/fr/guide/who-are-you)).

<Shot name="pair-device" alt="Le code QR et le code du nouvel appareil" />

<Shot name="pair-approve" alt="L’approbation du nouvel appareil sur le téléphone d’un parent" />

Le code QR contient aussi le serveur : la caméra de votre téléphone peut donc ouvrir directement la confirmation dans l’app. Le code dure **10 minutes** et ne sert **qu’une fois**. En cas d’échec, recommencez sur le nouvel appareil. L’écran mural présente ensuite une courte [liste de préparation](/fr/guide/wall).

::: tip Appareils plus anciens
Dans **Paramètres → Avancés → Appareils**, **Créer un code pour un ancien appareil** permet encore de connecter une ancienne version. Cette option disparaîtra à la prochaine version.
:::
