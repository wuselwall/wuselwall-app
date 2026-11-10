# Sécurité

Les réglages de connexion et de sécurité sont réservés au **téléphone personnel d’un parent**, dans **Paramètres → Compte et sécurité**.

## Connexion {#sign-in}

Le code par e-mail reste disponible si votre serveur envoie des e-mails. Vous pouvez définir ou modifier un [mot de passe](/fr/settings/account#password).

<Shot name="settings-sign-in" alt="Les réglages de connexion et de mot de passe" />

## Double authentification {#two-factor-sign-in}

En plus du mot de passe, l’app demande un **code à six chiffres** d’une app d’authentification : gestionnaire de mots de passe, Aegis, ou app équivalente.

1. Activez la double authentification.
2. Scannez le code QR avec l’app d’authentification.
3. Saisissez le code qu’elle affiche.

Chaque nouvelle connexion demandera ce code avant de donner accès aux données du foyer. Vous pouvez désactiver cette protection dans les mêmes réglages.

Si un seul parent a un compte connecté, un avertissement apparaît avant l’activation : sans votre authentificateur, aucun deuxième parent ne peut réinitialiser votre second facteur. Invitez d’abord un autre parent et demandez-lui de se connecter, ou conservez une sauvegarde séparée de votre authentificateur. Sinon, il faudra l’aide de la personne qui gère votre serveur. Vous pouvez annuler ou activer quand même.

<Shot name="totp-recovery-warning" alt="Avertissement avant l’activation sans deuxième parent connecté" />

## PIN parental {#guardian-pin}

Le PIN à six chiffres protège les actions parentales sur les [appareils partagés](/fr/guide/who-are-you). Votre téléphone personnel connecté permet d’en définir un nouveau, même si l’ancien est bloqué.

## Clé d’accès {#passkey}

Les clés d’accès ne sont pas encore disponibles dans l’application habituelle. Elles seront proposées après vérification sur de vrais appareils.

## À retenir {#good-to-know}

Choisissez un mot de passe d’au moins **10 caractères**, idéalement une phrase. Si un téléphone est perdu, [bloquez-le](/fr/settings/members-devices#blocking-a-device) depuis un autre appareil. Vos données restent sur le serveur choisi par votre famille. Si vous utilisez Supabase ou un autre hébergeur, elles sont hébergées chez ce prestataire ; WuselWall ne gère aucun service de données pour votre famille.
