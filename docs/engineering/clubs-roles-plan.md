# Plan : clubs, rôles, invitations (lot FB3)

Statut : **livré** (2026-10-17), sous émulateurs et doubles seulement. **Aucune base de production touchée** : rien de déployé,
`flutterfire configure` non exécuté, aucun accès administrateur à la production. Les règles complètes sont écrites et testées ;
**leur publication dans la console est à faire par l'utilisateur** (voir « À faire par l'utilisateur »).
Décisions : [ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) (décisions 14 à 16, 22 à 25, matrice des droits,
note de réalisation FB3 pour les écarts) et [ADR 0025](adr/0025-comptes-et-donnees-de-mineurs-conformite.md).
Aucune décision nouvelle : les précisions de réalisation sont dans la note de l'ADR 0024.

## Découpage FB3 / FB4 (ce qui est livré, ce qui reste)

L'ADR et la feuille de route placent en **FB3** : les règles de tout le modèle, les entités `club` et `membership`, les écrans « Mon club » et
« Administration », les invitations, le lien d'un compte élève ou parent à une fiche, la navigation par rôle. Ils placent en **FB4** les dépôts
Firestore de **données** (élèves, groupes, saisons, séances, saisies, passages, acquis, bilans, archives, réglages), tous encore locaux (drift).
Le découpage retenu :

