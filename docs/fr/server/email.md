# E-mails (facultatif)

Un serveur WuselWall fonctionne **avec ou sans e-mails**. Sans, chacun crée son compte et se connecte avec son adresse e-mail et un mot de passe. Avec, le serveur envoie un **code de connexion à six chiffres**, sans mot de passe à retenir.

| | Sans e-mails | Avec e-mails |
|---|---|---|
| **Créer un compte** | Adresse et mot de passe. L’app s’ouvre sur **Nouveau compte** | Un code par e-mail ; le mot de passe est facultatif |
| **Mot de passe oublié** | Un responsable donne un code à usage unique ([plus bas](#forgotten-password)) | Un code par e-mail |
| **Invitations** | Par lien, QR ou code d’invitation | Idem, et une invitation qui nomme votre adresse vous trouve seule |
| **Qui voit quoi** | Personne d’autre | Le fournisseur voit adresses et codes |

Sans e-mails, personne ne vérifie l’adresse. Ce n’est pas un problème : un compte seul ne voit rien, seule une invitation ou le code de configuration le fait entrer dans une famille. Pour la même raison, un serveur sans e-mails n’attribue jamais une invitation à un compte parce que les adresses correspondent.

Vous pouvez activer ou couper les e-mails à tout moment ; les comptes gardent leur mot de passe. L’app voit le changement à son prochain démarrage.

## Configurer {#setup}

Dans le dossier de l’outil `wuselwall` :

```bash
./wuselwall mail smtp --gmail --user famille.martin@gmail.com
```

L’outil demande le mot de passe, qui n’apparaît ni dans la commande ni dans l’historique. Pour un autre fournisseur : `--host smtp.example.org --port 587` à la place de `--gmail`. `--sender` fixe une autre adresse d’expéditeur, `--name` son nom (par défaut WuselWall). L’outil écrit `stack/.env` et ne redémarre que l’authentification.

| Commande | Effet |
|---|---|
| `./wuselwall mail test vous@example.org` | Envoie un message de test par le serveur indiqué |
| `./wuselwall mail` | Indique si et comment le serveur envoie des e-mails |
| `./wuselwall mail off` | Plus d’e-mails : connexion par mot de passe seulement |

La langue des e-mails se choisit à part ([Installation](/fr/server/home-server#email-language)).

## Avec Gmail {#gmail}

Un compte Gmail suffit : pas de domaine, pas d’enregistrements DNS, gratuit. Google exige un **mot de passe d’application** de 16 lettres, réservé à WuselWall.

1. **Un compte dédié.** Prenez une adresse Gmail réservée au serveur familial. Un mot de passe d’application ouvre toute la boîte : qui lit `stack/.env` pourrait lire et envoyer ses e-mails.
2. **Validation en deux étapes.** Sur [myaccount.google.com](https://myaccount.google.com/) → **Sécurité** → **Validation en deux étapes**. Sans elle, pas de mots de passe d’application.
3. **Créer le mot de passe.** Ouvrez [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords), nommez-le `WuselWall` et appuyez sur **Créer**. Copiez les 16 lettres : Google ne les montre qu’une fois.
4. **Le saisir sur le serveur** : `./wuselwall mail smtp --gmail --user …`, puis `./wuselwall mail test vous@example.org`. Les espaces ne comptent pas.

Bon à savoir : les codes partent toujours de l’adresse Gmail ; Gmail envoie environ 500 messages par jour ([Google](https://support.google.com/mail/answer/22839?hl=fr)) ; changer le mot de passe Google révoque les mots de passe d’application (en créer un nouveau et relancer `mail smtp`) ; indisponible avec des clés de sécurité seules, la Protection Avancée ou la plupart des comptes professionnels ou scolaires ([Google](https://support.google.com/mail/answer/185833?hl=fr)) ; Google voit adresses et codes.

## Autres fournisseurs {#providers}

| Fournisseur | Possible ? |
|---|---|
| **Votre boîte** chez Orange, Free, Posteo, mailbox.org, Infomaniak… | En général oui : serveur, port `587` et identifiant dans l’aide du fournisseur ; certains demandent d’activer l’accès des logiciels de messagerie |
| **Outlook.com, Hotmail** | Non : Microsoft n’accepte plus que sa propre connexion (OAuth) pour l’envoi |
| **Service d’e-mails transactionnels** (Scaleway, Brevo, Mailjet…) | Oui, avec votre domaine et les enregistrements SPF, DKIM et DMARC demandés |

Exemples, pas des recommandations ; WuselWall n’est lié à aucun de ces fournisseurs. À la place de SMTP, la fonction WuselWall peut aussi envoyer via Scaleway (`SCW_SECRET_KEY`, `SCW_PROJECT_ID`, `MAIL_FROM`).

## Mot de passe oublié sans e-mails {#forgotten-password}

1. Un **responsable**, sur son propre téléphone : **Paramètres → Famille → Membres**, **Réinitialiser le mot de passe** à côté du nom, puis **Créer le code**.
2. L’app affiche un **code de 8 caractères**, valable **une fois**, **10 minutes**. Remettez-le en personne.
3. Sur l’appareil concerné : **Continuer par e-mail** → **Se connecter** → **Mot de passe oublié ?**, puis l’adresse, le code et un nouveau mot de passe d’au moins 10 caractères.

La double authentification reste demandée si elle est active. **Le seul responsable a oublié ?** L’administrateur du serveur crée le même code : `./wuselwall password adresse@example.org`.
