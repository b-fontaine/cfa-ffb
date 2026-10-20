# Plan : dépôts Firestore (lot FB4)

Statut : **parties 1, 2 et 3 livrées** (2026-10-18) puis **FB5b** (2026-10-19, section en fin de document), sous émulateurs et doubles seulement. **Aucune base de production touchée.** **La bascule de production n'a PAS lieu dans FB4** (décision de l'utilisateur, 2026-10-18) : `DATA_BACKEND` reste `drift` par défaut jusqu'à ce que **FB7** soit livré ; la bascule est un **lot dédié après FB7**. Décisions :
[ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) (décisions 14, 15, 17 à 19, 28 ; notes de réalisation FB4a, FB4b, FB4c pour les écarts). Deux décisions de l'utilisateur du 2026-10-18 (décision 18 amendée, groupe obligatoire : notes FB4b de l'ADR 0024, ADR 0007 amendé).

## Découpage en trois parties

| Partie | Contenu | État |
|---|---|---|
| 1 | Erreurs d'ouverture de session ; garde-fou d'index ; fondation (chemins, club résolu à l'appel, requêtes, sélecteur de backend) ; suite de contrat sur Firestore ; dépôts **settings**, **student**, **group (+ appartenances)** ; règle `audienceHistory` | **fait** |
| 2 | `UnitOfWork` Firestore (lot) ; création d'élève par un enseignant ; dépôts **saisons, archives, séances planifiées, saisies** ; identifiant déterministe d'une saisie liée ; bornes du domaine | **fait** (2026-10-18) |
| 3 | Passages (rang dérivé), acquisitions, acquittements, bilans ; `CompositeUnitOfWork` non bloquant hors ligne ; `RulesStore` rechargé par club ; contrat complet sur Firestore | **fait** (2026-10-18) ; **bascule de production : lot dédié après FB7** ; sauvegarde et effacement : FB7 et FB8 |

## Ce que la partie 1 pose

- **`ClubPaths`** (`shared/persistence`) : tous les chemins d'un club ; aucun dépôt n'en compose un à la main. Appartenance : `clubs/{c}/memberships/{groupId_studentId_from}`.
- **`ClubStore`** : `DocumentStore` + `ActiveClubScope`. Le club est lu à **chaque appel** ; sans club actif, `ServiceFailure(denied, 'no-active-club')`. Offre `role`, `manages`,
  `groupIds`, `studentIds` et `commit` par lots de 500.
- **`DocumentStore.query(collection, filtre)`** : égalité ou `array-contains-any` sur **un** champ (jamais d'index composite). Implémenté par la mémoire, `FirestoreDocumentStore`
  et `FirestoreSdkAccess`.
- **Codecs** (`student_document`, `group_document`, `settings_document`, `document_values`) : dates en ISO 8601 (fuseau et microsecondes conservés, texte accepté par les règles), champs de la
  liste blanche seulement, document mal formé = `ServiceFailure(other)` qui nomme le champ.
- **`DataBackend`** (`app/data_backend.dart`) : `--dart-define=DATA_BACKEND=firestore`, défaut drift, valeur inconnue = erreur. `DataBackendModule` aiguille settings, student et group ;
  les dépôts drift sont enregistrés sous leur type concret.

## Cartographie des dépôts migrés

| Port | Document(s) | Écriture | Lecture par rôle |
|---|---|---|---|
| `SettingsRepository` | `clubs/{c}/settings/main` | directeur, administrateur | tout membre |
| `StudentRepository` | `clubs/{c}/students/{id}` (même document que `StudentDirectory`) | gestionnaire (l'enseignant crée avec un groupe : partie 2) | gestionnaire : liste ; enseignant : `array-contains-any` ; parent, élève : fiches liées |
| `GroupRepository` | `clubs/{c}/groups/{g}` + `clubs/{c}/memberships/{…}` + `groupIds` des fiches | gestionnaire | gestionnaire : liste ; enseignant : ses groupes et leurs appartenances ; parent, élève : groupe sans appartenances |

Portée et réouverture : `ClubStore` ferme les flux épinglés dès l'écriture de la portée (club, rôle, groupes et fiches triés ; `permissionDenied` `scope-changed`, écoute relâchée sans attendre un événement) ; `ClubScoped` ne referme pas les blocs des pages ouvertes (le `Navigator` de go_router survit), c'est `LiveReload` qui rouvre l'écoute après l'erreur, sous la nouvelle portée. Contrat : Firestore ferme un flux après une erreur, mémoire et drift le laissent ouvert. Limites assumées : voir l'ADR 0024 (notes FB5b, a à c), dont l'`arrayUnion` d'un enseignant sur les présents d'une saisie.

Budget de lectures : `GroupRepository.save` lit le groupe, les appartenances du groupe et chaque fiche concernée ; `all()` d'un gestionnaire : 2 lectures de collection ;
`StudentRepository.save` : 1 lecture. Écritures : un lot par `save` (500 au plus par lot).

## Ce que la partie 2 pose

- **`UnitOfWork` Firestore** (`FirestoreUnitOfWork`, `shared/persistence`) : les écritures des dépôts Firestore faites pendant `run` (même zone) attendent la fin du corps, puis
  partent en **un seul lot atomique** (`ClubStore.atomically`). Au plus **500** écritures : au-delà, `StoreFailure(batchTooLarge)` (`ServiceFailure` `other`, détail « 501 writes > 500 »)
  **avant** toute écriture, dans le stock en mémoire comme dans `FirestoreDocumentStore`. Deux écritures d'un même document sont **fusionnées** (`PendingWrites`) ; un dépôt
  **relit ses propres écritures** (`ClubStore.get` ; les listes et requêtes ne les voient pas). Hors unité, `ClubStore.commit` garde les lots de 500 successifs et idempotents
  (opérations longues : FB7, FB8). `CompositeUnitOfWork` enveloppe le lot Firestore dans la transaction drift tant que des dépôts restent sur drift (le lot part avant la
  validation de drift) ; `DataBackendModule` choisit.
- **Création d'un élève par un enseignant (tranché)** : l'enseignant inscrit la fiche **dans le même lot** que l'appartenance (`EnrollStudent` dans l'unité de travail). La règle de
  création des fiches **ne change pas** (au moins un groupe, tous à l'enseignant). La règle des **appartenances** admet un enseignant **uniquement** pour une fiche **neuve** de son groupe
  (`teacherEnrolls` : `!exists(fiche)` avant le lot et `getAfter(fiche).groupIds` contient le groupe) ; la mise à jour et la suppression restent au gestionnaire. Écartée : une règle de
  fiche acceptant `groupIds: []` ou un groupe lu par `get()` (plus lâche, et l'appartenance resterait sans règle). Pour que l'enseignant n'écrive ni la saison ni le groupe, **un document
  inchangé n'est pas réécrit** (saison, groupe) ; la fiche part par fusion avec `groupIds` cumulé par `ArrayUnion`.
- **Dépôts** (même méthode : codec à liste blanche, contrat sur drift + mémoire + Firestore faux, test Node contre les vraies règles par rôle) :

| Port | Document(s) | Écriture | Lecture par rôle |
|---|---|---|---|
| `SeasonRepository` | `clubs/{c}/seasons/{id}` | gestionnaire | tout membre : liste |
| `SeasonArchiveRepository` | `clubs/{c}/archives/{saison_public}` (synthèse) et `{saison_public_bloc_n}` (exercice) | gestionnaire, remplacement par saison | enseignant et gestionnaire |
| `SessionRepository` | `clubs/{c}/sessions/{id}` (groupe et saison dénormalisés) | enseignant de son groupe, gestionnaire | gestionnaire : liste ; enseignant, parent, élève : **un groupe à la fois** (égalité sur `groupId`) |
| `SessionRecordRepository` | `clubs/{c}/records/{id}` (`presentStudentIds`, étiquettes en codes) | enseignant de son groupe, gestionnaire | gestionnaire : liste, `array-contains-any` par élève ; enseignant : un groupe à la fois, élève filtré en mémoire ; **parent et élève : aucune lecture** (listes vides, aucune requête refusée) |

  Budget de lectures : `SeasonRepository.save` 1 lecture ; `SessionRepository.add` 2 (groupe, séance) ; `SessionRecordRepository.save` 1 ; `all()` d'un gestionnaire 1 lecture de
  collection, d'un enseignant une requête par groupe.
- **Identité d'une saisie** (décision 18, amendée le 2026-10-18) : `sittingId(groupe, jour, séance)` = `groupe_AAAAMMJJ_séance` (domaine, borné à 64 comme toute référence de séance :
  `sessionReferenceTooLong`) ; `OpenSession` l'utilise pour une saisie liée à une séance du catalogue, un UUID sinon. Deux appareils qui ouvrent la même séance le même jour **réussissent
  tous deux et convergent** : `SessionRecordRepository.open` crée le document par une transaction (`DocumentStore.createIfAbsent`, seule écriture à poser `createdAt`), sinon réunit les
  présents par `ArrayUnion` (jamais lus puis réécrits ; au-delà de 60 présents réunis, `tooManyPresent` après relecture) ; `resume` (reprise d'une saisie existante) **remplace** les présents (décocher reste possible),
  l'union est réservée à l'ouverture concurrente. Règle : `createdAt` exigé à la création, **absent du diff d'une mise à jour**. Lecture d'un document absent : gestionnaire, ou enseignant pour un identifiant
  aléatoire ou portant l'un de ses groupes (`mayProbeAbsent` : pas d'oracle d'existence sur `groupe_AAAAMMJJ_séance`).
- **Bornes ajoutées au domaine** (`InvariantViolation` localisée fr/en, test d'abord) : libellé de saison ≤ 80 (constructeur : les libellés sont générés), nom de groupe ≤ 80
  (`requireGroupNameFits`, à la création, au renommage, à l'inscription et au changement de public), titre de séance planifiée ≤ 120 (`PlanSession`), ≤ 60 élèves présents
  (`requirePresentFit`, à l'ouverture et à la reprise d'une séance) : `nameTooLong` ou `tooManyPresent`. Les deux dernières ne sont **pas** dans les constructeurs : une donnée
  déjà enregistrée (drift, avant la borne) reste lisible. Séance planifiée **sans groupe** refusée par le domaine (`PlanSession`, `sessionNeedsGroup`). `rule_bounds_test` lit `firestore.rules`
  et échoue si une borne diverge.
- **Index** : aucun nouvel index (égalité et `array-contains-any` sur un seul champ) ; `firestore.indexes.json` inchangé.

## Écarts et limites de la partie 2

- **Séance planifiée : groupe obligatoire (tranché le 2026-10-18)** : `PlanSession` refuse une séance sans groupe (`sessionNeedsGroup`) ; l'écran exige un groupe (le public est celui du
  groupe). Le dépôt Firestore ne garde qu'une garde défensive. Les séances sans groupe **déjà dans drift restent lisibles** : **reprise au FB7** (les rattacher à un groupe ou les écarter
  avant leur transfert).
- **Transfert d'une saisie libre vers une séance du catalogue (tranché le 2026-10-18)** : `OpenOrResumeSession` garde la confirmation actuelle de l'écran ; la saisie **garde son UUID**.
  Un doublon entre deux appareils est possible mais rare, et assumé (décision 18 amendée).
- **Appartenance créée par un enseignant** : liée à son contenu (identifiant `groupId_studentId_from`, `from` = début de l'historique de la fiche neuve, période ouverte, saison du
  groupe). Limite assumée : un enseignant du groupe peut recréer une fiche sous le même identifiant après sa suppression par le directeur (les données gardées sous cet identifiant restent).
- **Transaction hors ligne** : `createIfAbsent` est une transaction, qui échoue hors ligne ; à traiter avec la stratégie hors ligne de la partie 3 (bloquant de bascule, déjà inscrit).
- **Saison courante du club** (`currentSeasonId`, document du club) : écrite par l'administrateur seulement (règle FB3) ; `SeasonRepository` ne la touche pas. Un directeur qui
  clôt une saison ne peut pas la déplacer : à traiter avec la clôture reprenable (FB7).
- **Suppression** : physique pour les quatre dépôts (décision 15) ; les passages d'une saisie supprimée sont du lot suivant ; `idsEverPresent` et `idsOfGroups` ne voient plus
  les éléments supprimés (drift gardait les suppressions logiques pour le droit à l'effacement).
- **Ordre des listes** : saisons par début, séances planifiées et saisies par jour puis identifiant, archives par saison (l'ordre de première sauvegarde n'existe pas côté serveur).
- **Mélange de backends** (partie 2) : passages, acquisitions, acquittements et bilans restaient sur drift ; **ils ont migré en partie 3** (ci-dessous). Reste local avec `DATA_BACKEND=firestore` : `run_progress` (ADR 0020) et le marqueur de sauvegarde ; le réglage ne sert qu'au développement et aux tests, jusqu'au lot de bascule après FB7.

## Ce que la partie 3 pose

- **Passage = un document** (`clubs/{c}/attempts/{id}`, ajout seul) ; le **rang est dérivé** (décision 17, ADR 0006 amendé) : `ExerciseAttempt` perd `passIndex`, `passRanks` et `chronological` (`exercise_attempt.dart`) le calculent d'après l'**ordre d'enregistrement** que rendent les dépôts (Firestore : `createdAt` du serveur, puis `recordedAt`, puis identifiant ; drift et mémoire : insertion). Supprimer ou corriger un passage ne renumérote rien. Schéma drift **v12** (colonne retirée) ; sauvegarde v5 inchangée (rang dérivé écrit, ignoré à la lecture).
- **Dépôts** (même méthode : codec à liste blanche, contrat sur drift + mémoire + Firestore faux, `progress.test.mjs` contre les vraies règles par rôle) :

| Port | Document(s) | Écriture | Lecture par rôle |
|---|---|---|---|
| `AttemptRepository` | `clubs/{c}/attempts/{id}` (groupe et saison de la séance, `createdAt` serveur) | enseignant de son groupe, gestionnaire ; correction : billes seulement | gestionnaire : liste ; enseignant : un groupe à la fois (avec élève ou séance) ; **parent, élève : la fiche liée** |
| `AcquisitionRepository` | `clubs/{c}/acquisitions/{id}` (groupe de la fiche) | enseignant de son groupe, gestionnaire | idem passages ; **la famille lit les blocs acquis de sa fiche liée** |
| `AssessmentRepository` | `clubs/{c}/assessments/{id}` | idem | gestionnaire, enseignant du groupe ; **famille : rien** (B2) |
| `AcknowledgementRepository` | `clubs/{c}/acknowledgements/{id}` (`createdBy` = uid) | idem (`createdBy` = son uid) | gestionnaire, enseignant du groupe ; **famille : rien** (B2) ; **« Vu » partagé par club** |

  Budget de lectures : `AttemptRepository.add` 1 lecture (la séance), `correct` 1 ; bloc acquis, bilan, acquittement : 1 (le document) + `1 + 2n` pour un document neuf (fiche, `n` groupes et leurs saisons) ; un acquittement lit d'abord le dernier passage acquitté ; lectures : une requête (gestionnaire), une par groupe (enseignant) ou par fiche liée (famille). Écritures : un document par passage.
- **Index** : aucun (égalités seulement, `AllEqual` : plusieurs égalités sur des champs différents, servies par fusion d'index à champ unique) ; `firestore.indexes.json` inchangé, `tool/check_indexes.dart` vert.
- **`CompositeUnitOfWork`** : le lot Firestore est validé localement **sans attendre l'accusé du serveur** ; envoi suivi à part (`SendStatus`, lu en FB5). Voir l'ADR 0024 (notes FB4c) pour l'écart assumé (refus tardif du serveur).
- **`RulesStore`** : `ReloadRules` à l'activation et à la bascule de club (`AuthCubit`) ; réglages du club séparés des préférences d'appareil.
- **Contrat complet** : `repositoryContract` joué sur tous les dépôts de données Firestore (`ContractTraits`), plus `acquisitionContract`, `acknowledgementContract`, `planningContract`, etc. Voir testing.md pour ce que le faux ne prouve pas.

## Écarts et limites de la partie 3

- **Bascule de production reportée (décision de l'utilisateur, 2026-10-18)** : pas dans FB4 ; **lot dédié après FB7**. Tant que FB7 n'est pas livré, `DATA_BACKEND=firestore` reste réservé au développement et aux tests : aucune sauvegarde ne s'importe (avec saisie), aucun club existant ne migre.
- **Ajout seul d'un passage** : sur Firestore, rejouer un identifiant est refusé ; une correction passe par `correct`. Hors ligne, `add` ne lit rien (pas de blocage) ; `correct` relit le passage (en cache, déjà listé).
- **Fiche sans groupe** : ne peut recevoir ni bloc acquis, ni bilan, ni acquittement (`ServiceFailure` `other`) ; une fiche d'enseignant hors de ses groupes est refusée.
- **Ordre à date égale** : deux passages enregistrés au même instant du serveur sont ordonnés par identifiant ; la borne de passages par séance est un compte, pas une garantie entre deux appareils simultanés.
- **Écritures hors unité de travail** : elles attendent encore l'accusé du serveur (FB5) ; la création d'une saisie (transaction) échoue hors ligne (FB5).
- **Import** : `ImportBackup` (drift) reste `unsupported` avec une saisie sous Firestore (une saisie se crée par transaction, impossible dans un lot) ; sans aucune saisie, il est supporté (atomique, figé par un test) mais refuse une séance planifiée sans groupe. **Le moteur d'import vers un club Firestore est livré en FB7, partie A (2026-10-20)** : voir la section « Import d'une sauvegarde (FB7, partie A) » ci-dessous. **Sauvegarde et `StudentEraser` côté serveur** : FB7 (clôture) et FB8 (lots reprenables, marqueur `erasing`) ; `eraseStudent` des dépôts n'est qu'une requête par élève, réservée aux gestionnaires.

## Reste après FB4

- **Lot de bascule de production, après FB7** (décision du 2026-10-18) : défaut `DATA_BACKEND=firestore`, retrait de `CompositeUnitOfWork` et des dépôts drift de données (FB7), parcours navigateur application + émulateurs avec les dépôts Firestore, déploiement des règles et des index **par l'utilisateur** (rien n'est déployé).
- **FB5** : **fait** (parties A et B, 2026-10-19) : `watch…`, pastille, écritures non bloquantes hors ligne, création de saisie hors ligne, SDK web local ; voir la section suivante. Reste hors FB5 : écran de positionnement et fiche sans groupe.
- **FB7** : **partie A faite (2026-10-20)** : moteur d'import (plan, intégrité, droits, lots, marqueur, règles, tests émulateur). **Reste (partie B)** : écran d'import, choix des groupes et des séances sans groupe, confirmation des élèves effacés, avancement, reprise ; parcours navigateur ; **clôture reprenable** (lots de 500 avec marqueur) ; reprise des séances sans groupe de drift *(faite côté moteur : choix explicite par séance)* ; saison courante du club (écrite par l'administrateur seulement).
- **FB8** : `StudentEraser` côté serveur, effacement par lots reprenables.

## Ce que FB5b ajoute (2026-10-19)

Détail et décisions : [ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md), notes FB5b.

### Flux (`watch…`) : même cartographie que les lectures

Chaque flux suit **les mêmes requêtes que la lecture `Future` du même rôle** (les règles n'autorisent pas la même requête à tous), jamais la collection entière pour un enseignant ou un parent.

| Port | Flux | Gestionnaire | Enseignant | Parent, élève |
|---|---|---|---|---|
| `StudentRepository` | `watchById`, `watchAll` | collection | `array-contains-any` sur ses groupes (30 par requête) | ses fiches liées, un document chacune |
| `GroupRepository` | `watchAll`, `watchById` | groupes + appartenances | document de chaque groupe + appartenances (`groupId`) | documents des groupes, **sans** appartenances |
| `SessionRepository` | `watchAll` | collection | une requête par groupe | une requête par groupe |
| `SessionRecordRepository` | `watchForGroup`, `watchForStudent`, `watchAll` | collection ou `array-contains-any` | une requête par groupe (filtre en mémoire pour l'élève) | **aucune écoute** (liste vide) |
| `AttemptRepository` | `watchForStudent`, `watchForSession`, `watchAll` | égalité sur l'élève / la séance | groupe + élève (ou séance) | la fiche liée |
| `AcquisitionRepository` | `watchForStudent`, `watchAll` | idem | groupe + élève | la fiche liée |
| `AcknowledgementRepository` | `watchForStudent`, `watchAll` | idem | groupe + élève | **aucune écoute** |
| `AssessmentRepository` | `watchForStudent` | idem | groupe + élève | **aucune écoute** |

Budget de lectures : une écoute facture les documents de son premier état puis chaque document modifié ; une écoute rouverte après une erreur ou un « Réessayer » relit son premier état (depuis le cache s'il est chaud). Un écran abonné ouvre : fiche d'un élève 7 sources, liste des groupes 5, séance du jour 3 (chacune fermée avec l'écran). Aucun index composite.

### Règle de conflit (B5) : table document → règle

Texte complet et limites dans l'ADR (notes FB5b). Un test par ligne : `app/test/contract/conflict_contract.dart` (faux Firestore et double du stock, deux appareils) et `scripts/rules_test/conflicts.test.mjs` (émulateur, deux clients, vraies règles).

| # | Document | Règle |
|---|---|---|
| C1 | fiche élève | dernier écrit gagne par document ; `groupIds` jamais réécrit |
| C2 | `groupIds` d'une fiche | réunion commutative (`ArrayUnion` / `ArrayRemove`) |
| C3 | groupe | nom et public : dernier écrit gagne ; appartenances d'élèves différents réunies |
| C4 | appartenance | identifiant déterministe : écritures identiques = un document |
| C5 | saisie liée à une séance | une création, présents réunis, date et blocs du premier ; hors ligne : écriture simple puis reprise |
| C6 | saisie (enregistrer) | remplacement en bloc, dernier écrit gagne ; `open` réunit, `resume` remplace |
| C7 | étiquettes | liste remplacée en bloc |
| C8 | passages | ajout seul, un document par passage ; rejeu d'un identifiant refusé |
| C9 | correction d'un passage | dernier écrit gagne sur les billes seulement |
| C10 | blocs acquis | un document par marquage, doublons fusionnés par le calcul |
| C11 | « Vu » partagé | un document par acquittement, à son auteur ; le calcul garde le dernier |
| C12 | séances planifiées | un document par séance |
| C13 | suppression physique, réglages | suppression idempotente, `update` ne recrée pas, réglages : une écriture entière gagne |

Limites sans règle sûre : L1 agrégat de groupe périmé, L2 fiche supprimée recréée par fusion, L3 historique du public remplacé en bloc, L4 listes de présents et d'étiquettes remplacées en bloc, L5 reprise de création hors ligne non durable.

### Écritures non bloquantes hors ligne

`ClubStore.commit` (hors unité de travail) n'attend l'accusé du serveur que `ackGrace` (1,5 s), puis confie l'envoi au suivi (`SendTracker`) ; il n'attend pas du tout si le réseau est connu coupé ou si un envoi attend déjà. Un refus dans le délai reste l'échec de l'appelant ; un refus tardif arrive à la pastille. Les écritures qui parlent à `DocumentStore` sans `ClubStore` (clubs, invitations, membres, publication de la fiche à l'invitation) restent volontairement en ligne et **attendent encore** hors ligne (reste de FB6/FB7).

## Ce que FB6 ajoute (2026-10-19) : aucun aiguillage par rôle

**Décision de l'utilisateur du 2026-10-19** (ADR 0024, notes FB6) : **pas d'aiguillage de backend par rôle**. Une proposition d'aiguiller les comptes `student` et `guardian` vers Firestore avant la bascule (`DataBackendChoice.forRole`, `RoleRoute`, six `RoleRouted…Repository`) a été écartée : l'espace famille ne lit Firestore qu'avec `DATA_BACKEND=firestore` explicite, donc après la bascule, et **drift reste le défaut pour tous les rôles**. Aucune lecture de mineurs n'arrive au serveur avant.

| Élément | Rôle |
|---|---|
| `DataBackendChoice(backend)` et `DataBackendModule` | inchangés : `choice.backend.choose`, le dépôt choisi par le réglage du build, l'autre n'est pas construit ; aucun rôle n'intervient |
| Tests, dans les deux sens | `data_backend_module_test.dart` : sans `DATA_BACKEND`, les onze dépôts et l'unité de travail sont drift (le module ne reçoit aucun rôle : défaut drift vérifié, identique pour tout compte) ; `DATA_BACKEND=firestore` donne Firestore à tous ; `production_graph_test.dart` : graphe de production exact (drift) |
| Parcours navigateur | `scripts/emulator_e2e/serve_and_test.sh` lance l'application avec `--dart-define=DATA_BACKEND=firestore` |

**Ce que lit un parent ou un élève** (liste exacte : `scripts/rules_test/family_reads.json`) : le document de **chaque fiche liée** (`get` et écoute), ses passages et ses blocs acquis (égalité sur `studentId`), les séances de **ses groupes** (égalité sur `groupId`), le document de **chaque groupe** (jamais ses appartenances), le réglage du club (`settings/main` **en entier**, pas seulement les règles de validation) et **son propre `member`**. L'appareil **reçoit et met en cache sans l'afficher** : tous les passages de la fiche liée, réussis et manqués, avec leur date, leur séance et leur groupe (la présence s'en déduit), le document de chaque groupe (il porte `teacherUids`, identifiants de compte des enseignants : données d'un tiers) et toutes les séances de ces groupes, passées comprises (cinq affichées). Ni liste d'élèves, ni appartenances, ni saisies, bilans, « Vu », archives. Le test Dart du cas d'usage compare le journal des demandes de l'appareil à cette liste, le test de règles joue la liste contre les vraies règles et joue les lectures interdites.

## Import d'une sauvegarde (FB7, partie A)

Le moteur écrit une sauvegarde (formats 1 à 5) dans un club **sans passer par les dépôts** : les dépôts lisent le propriétaire d'une donnée dans le club et créent une saisie par transaction, ce qu'un lot ne permet pas. Il réutilise leurs **codecs** (`*_document.dart`, via `app/club_import_operations.dart`) : les documents écrits sont exactement les leurs, `ClubStore` n'étant pas utilisé pour l'écriture (`documents.commit` attend l'accusé du serveur, ce que le marqueur exige).

| Pièce | Rôle | Où |
|---|---|---|
| `ClubImportPlanner` | plan avant toute écriture : intégrité, correspondance des groupes, choix explicites, droits du rôle, élèves effacés, lots | `features/backup_data/domain/club_import/` |
| `ClubImportRunner` | écrit les lots à partir du marqueur ; budget du jour ; coupure et refus | idem |
| `ClubImportStore` (port) | lire le club dans le périmètre du rôle, lire le marqueur, écrire un lot et le marqueur | idem |
| `FirestoreClubImportStore` | le port sur `DocumentStore` (jamais d'écrasement ; accusé du serveur attendu) | `app/` |
| marqueur `clubs/{c}/imports/{fileId}_{uid}` (propre à son auteur) | compare-and-swap de chaque lot ; reprise ; un fichier une fois | `firestore.rules`, `app/import_marker_document.dart` |

Lecture du club (`inventory`) : un gestionnaire **liste** les collections du club ; un enseignant interroge **un groupe à la fois** (égalité sur `groupId`) et ses fiches par `groupIds` (`array-contains-any`, 30 valeurs). Coût : une lecture par document présent, zéro pour un club vide ; aucune donnée personnelle ne sort de l'inventaire. Aucun index à déclarer (`tool/check_indexes.dart` vert).

Limites et écarts : voir les notes FB7a de l'[ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) (20 documents lus par lot par les règles, `recordedAt` et `createdAt`, élèves effacés non détectables, aucun import des réglages, aucun document existant modifié).