| Sujet | FB3 (livré) | FB4 (reste) |
|---|---|---|
| Règles Firestore | **tout le modèle** : 16 collections, matrice rôle × action, invitations par lot, bornes de champs, refus par défaut | modifier une règle seulement si un champ change (avec ses tests) |
| Équipe et familles du club | liste des membres (directeur, administrateur), retrait d'accès, nom du club | affectation des groupes d'un membre existant (aujourd'hui : le code porte les groupes) |
| Groupes et élèves du club | **restent dans « Élèves » (drift)** : « Mon club » n'en gère pas ; ils servent à **choisir** pour qui inviter (enseignant : groupes ; élève, parent : fiche) | dépôts Firestore, listes serveur, écrans par groupe filtrés par rôle |
| Fiche d'un élève lié | **publication minimale** à la première invitation (`StudentDirectory` : prénom, public, groupes courants, identifiant local) : les règles exigent que la fiche existe | le dépôt Firestore des élèves écrit le même document (même identifiant) |
| Vue du parent et de l'élève | **Périmé** (remplacé par FB6, voir « Espace élève et parent » plus bas) : « Mes enfants » / « Ma progression » : les fiches liées lues **sur l'appareil**, puis la fiche en parcours existante | **Périmé** : la même vue sur des données serveur (livré par FB6 : « Espace élève et parent ») |
| Visibilité de l'enseignant | formulaire d'invitation et « Mon club » limités à **ses groupes** (cas d'usage) ; **règles : tout son périmètre** | listes et saisies limitées par les requêtes Firestore (`array-contains`, `in`) |

**Périmé depuis FB4 et FB6** (voir « Espace élève et parent » plus bas : un parent lit désormais Firestore). Conséquence assumée et écrite : tant que FB4 n'est pas livré, un parent ou un élève qui rejoint un club sur **son** appareil arrive sur
« Mes enfants » **sans données locales** (la liste est vide : ses fiches liées n'existent que sur l'appareil de l'animateur). Les scénarios
BDD le montrent sur l'appareil de l'animateur (même graphe en mémoire). C'est cohérent avec le garde-fou : aucun vrai élève avant FB4 et
l'AIPD (roadmap, « Garde-fou de mise en production »).

## Où est quoi (FSD)

| Couche | Contenu |
|---|---|
| `shared/lib` | `InvitationCode` (Base32 de 10 à 32 caractères, génération, lien), `Capability` et `RolePolicy` (table unique des droits par rôle), `ClubSession` (qui agit, où, avec quel périmètre), `field_limits` (bornes identiques aux règles), `ActiveClubScope` étendu (`groupIds`, `studentIds`), `CurrentUser.isAdmin`, `ServiceFailure` |
| `shared/persistence` | `DocumentStore` (port minuscule : `get`, `list`, requête de groupe de collections, **lot atomique**), `InMemoryDocumentStore` (double des tests, **sans** règles), `guardStore` |
| `shared/ui` | `InvitationCodeCard` (code, date limite, copie du code et du lien), `InvitationRow` |
| `entities/club` | `Club`, `ClubRepository`, `StoreClubRepository` |
| `entities/membership` | **FB6** : `OwnLink`, `OwnLinkSource`, `StoreOwnLinkSource` (le propre `member` du compte) ; `Member`, `MemberRepository`, `ClubMembership` (rôle et périmètre), `MembershipsSource` (+ `isAdmin`), `StoreMembershipsSource` (requête de groupe `members` filtrée sur `uid`) |
| `entities/invitation` | `Invitation` (forme par rôle, `InvitationPolicy` : 48 h / 7 j, qui invite qui), `InvitationRepository` (créer, trouver, révoquer, **accepter par lot**), `InvitationLog` (journal local par compte et club), `IssuedInvitations`, `InvitationCodeSource` (sécurisé en production, séquentiel en test) |
| `entities/student` | `StudentDirectory` (publication de la fiche minimale), `StoreStudentDirectory` |
| `features/manage_club` | `ListMembers`, `RemoveMember`, `RenameClub`, `ListInvitableStudents`, `ListInvitableGroups`, `IssueInvitation`, `ListIssuedInvitations`, `RevokeInvitation` ; `ClubCubit`, `InviteCubit` ; `ClubMembersCard`, `IssuedInvitationsCard`, `InviteForm`, dialogue de renommage |
| `features/administration` | `ListClubs`, `CreateClub`, `InviteDirector`, `ListDirectorInvitations`, `RevokeDirectorInvitation` ; `AdministrationCubit` ; `AdministeredClubCard`, dialogue de création |
| `features/sign_in` | `AcceptInvitation` (consomme le code), `JoinCubit`, `JoinForm` |
| `features/student_showcase` | `GetStudentShowcase` ; **FB6** : `GetFamilySpace`, `WatchFamilySpace`, `CheckFamilyAccess`, `FamilySpace` / `FamilyChild` / `FamilySession`, `FamilySpaceCubit` ; `ShowcaseView`, `FamilySpaceView`, `ChildSelector`, `UpcomingFamilySessions`, `FamilyNotice` (remplacent `ListLinkedStudents`, `LinkedStudentsCubit`, `LinkedStudentsList`) |
| `pages` | `club`, `invite_member`, `join`, `administration`, `my_children` ; `more` (entrées par rôle), `select_club` (« J'ai un code », « Administration ») |
| `app` | `AuthCubit` (administrateur, code gardé, groupes et fiches de la portée), `authRedirect` + `roleRedirect` (garde de route), `AppShell` (deux destinations pour un élève ou un parent), routes ; `platform/firestore_document_store.dart` (**seul** importeur de `cloud_firestore` avec la passerelle de démarrage, règle 9) |

`NoMembershipsSource` et `InMemoryMembershipsSource` disparaissent de `lib/` : `StoreMembershipsSource` sert la production **et** les scénarios BDD (sur le
double en mémoire du stock) ; un double `InMemoryMembershipsSource` reste dans `test/support/` pour isoler les tests unitaires d'`AuthCubit`.

## Modèle de données (noms de champs figés par les tests de règles)

| Chemin | Champs |
|---|---|
| `admins/{uid}` | **document vide** (créé en console) ; les règles testent `exists()`, jamais un champ |
| `clubs/{c}` | `name` (1 à 80), `createdAt` (date du serveur), `currentSeasonId` (facultatif) |
| `clubs/{c}/settings/main` | `passesRequired`, `alertThreshold`, `recallStaleSessions`, `groupFailureSharePercent` (entiers bornés), `backupReminderDays` (facultatif) |
| `clubs/{c}/members/{uid}` | `uid` (= identifiant), `role`, `groupIds`, `studentIds`, `displayName` (1 à 40), `createdAt` (serveur), `invitationCode` (facultatif : le code utilisé) |
| `invitations/{code}` | `clubId`, `role`, `groupIds`, `studentIds`, `createdBy`, `createdAt` (serveur), `expiresAt`, `used` ; à l'usage : `usedBy`, `usedAt` |
| `clubs/{c}/students/{id}` | `firstName` (1 à 40), `initial` (une lettre, facultatif), `audience`, `groupIds` (groupes courants), `createdAt`, `erasing`, `expireOn` ; **aucun autre champ** |
| `clubs/{c}/groups`, `seasons`, `memberships`, `sessions`, `records`, `attempts`, `acquisitions`, `assessments`, `acknowledgements`, `archives` | champs d'appartenance dénormalisés (`groupId`, `seasonId`, `studentId` selon la collection) ; **liste blanche de champs par collection** et valeurs bornées (voir `firestore.rules`, fonctions `*Shape`) ; commentaire d'évaluation borné à 500 ; étiquettes de saisie = les huit codes de `SessionTag` ; archives : un document de synthèse et un par exercice, compteurs seulement ; un enseignant ne crée une donnée d'élève que si l'élève est de son groupe |

**Écart à l'ADR 0024 (noté dans sa note de réalisation)** : `invitations/{code}` est **à la racine**, pas sous `clubs/{c}`. L'invité ne connaît que le code ;
sous un chemin de club il ne pourrait pas le lire. C'est aussi ce qui permet « get seul, jamais list » : il n'y a rien à énumérer.

Les identifiants de groupes et de fiches sont les **identifiants locaux** (UUID) : FB4 et l'import (FB7) retrouvent les mêmes documents.

## Les règles (`firestore.rules`)

Principes (en tête du fichier) : refus par défaut en dernier bloc (administrateur et directeur compris) ; e-mail vérifié partout ; le rôle se lit par **un seul
`get()`** sur `clubs/{c}/members/{uid}` (`me(c)`), l'administrateur (`exists(/admins/{uid})`) n'est évalué **qu'après** le rôle de club ; `admins` : `write: false` ;
`invitations` : `get` seul ; un `member` ne naît que par une invitation consommée **dans le même lot** (`getAfter` d'un côté, `existsAfter` de l'autre), ou
par le directeur (enseignant, élève, parent) ou l'administrateur ; aucune élévation de privilège par mise à jour de son propre `member` (seul le nom affiché change).

Mesures faites à l'émulateur (`budget.test.mjs`) : la limite est de **10 documents distincts** par évaluation, et un même document lu plusieurs fois ne compte
**qu'une fois**. Budget des opérations les plus coûteuses (jamais plus de 6 sur 10, donc `teacherGroupIds` n'est pas nécessaire) :

| Écran ou action | Opération | Accès par évaluation de règle |
|---|---|---|
| Démarrage, « mes clubs » | requête de groupe `members` (`uid`) ; `get` du club ; `get` de `admins/{uid}` | 0 ; 1 (rôle) + 1 (administrateur, si pas de member) ; 0 |
| « Mon club » (directeur) | liste des `members` | 1 par document (le même `get`) |
| Inviter (directeur) | création d'une invitation de parent à 4 enfants | 1 (administrateur, évalué d'abord) + 1 (rôle) + 4 (existence des fiches) = 6 |
| Inviter (enseignant) | création d'une invitation de parent à 4 enfants | 1 + 1 (rôle) + 4 (fiche dans un de ses groupes) = 6 |
| Inviter (administrateur) | création d'une invitation de directeur | 1 + 1 (le club existe) = 2 |
| Publier la fiche d'un élève invité | création de `students/{id}` | 1 à 2 |
| Rejoindre | création du `member` ; mise à jour de l'invitation | 2 (`get` et `getAfter` de l'invitation) ; 2 (`existsAfter` et `getAfter` du member) |
| Données de groupe (FB4) | lecture, écriture | 1 (rôle) + 1 (administrateur) ; + 1 pour la fiche à la création d'un passage, d'un acquis, d'un bilan, d'un acquittement |

Requêtes que les règles acceptent (mesurées, `matrix.test.mjs`) : `array-contains` et `array-contains-any` sur `groupIds` (fiches, par `hasAny`) ; `==` et `in` sur
`groupId` ou `studentId` (données de groupe) ; requête de groupe de collections `members` filtrée sur `uid`. Une requête non filtrée, ou sur plusieurs groupes
dont un n'est pas le sien, est refusée. **Production** : la requête de groupe sur `members.uid` exige l'**exemption d'index** de `firestore.indexes.json`
(déployée avec les règles).

## Invitations

- **Code** : 12 caractères tirés de l'alphabet Base32 (lettres A à Z, chiffres 2 à 7 : jamais 0, 1, 8, 9) par `Random.secure()`, soit 60 bits ; la saisie accepte
  10 à 32 caractères, majuscules ou minuscules, avec espaces ou tirets. Aucune limitation de débit sans Functions : la résistance à l'énumération repose sur la
  longueur, sur l'absence de `list` et sur App Check (FB8).
- **Durée** : 48 heures pour un enseignant ou un directeur (plus puissants), 7 jours pour un élève ou un parent. L'application fixe la durée nominale ; les règles
  tolèrent 1 heure de plus (horloge du client).
- **Qui invite qui** : l'enseignant invite un élève ou un parent dans **ses** groupes et pour des fiches de **ses** groupes ; le directeur un enseignant, un élève
  ou un parent ; l'administrateur un directeur (et, si besoin, le reste). Jamais un directeur depuis un club.
- **Élève** : une seule fiche, case « a 15 ans ou plus » obligatoire (déclaration, rien n'est stocké) ; **parent** : une à quatre fiches.
- **Usage unique** : un seul lot crée le `member` (rôle, groupes et fiches **identiques** à ceux de l'invitation) et passe l'invitation à « utilisée » ; chaque écriture
  seule est refusée ; une invitation ne fait naître qu'un `member`.
- **Révocation** : suppression de l'invitation, par son créateur, le directeur du club ou l'administrateur.
- **Journal local** : le serveur ne liste jamais les invitations ; l'appareil se souvient des codes qu'il a créés (par compte et par club, au plus 20), les relit un par
  un pour afficher leur état (en attente, utilisée, expirée, inconnu hors ligne), et les oublie à la déconnexion. Une invitation créée sur un autre appareil ne figure
  pas ici ; elle se révoque en saisissant son code (limite assumée).
- **Lien** : `/#/join/<code>` (web seulement), construit dans la couche `app` à partir de `AppRoutes.joinWith` (`inviteLinkFor`, testé contre les routes du routeur) ; hors connexion il ouvre l'inscription avec le code saisi (code valide ; `/join` sans code ou au code mal formé mène à la connexion, à froid comme session connue) ; connecté sans club il ouvre « Rejoindre un club ». **Démarrage à froid** : l'état de session est d'abord inconnu ; le code survit à l'écran de démarrage dans `/splash?code=<code>` (jamais dans `from`, `safeReturnAddress` écarte les adresses `/join…`), puis chaque état l'emmène au bon écran (`/register?code=`, `/join/<code>`).
- **Consommation** : après la première connexion vérifiée, `AuthCubit` lit le code gardé à l'inscription (`PendingInvitations`, FB2) ; un compte sans aucun club est
  envoyé d'office sur `/join/<code>`. `AcceptInvitation` contrôle l'invitation (introuvable, expirée, utilisée : messages distincts), demande le nom affiché, puis
  écrit le lot ; le serveur reste juge en dernier (`refused` si une règle refuse).

## Rôles, navigation et garde de route

Table unique : `shared/lib/role_policy.dart` (testée ligne à ligne).

| Capacité | Élève, parent | Enseignant | Directeur | Administrateur |
|---|:-:|:-:|:-:|:-:|
| Menu et routes d'animateur (séances, élèves, résultats, sauvegarde, saisons en lecture) | non | oui | oui | oui |
| Réglages du club, clôture d'une saison | non | non | oui | oui |
| « Mon club » : inviter | non | élèves, parents | tous sauf directeur | idem |
| « Mon club » : équipe, retrait, renommer | non | non | oui | oui |
| « Administration » (compte administrateur, même sans club) | non | non | non | oui |
| « Mes enfants » / « Ma progression » | oui | non | non | non |

`roleRedirect` (fonction pure, `authRedirect`) applique la même table aux **adresses** : un lien tapé à la main n'ouvre pas ce que le menu ne montre pas. Un élève ou
un parent n'a que « Mes enfants », « Plus » et la fiche en parcours de **ses** élèves liés (`/students/<id>/show`) ; le reste le ramène à « Mes enfants ». Un
compte sans club mais administrateur atteint `/administration` depuis l'écran « Aucun club ». Le club « Démo » est un club **ordinaire** (C6) : aucun mode sans compte, aucun code
particulier ; il est créé par la graine des émulateurs ou, en production, par l'administrateur.

## Espace élève et parent (lot FB6, 2026-10-19)

Un parent ou un élève de 15 ans et plus connecté arrive sur `/my-children` (le garde de rôle y ramène toute autre adresse) : **une seule page, en lecture seule**.

| Zone | Contenu | Source (rôle `guardian` ou `student`) |
|---|---|---|
| Sélecteur d'enfant | une puce par fiche liée (`members.studentIds`, ordre du lien) : initiale et prénom ; deux prénoms identiques sont numérotés (« Léa (1) », « Léa (2) »). Absent avec un seul enfant. Le choix survit aux mises à jour ; chaque parcours est lu et gardé **par élève** (aucun état partagé entre deux enfants) | `StudentRepository.byId` par fiche liée |
| Parcours de l'élève choisi | la vue « à montrer à l'élève » (ADR 0014, `ShowcaseView`) : devenue la page ; exercice en cours, cases, jamais un échec | `AttemptRepository.forStudent`, `AcquisitionRepository.forStudent` (égalité sur `studentId`) |
| Prochaines séances | au plus 5, à partir d'aujourd'hui, des groupes **du compte** : titre, jour, nom du groupe | `SessionRepository` (égalité sur `groupId`, un groupe à la fois) et `GroupNames` (document du groupe, **jamais** ses appartenances) |
| Messages | chargement ; « Aucun élève n'est encore lié » ; aucune séance prévue ; **hors ligne** (dernières données + pastille de la barre) ; **Accès refusé** (distinct de « service injoignable », ADR 0024 notes FB4a) ; **Accès retiré** | `FamilyStatus` |

**Aucune écriture** : pas de bouton (Noter, Planifier, Saisir, Inviter, « Terminé »), menu réduit à deux destinations, routes d'animateur refusées par `roleRedirect`, règles qui n'autorisent aucune écriture à ces rôles. **Jamais lus** : autres fiches, liste des camarades (appartenances), saisies, **« Vu »** (acquittements), bilans, étiquettes, archives. **Alertes : calculées, jamais stockées** : aucune alerte n'existe côté serveur ; elle est **calculée sur l'appareil** (`StudentProgress.derive` puis `techniqueSummary` produisent `BlockStatus.toReview`) à partir des passages et de `settings/main` reçus, **même sans les « Vu »** ; elle n'est masquée qu'à l'affichage (une technique « à revoir » est montrée « en cours »). **Structure « affiché / reçu sans être affiché »** (point à porter à l'AIPD, fait foi : `scripts/rules_test/family_reads.json`, contrôlé par `scripts/check_family_register.dart` contre le registre) :

| Lecture | Affiché | Reçu sans être affiché |
|---|---|---|
| `students/{student}` | prénom | la fiche entière : `audience`, `audienceHistory` (changements de public datés), `groupIds` courants, `createdAt` |
| `attempts` | parcours (passages réussis) | **tous** les passages, réussis **et manqués**, avec date, séance, groupe (la **présence** s'en déduit) |
| `acquisitions` | parcours (blocs validés) | date et source (`placement`) des blocs acquis |
| `settings/main` | rien directement | le document **en entier** (sert au calcul du parcours et des alertes) |
| `groups/{group}` | nom du groupe | le document, dont `teacherUids` (**données d'un tiers**) |
| `sessions` | cinq prochaines : titre, jour, nom du groupe | **toutes** les séances des groupes, passées comprises, avec leur public |
| `members/{uid}` (le propre) | rien directement | `displayName`, `role`, `groupIds`, `studentIds`, `invitationCode` |
| connexion : `clubs/{club}`, `admins/{uid}`, requête de groupe `members` `uid=` | nom du club | nom, `currentSeasonId` ; existence du document `admins/{uid}` ; rattachements du compte |

**Temps réel** : un seul abonnement `WatchFamilySpace` (fiche, passages et acquis de chaque fiche liée, séances, groupes, et **son propre `member`**) ; l'écran se recharge en place par `GetFamilySpace` (même `LiveReload` que les autres écrans). **Lien retiré** : le `member` supprimé fait refuser l'écoute de ce document (et elle seule) ; les écoutes de données déjà ouvertes ne le sont qu'à la modification suivante ; l'écran relit son lien (`OwnLinkSource.read`) : plus de `member` (ou plus de fiche liée, ou lecture refusée) = **Accès retiré** : l'écran passe en direct à cet état (écoute du `member`), l'abonnement est relâché, plus aucune donnée n'est affichée. Côté serveur, les nouvelles lectures sont refusées et une écoute déjà ouverte n'est refusée qu'à la prochaine modification d'une séance ou du document de ce groupe (un renommage suffit), ou du document écouté ; le cache de l'appareil est vidé à la déconnexion ; un lien qui existe encore mais dont la lecture est refusée = **Accès refusé** (réessayer n'y change rien). Un retrait **partiel** (une fiche sur deux) : `CheckFamilyAccess` rend `AccessGranted` avec les fiches restantes seulement ; la fiche déliée n'est plus lue et l'enfant encore lié reste affiché. **Limite pour les groupes** : le retrait d'un **groupe** n'est pas géré de la même façon. `OwnLink` lit `groupIds`, mais les séances et les noms de groupes passent par les dépôts Firestore, qui parcourent `ActiveClubScope.groupIds`, figé à la connexion (port en lecture seule) : sans relire la portée de session, l'écran ne peut ni cesser de lire ce groupe ni filtrer ses séances. Deux preuves de natures différentes : (1) **côté serveur, durable** (`family.test.mjs`, « known limit », SDK navigateur, vraies règles, émulateur ; ne casse **pas** avec FB7, c'est le comportement des règles) : au retrait du groupe, les écoutes ouvertes ne reçoivent aucun refus, une lecture faite **par la même instance du client** est servie par la cible de l'écoute déjà ouverte (une lecture depuis une **autre** instance est refusée), à la **prochaine modification d'une séance ou du document de ce groupe (un renommage suffit)** l'écoute est refusée, toute lecture neuve est refusée ; (2) **côté client, destinée à casser avec FB7** : tests unitaires avec **doubles** (`check_family_access_test`, « known limit » : le lien relu sans le groupe reste `AccessGranted` ; `family_space_cubit_test`, « known limit » : l'écran garde les séances du groupe retiré) ; ce ne sont **pas** des mesures à l'émulateur, ils fixent le comportement du code de l'application. Reste pour FB7 : relire la portée sans reconnexion, fiches et groupes.

**Pas d'aiguillage de backend par rôle (écarté par l'utilisateur le 2026-10-19)** : l'espace famille ne lit Firestore qu'avec `DATA_BACKEND=firestore` explicite, donc après la bascule ; drift reste le défaut pour **tous** les rôles et aucune lecture de mineurs n'arrive au serveur avant. Le parcours navigateur sous émulateurs est lancé avec l'indicateur. Détail : [repositories-firestore-plan.md](repositories-firestore-plan.md).

