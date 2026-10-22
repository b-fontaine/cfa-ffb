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

Statut technique : **réalisé côté serveur** (FB8 partie A, [ADR 0024](../adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) notes FB8a) ; avec une application encore sur l'appareil (drift), l'effacement reste immédiat et local.

1. Le parent ou l'élève de 15 ans et plus dépose la demande (e-mail ou document sans nom d'enfant).
2. Le directeur (ou l'administrateur) vérifie la demande, puis ouvre la fiche et **« Effacer cet élève »**. Un enseignant ne le peut pas (les règles le refusent) : il transmet la demande au directeur.
3. L'écran **chiffre ce qui sera supprimé** (passages, bilans, présences, comptes liés) et rappelle les limites ; le directeur confirme.
4. L'application, **dans cet ordre** : (a) marque la fiche « en cours d'effacement » (aucune donnée nouvelle ne peut plus s'y rapporter) ; (b) **supprime** le compte de rôle élève ou parent lié à cette seule fiche (son nom affiché est en pratique celui de l'enfant) ; un parent lié à d'autres élèves garde son compte, sans le lien ; (c) retire l'élève des listes de présents, supprime appartenances, passages, blocs acquis, bilans et acquittements, par lots de 400 écritures au plus, et efface sur l'appareil la progression locale des séances guidées liée à l'élève ; (d) supprime **la fiche en dernier**, avec le marqueur d'opération. **Aucune trace nominative ne reste.**
5. **Délais réels.** Un dossier ordinaire (quelques centaines de documents) : **quelques secondes à quelques minutes**, en un seul passage, écran ouvert. Un très gros dossier ou une connexion coupée : l'avancement s'affiche, **Arrêter** s'arrête entre deux étapes, et l'effacement **se reprend depuis la fiche** (proposé dès l'ouverture, sans nouvelle confirmation) ; au-delà de **10 000 écritures par jour sur un appareil**, l'effacement est suspendu pour la journée et reprend le lendemain (quota gratuit de la plateforme : 20 000 suppressions par jour). La demande doit être honorée **sous un mois** ; une fiche marquée n'accepte plus aucune donnée nouvelle, ce qui limite la portée d'un retard.
6. Réponse écrite au demandeur sous un mois ; elle rappelle ce que l'application **ne peut pas effacer** (ci-dessous).
7. **Ce qui reste, et que le club traite lui-même** (liste identique dans l'ADR 0025 et le registre 4 ter) : la **copie locale** de l'élève dans la base d'un appareil qui a utilisé l'application avant le passage au club synchronisé (l'écran d'effacement et le guide le disent ; la réimporter rétablirait l'élève : à supprimer en effaçant les données du site ou en désinstallant) ; les **fichiers JSON ou PDF déjà exportés** (supprimer ou remplacer, voir le point suivant) ; les copies d'écran ; les sauvegardes de la plateforme (180 jours pour Auth) ; une **présence orpheline** (identifiant d'élève ajouté aux présents d'une saisie par un appareil retardataire après le dernier passage de la purge : sans prénom ni fiche ; la purge est rejouée juste avant la suppression de la fiche, fenêtre réduite, pas fermée) ; une **appartenance orpheline** (créée par un second appareil du directeur après la suppression de la fiche : identifiant d'élève lié à un groupe et à des dates, sans prénom ni fiche ; la règle de création d'appartenance ne distingue pas une fiche supprimée d'une fiche jamais créée, car la restauration d'une sauvegarde écrit l'appartenance avant la fiche : limite assumée) ; les **invitations non utilisées** qui citent l'élève (elles ne se listent pas et s'éteignent à l'expiration, FB8 partie B ; la règle d'utilisation les refuse dès que la fiche citée est absente ou en cours d'effacement, donc aucun compte n'en tire un lien ni un identifiant ; reste le document d'invitation, avec l'identifiant de l'élève, jusqu'à l'expiration) ; un **lien de compte vers une fiche absente** (le directeur et l'administrateur peuvent créer un membre parent ou élève avec l'identifiant d'une fiche supprimée ou en cours d'effacement, ou l'ajouter à ses liens : la règle des membres ne regarde pas l'existence de la fiche ; un appareil de directeur retardataire laisse alors un identifiant d'élève effacé dans un compte, sans prénom, et ce lien n'ouvre aucune donnée tant que la fiche est absente : limite assumée) ; une **édition tardive pendant l'effacement** (la promesse « aucune donnée nouvelle » ne vaut que pour les **créations** : pendant `erasing`, la règle accepte encore une mise à jour de la fiche (prénom) et des passages, blocs acquis et bilans existants ; une édition tardive est supprimée par la purge ou rejouée par l'étape de suppression : limite assumée) ; la **progression locale des séances guidées** d'un autre appareil (elle n'est effacée que sur l'appareil qui mène l'effacement ou la clôture : celle d'une tablette d'enseignant reste, sans prénom, liée par des identifiants de séance ou de groupe); une **fiche recréée** (garanti : une édition, qui est une mise à jour, échoue sur une fiche supprimée, et la création d'une fiche exige la date du serveur ; sous Firestore, l'invitation ne crée jamais de fiche (`ExistingStudentDirectory` vérifie seulement qu'elle existe), donc une fiche supprimée entre la liste des élèves invitables et la publication ne revient pas ; sous drift, la publication d'une fiche locale vers le club à la première invitation reste une création ; non garanti : une inscription rejouée ou volontaire d'un gestionnaire est une création ordinaire, que la règle ne distingue pas, et aucun tombstone nominatif ne permet de l'interdire ; la fiche revient alors avec le seul prénom envoyé, sans passage ni bilan) ; le **compte d'authentification** (Auth) du parent ou de l'élève, qui subsiste et se supprime par la suppression de compte (FB8 partie B) ; le **marqueur d'effacement**, dont l'identifiant est un pseudonyme dérivé (empreinte salée par l'identifiant du club : recalculable seulement avec l'identifiant du club et celui de l'élève), supprimé avec le dernier lot ; une **clôture commencée par un autre gestionnaire**, non détectée (seul le marqueur du compte courant est lu : la seconde clôture converge, elle n'est pas refusée ; test de caractérisation). Si une **clôture de saison** a lieu pendant un effacement commencé, elle le **termine**.
8. Le club supprime lui-même ses propres exports contenant l'élève, ou les remplace.
9. **Registre** : le club note la demande dans son registre des demandes (date de réception, type, date de réponse), **sans nom d'enfant** ; l'opération elle-même ne laisse aucun journal (traitement 4 ter du [registre des traitements](registre-des-traitements.md)).

## Clôture de saison (effacement des élèves sortants)

Réalisée côté serveur par la même méthode (FB8 partie A) : l'**archive agrégée** (chiffres par public, sans nom) est écrite **avant** tout effacement ; les élèves choisis par le directeur sont marqués puis purgés par lots ; les autres sont reconduits ; **aucune liste d'élèves effacés n'est conservée**. L'assistant montre un **aperçu des effets**, demande une confirmation explicite (« J'ai compris »), affiche l'avancement et propose la **reprise** d'une clôture interrompue sans rien redemander. Limite : **390 élèves effacés au plus par clôture** (les autres s'effacent ensuite, un par un). Règle de période : **aucune clôture pendant la période de bascule des données locales** (roadmap, FB7).

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
