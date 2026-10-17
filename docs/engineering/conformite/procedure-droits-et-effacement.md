# Procédure d'exercice des droits et d'effacement — projet à valider par la fédération ou un DPO

Statut : **projet, non validé** (2026-10-17). Décisions : [ADR 0025](../adr/0025-comptes-et-donnees-de-mineurs-conformite.md), décisions 6, 7 et 11. Délai légal de réponse : **un mois** à compter de la demande (prolongeable dans les cas prévus par le RGPD : `[à valider par le DPO]`).

## Principes

- La demande est adressée au **club** (responsable) ; l'éditeur assiste. Contact : `[e-mail du club]`.
- Une demande ne doit **pas contenir le nom de l'enfant dans un champ libre de l'application** : le parent la fait par e-mail au club, ou par le document de demande de l'application (type de demande + identifiant de la fiche liée, sans texte libre).
- Le directeur vérifie l'identité du demandeur : un parent est lié à la fiche par son compte ; autre demandeur : justificatif `[à définir par le club]`.
- Aucun journal nominatif des effacements n'est conservé (ADR 0019). Le club tient seulement un registre des demandes **sans nom d'enfant** : date de réception, type, date de réponse.

## Droit d'accès et portabilité

1. Le directeur ouvre la fiche de l'élève et lance **« Exporter les données de l'élève »** (FB8).
2. Contenu : fiche, appartenances aux groupes, présences, passages, résultats, étiquettes des saisies de ses séances, comptes liés (rôles, sans mot de passe) ; JSON lisible et feuille PDF.
3. Remise au parent (ou à l'élève de 15 ans et plus) par un moyen sûr choisi par le club (en main propre, ou e-mail protégé). Délai : un mois.
4. Les données de l'adulte (e-mail, rôle) : le directeur ou l'administrateur les lit dans l'écran des membres ; l'utilisateur voit son propre compte.

## Rectification

L'enseignant ou le directeur corrige la fiche (prénom, initiale, groupe) ; une saisie de passage se corrige dans l'historique (ADR 0006). Un utilisateur corrige son e-mail depuis son compte.

## Effacement d'un élève (à la demande)

1. Le parent ou l'élève de 15 ans et plus dépose la demande (e-mail ou document sans nom d'enfant).
2. Le directeur vérifie la demande, puis ouvre **« Effacer cet élève »**.
3. L'application marque la fiche `erasing` (transitoire), supprime par lots reprenables (400 écritures au plus) les appartenances, présences, passages, résultats, acquittements et étiquettes liées à la fiche, puis la fiche elle-même et le marqueur. Si la connexion tombe, **reprendre depuis le même écran** : l'effacement est idempotent.
4. Les comptes liés : si le parent n'a plus d'autre enfant lié dans le club, son compte est retiré du club (`members`) ; le compte Auth est supprimé par l'utilisateur lui-même.
5. Réponse écrite au demandeur sous un mois ; elle rappelle ce que l'application **ne peut pas effacer** : fichiers JSON ou PDF déjà exportés, copies d'écran, sauvegardes Google (180 jours pour Auth).
6. Le club supprime lui-même ses propres exports contenant l'élève, ou les remplace.

## Suppression d'un compte d'adulte

- **Parent, enseignant** : depuis son compte, après réauthentification : suppression du compte Auth et du document `members` du club.
- **Directeur** : désigne d'abord un successeur (l'application l'impose) ; sinon l'administrateur intervient.
- **Administrateur** : retiré en console par le titulaire du projet.

## Purge de fin de saison

1. À la clôture (lot 11), le directeur lance la purge : élèves à effacer selon la proposition (ADR 0019), comptes et invitations échus (ADR 0025, décision 6).
2. Une **échéance** `expireOn` s'affiche ; le bandeau s'allume à l'approche, la **saisie est bloquée** à l'échéance tant que la purge n'est pas faite.
3. Si le club ne le fait pas, l'**administrateur peut forcer la purge** de ce club après en avoir informé le directeur.
4. La garantie de durée est **organisationnelle, non automatique** : elle est dite aux familles (notice).
5. Quota Spark : 20 000 suppressions par jour (vérifié) ; une très grosse purge s'étale sur plusieurs jours.

## Opposition, limitation

Examinées par le directeur et le DPO ; la limitation consiste à retirer l'accès de la fiche aux comptes d'enseignement sans l'effacer. `[Détail à valider.]`

## Violation de données

Voir le registre. L'éditeur informe le club sans délai ; le responsable évalue et notifie la CNIL sous 72 heures si nécessaire, puis les familles si le risque est élevé. `[Contacts à renseigner.]`

## Suivi

Délais, types de demandes et suites sont notés dans le registre des demandes du club (sans nom d'enfant). Validation de cette procédure : `[fédération ou DPO]`, date `[à renseigner]`.