**Textes** (fr et en) : sobres, pour des familles, **à valider** par la fédération ou le DPO avec la notice ([conformite/notice-information-familles.md](conformite/notice-information-familles.md)). Les titres de séance sont du texte libre de l'animateur, visible de toutes les familles du groupe : consigne de n'y mettre aucun nom d'élève.

**Prénom + initiale** : le domaine `Student` n'a ni initiale ni nom de famille (l'initiale du nom reste un champ facultatif de la fiche, inutilisé) : le sélecteur affiche l'**initiale du prénom** dans la pastille et numérote les prénoms identiques. Ajouter l'initiale du nom serait une donnée de plus sur un mineur (décision à prendre avec l'AIPD).

## Tests

| Niveau | Où |
|---|---|
| Règles, grille | `scripts/rules_test/matrix.test.mjs` : chaque collection × chaque action × 12 acteurs (anonyme, e-mail non vérifié, invité sans member, élève, deux parents, deux enseignants, enseignant d'un autre club, directeur, directeur d'un autre club, administrateur) ; la liste des **autorisés** est écrite à la main, tout le reste doit être refusé |
| Règles, invitations | `invitations.test.mjs` : création par rôle, formes, durées, codes, lecture, consommation par lot (réutilisation, expiration, mauvais club, mauvais rôle, mauvais périmètre, e-mail non vérifié, deux comptes dans un lot), révocation |
| Règles, élévation et bornes | `escalation.test.mjs`, `bounds.test.mjs` : mise à jour de son propre member, directeur, enseignant, parent ; chaque borne juste en dessous (acceptée) et juste au-dessus (refusée) |
| Règles, refus par défaut | `default_deny.test.mjs` : chemins hors modèle refusés à tous ; anonyme et e-mail non vérifié refusés sur tout le modèle |
| Règles, couverture du modèle | `model_coverage.test.mjs` + `model.json` : chaque collection de l'ADR a son bloc `match`, sa ligne dans l'ADR et sa grille ; aucune collection non documentée |
| Règles, budget | `budget.test.mjs` : les deux hypothèses du budget de 10 accès, mesurées |
| Graine et jetons réels | `seed.test.mjs` : la graine refuse tout hôte non local et tout projet hors `demo-…` ; chaque compte de la graine se connecte à l'émulateur Auth et voit ce que la matrice lui accorde ; un compte neuf rejoint le club « Démo » avec le code de la graine |
| Parcours de bout en bout | `scripts/emulator_e2e.sh` : l'application (debug) contre les émulateurs Auth et Firestore et la graine : la directrice se connecte, « Mon club » affiche l'équipe semée (lue sous les règles) ; un parent atterrit sur « Mes enfants » |
| BDD | `test/bdd/clubs_roles.feature` : 25 scénarios (dont deux démarrages à froid sur un lien) (invitation d'un enseignant, d'un élève, d'un parent, case d'âge, enseignant limité à ses groupes, garde de route, élève sans action d'animateur, parent qui rejoint et voit son enfant seulement, lien, code gardé à l'inscription, code expiré, utilisé, inconnu, nom exigé, révocation, retrait, renommage, administrateur sans club, directeur invité, français) |
| Unitaires | cas d'usage, cubits (`bloc_test`), dépôts sur le double en mémoire, adaptateur Firestore sur un accès scripté, widgets (cibles de 48 dp, sémantique), pages, `authRedirect` et `roleRedirect`, graphe de production |
| Mutations à la main | tableau dans [testing.md](testing.md) (règles, copie du fichier) |

### Journal du rouge (BDD d'abord)

| Étape | Constat |
|---|---|
| `clubs_roles.feature` écrit, étapes générées (`UnimplementedError`) | la compilation échoue : étapes absentes |
| Étapes écrites sur le stock de documents brut (`UiWorld`, sans dépendre des cas d'usage ni des pages), application **sans** le lot | exécution : `+0 -14` aux 14 premiers scénarios (**aucun ne passe** ; la sortie affichée s'arrête là, 23 scénarios au total) : « Léa » absente de l'écran, « Inscription sur invitation » absente du lien, « Rejoindre un club » absente, adresse `/students/…/show` ouverte à un élève au lieu de `/my-children` |
| Corrections de relecture (2026-10-18) : deux scénarios de démarrage à froid sur un lien (`When the app is opened on the address`) | **rouge vu** avant le correctif : `authRedirect(AuthUnknown, /join/<code>)` donnait `/splash?from=%2Fjoin%2F<code>`, puis la connexion ; scénarios : « Inscription sur invitation » et « Rejoindre un club » absents ; tests unitaires de la chaîne : 6 échecs sur 8 ; vert après `invitationCodeOf` et `splashWith` |
| Vert | les 23 scénarios passent après les cubits, les pages, le garde de route et le routeur ; les scénarios d'authentification (FB2) et tous les autres restent verts (`flutter test` complet) |

### Journal du rouge FB6 (BDD d'abord)

| Étape | Constat |
|---|---|
| `family_space.feature` (10 scénarios à l'origine, 12 aujourd'hui) et étapes écrits **avant** le code | étapes ne dépendant que de l'existant (`UiWorld`, `DeviceDocumentStore`, serveur partagé de FB5b) |
| Joué sur l'application **d'avant le lot** (`git worktree` du commit FB5, journal `fb6-bdd-red.log` du dossier de travail) | `+1 -9` sur les 10 scénarios d'alors : 9 scénarios rouges (pas de sélecteur, pas de séances, pas de « Accès refusé » ni « Accès retiré », le parcours n'apparaît pas dans « Mes enfants », « My children » en double), le seul vert étant la garde de route (déjà en place) |
| Non vus rouges | les 2 scénarios ajoutés après (« second enfant suivi en direct », « retrait d'un seul des deux liens ») n'ont **pas** été joués sur l'application d'avant le lot : leur rouge n'est pas établi |
| Vert | les 12 scénarios passent avec `FamilySpaceCubit`, le sélecteur, les séances et les messages (sur Firestore en mémoire, `DATA_BACKEND=firestore` explicite) |
| Parcours navigateur (premier passage) | **rouge utile** : « Accès retiré » ne venait pas (les lectures étaient servies par les écoutes ouvertes ; voir ADR 0024 notes FB6) ; les puces de choix n'ont qu'une étiquette d'accessibilité (pas de texte) : le parcours les cherche par étiquette |

## Limites assumées

- Les règles sont **testées contre l'émulateur**, jamais contre la production : la région, les index et la protection contre l'énumération d'adresses de la console
  restent à contrôler par l'utilisateur.
- L'adaptateur `FirestoreDocumentStore` (le plugin natif) ne tourne pas sous `flutter test` ; ses appels directs au SDK (quatre fonctions) sont couverts par les
  opérations équivalentes du SDK web dans les tests de règles ; la traduction des valeurs et des échecs l'est sur un accès scripté. **La fumée du build web compilé
  n'exerce pas Firestore** : les flux longs du SDK ne passent pas par une interception de requêtes ; elle refuse explicitement les appels Firestore (voir testing.md). Le chemin application + Firestore + règles est exercé par `scripts/emulator_e2e.sh`, en **mode debug** (le build compilé n'accepte pas l'émulateur : release refusée, profile inutilisable, testing.md « Piège »). `FirestoreSdkAccess` est testé sur `fake_cloud_firestore` (dépendance de test).
- Un administrateur supprimant un club ne supprime pas ses sous-collections : les `members` restent lisibles jusqu'à la purge (FB8).
- La date de création d'une invitation est celle du serveur ; la durée est calculée sur l'horloge du client (tolérance de 1 heure dans la règle).
- Un enseignant crée une fiche d'élève mais ne la modifie pas ; le directeur seul corrige ou efface (matrice de l'ADR).
- La graine des émulateurs partage un mot de passe public de démonstration, valable **uniquement** dans l'émulateur.

## À faire par l'utilisateur (console Firebase) : **jamais fait par l'agent**

1. **Déployer les règles et les index** : `firebase deploy --only firestore:rules,firestore:indexes` (projet `animation-billard`). **Date du déploiement : À FAIRE PAR L'UTILISATEUR.**
   Tant que ce n'est pas fait, la base publiée refuse tout (règles du lot FB0) : l'application connectée ne peut ni lire ses clubs ni rejoindre un club.
2. **Créer l'administrateur** : dans la console Firestore, créer le document **vide** `admins/{uid}` pour le compte Auth de l'administrateur (un à deux comptes).
   Le champ n'est jamais testé : l'existence suffit.
3. **Créer le premier club** : se connecter avec ce compte, ouvrir « Administration », « Créer un club », « Inviter un directeur », remettre le code (48 heures).
4. Contrôler dans la console que l'index d'exemption `members.uid` (groupe de collections) est actif après le déploiement des index.
5. Les actions déjà listées pour FB1 et FB2 restent valables (fournisseur e-mail seul, protection contre l'énumération, modèles de courriel, domaines autorisés,
   `flutterfire configure`).
6. **Garde-fou de mise en production** : aucun vrai élève avant la décision `[U]` datée de `conformite/README.md`.
