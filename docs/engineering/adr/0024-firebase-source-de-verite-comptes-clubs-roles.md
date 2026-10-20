# ADR 0024 — Firebase source de vérité : comptes, clubs, rôles, modèle de données Firestore, garde-fous de mise en production

- Statut : **accepté le 2026-10-17** (lot FB0 de l'horizon H5). Les huit décisions `[U]` du 2026-10-16 sont reprises telles quelles ;
  la région est **tranchée par l'animateur le 2026-10-17** (base créée en `europe-west9`) ; **pour tout le reste, l'animateur a retenu la
  recommandation** de chaque point (A2 à A12, B1 à B9, C1 à C7). Les points juridiques ou chiffrés non vérifiés sont marqués
  **« à valider »** avec le nom de qui valide. La conformité (responsabilité, minimisation, conservation, effacement) est détaillée dans l'[ADR 0025](0025-comptes-et-donnees-de-mineurs-conformite.md) et `../conformite/` ; en cas de divergence sur ces points, l'ADR 0025 précise celui-ci. Recherche : [../research/firebase.md](../research/firebase.md) ; plan : [../roadmap.md](../roadmap.md) § H5.
- **Amende** : [ADR 0001](0001-persistance-locale-drift.md) (drift n'est plus la source de vérité ; « un seul animateur » et « aucune donnée
  ne quitte l'appareil » ne sont plus vrais), [ADR 0006](0006-historique-et-correction-des-passages.md) (`passIndex` dérivé),
  [ADR 0016](0016-identite-de-la-saisie-par-groupe-jour-et-seance.md) (identifiant déterministe de la saisie),
  [ADR 0018](0018-hors-ligne-service-worker-precache-versionne.md) (Node, Java et `firebase-tools` entrent dans la chaîne),
  [ADR 0019](0019-cloture-de-saison-archive-agregee-et-effacement-en-lot.md) (atomicité de la clôture, trace transitoire),
  [ADR 0020](0020-seance-en-cours-persistee-locale-hors-sauvegarde.md) (hôte local de la séance en cours), la règle 3 d'`AGENTS.md`
  (pile imposée) et sa décision de cadrage « Persistance : local d'abord ».

## Contexte

L'application sert aujourd'hui un animateur seul : tout est local (drift, ADR 0001), rien ne quitte l'appareil. La décision `[U]` du
2026-10-16, confirmée le 2026-10-17, répond « oui, via Firebase » à la question ouverte n° 4 : comptes, clubs, rôles et synchronisation
multi-appareils (lot 22 rattaché à H5). Les élèves sont des mineurs : la décision engage la conformité autant que le code.

Faits vérifiés dans le dépôt le 2026-10-17 : projet unique `animation-billard` (`.firebaserc`), déjà branché sur Hosting et les
previews de PR ; `firebase.json` déclarait une base `eur3` et trois fournisseurs (anonyme, e-mail, Google) et `firestore.rules` était en
mode test ouvert jusqu'au 2026-11-13, ce qui contredisait la roadmap ; sauvegarde v5 (`supportedVersions = {1..5}`, schéma v11,
ADR 0023) ; `Student` = identifiant, prénom et historique de public, sans compte, club, initiale ni âge ; **16 interfaces**
`*_repository.dart` dans `domain`, dont 3 d'assets (catalogue, diagrammes, fiches de séance) ; **13 de données**, dont `run_progress`
(local, décision 23) et `backup_marker` (local à l'appareil, sans objet après B5) ; soit **11 dépôts Firestore** ; `pubspec.yaml` ne
contient que `firebase_core`.
Le plan **Spark** (gratuit) impose : pas de Cloud Functions (donc ni claims personnalisées, ni purge automatique), 20 000 écritures,
50 000 lectures et 20 000 suppressions par jour, 10 `get()` par évaluation de règle, 500 écritures par lot, aucune transaction hors ligne.

## Décision

### Cadrage (décisions `[U]` du 2026-10-16, reprises)

1. **Source de vérité : Firestore seul**, avec son cache hors ligne ; drift est retiré une fois FB7 (migration) livré ; aucun mode « sans compte ».
2. **Comptes élèves : compte parent rattaché** ; un élève de 15 ans ou plus peut avoir son propre compte.
3. **Formule Spark.** Pas de Functions : invitations par code, purge lancée depuis l'application, **rôles stockés dans Firestore**
   (documents `members` lus par `get()` ; administrateurs dans `admins/{uid}`, créés à la main dans la console).
4. **Plateformes : Android, iOS et web.** Linux abandonné ; Windows = poste de développement.
5. **Connexion : e-mail et mot de passe** (avec « mot de passe oublié »).
6. **Invitations** : l'enseignant invite dans ses groupes, le directeur dans son club, l'administrateur partout.
7. **Visibilité** : l'enseignant ne voit que ses groupes ; le directeur voit son club.
8. **Conservation** : la saison en cours et l'année suivante, puis effacement ; effacement à la demande à tout moment.

### A1 — Projet, région, environnements

9. Base `(default)` **créée par l'animateur en `europe-west9`** (Paris) le 2026-10-17 (fait, déclaré par l'animateur) ; la région est
   irréversible. `firebase.json` est aligné (`firestore.location = europe-west9`, `auth.providers = { emailPassword }` seul). Restent
   à faire par l'animateur : publier `firebase.json` et `firestore.rules`, contrôler dans la console les fournisseurs et les règles
   publiés, constater la région effective (`[à confirmer]`) et relever le quota gratuit de la région, désormais visible dans la console.
10. **Un seul projet** `animation-billard`. Développement, tests et CI s'exécutent sous **émulateurs** ; les **previews de PR ne sont
    pas connectées à Firestore** (build sans configuration de production : l'application y affiche l'état « indisponible » de B8).
    Un second projet n'est envisagé que lorsque de vrais élèves arrivent ; compensations d'ici là : règles par défaut « refus »,
    App Check (C3), aucune donnée réelle avant A3.

### A2, A3, A4 — Conformité et garde-fou de mise en production

11. **Responsabilité de traitement** : cible **chaque club responsable**, l'éditeur de l'application sous-traitant avec un paquet de livrables
    types (registre, AIPD, notice d'information, DPA) ; **si une fédération ou un comité se manifeste, il devient responsable unique**
    (variante B). **À valider : l'animateur** (existence d'un partenaire fédéral).
12. **Garde-fou de mise en production (A3)** : FB1 à FB5 se développent sous émulateur avec des comptes de test. **Aucune base de
    production n'accueille de vrai élève, parent ou enseignant avant que l'AIPD soit validée et que les textes (notice d'information, registre, accord de sous-traitance, procédure) soient validés ; le détail et la levée par décision `[U]` datée sont dans l'[ADR 0025](0025-comptes-et-donnees-de-mineurs-conformite.md) (décision 3).** L'agent rédige en FB0 des **projets** fr/en, marqués « projet — à valider » dans le texte
    et dans le code ; **à valider : la fédération ou un DPO, désigné par l'animateur**. Le jalon est écrit dans la roadmap.
13. **Âge et identité (A4)** : une case déclarative « a 15 ans ou plus » est posée par l'adulte qui invite ; **aucun âge ni date de
    naissance n'est stocké**. L'identité d'une fiche est le **prénom plus une initiale**, bornés dans le domaine (longueur maximale,
    initiale seule). C'est de la **minimisation, pas de la pseudonymisation**, et l'ADR l'écrit ainsi. Un **commentaire d'évaluation**
    existe déjà (`MaturityAssessment.comment`) : il est **facultatif, borné à `maxCommentLength`, conservé, et signalé à l'AIPD comme
    texte libre sur un mineur**. Seule la note de jeu (ADR 0023) est sans texte libre.

### A5 — Modèle de données

14. Sous-collections **par club** : `clubId` se lit dans le chemin. `seasonId` est **toujours un champ, jamais un ancêtre** du chemin.
    Les appartenances aux groupes restent **datées** (ADR 0019 décision 5). Le club actif est injecté à la construction du dépôt :
    **les signatures des interfaces ne changent pas** (A10). Les documents de données portent `groupId`, `studentId` et `seasonId`
    **dénormalisés**, car une règle ne filtre pas les champs et ne peut pas parcourir une liste.

| Document | Élève / parent (`student`, `guardian`) | Enseignant (`teacher`) | Directeur (`director`) | Admin | Invité (authentifié, e-mail vérifié, sans `member`) |
|---|---|---|---|---|---|
| `admins/{uid}` | — | — | — | lecture de soi ; **écriture jamais** (console) | — |
| `clubs/{c}` (nom, saison courante) | lecture | lecture | lecture ; modifie le nom | lecture, création, suppression | — |
| `clubs/{c}/settings/main` (réglages, document unique) | lecture (`GetStudentShowcase` lit `RulesConfig` ; aucune donnée nominative) | lecture | lecture, écriture | lecture, écriture | — |
| `clubs/{c}/members/{uid}` (`role`, `groupIds`, `studentIds`, dates) | lecture du sien | lecture du sien | lecture des `members` du club ; écriture limitée aux rôles `teacher`, `student`, `guardian` ; **création ou modification d'un `director` réservée à l'admin** | lecture, écriture | **création de soi seulement**, avec rôle, club, `groupIds` et `studentIds` égaux à ceux de l'invitation, vérifiés par `getAfter` |
| `clubs/{c}/invitations/{code}` | — | `get` ; crée pour ses groupes (élève, parent) | `get` ; crée, révoque | idem, partout | `get` ; **mise à jour unique** (consommée), dans le même lot que la création de son `member` |
| `clubs/{c}/seasons/{s}` | lecture | lecture | lecture, écriture, clôture | idem | — |
| `clubs/{c}/groups/{g}` (`seasonId`, public, `teacherUids`) | lecture des siens | lecture des siens | lecture, écriture | idem | — |
| `clubs/{c}/memberships/{studentId_from}` (appartenance datée) | — | lecture de ses groupes ; **création** avec une fiche neuve de son groupe (même lot, FB4b) | lecture, écriture | idem | — |
| `clubs/{c}/students/{id}` (prénom, initiale, public) | lecture de la fiche liée (`studentIds`) | lecture de ses groupes ; crée | lecture, écriture, effacement | idem | — |
| `clubs/{c}/sessions/{id}` (séance planifiée) | lecture des séances de ses groupes | lecture, écriture de ses groupes | club | idem | — |
| `clubs/{c}/records/{id}` (saisie, assiduité, étiquettes) | **aucune lecture** (expose les camarades présents) | lecture, écriture de ses groupes | club | idem | — |
| `clubs/{c}/attempts/{id}` (un passage) | lecture de ceux de la fiche liée | lecture, écriture de ses groupes | club | idem | — |
| `clubs/{c}/acquisitions/{id}` | lecture de celles de la fiche liée (`studentIds`) ; `GetStudentShowcase` lit `AcquisitionRepository.forStudent` | ses groupes | club | idem | — |
| `clubs/{c}/assessments/{id}`, `acknowledgements/{id}` | — (bilans et alertes exclus par B2) | ses groupes | club | idem | — |
| `clubs/{c}/archives/{season_public}` (archive agrégée) | — | lecture | lecture, écriture à la clôture | idem | — |
| `clubs/{c}/imports/{fileId}_{uid}` (marqueur d'import d'une sauvegarde, FB7, **un par fichier et par auteur**, **sans identifiant d'élève**) | — | lecture, création et avancement de **son** marqueur seulement : l'identifiant porte son `uid` (jamais de suppression) | lecture, création et avancement de **son** marqueur seulement, comme l'enseignant ; liste du dossier | idem | — |

« Ses groupes » = `members/{uid}.groupIds` ; « sa fiche » = `members/{uid}.studentIds`. Les noms exacts des champs et des collections sont
figés par les tests de règles de FB3, pas par ce tableau. Le catalogue, les fiches et les diagrammes restent des **assets**.
15. **Conflits (B5)** : dernier écrit gagne **par document** pour les scalaires (nom, réglages, titre) ; les listes datées
    (`audienceHistory`, appartenances) sont des **documents ajoutés, sans réécriture** ; suppression **physique** par défaut ;
    `deletedAt` seulement s'il a un sens métier ; l'acquittement « Vu » est **partagé par club** et enregistre l'`uid`.
    *Table document → règle, un test par ligne, et limites : notes FB5b.* Les méthodes
    `idsEver*` de l'effacement par lien (ADR 0020) sont à réexpliquer sur les appartenances closes. `backupReminderDays` est retiré en
    FB5 pour les clubs synchronisés. Les **réglages du club** (`RulesConfig`) sont séparés des **préférences d'appareil** (A11).

### A6 — Rattachement parent et élève

16. Rôle **`guardian`** distinct de `student`. Le lien vit dans **`members/{uid}.studentIds`** : un seul `get()` donne rôle et périmètre.
    Un parent dont les enfants sont dans deux clubs a **un `member` par club**. Le parent garde la lecture quand l'élève de 15 ans a son
    compte ; le directeur peut la retirer. Un tableau `linkedUids` sur la fiche n'est ajouté que si un écran en a besoin.
    Un uid = **un rôle par club** : le cumul parent et enseignant dans un même club n'est pas prévu. **À valider : l'animateur, avant FB3**
    (défaut : rôle unique ; le rôle en liste serait un amendement).

### A7 — Identité des données et atomicité (amendements 0006, 0016, 0019)

17. **ADR 0006 amendé** : un **passage est un document** ; `passIndex` est **dérivé** (tri par date, `createdAt` serveur, `recordedAt` de l'appareil, identifiant) au lieu
    d'être stocké et renuméroté. La correction en place d'un passage reste possible ; la suppression ne renumérote plus rien.
    `ExerciseAttempt` et `ExerciseResult.derive` changent ; ce changement précède FB4. **Réalisé en FB4c (2026-10-18)** : voir les notes FB4c.
18. **ADR 0016 amendé** : une saisie liée à une séance du catalogue reçoit un **identifiant déterministe** (groupe, jour, séance du
    catalogue) : deux appareils qui la créent écrivent le même document. Une saisie libre garde un UUID. **Amendée le 2026-10-18
    (décision de l'utilisateur)** : le transfert d'une saisie libre vers une séance du catalogue **reste la confirmation actuelle de
    l'écran** (l'animateur confirme le rattachement) et la saisie **garde son UUID** (elle ne prend pas l'identifiant déterministe).
    **Limite assumée** : si deux appareils ouvrent ensuite la même séance du catalogue, l'un ouvrant le document déterministe et l'autre
    reprenant la saisie transférée, un **doublon** est possible ; il est rare (un transfert, puis une ouverture concurrente d'un autre
    appareil le même jour) et corrigeable à la main (suppression de la saisie en trop).
19. **ADR 0019 amendé** : `UnitOfWork` devient un **`WriteBatch`** pour les petits cas ; la clôture de saison, la purge et l'import sont
    des **lots idempotents reprenables** (500 écritures par lot, marqueur de reprise, reprise après coupure). Les garanties « tout ou
    rien » et « aucune trace nominative » de l'ADR 0019 deviennent : atomicité **par lot**, et **marqueur `erasing` transitoire** sur la
    fiche pendant un effacement en cours, supprimé avec elle ; ni journal ni liste d'identifiants effacés (pas de tombstone).
    Les décisions d'atomicité sont testées dans la suite de contrat.
    **Import réalisé en FB7, partie A (2026-10-20)** : lots de 400 écritures au plus, marqueur d'import par club et par fichier avancé dans le lot lui-même, reprise ; voir les notes FB7a. Clôture et effacement : à venir (FB7, FB8).

### A8 — Outillage

20. Les émulateurs exigent **Node LTS, Java 21 et `firebase-tools`** : `package.json` racine épinglé (avec verrou), `setup-node` et `setup-java`
    dans le job de test, `scripts/rules_test.sh` via `emulators:exec`, contrat Firestore tagué `emulator`, prérequis vérifiés par
    `scripts/setup.sh`. **Échec explicite si un prérequis manque, jamais de skip.** Émulateurs sur ubuntu et macOS si le temps de CI le
    permet, sinon ubuntu seul, documenté comme exception explicite. `fake_cloud_firestore` n'est pas adopté (facultatif plus tard).

### A9, A10, A11, A12 — Premiers pas

21. **Règles sûres dès FB1** : `firestore.rules` est remplacé par `allow read, write: if false` (fait le 2026-10-17 avec cet ADR) et les
    fournisseurs anonyme et Google sont retirés. **À contrôler par l'animateur dans la console** que les fournisseurs et les règles publiés correspondent.
22. **Ports dans `shared`** : `CurrentUser` et `ActiveClubScope` (avec `ClubId` et `Role`) ; entités `account`, `club`, `membership` ;
    features `sign_in`, `select_club`, `manage_club`, `administration`. Les dépôts sont **sans état** et lisent la portée à chaque appel ;
    `KeyedSubtree(clubId)` reconstruit l'interface au changement de club ; la bascule est interdite pendant une séance guidée ou une
    saisie ouverte. Le club actif mémorisé est une préférence locale de l'appareil.
23. **Stockage local résiduel** : `shared_preferences` derrière un petit port clé/valeur, **clé par uid et club**, pour la séance en cours *(Dépendance introduite avec le port et son test, pas avant : retirée de `pubspec.yaml` à la relecture de FB1.)*
    (ADR 0020 amendé : même contenu, même péremption de 7 jours, effacement par lien, à la déconnexion et à la clôture), le club
    actif et les préférences. Aucune écriture Firestore pendant la séance ; pas de reprise sur un autre appareil.
24. **Inscription fermée** : un **code d'invitation obligatoire**, lié à un rôle, un club et (enseignant) ses groupes ou (élève, parent) une
    fiche ; au moins 10 caractères Base32 sans caractères ambigus ; **usage unique, révocable, lecture par `get` seul (jamais `list`)** ;
    expiration **7 jours, 48 h pour un enseignant** ; le lien `/join?code=` n'est qu'un confort web. L'usage unique passe par un lot
    côté client contrôlé par `getAfter` dans la règle. Le directeur est invité par l'administrateur. L'e-mail doit être **vérifié**
    (`email_verified`) et le mot de passe compte **au moins 10 caractères**. L'application n'envoie aucun e-mail ; Firebase Auth envoie
    seul les e-mails de vérification et de réinitialisation.

### Vague B

25. **Règles (B1)** : dénormalisation (`groupId`, `studentId`, `seasonId`), **un `get()` sur `members`**, rôle de club évalué avant l'admin ;
    un à deux comptes admin, `write: false` sur `admins`. Si l'accès ne se prouve pas en 10 `get()`, `teacherGroupIds` est ajouté
    à la fiche. Un budget de lectures par écran est documenté en FB3. Le directeur et l'admin lisent les prénoms de mineurs :
    à déclarer au registre.
26. **Vue parent et élève (B2)** : `StudentShowcase` et les prochaines séances de ses groupes ; **pas de lecture de `records`** ; assiduité
    réservée aux animateurs ; garde de route par lien `uid` pour `/students/:id/show` ; « Montrer à l'élève » reste pour les rôles
    animateurs. Assiduité à rouvrir avec la fédération après retours.
27. **Conservation hors élèves (B3)** : compte parent effacé à la fin de la saison suivant celle de son dernier enfant lié ; enseignant et
    directeur effacés 12 mois après leur dernier rattachement ; invitations expirées purgées à la clôture. **À valider : l'animateur**
    (cela étend la décision 8) puis la fédération ou le DPO au registre.
28. **Migration des dépôts (B4)** : les `Future` sont conservés, des **`watch…` ciblés** s'ajoutent et les dépôts in-memory les
    implémentent aussi ; environnement par `--dart-define=FIREBASE_EMULATOR`, valeur sûre par défaut (debug sur émulateur, **release refuse
    l'émulateur**), sans flavors natifs ; ~~bascule de production à la fin de FB4~~ **amendé le 2026-10-18 (décision de l'utilisateur) : la bascule de production n'a PAS lieu dans FB4 ; drift reste le backend par défaut jusqu'à ce que FB7 (migration) soit livré, la bascule est un lot dédié après FB7** ; ordre : réglages, élèves / groupes / saisons, séances /
    saisies / passages, puis acquisitions, acquittements, bilans, archives.
29. **Déploiement des règles (B6)** : tests de matrice complète (rôle × action) et de refus par défaut **obligatoires** ; déploiement par la
    CI protégé par ces tests, avec protection de branche, **après FB3** (compte de service élargi) ; manuel d'ici là.
30. **SDK web (B7)** : chargé depuis `gstatic.com` en FB1 (non bloquant au démarrage), **servi localement, épinglé et précaché avant FB5**
    si le plugin l'accepte. **Levé en FB5a (2026-10-19)** : le plugin l'accepte, sans fork, par une **carte d'import** (notes FB5a) ;
    `--wasm` toujours non adopté, sans COOP ni COEP (ADR 0022).
31. **Démarrage (B8)** : `AuthCubit` (`unknown`, `signedOut`, `noClub`, `ready`, `indisponible`) avec redirection `go_router` et écran de
    démarrage localisé ; initialisation Firebase attendue par `AuthCubit` ; `AuthFailureCode` distinct d'`InvariantCode`, messages
    génériques (anti-énumération) ; démarrage hors ligne seulement avec une session persistée.
32. **Plateformes et dépendances (B9)** : suppression de `app/linux`, retrait de `macos` et `windows` de `firebase_options`, `Taskfile`
    `DEVICE=chrome` ; `firebase_auth` et `cloud_firestore` entrent dans la pile imposée ; **job CI `flutter build apk --debug`**.

## Alternatives écartées

- **Deux projets Firebase dès maintenant** : deux bases et deux configurations pour zéro donnée réelle ; repoussé à l'arrivée des vrais élèves.
- **`eur3`** (déclaré dans l'ancien `firebase.json`) et **conserver une base `eur3` déjà existante** (option 3 du relevé) : contredisaient la roadmap ;
  écartés par la décision de l'animateur du 2026-10-17 (base créée en `europe-west9`).
- **Modèle simplifié `{saison, public, studentIds[], teacherUids[]}`** : perd les dates d'effet, réécrit `MoveStudent`, contredit l'ADR 0019. Liste
  d'appartenances embarquée dans le groupe : conflits d'édition, transactions impossibles hors ligne.
- **Parent par `linkedUids` sur la fiche** ou **sous-collection de liens** : un `get()` ou `exists()` de plus par accès.
- **Domaine inchangé** (`passIndex` stocké, UUID partout, transactions en ligne) : doublons réels entre appareils, aucune correction hors ligne.
  **Suppression de `UnitOfWork`** : réécriture lourde et perte de l'atomicité par lot.
- **Journal technique pseudonymisé de l'effacement** : contredit l'ADR 0019 (un identifiant conservé relie un fichier à une personne).
- **`get_it` par club ou `clubId` en paramètre de chaque méthode** : contourne `injectable`, ou change 11 interfaces et tous les cas d'usage.
- **`RunProgress` dans Firestore** : écritures fréquentes sur Spark, reprise multi-appareils non demandée. **Mémoire seule** : régression du lot 10b.
- **Inscription libre** (avec rattachement ultérieur ou pour fonder un club) : comptes orphelins, robots, contredit la matrice des droits.
- **Passage à Blaze** (TTL, fonction planifiée, claims) : contredit la décision 3.
- **Fiche complète en lecture seule pour le parent** : expose alertes et bilans, contredit Q6 et l'ADR 0014.
- **Mode démo intégré en mémoire** : rouvrirait la décision 1 (voir C6).

## Conséquences

- **Positives** : multi-appareils, multi-clubs, rôles ; l'effacement d'un élève et la clôture restent exprimables sur Firestore ; les
  signatures des interfaces de domaine ne changent pas.
- **Coûts** : première dépendance Node et Java dans la chaîne ; `--full` passera de quelques dizaines de secondes à plusieurs minutes
  (`pre-push` concerné) ; `ExerciseAttempt`, `ExerciseResult.derive` et l'identité de la saisie à modifier ; régime d'identité double
  (déterministe et UUID) ; plus de lectures (dénormalisation à maintenir par les lots d'écriture).
- **Garde-fous ajoutés** : tests de règles contre l'émulateur (matrice et refus par défaut) dans `scripts/check.sh --full` et en CI ;
  suite de contrat Firestore ; échec explicite sans prérequis ; release qui refuse l'émulateur ; **garde-fou de mise en production (décision 12)**.
- **Reste, selon les lots** (défauts retenus le 2026-10-17, tous `[Prop]` jusqu'à validation) :
  - **C1 (FB8)** purge de fin de saison et effacement RGPD **sans Functions** : purge par le client en lots reprenables avec `expireOn` par document,
    bandeau puis blocage de saisie à l'échéance, **administrateur pouvant forcer la purge** d'un club défaillant ; le parent demande l'effacement
    par un document **sans nom d'enfant**, traité par le directeur ; effacement du compte Auth par l'utilisateur après réauthentification ;
    `clearPersistence` à la déconnexion ; un directeur désigne un successeur avant de supprimer son compte. La durée de conservation est
    **organisationnelle, non automatique**, et l'information des familles le dit.
  - **C2 (FB7)** import d'une sauvegarde **v5** (formats 1 à 5) par le directeur, l'administrateur et l'enseignant sur ses groupes seulement,
    idempotent par UUID, lots de 400 avec reprise, fenêtre de migration d'environ un mois, avertissement sur la résurrection d'élèves
    effacés ; l'export reste la portabilité.
    **Moteur livré en FB7a (2026-10-20)**, écran et parcours en FB7 partie B ; les écarts (budget de 20 lectures de règles par lot, aucun import des réglages) sont dans les notes FB7a.
  - **C3 (FB8)** App Check en surveillance puis strict ; fournisseur web à lister au registre (reCAPTCHA ajoute Google comme destinataire de
    l'IP) ; MFA pour directeur et admin à étudier.
  - **C4 (FB5)** persistance hors ligne activée partout, cache vidé à la déconnexion, avertissement appareil partagé, pastille discrète
    « À jour / Envoi en attente (n) / Hors ligne ». **Libellés fr/en à valider : l'animateur.** *FB5a (2026-10-19) : persistance, cache vidé,
    avertissement et pastille livrés (notes FB5a) ; `watch…` et cubits abonnés livrés en FB5b (notes FB5b).*
  - **C5 (FB1)** Android signé pour FB8 ; iOS préparé sans distribution (PWA en repli) ; le web suffit de FB1 à FB7.
  - **C6 (FB3)** écran Administration minimal (clubs, directeurs, codes d'invitation de directeur), admins créés en console ; club « Démo »
    ordinaire avec compte de démonstration (mot de passe partagé, à faire tourner) ; textes rédigés par l'agent, **marqués « à valider »**.
  - **C7 (FB4)** tests de règles automatiques et BDD en mémoire ; un seul scénario multi-appareil manuel, documenté (`task e2e:firebase`),
    non bloquant en CI.

## Vérifications à la source (FB0, 2026-10-17)

- **Quotas Spark de Firestore** : confirmés sur <https://firebase.google.com/pricing> (lu le 2026-10-17) : 1 GiB stocké, 10 GiB/mois de sortie,
  20 000 écritures, 50 000 lectures et 20 000 suppressions par jour ; Cloud Functions non disponibles sur Spark ; Auth 50 000 MAU.
- **Âge de 15 ans** : confirmé sur le site de la CNIL (recommandation sur le consentement d'un parent pour les mineurs de moins de 15 ans),
  qui cite l'article 45 de la loi Informatique et Libertés ; le consentement d'un seul titulaire de l'autorité parentale suffit.
  Dans cette application, la case « a 15 ans ou plus » n'est qu'une déclaration de l'adulte (décision 13).
- **Non vérifiés, restent « à valider »** : quota gratuit propre à `europe-west9` (**à relever par l'animateur dans la console, la base étant créée**) ;
  TTL Firestore sur Spark (inutile tant que la purge est client, à revérifier en FB8) ; conservation de 180 jours des sauvegardes d'Auth et
  traitement d'Auth aux États-Unis (source : `research/firebase.md`, à confirmer pour l'AIPD par la fédération ou le DPO).

## Limites assumées

- La purge n'est **pas automatique** : elle dépend d'un humain (directeur, ou administrateur qui la force). Les fichiers JSON déjà exportés
  et les caches d'appareils hors ligne échappent à l'effacement.
- Un appareil retardataire peut ressusciter une fiche effacée ; atténué par un `exists()` sur la fiche dans les règles.
- Firebase Auth traite l'adresse e-mail et l'IP aux États-Unis quelle que soit la région de Firestore (DPF et clauses contractuelles types).
- Les admins et le directeur lisent les prénoms de mineurs ; sans Functions, aucun contrôle plus fin que les règles.
- Pas de limitation de débit sans Functions : la résistance à l'énumération des codes repose sur leur longueur et sur App Check.
- La dénormalisation peut diverger hors ligne (par exemple `groupIds` d'un parent après un déplacement d'élève) ; rattrapée à la reconnexion.
- Le commentaire d'évaluation (`MaturityAssessment.comment`) est un texte libre sur un mineur : borné et facultatif, mais non filtré ; risque porté à l'AIPD.
- Les textes juridiques et l'AIPD ne sont **pas** produits par cet ADR : seuls des projets le sont, **à valider par la fédération ou un DPO**.

## Notes de réalisation du lot FB2 (2026-10-17, aucune décision nouvelle)

Détail : [../auth-plan.md](../auth-plan.md). Précisions des décisions 22, 23, 24 et 31 constatées à la réalisation :

- **`AuthCubit` vit dans la couche `app`** (décision 31) : il compose `entities/account`, `entities/membership` et
  `features/select_club`, qui ne peuvent pas s'importer. Il n'attend pas `FirebaseStartup` directement mais le port `SessionStartup`
  (`FirebaseStartup` l'implémente, un double en mémoire sert aux tests ; `FirebaseStartup` n'est toujours pas câblé en test).
  `FirebaseStartup.retry()` relance une initialisation échouée (« Réessayer »). L'état `indisponible` couvre aussi des clubs
  illisibles **sans club retenu** sur l'appareil ; avec un club retenu, l'application s'ouvre hors ligne (session persistée du SDK
  et club retenu).
- **Club actif mémorisé** (décisions 22 et 23) : `shared_preferences` (API asynchrone) derrière `KeyValueStore`, clé
  `active_club.<uid>`, valeur = club, nom et rôle (pour rouvrir hors ligne) ; effacé à la déconnexion et quand le compte n'a plus de
  club ; le rôle courant du serveur l'emporte sur le rôle retenu. La séance en cours reste en drift jusqu'à FB4 (le passage à
  `shared_preferences` de l'ADR 0020 n'est pas fait dans ce lot).
- **Bascule interdite** : `ClubSwitchGuard` est implémenté par `RunningSessionsClubSwitchGuard` (séance guidée commencée,
  saisie ouverte depuis le guide comprise). Une saisie ouverte seule est un écran de route déjà enregistré à chaque passage : la
  bascule se fait depuis « Plus » et ne perd rien.
- **Inscription par code** (décision 24) : l'`get` d'une invitation exige un compte authentifié (matrice du modèle de données) ;
  le code ne peut donc pas être vérifié avant la création du compte. L'inscription crée **le compte seulement** (forme du code,
  mot de passe d'au moins 10 caractères, courriel de vérification envoyé par Firebase Auth), garde le code sur l'appareil sous le
  compte (`PendingInvitations`, point d'extension) et ferme la session ; **FB3** lit ce code après la première connexion vérifiée
  et le consomme dans le lot d'écritures contrôlé par `getAfter`. **Le serveur n'impose que 6 caractères** (mesuré à l'émulateur
  Auth) : les 10 caractères sont une règle de l'application seule, contournable par un client modifié ; la défense d'un compte sans
  `member` reste les règles Firestore (refus par défaut, aucune lecture sans `member`).
- **Anti-énumération** (décision 31) : l'émulateur et un projet sans protection distinguent `wrong-password` et `user-not-found` ;
  le regroupement en un seul message est fait par `FirebaseAuthRepository`. **À activer dans la console** : la protection contre
  l'énumération d'adresses e-mail du projet (le code attend alors `invalid-credential`, déjà traité).
- **Avant FB3**, la production lie `MembershipsSource` à `NoMembershipsSource` : aucun club n'existe côté serveur (règles : refus
  total), donc tout compte connecté arrive en « Aucun club » ; FB3 remplace cette classe par la lecture des documents `members`.

## Notes de réalisation du lot FB3 (2026-10-17, aucune décision nouvelle)

Détail : [../clubs-roles-plan.md](../clubs-roles-plan.md). Précisions et **écarts** constatés à la réalisation (le tableau « document × rôle × règle » de la décision 14
reste la référence des droits ; les noms de champs sont figés par `scripts/rules_test/`, comme il le dit) :

- **Écart : `invitations/{code}` à la racine**, pas sous `clubs/{c}/invitations/{code}`. L'invité ne connaît que le code, jamais le club : sous un chemin de club il ne
  pourrait pas le lire avant d'en être membre. Le document porte `clubId`. Conséquences : « get seul, jamais list » devient un fait de structure (rien à énumérer) ;
  la création vérifie que le club existe (administrateur) ou que le créateur y a le bon rôle (`get` du member de `clubId`).
- **Écart : le champ `uid` du `member`** (égal à l'identifiant du document) : la requête de groupe de collections `members` filtrée sur `uid` est la seule requête qu'un compte
  **sans club** peut faire pour découvrir ses clubs ; la règle `{path=**}/members/{m}` autorise la lecture du **seul** document dont `uid` est celui du compte. Elle exige
  une exemption d'index « groupe de collections » (`firestore.indexes.json`, à déployer avec les règles).
- **Écart : `groupIds` sur la fiche élève** (groupes courants, copie dénormalisée). Une règle ne parcourt pas une liste : lire une fiche, ou la lister par `array-contains`
  sur un groupe, exige ce champ (mesuré : `resource.data.groupIds.hasAny(me(c).groupIds)` est accepté en `get` **et** en requête, la forme inverse non). Un enseignant
  qui invite pour une fiche prouve qu'elle est dans un de ses groupes par le même champ (jusqu'à quatre fiches, `get` de chacune).
- **Précisions du `member`** : `displayName` (1 à 40 caractères) saisi par l'invité ; `invitationCode` (le code utilisé, qui lie le `member` à l'invitation consommée dans
  le lot) ; `createdAt` (date du serveur). Le directeur écrit les `members` de rôle `teacher`, `student`, `guardian` (jamais `director`) ; l'administrateur tous ; le titulaire ne
  change que son nom affiché.
- **Usage unique** : le lot crée le `member` et met l'invitation à « utilisée » ; chaque écriture **seule** est refusée (`getAfter` côté member, `existsAfter` côté
  invitation) ; les conditions vérifiées des deux côtés (club, rôle, état, expiration, e-mail vérifié) sont **volontairement redondantes** (défense en profondeur) : un
  mutant qui n'en retire qu'un côté survit, **les doubles mutants** (retrait des deux) sont tués (testing.md).
- **Durées** : 48 heures pour un enseignant **et un directeur** (rôles plus puissants ; la décision 24 ne chiffrait que l'enseignant : le directeur suit, `[Prop]`), 7 jours
  pour un élève ou un parent ; une heure de tolérance sur l'horloge du client dans la règle.
- **Journal local des invitations** : puisque `list` est interdit, l'appareil de l'inviteur se souvient des codes créés (`KeyValueStore`, par compte et par club, effacé à la déconnexion). Une
  invitation créée sur un autre appareil ne s'y voit pas.
- **Fiche publiée avant l'invitation** : tant que les dépôts de données sont locaux (FB4), la première invitation d'un élève ou d'un parent publie sa fiche minimale
  (prénom tronqué à 40 caractères, public, groupes courants) sous l'identifiant local (`StudentDirectory`) ; une fiche déjà publiée n'est jamais réécrite. FB4 écrit le même document.
- **Le directeur d'un club créé par l'administrateur** est invité par un code de 48 heures ; l'administrateur voit **tous** les clubs (`MembershipsSource`), avec le rôle `admin`
  dans ceux où il n'a pas de `member` ; son document `admins/{uid}` reste **vide** (créé en console).
- **Budget de `get()`** : 10 documents distincts par évaluation, un même document n'en compte qu'un (mesuré à l'émulateur, `budget.test.mjs`). Les opérations les plus coûteuses
  en consomment 6 : `teacherGroupIds` (décision 25) n'est pas nécessaire. Tableau par écran dans le plan.
- **Limites** : l'adaptateur `FirestoreDocumentStore` n'est pas exercé contre l'émulateur par du code Dart (plugin natif) ; ses opérations le sont avec le SDK web (jetons réels
  de l'émulateur Auth) ; la fumée du build web n'exerce pas Firestore. Le SDK web de Firestore appelle `https://www.google.com/images/cleardot.gif` (sonde de connectivité) :
  consigné au registre des traitements.
- **Corrections de relecture FB3 (2026-10-18)** : (1) **un enseignant ne crée une donnée d'élève** (`attempts`, `acquisitions`, `assessments`, `acknowledgements`) **que si l'élève
  est de SON groupe** : `get()` de la fiche et `groupIds.hasAny([groupId])` remplacent `exists()` (même budget d'accès) ; le directeur et l'administrateur gardent « la fiche
  existe » (import d'un historique, FB7). (2) **Liste blanche de champs par collection** (`keys().hasOnly`) et bornes de chaque valeur (texte, entier, date courte, codes
  d'étiquettes prédéfinis) : plus de champ libre ni de stockage libre jusqu'à 1 MiB par document (décision `[U]` « étiquettes sans texte libre » tenue, commentaire d'évaluation
  seul texte libre). Noms de champs figés par `scripts/rules_test/bounds.test.mjs`. Les archives deviennent un document de synthèse (`season_public`) **et un document par
  exercice** (compteurs seulement) : une règle ne valide pas les éléments d'une liste de tables. (3) **Limite mesurée** : une règle ne boucle pas et le budget est de 1000
  expressions par requête ; les listes d'identifiants (`groupIds`, `studentIds`, `presentStudentIds`) sont bornées en nombre **et en taille totale** (`join`), pas élément par
  élément ; seule `groups.teacherUids` (écrite par le seul directeur) vérifie que **chaque** élément est un texte (30 éléments déroulés). (4) **Projet de l'émulateur** : l'application
  vise `demo-cfa-ffb` (`FirebaseEnvironment.emulatorProjectId`) quand elle vise l'émulateur ; avec le projet réel, elle lisait une base vide.
- **Choix assumés des règles (relecture FB3, 2026-10-18, constatés dans `firestore.rules`)** : (a) le **directeur et l'administrateur** peuvent créer une donnée d'élève
  (`attempts`, `acquisitions`, `assessments`, `acknowledgements`) pour **n'importe quelle fiche existante du club**, y compris hors des groupes écrits (import d'un historique,
  FB7) ; seul l'enseignant est borné à ses groupes. (b) Les **archives de saison** (`archives/{id}`) sont **lisibles par tous les enseignants du club** (pas par groupe : un
  document de synthèse n'a pas d'élève nommé), écrites et supprimées par le seul directeur ou l'administrateur ; élèves et parents n'y ont pas accès. (c) Le **directeur crée
  un `member` sans invitation** (rôles `teacher`, `student`, `guardian`, jamais `director` ; `uid` égal à l'identifiant du document, `createdAt` du serveur) ; l'administrateur
  crée n'importe quel rôle. L'invitation reste la seule voie pour un compte **qui s'ajoute lui-même** (usage unique, e-mail vérifié).

## Notes de réalisation du lot FB4a (2026-10-18, aucune décision nouvelle)

Première partie de FB4 (détail : [repositories-firestore-plan.md](../repositories-firestore-plan.md)). Écarts et précisions :

- **Erreurs d'ouverture de session** : `MembershipsDenied` (règle, `permission-denied`, ou index manquant, `failed-precondition`) est distinct de
  `MembershipsUnavailable` (réseau). Le premier mène à l'état `AuthAccessDenied` (« Accès refusé à vos clubs », déconnexion seule, **pas** de
  « Réessayer », **pas** de repli sur le club retenu sur l'appareil) ; le second garde « Service injoignable » avec « Réessayer ». Le journal reçoit le seul
  code technique (jamais d'e-mail ni d'uid). `StoreFailureCode.failedPrecondition` est nouveau.
- **Identifiant d'une appartenance (écart à la décision 14)** : `groupId_studentId_from` et non `studentId_from`. Les appartenances de tous les groupes
  partagent la collection `clubs/{c}/memberships` ; un élève qui débute le même jour dans deux groupes écrasait l'autre appartenance (trouvé par la suite
  de contrat). `from` est écrit en ISO 8601 (fuseau et microsecondes conservés).
- **Historique du public (écart à la décision 15, « documents ajoutés »)** : `audienceHistory` est une **liste embarquée** dans la fiche (10 changements au plus,
  chacun `{audience, effectiveFrom}` contrôlé élément par élément), pas une sous-collection : une collection de plus aurait demandé règles, matrice et tableau
  pour une donnée que seul un gestionnaire change. Dernier écrit gagne par document. Règle `audienceHistoryOk` ajoutée à `studentShape` avec ses tests et ses
  mutations (testing.md). Les autres champs de la fiche sont ceux de FB3 ; `initial` reste facultatif et **inutilisé** (le domaine n'a pas d'initiale).
- **Même document que `StudentDirectory`** : `FirestoreStudentRepository.save` met à jour la fiche publiée (prénom, public, historique) sans toucher `groupIds` ni
  `createdAt`, et la crée sans groupe courant. `groupIds` (dénormalisé, lu par les règles) est tenu par `FirestoreGroupRepository.save` / `delete` : il ajoute ou
  retire le groupe sur les fiches concernées, dans le même lot ; une fiche absente est ignorée. Le retrait et l'ajout sont **atomiques côté serveur** (`ArrayUnion` /
  `ArrayRemove` du port `DocumentStore`, sans relire ni réécrire la liste) : deux gestionnaires qui enregistrent deux groupes d'un même élève s'additionnent. La fiche est
  écrite par fusion (`SetOp(merge: true)`, `groupIds: ArrayUnion([])`) : même si la lecture ne voit pas une fiche existante, `groupIds` n'est jamais remplacé ; seule `createdAt`
  (informative) peut être réécrite dans ce cas. Le domaine refuse plus de 10 changements de public et un prénom de plus de 40 caractères (mêmes bornes que les règles).
- **`teacherUids`** appartient au directeur : le dépôt de groupes ne l'écrit qu'à la création (vide, les règles l'exigent) et met à jour les autres champs sans le remplacer.
- **Rôle et requêtes** : les règles n'autorisent pas la même requête à chaque rôle ; `all()` s'adapte (directeur et administrateur : liste ; enseignant :
  `array-contains-any` sur `groupIds`, 30 valeurs par requête ; parent et élève : lecture des fiches et groupes liés un à un, sans appartenances). `idsEverContaining`
  et `eraseStudent` (requête par élève) sont réservés aux gestionnaires par les règles.
- **Ordre des listes** : élèves triés par inscription puis identifiant, groupes par identifiant, appartenances par (groupe, élève, début) : l'ordre de première sauvegarde
  de la mémoire n'existe pas côté serveur.
- **Club résolu à l'appel** (et non à la construction, décision 14 : « injecté à la construction ») : `ClubStore` relit `ActiveClubScope` avant chaque lecture ou écriture ;
  un dépôt unique survit à un changement de club et sans club actif l'accès est refusé (`ServiceFailure` `denied`). Les signatures des interfaces sont inchangées.
- **Suppression physique** (décision 15) de la fiche et du groupe ; la cascade des données de l'élève est FB8. Lots de 500 écritures au plus, idempotents ; l'atomicité
  « tout ou rien » d'un `save` de groupe n'est garantie que sous 500 écritures.
- **Réglages** : `clubs/{c}/settings/main` porte les cinq champs de `ClubSettings` (`backupReminderDays` reste facultatif jusqu'à FB5) ; les préférences d'appareil restent
  dans le `KeyValueStore` local.
- **Backend** : `--dart-define=DATA_BACKEND=firestore` (défaut `drift`, valeur inconnue = erreur). La bascule de production **n'a pas lieu en FB4** : lot dédié après FB7 (notes FB4c).
- **Constat pour la partie 3** : `RulesStore` est chargé au démarrage depuis `SettingsRepository` ; avec Firestore, la lecture a lieu avant l'ouverture de session
  (club absent, accès refusé) : il devra être rechargé à l'activation d'un club.

## Notes de réalisation du lot FB4b (2026-10-18, dont deux décisions de l'utilisateur : décision 18 amendée, groupe obligatoire)

Deuxième partie de FB4 (détail : [repositories-firestore-plan.md](../repositories-firestore-plan.md)). Écarts et précisions (les deux décisions de l'utilisateur du 2026-10-18 sont celles marquées « tranché » ou « décision de l'utilisateur » : l'identité d'une saisie, décision 18 amendée, et le groupe obligatoire d'une séance planifiée, amendement de l'[ADR 0007](0007-lien-seance-planifiee-saisie-catalogue.md)) :

- **`UnitOfWork` (décision 19)** : `FirestoreUnitOfWork` retient les écritures des dépôts Firestore faites pendant `run` (zone) et les envoie en **un seul `WriteBatch`** (500 au plus ;
  `StoreFailure(batchTooLarge)` explicite avant toute écriture, aussi dans le stock en mémoire). Écritures d'un même document fusionnées ; lecture de ses propres écritures pour `get` seulement. **Écart corrigé dans le texte** : `CloseSeason` appelle encore `UnitOfWork.run` ; avec `DATA_BACKEND=firestore`, au-delà de 500 écritures (club réel : appartenances, fiches, groupes reconduits) elle échoue
  explicitement (`batchTooLarge`, aucune écriture, testé), et les listes n'y voient pas les écritures en attente. **`ImportBackup` n'est PAS supporté avec `DATA_BACKEND=firestore` avant FB7** : il écrit les
  saisies par `SessionRecordRepository.save`, qui crée le document par une transaction (`createIfAbsent`), impossible dans le lot d'une unité de travail ; l'import (dès qu'il contient une saisie, c'est-à-dire
  toute sauvegarde d'un club réel) échoue donc par un `ServiceFailure` `unsupported`, message localisé fr/en (« l'importation d'une sauvegarde viendra plus tard »), **sans rien écrire** (lot annulé, drift
  annulé), et jamais par une exception hors `Failure`. Prouvé par `backupImportUnsupportedContract` (`firestore_contract_test.dart`, dépôts Firestore + drift + `CompositeUnitOfWork`). Les lots reprenables avec
  marqueur de la décision 19 (FB7, FB8) remplaceront la clôture et l'import : **bloquant de bascule**, inscrit pour la partie 3.
- **Hors ligne (décision 1, C4)** : le SDK n'acquitte `batch.commit()` qu'à la réponse du serveur ; hors ligne, l'attendre dans la transaction drift de `CompositeUnitOfWork` la laisserait ouverte et
  bloquerait les écritures drift. **Stratégie retenue** (à réaliser avant la bascule, bloquant) : valider le lot localement (le SDK l'applique au cache dès l'appel), ne pas attendre l'accusé du serveur
  dans une transaction locale, et suivre l'envoi à part pour la pastille « Envoi en attente » (C4). Tant que `CompositeUnitOfWork` existe (drift partiel), le réglage Firestore reste réservé au
  développement et aux tests. Les opérations longues seront des lots reprenables de FB7 et FB8. Tant que des dépôts restent sur drift, `CompositeUnitOfWork` enveloppe le lot dans la
  transaction drift (le lot Firestore part avant la validation de drift ; si une panne de l'appareil survient entre les deux, l'écart est assumé).
- **Création d'un élève par un enseignant (tableau A5, ligne `students` « crée » ; ligne `memberships`)** : l'enseignant écrit fiche (avec un de **ses** groupes) et appartenance dans le **même lot**.
  Règle des fiches inchangée ; règle des appartenances : création par un enseignant **seulement** si la fiche n'existe pas avant le lot et si la fiche du lot porte ce groupe
  (`!exists` + `getAfter`) ; mise à jour et suppression au gestionnaire. Le tableau A5 (« `memberships` : écriture directeur, admin ») est précisé en ce sens. Les documents inchangés (saison, groupe)
  ne sont pas réécrits, l'enseignant n'ayant pas le droit de les écrire.
- **Identifiant d'une saisie (décision 18, amendée)** : `groupe_AAAAMMJJ_séance` (domaine, `sittingId`), pour les saisies liées à une séance du catalogue ; UUID pour les saisies libres. Le transfert d'une
  saisie libre vers une séance du catalogue (`OpenOrResumeSession`) reste la confirmation actuelle de l'écran et **la saisie garde son UUID** ; un doublon entre deux appareils est possible mais rare et assumé
  (décision 18 amendée). Plus d'écart « à décider ». **Bornes** : l'identifiant d'une saisie est cité par les passages (`sessionId`, borné à 64 par les règles) : `sittingId` lève `sessionReferenceTooLong`
  (fr/en) au-delà de `maxSessionReferenceLength` (64), comparée à `firestore.rules` par `rule_bounds_test`.
- **Ouverture concurrente d'une saisie (relecture FB4b)** : `createdAt` est posé par la **création** seulement (règle : exigé à la création et égal à `request.time`, **interdit dans le diff d'une
  mise à jour**) ; la création est une transaction `createIfAbsent` (un lot ne sait pas « créer »), puis, si le document existe, `open` réunit les présents par **`ArrayUnion`** seul.
  Deux appareils qui ouvrent la même saisie réussissent donc tous deux, sans qu'aucun réécrive la date. Si la réunion dépasse 60 présents (40 + 30), les règles refusent sans dire pourquoi : le dépôt relit la
  saisie et lève `InvariantViolation(tooManyPresent)` (message avec le maximum). **`resume`** (l'animateur revient sur sa saisie) **remplace** les présents, comme avant FB4b, en drift comme en Firestore : décocher
  un élève coché par erreur reste possible ; l'union est réservée à l'ouverture concurrente (création absente des deux côtés). Cas limite assumé : un appareil dont la liste locale est périmée appelle `open`
  (et non `resume`) pour une saisie qui existe déjà et en réunit les présents au lieu de les remplacer. **Lecture d'un document absent** (`records`, `sessions` ; sans elle `resource.data` fait échouer la lecture
  avant création) : réservée à un gestionnaire, ou à un enseignant pour un identifiant **aléatoire** (sans `_` : rien à deviner) ou dont le groupe (avant le premier `_`) est l'un des siens ; sans cela
  l'identifiant déterministe `groupe_AAAAMMJJ_séance` serait un oracle d'existence (« g1 a-t-il tenu une séance ce jour-là ? ») ; fonction `mayProbeAbsent`, test d'attaque et mutations dans `testing.md`. Le faux Firestore n'isole pas ses transactions : l'isolation est
  prouvée contre l'émulateur (`planning.test.mjs`). Hors ligne, une transaction échoue : à traiter avec la stratégie hors ligne de la partie 3.
- **Appartenance créée par un enseignant (resserrage)** : liée à son contenu : identifiant `groupId_studentId_from`, `from` = début de l'historique de la fiche neuve (une seule période par fiche et par
  groupe), période ouverte, `seasonId` = celui du groupe (`get`). Limite assumée : un enseignant du groupe peut recréer une fiche sous le même identifiant après sa suppression par le directeur (les
  données gardées sous cet identifiant restent) ; non corrigé, faute de preuve simple.
- **Collections** : `records` (pas `session_records`), `archives` (`{saison}_{public}` et `{saison}_{public}_{bloc}_{n}`, un document d'exercice se reconnaît à `blockId`). Les saisies portent `presentStudentIds`
  (60 au plus) et leurs étiquettes en codes de la liste fermée ; **parent et élève ne lisent aucune saisie** (les listes de leurs dépôts sont vides, aucune requête refusée).
- **Séance planifiée : groupe obligatoire (décision de l'utilisateur, 2026-10-18)** : l'invariant est dans le **domaine** (`PlanSession` lève `sessionNeedsGroup`, localisé fr/en) ; l'écran de
  planification exige un groupe (plus d'option « aucun groupe », ni de choix du public : c'est celui du groupe ; sans groupe dans le club, consigne de le créer). Le dépôt Firestore ne porte
  plus de règle métier : il garde une garde défensive (`StoreFailure`, jamais affichée). Les séances **sans groupe déjà présentes dans drift restent lisibles** (aucune exception à la lecture) :
  **reprise à faire au FB7** (migration : les rattacher à un groupe, ou les écarter, avant leur transfert vers Firestore).
- **Saison courante** : reste dans le document du club, écrite par l'administrateur (FB3) ; `SeasonRepository` ne la touche pas.
- **Suppression physique** (décision 15) des saisons, séances planifiées, saisies et archives : `idsEverPresent` et `idsOfGroups` ne rendent que ce qui existe.
- **Bornes** : libellé de saison 80 (constructeur), nom de groupe 80 et 60 présents (vérifiés à la saisie, pas à la construction : les données déjà enregistrées restent lisibles), titre de séance 120 : `InvariantViolation` fr/en, `rule_bounds_test` les compare aux règles. Aucun index nouveau.
- **Test** : `fake_cloud_firestore` n'est **pas atomique** pour un lot dont une écriture échoue (les précédentes restent) ; l'atomicité du vrai lot est prouvée contre l'émulateur.

## Notes de réalisation du lot FB4c (2026-10-18, dont une décision de l'utilisateur : la bascule de production est reportée après FB7)

Troisième et dernière partie de FB4 (détail : [repositories-firestore-plan.md](../repositories-firestore-plan.md)). **Décision de l'utilisateur (2026-10-18)** : la **bascule de production n'a PAS lieu dans FB4** ; `DATA_BACKEND` reste `drift` par défaut jusqu'à ce que **FB7** soit livré ; un **lot dédié, après FB7**, bascule le défaut (amende la décision 28 : « bascule de production à la fin de FB4 »). Aucune base de production touchée : tout est joué sous faux Firestore et émulateurs. Écarts et précisions :

- **Décision 17 réalisée, ADR 0006 amendé** : `ExerciseAttempt` n'a plus de `passIndex`. Le **rang** d'un passage (« passage 2 de la séance ») est **dérivé** : `passRanks` compte les passages d'une même séance, élève et exercice dans l'ordre reçu ; `chronological` trie par date en gardant l'ordre reçu à égalité (tri stable) ; `ExerciseResult.derive` s'appuie dessus et expose `lastAttemptRank` (qui remplace `passIndex` dans `compareLastAttempt`). Les dépôts rendent l'**ordre d'enregistrement** : Firestore `createdAt` du serveur, puis `recordedAt` de l'appareil, puis identifiant (un passage dont la date n'est pas encore acquittée est le dernier) ; drift et mémoire l'insertion (`seq`). **La suppression ne renumérote plus** (`DeleteAttempt` ne réécrit rien et n'a plus d'`UnitOfWork`) ; `RecordAttempt` n'attribue plus d'index (la borne `maxPassesPerExercisePerSession` reste un **compte** ; deux appareils simultanés peuvent la dépasser d'un passage, comme deux saisies concurrentes : assumé). Les courbes, alertes et validations restent identiques à l'observable (scénarios BDD existants verts, deux scénarios ajoutés). **Schéma drift v12** : la colonne `pass_index` disparaît (table recréée, lignes et `seq` conservés ; test de migration) ; l'invariant `invalidPassIndex` est retiré. **Sauvegarde** : le format reste **v5**, lu de v1 à v5 ; l'encodeur écrit encore `passIndex` (rang dérivé) pour qu'une version qui le lit encore reste compatible, le décodeur l'**ignore** (l'ordre du fichier est l'ordre d'enregistrement) ; `BackupRules` vérifie le nombre de passages par séance, élève et exercice au lieu de l'unicité des index ; test d'aller-retour.
- **Port `AttemptRepository`** : `correct(attempt)` est ajouté (correction en place des billes, `NotFound` si absent) ; `add` crée un passage **neuf**. Sur drift et en mémoire, rejouer un identifiant connu le remplace encore (l'import reste idempotent) ; sur Firestore il est **refusé** (ajout seul : une écriture sur un document existant change `createdAt`, interdit par les règles). `add` écrit par un `set` simple (jamais de lecture préalable : hors ligne, la lecture d'un document absent échouerait), `correct` par un `update` de `potted` et `total`.
- **Règles resserrées** (`firestore.rules`) : `passIndex` retiré de la liste blanche ; **`createdAt` exigé égal à `request.time`** à la création d'un passage (un client ne peut pas antidater un passage, donc ne peut pas en changer le rang) et interdit ensuite ; une mise à jour ne change que `potted`, `total` (et `updatedAt`) ; **`createdBy` d'un acquittement exigé égal à `request.auth.uid`** à la création (on n'acquitte pas au nom d'un collègue) et figé ensuite. Tests : `progress.test.mjs` (matrice par rôle, requêtes autorisées et refusées, deux passages au même instant, suppression sans réécriture), `matrix` et `bounds` mis à jour, **mutations** de la copie des règles consignées dans testing.md.
- **Groupe et saison dénormalisés** : un passage porte ceux de **sa séance** (document lu, `OwnerResolver.ofSession`) ; un bloc acquis, un bilan, un acquittement portent ceux d'**un groupe de la fiche** (`ofStudent`) : pour un enseignant parmi **ses** groupes ; puis saison **ouverte** la plus récente, puis identifiant ; un acquittement suit le **groupe du dernier passage acquitté** s'il existe. Rejouer un identifiant connu garde son propriétaire (les règles le figent). **Limite** : une fiche **sans groupe** ne peut pas recevoir de bloc acquis, de bilan ni d'acquittement (`ServiceFailure` `other`, « no group ») : à traiter avec la reprise de FB7 et l'écran de positionnement de FB5.
- **Lecture par rôle** (aucune requête que les règles refuseraient) : le directeur et l'administrateur interrogent le club ; un enseignant **un groupe à la fois**, avec l'élève ou la séance (`AllEqual` : plusieurs égalités sur des champs différents, **sans index composite**, `firestore.indexes.json` inchangé) ; un parent ou un élève, **la fiche liée** pour les passages et les blocs acquis (`GetStudentShowcase`), **rien** pour les bilans et les acquittements (listes vides, B2). `DocumentStore.query` accepte `AllEqual`.
- **« Vu » partagé par club avec `uid` (B5)** : `createdBy` = `CurrentUser.id` à la création, conservé au remplacement ; le domaine (`AlertAcknowledgement`) ne le porte pas ; donnée personnelle d'animateur **déclarée au registre** (conformité). Les acquittements ne sont lus ni par la famille ni par les enseignants d'un autre groupe.
- **`CompositeUnitOfWork` (bloquant de FB4b levé)** : `FirestoreUnitOfWork(club, tracker:)` **n'attend plus l'accusé du serveur** du `WriteBatch` : le SDK l'applique au cache dès l'appel, l'unité se termine, la transaction drift se ferme et aucune écriture locale n'est bloquée hors ligne. L'envoi est suivi à part par `SendTracker` (port `SendStatus` : `pending`, `pendingChanges`, `lastFailure`, `clearFailure`) que FB5 lira pour la pastille « Envoi en attente ». La taille du lot (500) est vérifiée **avant** l'envoi. **Écart assumé** : un refus du serveur (règles, quota) arrive **après** la validation de drift et ne l'annule pas ; il est rendu par `lastFailure`. Test de contrat avec un store dont le commit ne se termine jamais. Sans suivi, `run` attend le serveur (montage Firestore seul). **Reste pour FB5** : les écritures **hors unité de travail** attendent encore le serveur, et la création d'une saisie (`createIfAbsent`, transaction) échoue hors ligne.
- **`RulesStore` rechargé** : `ReloadRules` (feature `manage_settings`) est appelé par `AuthCubit` **avant** d'émettre `ready`, à l'activation d'un club et à la bascule ; `reset` à la déconnexion et quand aucun club n'est actif. Il part des règles **de base** (`RulesStore.base` : les valeurs par défaut, plus ce qui n'est pas un réglage du club ; le club suivant ne reprend rien du précédent) et n'applique que les **réglages du club** (document `clubs/{c}/settings/main`) ; les préférences d'appareil (club retenu) restent dans le `KeyValueStore`. Des réglages illisibles (refus, réseau) laissent les valeurs par défaut sans bloquer l'ouverture. Le démarrage ne lève plus avec Firestore (aucun club actif au lancement : valeurs par défaut).
- **Contrat complet sur Firestore** : `RepositoryHarness` est joué sur les dépôts Firestore de tous les dépôts de données (faux en mémoire, `runProgress` local, unité de travail composite) ; écarts dits (`ContractTraits`, testing.md) : listes en ordre canonique, propriétaires d'abord, séance sans groupe refusée, ajout seul d'un passage. **Hors contrat Firestore, et pourquoi** : la **sauvegarde** (export complet, import) — l'import d'une sauvegarde **avec** saisie reste `unsupported` (une saisie se crée par transaction, impossible dans un lot ; **FB7**, lots reprenables) ; sans aucune saisie il est supporté (figé par un test) mais refuse une séance planifiée sans groupe ; `StudentEraser` côté serveur (**FB8** : l'effacement physique d'une fiche et de ses données par lots reprenables, marqueur `erasing` ; `eraseStudent` de chaque dépôt n'est qu'une requête par élève réservée aux gestionnaires).
- **Forme des identifiants figée** (hypothèse de `mayProbeAbsent`) : un identifiant déterministe de saisie contient toujours `_` ; les identifiants libres sont des UUID v4 sans `_`.
- **`SuggestedSessionPage.onPlan`** typé `(SheetId?, GroupId)` (le groupe est obligatoire, `state.groupId!`) ; scénarios de routeur (`planner_route.feature`) : le groupe arrive dans l'adresse du planificateur depuis la revue d'une séance, le détail d'une séance du catalogue et la suggestion.

- **Relecture FB4c (2026-10-18), corrections**
  - **Ordre des passages en attente** : `createdAt` est `null` à la lecture tant que le serveur n'a pas acquitté ; deux passages en attente se départageaient par un UUID aléatoire. Un champ **`recordedAt`** (horloge de l'appareil, **strictement croissante** par dépôt : +1 µs si l'horloge n'avance pas) est écrit à la création, exigé et figé par les règles. Ordre : `createdAt` (nul = après toute date connue), puis `recordedAt`, puis identifiant. `RecordAttempt` (le passage neuf en dernier) et la relecture serveur concordent donc. Limite : horloges d'appareils différents, seulement pour départager des dates serveur **égales** ou deux écritures **en attente** d'un même appareil. **Conséquence pour FB7** : l'import doit écrire `recordedAt` **strictement croissant dans l'ordre du fichier** : `createdAt == request.time` est exigé même d'un directeur ou d'un administrateur, donc tous les passages importés ont la même date serveur et seul `recordedAt` (puis l'identifiant) fixe leur ordre.
  - **Règles complètes à la création** : passages (`sessionId`, `blockId`, `exerciseNumber`, `date`, `potted`, `total`, `recordedAt`), blocs acquis (`blockId`, `date`, `source`), bilans (`date` et les trois notes), acquittements (`blockId`, `exerciseNumber`, `lastAttemptId`, `date`) : plus de document minimal que le codec ne sait pas lire. Un champ présent n'est jamais `null` ; une mise à jour **ne supprime aucun champ** (`noFieldLost`) ; `potted <= total`, `total` de 1 à 16 (bornes du domaine). Côté client, `decodeValid` **écarte** un document malformé (créé avant les règles ou par un autre client) au lieu de faire échouer la liste entière ; l'écart n'est pas signalé à l'utilisateur (à reprendre avec la pastille de FB5).
  - **Lecture d'un document absent** : `get` d'un passage, d'un bloc acquis, d'un bilan ou d'un « Vu » absent passe par `mayProbeAbsent` (directeur ; enseignant, identifiant aléatoire seulement ; jamais la famille). Un enseignant peut donc créer ces documents (lecture puis écriture), et `correct` d'un passage absent rend `NotFound` au lieu d'un refus.
  - **Limite connue, bloquante pour la bascule (FB5)** : **LEVÉE en FB5a (2026-10-19, notes FB5a).** Texte d'origine : `StudentData.upsert` **lit** le document cible avant d'écrire (propriétaire et auteur du « Vu » conservés). Hors ligne, la lecture d'un document absent échoue : **créer un bloc acquis, un bilan ou un « Vu » est impossible hors ligne** (test `offline (known limit, FB5)`). Le passage (`add`), lui, s'écrit hors ligne. Deux appareils qui créent le même identifiant en même temps : le second est refusé par `sameOwnership` après coup. Levée prévue en FB5 : créer par `SetOp(merge: true)` avec le propriétaire résolu depuis le cache, l'invariant étant porté par les règles.
  - **`ReloadRules`** n'écrit les règles que si le chargement est **toujours d'actualité** (`isCurrent`, la génération de l'`AuthCubit`) : un chargement tardif ne réinstalle ni les règles d'un club quitté, ni celles d'une session terminée (tests : deux chargements finissant à l'envers, déconnexion pendant le chargement).
- **Relecture FB4c, second tour (2026-10-18)**
  - **Dates des règles** : `optStamp` / `presStamp` acceptent un horodatage ou le texte exact de `DateTime.toIso8601String` (`AAAA-MM-JJThh:mm:ss`, fraction de 1 à 6 chiffres facultative, `Z` facultatif), par un motif `matches` (`isoText`). Un texte quelconque (`'zz'`) était accepté puis écarté sans bruit par `decodeValid`. Le motif borne les plages (mois 01-12, jour 01-31, heure 00-23, minute et seconde 00-59) : `DateTime.tryParse` **corrige** une date fausse au lieu de la rejeter (`2026-13-45T99:99:99` devient le 18 février 2027), donc seules les règles l'arrêtent. **Limite** : le jour qui n'existe pas dans son mois (30 février, 31 avril) n'est pas bornable par une règle simple ; `DocumentValues.decodeDate` le **rejette** (une date relue puis réécrite au même format, jusqu'aux secondes, doit redonner le texte d'origine ; sinon `ServiceFailure` `other`) et `decodeValid` écarte alors le document. L'historique du public (`audienceHistory[i].effectiveFrom`) passe par le même `isoText`.
  - **Lecture d'une liste de passages** : `FirestoreAttemptRepository` décode (et écarte les documents illisibles, champs de tri `createdAt` / `recordedAt` compris) **avant** de trier ; un document malformé ne rend plus la liste illisible.
  - **`ReloadRules`** : le chemin d'échec respecte aussi la génération courante.
  - **Mutant équivalent** : `presInt(d, 'potted', 0, 100)` n'est pas tuable : `potted <= total <= 16` borne déjà `potted` (la création exige les deux champs, `noFieldLost` interdit de retirer `total`).

## Notes de réalisation du lot FB5, partie A (2026-10-19, infrastructure ; `watch…` et cubits abonnés : partie B)

Les règles et les index ont été **déployés sur le projet réel par l'utilisateur** avant ce lot ; aucun accès au projet réel n'a été pris
(émulateurs `demo-cfa-ffb` et doubles).

- **SDK web servi localement (B7 levé)** : `firebase_core_web` 3.12.0 charge `import("https://www.gstatic.com/firebasejs/<v>/firebase-<service>.js")` ;
  l'URL est écrite en dur, seule la version se règle (`window.flutterfire_web_sdk_version`), et les bundles s'importent entre eux par cette
  même URL absolue. **Méthode retenue : une carte d'import** (`<script type="importmap">` de `app/web/index.html`) qui redirige les trois URL
  (`firebase-app.js`, `firebase-auth.js`, `firebase-firestore-pipelines.js`, le bundle que le plugin importe pour Firestore) vers
  `app/web/firebasejs/<version>/`, des copies **octet pour octet** de celles de gstatic (paquet npm `firebase@<version>`, identique, vérifié à
  l'épinglage). Aucun fork, aucune modification du plugin ; le service worker les précache comme tout fichier de `web/`. Écartées : `flutterfire_ignore_scripts` (désactive l'injection mais laisse à écrire soi-même l'import des modules dans les variables globales
  que le plugin lit : on reproduit sa mécanique interne, fragile à chaque version) ; réécrire les imports des bundles (fichiers modifiés,
  l'empreinte ne prouve plus rien). **Garde-fous** : `scripts/sync_firebase_sdk.dart --check` dans `check.sh --fast` (version = celle du plugin résolu,
  empreintes SHA-256 du manifeste, carte d'import exacte et placée avant tout script, aucun import interne non couvert) ; `pwa.dart check` (seules
  clés autorisées : l'URL gstatic du SDK, redirigées vers `./firebasejs/`) et `verify` (présence au build et au précache) ; la fumée du build
  compilé et le parcours navigateur **refusent désormais gstatic.com** et exigent que les trois fichiers soient servis par l'application ;
  `platform_privacy_test` exempte `web/firebasejs/`. **Limite** : un navigateur sans cartes d'import (Safari avant 16.4) ignore la carte et
  retombe sur gstatic.com (en ligne seulement, adresse IP transmise) ; non exercé ici. Une mise à jour de `firebase_core_web` qui change la
  version fait échouer `--check` jusqu'à `dart run scripts/sync_firebase_sdk.dart`. **Liste blanche réseau écrite** (hôtes joignables par le
  navigateur, hors l'application elle-même) : `identitytoolkit.googleapis.com` et `securetoken.googleapis.com` (Auth), `firestore.googleapis.com`
  et `www.google.com/images/cleardot.gif` (sonde de connectivité de Firestore) ; le test de fumée n'accepte rien d'autre.
- **Persistance hors ligne (C4)** : `FirebaseSdkGateway.initialize` règle `Settings(persistenceEnabled: true, webPersistentTabManager:
  WebPersistentMultipleTabManager())` **après** l'initialisation et **avant** `useEmulators` (sur le web, la connexion à l'émulateur crée
  l'instance et figerait un cache en mémoire). Le cache est **multi-onglets** (sans cela deux onglets s'excluent).
- **Cache local vidé (C4)** : port `LocalDataCache` (`clear` = `terminate()` puis `clearPersistence()`, `reopen` = rechargement de la page sur le
  web ; sur natif le SDK recrée l'instance, **non exercé**) et `LocalDataGuard` : le cache a **un propriétaire** (uid dans `KeyValueStore`),
  consigné **avant** toute lecture ; un **autre** compte le vide d'abord (un échec lève : `indisponible`, jamais de donnée servie au mauvais
  compte) ; la **déconnexion voulue** le vide, oublie le propriétaire, puis recharge la page. Une session perdue autrement (jeton révoqué, autre
  onglet) **ne vide pas** (des écritures hors ligne pourraient s'y trouver ; le même compte les retrouve, un autre compte déclenche l'effacement) :
  choix assumé. **Une déconnexion avec des envois en attente les perdrait** : `AuthCubit.signOut` la refuse (`SignOutResult.unsentWrites`) et
  l'interface demande confirmation (aucune donnée affichée). `clearPersistence` abandonne le stockage **sans le réécrire** (le SDK le dit) : le
  registre de conformité le consigne. Avertissement « appareil partagé » dans l'écran de connexion (`SharedDeviceNote`, fr + en).
- **Pastille de synchronisation** : `SendStatus` (port de lecture, déplacé dans `shared/lib` : la présentation ne peut pas importer
  `shared/persistence`) expose `pending`, `pendingChanges`, `hasFailure`, `clearFailure` ; `SyncStatusCubit` le croise avec `ConnectivityStatus`
  (web : `navigator.onLine` et événements `online` / `offline` ; **natif : toujours « en ligne »**, aucun plugin de réseau retenu : la pastille ne
  dit jamais « Hors ligne » à tort, et ne le dit pas sur mobile) en `SyncState` (échec > en attente > hors ligne > à jour). `SyncStatusChip` :
  bleu-tapis pour tous les états normaux, couleur d'attention seulement pour un envoi refusé (message sobre, action « Compris »), région vive,
  aucun texte de donnée personnelle ; posée dans le cadre de navigation. **Libellés à valider par l'animateur** : fr « À jour », « Envoi en attente
  (n) », « Hors ligne », « Hors ligne, envoi en attente (n) », « Une modification n'a pas
  pu être enregistrée et a été annulée sur cet appareil. » (en : « Up to date », « Waiting to send (n) », « Offline », « Offline, waiting to
  send (n) », « A change could not be saved and was undone on this device. »).
- **Écritures hors ligne sans lecture du serveur** : nouveau `DocumentStore.peek` (cache local seulement : jamais d'attente du réseau, `null`
  si absent du cache, jamais une affirmation d'absence). `StudentData.upsert` lit la cible dans le cache **puis sur le serveur** (`cachedOrGet`, corrigé après revue : un cache froid, vidé à chaque déconnexion, réécrivait en création, **en ligne**, un document existant, et les règles refusaient après coup) ; seul `unavailable` (hors ligne) vaut « absent » ; `OwnerResolver` et
  `FirestoreAcknowledgementRepository._ownerOf` lisent le cache d'abord (`ClubStore.cachedOrGet`), le serveur ensuite, et **hors ligne** un « Vu »
  dont le passage n'est pas au cache retombe sur un groupe de la fiche. **Aucune règle ne change** : `sameOwnership` et `createdBy` figé
  portent l'invariant (déjà éprouvés : `progress.test.mjs`) ; si le document existait sur le serveur sans être au cache avec un autre
  propriétaire **et que l'appareil est hors ligne**, l'écriture est refusée plus tard et remonte par la pastille (cas limite hors ligne seulement). Les tests « le remplacement garde le propriétaire » et « garde
  l'auteur du Vu » sont inchangés et verts. **Reste hors ligne impossible** : une fiche d'élève absente du cache (propriétaire introuvable).
- **Création d'une saisie hors ligne** : une saisie **libre** (identifiant UUID : aucun autre appareil ne peut la créer en même temps) se crée par
  écriture simple si le cache ne la connaît pas (`createdAt` du serveur) ; si elle existait pourtant sur le serveur, la mise à jour qui changerait
  `createdAt` est refusée par les règles (nouveau test d'attaque `planning.test.mjs`). Une saisie **liée** à une séance du catalogue
  (identifiant déterministe, deux appareils peuvent la créer ensemble) garde la transaction `createIfAbsent` : **impossible hors ligne**,
  limite précise, **levée en FB5b** (écriture simple refusée par les règles si la saisie existe, puis reprise : notes FB5b, E).
- **Corrections de revue FB5a** : (1) **garde de déconnexion fondée sur le SDK** : `hasUnsentWrites` ne lit plus le seul compteur en mémoire
  (perdu au rechargement alors que la file IndexedDB survit) ; le port `SendStatus` gagne `hasUnsentWrites()` et `refresh()`, alimentés par
  `PendingWritesProbe` (`app/platform/firestore_pending_writes_probe.dart` : `waitForPendingWrites` borné à 800 ms ; l'attente sans borne
  rend la file restaurée visible dans la pastille, comme un lot en attente) ; scénario BDD « écriture avant redémarrage, déconnexion →
  confirmation » ; (2) **multi-onglets** : `clearPersistence` est borné (5 s, `TimeoutException`, propriétaire conservé, la déconnexion se
  termine) ; un onglet qui perd sa session alors qu'un autre a vidé le cache (clé propriétaire disparue) se recharge ; fumée du build compilé à
  deux onglets ; (3) `SyncState` est `@freezed` ; (4) **natif** : `reopen` réapplique les réglages du SDK après `terminate` (valeur inchangée :
  l'hôte d'un émulateur reste) ; **non prouvé par un test natif** (aucun appareil dans les garde-fous : plugin absent sous `flutter test` et
  sous Linux) : à éprouver à la main sur Android ou iOS (déconnexion, reconnexion, lecture) avant de basculer ; (5) `check.sh --full` échoue tôt
  si un port d'émulateur est pris (`scripts/check_ports_free.sh`) ; (6) **déploiement des règles à chaque exécution** (plus de filtre sur le
  diff d'un seul push : une exécution en attente remplacée par la suivante perdait ses règles).
- **Corrections de revue FB5a (2e passe)** : (1) **effacement raté à la déconnexion, traité** (vie privée) : la session se ferme, mais un repère
  « effacement en attente » (`firestore_cache_erase_pending`, valeur constante, aucune donnée personnelle) reste consigné ; il est retenté au
  démarrage **avant toute lecture de compte** et dans `claim` (le **même** compte compris : le repère l'emporte sur le propriétaire) ; un échec
  persistant rend l'application `indisponible` plutôt que de servir le cache ; l'écran de connexion dit « Les données hors ligne de cet appareil
  n'ont pas pu être effacées : fermez les autres onglets puis réessayez » avec « Réessayer l'effacement » (`AuthSignedOut.erasurePending`) ;
  (2) `StudentData.upsert` et `_ownerOf` : seul `unavailable` vaut « absent », `permissionDenied` et `other` remontent (tests à cache froid) ;
  (3) la pastille de synchronisation nomme sa région vive (`syncStatusLabel`) ; (4) `scripts/check_ports_free.sh` sonde `127.0.0.1`, `::1` et
  `0.0.0.0` ; (5) workflow de déploiement durci (`persist-credentials: false`, `npm ci --ignore-scripts`, concurrence partagée avec Hosting pour
  le lancement manuel) ; (6) multi-onglets : `_signingOut` (session fermée ici) et `stop` du garde (compte revenu) sont les deux seules défenses,
  chacune contrainte par un test qui tue sa mutation.
- **Déploiement des règles et des index par la CI** : décision de l'utilisateur du 2026-10-18, [deploiement-firestore.md](../deploiement-firestore.md) :
  workflow appelé par le workflow d'hébergement, **hébergement après règles et index** (`needs`), tests d'abord, fédération d'identité de
  charge de travail sans clé JSON, jamais depuis une pull request ; étapes de l'utilisateur documentées, **jamais exécuté contre le projet réel**.
- **Reste pour FB5b** *(traité : voir les notes FB5b ; ce qui reste y est listé)* : méthodes `watch…` (flux) sur les dépôts lus par plusieurs appareils et cubits abonnés ; règle de conflit documentée ;
  scénario BDD « la fiche se met à jour sans rechargement » ; écritures hors unité de travail rendues non bloquantes ; saisie liée hors ligne ;
  indice de réseau natif ; l'indicateur « prêt hors ligne » ; parcours navigateur hors ligne réel (Playwright `setOffline` sur l'application
  compilée avec `DATA_BACKEND=firestore` et l'émulateur) ; Safari ancien sans carte d'import.

## Notes de réalisation du lot FB5, partie B (2026-10-19, temps réel, règle de conflit, hors ligne des écritures ; aucune décision nouvelle)

Comme en partie A : **aucun accès au projet réel** (émulateurs `demo-cfa-ffb`, doubles et faux Firestore). `DATA_BACKEND` reste `drift` par
défaut ; la bascule est le lot dédié après FB7.

- **Flux du port `DocumentStore`** : `watchDocument`, `watchCollection`, `watchQuery` (mêmes filtres que les lectures : une égalité, un
  `array-contains-any`, plusieurs égalités sur des champs différents, **aucun index composite**, `check_indexes` inchangé). Un état complet à
  chaque changement (jamais un delta), trié par identifiant, **un lot arrive en un seul état** (prouvé contre l'émulateur ; le faux Firestore le
  livre document par document). Métadonnées `UpdateMetadata` (`fromCache`, `hasPendingWrites`) portées par chaque état (`DocumentUpdate`,
  `CollectionUpdate`) : le SDK n'est pas appelé avec `includeMetadataChanges`, donc aucun état « pour rien » ; les dépôts ne s'en servent pas
  (la pastille dit déjà l'envoi en attente), le port les offre pour les écrans à venir. **Erreur** : un `StoreFailure` (`permissionDenied`
  d'abord) arrive sur le flux, qui **se ferme** (une écoute Firestore est terminée après une erreur) ; les autres flux ne sont pas touchés ;
  **annuler** l'abonnement annule l'écoute du SDK (`relayStream`, testé). Le SDK n'est touché que dans `app/platform/firestore_document_store.dart`
  (`FirestoreAccess.watch…`).
- **Flux liés à la portée** : `ClubStore.watch…` mémorise club, rôle, groupes et fiches à l'ouverture ; si la session change (autre club, autre
  rôle, autre périmètre, déconnexion), le flux livre `permissionDenied` (`scope-changed`) et se ferme **en relâchant l'écoute**, au lieu de
  servir des documents d'un périmètre perdu. **La fermeture est immédiate** : `ActiveClubScope.changes` (signal synchrone à chaque écriture de la
  portée) fait réévaluer la portée à chaque flux épinglé (`relayStream`, `recheck`), qui se ferme et relâche son écoute sans attendre un
  événement du serveur (test `activeWatchers == 0` juste après `deactivateClub()`). La clé de portée est **triée** (groupes, fiches) : le même
  ensemble relu dans un autre ordre ne ferme rien. **`ClubScoped` ne referme pas les blocs des pages ouvertes** : il est posé dans
  `MaterialApp.builder` et le `Navigator` de go_router (clé globale) survit à sa reconstruction ; il ne reconstruit que ce qui est sous lui. Les
  défenses réelles sont donc : (1) `ClubStore._pinned` ferme les flux épinglés (`permissionDenied` `scope-changed`), (2) `LiveReload` relit
  puis **rouvre** le flux après l'erreur (une seule fois sans donnée entre-temps, pas de boucle ; `restart` repart de zéro) et rouvre ainsi
  l'écoute sous la nouvelle portée, (3) `ClubScoped` (clé `(club, rôle, groupes, fiches)`) reconstruit ce qui est sous lui. Scénario BDD
  « A screen keeps following the data when the scope of the account changes ». Limites assumées (FB5b) : (a) les blocs à transformateur
  concurrent (`StudentSheetBloc`) peuvent émettre le résultat d'une relecture plus ancienne après un plus récent (`LiveReload` ne sérialise pas
  les relectures des événements `changed` et `started`) ; la relecture suivante corrige l'écran ; (b) un enseignant peut ajouter par `arrayUnion`
  l'identifiant d'un élève d'un **autre** groupe aux présents d'une saisie de son groupe (attaque jouée à l'émulateur, antérieure à FB5 : les
  règles ne bornent pas l'appartenance des présents au groupe, faute de budget de `get()`) ; (c) contrat `watch…` : Firestore ferme le flux après
  une erreur, mémoire et drift le laissent ouvert (le port le dit par backend) ; l'abonné rouvre dans tous les cas.
  `ClubStore.watchSources`
  décrit une lecture par rôle (collection, requête, document) et les combine (`combineLatest`) : l'état est toujours celui de **toutes** les
  sources, une erreur d'une source ferme l'ensemble et libère toutes les écoutes.
- **`watch…` des dépôts (ajout ciblé, les `Future` sont conservés)** : `StudentRepository.watchById/watchAll`, `GroupRepository.watchAll/watchById`
  (groupe + appartenances), `SessionRepository.watchAll`, `SessionRecordRepository.watchForGroup/watchForStudent/watchAll`,
  `AttemptRepository.watchForStudent/watchForSession/watchAll`, `AcquisitionRepository.watchForStudent/watchAll`,
  `AcknowledgementRepository.watchForStudent/watchAll` (« Vu » partagé : l'acquittement d'un collègue arrive), `AssessmentRepository.watchForStudent`.
  **Liste minimale** : celle que lisent la fiche d'un élève, la liste des groupes et la séance du jour ; les saisons, les archives et les
  réglages ne se suivent pas (ils changent par une action de cet appareil ou rarement ; le club n'est pas relu en cours de séance). Chaque dépôt
  Firestore suit **les mêmes requêtes que sa lecture** par rôle (gestionnaire : la collection ; enseignant : un groupe à la fois ;
  parent et élève : la fiche liée ; aucune écoute pour ce que les règles cachent : saisies, bilans, « Vu » rendent un flux d'une liste vide) :
  tests par rôle (`firestore_watch_roles_test`, journal des écoutes du double) et contre les vraies règles (`watch.test.mjs`). Mémoire et
  drift implémentent le même contrat : mémoire par `ObservedMap` (annonces **retenues jusqu'à la fin d'une unité de travail, annulation
  comprise** : un abonné ne voit jamais un état à moitié appliqué), drift par `tableUpdates` (qui n'annonce qu'à la validation).
- **Écrans abonnés (lecture seule d'abord)** : `StudentSheetBloc` (fiche), `StudentsBloc` (liste des groupes et des élèves, partagée par
  trois pages), `UpcomingSessionsCubit` (séance du jour de l'accueil). Le temps réel ne réécrit **aucune règle de calcul** : les cas d'usage
  `WatchStudentSheet`, `WatchClubOverview`, `WatchUpcomingSessions` fondent les flux des dépôts en un flux de **changements** (`changesOf` : le
  premier état de chaque source est l'état de départ, ignoré) et l'écran se **recharge en place** par son cas d'usage habituel, sans état de
  chargement. `LiveReload` tient les règles : **un seul abonnement** (démarrer deux fois n'en ouvre pas un second), jamais deux relectures en
  parallèle (les changements qui arrivent pendant une relecture se fondent en une), une erreur du flux déclenche aussi une relecture (elle
  reproduit l'échec par le chemin normal : refus affiché comme à un chargement, localisé), « Réessayer » **rouvre** l'écoute fermée par
  l'erreur, la fermeture du bloc la relâche. Le guide « Mener » n'est **pas** concerné : il tourne sur le catalogue (assets) et la progression
  locale de l'appareil (ADR 0020), aucune donnée partagée. Effet de bord assumé : un écran qui se met à jour peut déplacer un bouton sous le
  doigt ; quatre scénarios BDD existants plaçaient leurs `Given` après le lancement et sont réordonnés (données d'abord, application ensuite).
- **Règle de conflit (B5), table document → règle.** Une ligne, un test (`C1` à `C13`) sur le faux Firestore **et** sur le double du stock
  (`conflict_contract.dart`, deux appareils, `Future.wait`) et contre l'émulateur avec les vraies règles et deux clients
  (`conflicts.test.mjs`). Quand la règle est « dernier écrit gagne », le test vérifie ce qui est vrai quel que soit l'ordre : le résultat est
  **l'une des deux écritures, entière** (jamais un mélange) et les deux appareils lisent la même chose.

  | # | Document | Règle de conflit | Mécanisme |
  |---|---|---|---|
  | C1 | `students/{id}` (prénom, public, historique) | **dernier écrit gagne par document** ; `groupIds` jamais réécrit par un enregistrement de la fiche | `SetOp(merge)` + `ArrayUnion([])` |
  | C2 | `students/{id}.groupIds` | **réunion** commutative : deux groupes ajoutés ou retirés en même temps s'additionnent | `ArrayUnion` / `ArrayRemove` côté serveur |
  | C3 | `groups/{id}` | nom et public : dernier écrit gagne ; appartenances de deux élèves différents : **réunies** | `UpdateOp` + un document par appartenance |
  | C4 | `memberships/{groupe_élève_début}` | identifiant **déterministe** : deux écritures identiques sont un seul document ; contenu différent : dernier écrit gagne | identifiant lié au contenu |
  | C5 | `records/{groupe_jour_séance}` (saisie liée) | **une création**, présents **réunis**, date de création et blocs du premier | `createIfAbsent` (transaction) puis `ArrayUnion` ; hors ligne : voir E |
  | C6 | `records/{id}` (enregistrer) | remplacement en bloc, dernier écrit gagne ; `resume` remplace les présents, `open` les réunit | fusion `SetOp` sans `createdAt` |
  | C7 | `records/{id}.tags` | liste remplacée **en bloc**, dernier écrit gagne | `UpdateOp` |
  | C8 | `attempts/{id}` (passages) | **ajout seul**, un document par passage : jamais de conflit ; rejouer un identifiant est **refusé** par les règles ; ordre `createdAt` serveur, `recordedAt`, identifiant | `SetOp` ; règle de création |
  | C9 | `attempts/{id}` (correction) | dernier écrit gagne sur `potted`/`total` **seulement** (toute autre modification est refusée) | `UpdateOp` ; règle de mise à jour |
  | C10 | `acquisitions/{id}` | un document par marquage : les doublons sont **fusionnés par le calcul** (dernier par bloc), indépendamment de l'ordre | `StudentProgress.derive` |
  | C11 | `acknowledgements/{id}` (« Vu » partagé) | un document par acquittement, `createdBy` = uid de son auteur (jamais au nom d'un collègue) ; le calcul garde le dernier par exercice | règle `createdBy`, `derive` |
  | C12 | `sessions/{id}` (planifiées) | un document par séance : deux appareils qui planifient s'additionnent | UUID |
  | C13 | tous : suppression et documents uniques | suppression **physique** idempotente ; une mise à jour (`update`) d'un document supprimé échoue, elle ne le recrée pas ; réglages du club : une écriture entière gagne | `DeleteOp`, `UpdateOp` |

  **Cas sans règle sûre, listés comme limites (tests de caractérisation `L1` à `L4`, `conflict_contract.dart`) :**
  - **L1** `GroupRepository.save` écrit l'agrégat entier : une **copie périmée** d'un groupe supprime l'appartenance ajoutée entre-temps par un
    autre appareil (les flux réduisent la fenêtre, ils ne la ferment pas ; une vraie correction demande des opérations d'appartenance, pas
    l'agrégat : à traiter avec FB7/FB8).
  - **L2** `StudentRepository.save` écrit par fusion : enregistrer une fiche supprimée ailleurs la **recrée** (`set merge`, prouvé contre
    l'émulateur) ; une mise à jour pure (`update`) ne la recrée pas.
  - **L3** l'historique du public est une liste embarquée **remplacée en bloc** (écart assumé à la décision 15, notes FB4a) : un changement de
    public fait sur un appareil est perdu si un autre enregistre ensuite une fiche lue avant ; seul un gestionnaire change le public.
  - **L4** étiquettes et présents d'un `save`/`resume` sont des listes remplacées en bloc : un ajout fait ailleurs entre-temps est perdu (les
    présents d'une **ouverture** sont réunis, voir C5).
  - **L5** la reprise d'une création de saisie hors ligne ne survit pas à la fermeture de l'application (voir E).
- **E. Saisie liée à une séance du catalogue hors ligne** : la transaction `createIfAbsent` est impossible hors ligne ; **voie sûre
  implémentée sans toucher aux règles** : identifiant déterministe + **écriture simple** `createdAt` du serveur. Les règles l'acceptent si la
  saisie n'existe pas (création) et la **refusent** si elle existe (elle changerait `createdAt`, figé : la règle existante, pas une règle
  affaiblie) ; le refus déclenche la **reprise** : les présents sont réunis (`ArrayUnion`, comme `open` en ligne). `ClubStore.mayAwaitServer`
  décide (réseau non connu coupé et aucun envoi en attente : la transaction ; sinon, ou si elle ne répond pas dans `ackGrace`, l'écriture
  simple). **Convergence prouvée** contre l'émulateur avec le vrai SDK hors ligne (`disableNetwork`/`enableNetwork`) : `conflicts.test.mjs`
  `E1` à `E4` (création acceptée ; saisie créée entre-temps : refus puis union ; deux appareils hors ligne : le premier reconnecté crée, le
  second est refusé puis réunit ; borne de 60 présents tenue) ; tests Dart avec un double qui rejoue la règle. **Limite précise (L5)** : la
  reprise vit avec l'application ; si elle est fermée avant la reconnexion, le SDK rejoue l'écriture mise en file au démarrage suivant **sans
  reprise** et, si la saisie existe alors, le refus est signalé par la pastille (« annulée sur cet appareil ») ; rouvrir la saisie réunit les
  présents. Aucune donnée n'est perdue en silence.
- **F. Écritures hors unité de travail non bloquantes** : inventaire (grep des `commit` hors `UnitOfWork`) : **cas d'usage** `RecordAttempt`,
  `CorrectAttempt`, `DeleteAttempt`, `OpenSession`/`OpenOrResumeSession`, `SetSessionTags`, `RecordAssessment`, `PlanSession`, `DeleteSession`,
  `CreateGroup`, `RenameGroup`, `DeleteGroup`, `RenameStudent`, `SaveSettings` : tous passent par `ClubStore.commit`, dont le `Future` du SDK
  n'est achevé **qu'à l'accusé du serveur** (donc jamais hors ligne : l'interface restait suspendue, par exemple à la saisie d'un passage).
  **Corrigé en un point** : `ClubStore.commit` n'attend plus l'accusé que `ackGrace` (1,5 s), pas du tout si le réseau est connu coupé ou si
  un envoi attend déjà (les accusés arrivent dans l'ordre), puis confie l'envoi au `SendTracker` (pastille, refus tardif). **Un refus dans le
  délai reste l'échec de l'appelant** (la traduction `tooManyPresent` est conservée) ; un refus tardif arrive à la pastille et annule
  l'écriture sur l'appareil, comme pour les lots d'unité de travail (FB4c). Sans suivi (tests unitaires des dépôts), l'écriture est attendue
  comme avant. **Restent bloquants hors ligne, volontairement en ligne** : création et renommage de club, émission et révocation d'une
  invitation, retrait d'un membre, publication de la fiche à l'invitation (`StoreClubRepository`, `StoreInvitationRepository`,
  `StoreMemberRepository`, `StoreStudentDirectory`, qui parlent à `DocumentStore` sans passer par `ClubStore`) : une invitation émise hors
  ligne n'est utilisable qu'à l'envoi ; leur donner une erreur franche (`unavailable`) plutôt qu'une attente est un reste de FB6/FB7 (le
  réseau natif n'est pas connu).
- **G. Indicateur « prêt hors ligne » : reporté, décision motivée.** Définir « prêt » demande deux signaux qu'on n'a pas encore : le service
  worker actif et son précache complet (pont JavaScript à ajouter) et un cache de données **complet** pour l'usage hors ligne, que le SDK ne
  sait pas affirmer (il sait si un document est au cache, pas si le club l'est) : afficher « prêt » à tort rassurerait faussement un
  animateur dont la fiche d'un élève n'a jamais été ouverte. Tant que `DATA_BACKEND=drift`, les données sont locales et l'application
  hors ligne depuis le lot 15 (sans indicateur) ; la pastille dit déjà « Hors ligne » et « Envoi en attente ». À reprendre **après la
  bascule**, avec la définition suivante : service worker actif et précache complet **et** premier état confirmé par le serveur
  (`fromCache` faux, désormais porté par `UpdateMetadata`) pour chaque flux de la session.
- **Doubles de test** : `DeviceDocumentStore` (un appareil devant un serveur partagé : coupure du réseau, flux retenus puis rattrapés,
  écritures mises en file, sans cache local ni règles ; limites dites dans `testing.md`) et `OtherDevice` (un graphe complet de plus, autre
  session, mêmes dépôts Firestore) servent aux scénarios BDD multi-appareils (`live_sync.feature`, 6 scénarios : la fiche suit un passage
  saisi ailleurs, la liste suit une fiche créée ailleurs, l'accueil suit une séance planifiée ailleurs, aucun abonnement ne reste après
  une page quittée, l'accès retiré ferme les écoutes et le dit, un appareil hors ligne rattrape à la reconnexion). **Rouge vu** : sans
  abonnement, 5 de ces 6 scénarios échouent ; sans libération à la fermeture, le sixième.
- **Reste pour FB6 et au-delà** : espace élève (lecture seule, mêmes flux filtrés par la fiche liée) ; erreur franche pour les écritures
  volontairement en ligne ; opérations d'appartenance atomiques (L1) ; reprise durable d'une création hors ligne (L5) si le besoin se
  confirme ; « prêt hors ligne » après la bascule ; parcours navigateur hors ligne réel (Playwright `setOffline` sur le build compilé avec
  `DATA_BACKEND=firestore` et l'émulateur) ; indice de réseau natif ; Safari ancien sans carte d'import ; flux de l'écran de groupe
  (`GroupOverviewCubit`), de l'alerte de groupe et de la semaine, qui reposent sur les mêmes `watch…` mais n'ont pas été abonnés ici.

## Notes de réalisation du lot FB6 (2026-10-19, espace élève et parent ; l'aiguillage de backend par rôle a été **écarté par l'utilisateur**)

Comme aux lots précédents : **aucun accès au projet réel** (émulateurs `demo-cfa-ffb`, doubles, graine). Plan : [../clubs-roles-plan.md](../clubs-roles-plan.md) (section « Espace élève et parent »).

- **Aiguillage de backend par rôle : écarté par l'utilisateur le 2026-10-19.** Raison : l'AIPD n'est pas faite et la mise en production reste conditionnée par le garde-fou de l'[ADR 0025](0025-comptes-et-donnees-de-mineurs-conformite.md) (décision 3 : aucun vrai élève sur le serveur avant la validation des documents de conformité) ; envoyer des lectures de mineurs au serveur avant la bascule la contournerait. L'agent coordinateur avait proposé que les comptes `student` et `guardian` lisent Firestore dès maintenant,
  les animateurs restant sur drift (`DataBackendChoice.forRole`, six `RoleRouted…Repository`). L'utilisateur l'a refusé : **l'espace famille ne lit Firestore qu'avec `DATA_BACKEND=firestore`,
  donc après la bascule ; aucune lecture de mineurs n'arrive au serveur avant.** Le code d'aiguillage est retiré ; `choice.backend.choose` redevient le seul choix, **drift par défaut pour
  tous les rôles** tant que `DATA_BACKEND` n'est pas explicite (décision 28 amendée, inchangée). Le garde-fou de mise en production (A3, ADR 0025) reste celui d'avant. L'espace famille est
  livré et testé avec `DATA_BACKEND=firestore` explicite (BDD sur Firestore en mémoire, contrat, règles, parcours navigateur sous émulateurs, lancé avec l'indicateur) ; sans l'indicateur,
  un parent connecté voit l'espace sur le stock drift de son appareil (vide : « Aucun élève n'est encore lié »), jusqu'à la bascule. Tests : `data_backend_module_test` (défaut drift pour
  tous les rôles ; `DATA_BACKEND=firestore` donne Firestore à tous) et `production_graph_test` (graphe exact).
- **Ce qu'est l'espace** (décisions 16 et 26 mises en œuvre) : `/my-children` est l'accueil unique des deux rôles : sélecteur d'enfant (dès deux fiches liées, ordre du lien, prénoms
  identiques numérotés), parcours de l'enfant choisi (`ShowcaseView`, ADR 0014, devenue la page) et au plus cinq prochaines séances **des groupes du compte** (titre, jour, nom du
  groupe). Lecture seule : aucun bouton, deux destinations de menu, routes d'animateur refusées (`roleRedirect`, inchangé), aucune écriture permise par les règles. La route
  `/students/<id>/show` reste ouverte aux fiches liées (garde de la décision 26) mais plus aucun écran n'y mène pour une famille. `LinkedStudentsCubit`, `ListLinkedStudents` et
  `LinkedStudentsList` sont remplacés par `FamilySpaceCubit`, `GetFamilySpace`/`WatchFamilySpace` et `FamilySpaceView`.
- **Isolation (B2) vérifiée à trois niveaux** (détail et mutation : [../testing.md](../testing.md)) : journal des demandes de l'appareil (BDD) ; égalité du journal avec
  `scripts/rules_test/family_reads.json` (test Dart des vrais dépôts) ; la même liste jouée contre les **vraies règles** avec, en regard, la liste des lectures interdites (94 tests).
  Constat : **les règles n'ont pas eu à changer** ; elles autorisaient déjà exactement ces lectures. Les `seasons` restent lisibles par tout membre (libellé et dates, aucune
  donnée d'élève).
- **Reçu sans être affiché (complétude, 2026-10-19)** : la liste champ par champ (fiche entière dont `audienceHistory`, passages réussis et manqués, acquis avec date et source, `settings/main`, groupes avec `teacherUids`, toutes les séances, propre `member` avec `invitationCode`, lectures de connexion `clubs/{club}`, `admins/{uid}`, requête de groupe `members`) est au registre (traitement 1 bis), contrôlée par `scripts/check_family_register.dart` (`check.sh --fast`). **Les alertes ne sont jamais stockées côté serveur : elles sont calculées sur l'appareil** (`StudentProgress.derive`, `techniqueSummary`, `BlockStatus.toReview`) à partir des passages et de `settings/main` reçus, même sans les « Vu » ; seuls les « Vu » ne sont jamais lus.
- **Deux ports étroits, pour ne pas ouvrir de tuyau vers ce qu'on cache** : `GroupNames` (`entities/group`) donne le **nom** des groupes du périmètre, jamais l'agrégat `Group`
  (ses appartenances sont les camarades) ; `OwnLinkSource` (`entities/membership`) lit le **propre `member`** du compte (rôle, fiches, groupes). Le garde de
  `get_student_showcase_test` (« la tranche n'importe rien qui puisse fuiter ») est resserré : seul `entities/group/domain/group_names.dart` est admis.
- **Lien retiré, constaté sur le vrai SDK navigateur (leçon)** : supprimer le `member` fait refuser l'écoute de **ce** document (`permission-denied`, mesuré à l'émulateur),
  mais **les lectures des données continuent d'être servies** par les écoutes déjà ouvertes (le serveur ne renvoie rien pour un document qui n'a pas changé) : un écran qui
  ne se fiait qu'à l'échec d'une lecture de données restait affiché (trouvé au parcours navigateur, invisible aux doubles). Règle retenue : **le lien se relit en premier** à chaque
  rechargement ; un `member` absent, sans fiche liée ou refusé en lecture = **« Accès retiré »**, abonnement relâché, aucune donnée affichée (cache de l'appareil vidé à la déconnexion) ; un refus des données alors que le
  lien existe encore = **« Accès refusé »** (message distinct de « service injoignable », décision FB4a ; pas de « Réessayer »). Un retrait **partiel** (une fiche sur deux) : le lien relu est
  confronté aux fiches de la session (`CheckFamilyAccess`, domaine) ; une fiche déliée n'est plus lue (sinon son refus faisait passer tout l'espace à « Accès refusé » et
  l'enfant encore lié disparaissait). Limite assumée : la portée de la session (`studentIds`, `groupIds`) n'est relue qu'à la connexion, et l'écoute temps réel de la fiche déliée
  reste fermée jusqu'à la relecture de la portée (FB7/FB8).
  **Limite précise pour les groupes** : `CheckFamilyAccess` ne confronte au serveur que les fiches (`studentIds`) ; `OwnLink` lit aussi `groupIds`, mais les séances et les noms de groupes passent par
  `FirestoreSessionRepository` et `FirestoreGroupRepository`, qui parcourent `ActiveClubScope.groupIds`, **figé à la connexion** (port en lecture seule). Après le retrait d'un groupe du `member`, l'écran ne
  peut donc ni cesser de le lire ni filtrer ses séances sans relire la portée : deux preuves de natures différentes. **(1) Côté serveur, durable** (mesuré à l'émulateur, SDK navigateur, vraies règles ; test `known limit` de `family.test.mjs` ; ne casse **pas** avec FB7, car c'est le comportement des règles) : au retrait du groupe, les écoutes déjà ouvertes (séances, document du groupe) ne reçoivent aucun refus ; une lecture faite par la **même instance** du client est servie par la cible de l'écoute déjà ouverte (une lecture depuis une autre instance est refusée) ; à la **prochaine modification d'une séance ou du document de ce groupe (un renommage suffit)**, l'écoute est refusée (`permission-denied`) ; toute lecture neuve du groupe est refusée, donc après reconnexion le groupe n'est plus lu. **(2) Côté client, destinée à casser avec FB7** : deux tests unitaires `known limit` avec **doubles** (pas des mesures à l'émulateur) : `check_family_access_test` (le lien relu sans le groupe reste `AccessGranted`, car `CheckFamilyAccess` ne regarde que `studentIds`) et `family_space_cubit_test` (l'écran garde les séances du groupe retiré). Ils fixent le comportement du code de l'application et casseront le jour où FB7 corrige. Même reste que pour les fiches : **relire la portée de session sans reconnexion (FB7)**, groupes compris. **Pas de coupure instantanée côté serveur** (mesuré à l'émulateur) : une écoute de données déjà ouverte ne reçoit pas
  de refus au retrait du lien, seulement à la prochaine modification d'une séance ou du document de ce groupe (un renommage suffit), ou du document écouté ; le signal immédiat est l'écoute du `member` du compte (`OwnLinkSource.watch`), et
  aucune donnée nouvelle n'est livrée après le retrait.
- **Hors ligne** : les dernières données restent affichées (cache du SDK, vidé à la déconnexion, FB5a) avec la pastille de la barre ; si une lecture échoue faute de réseau
  alors que des données sont affichées, elles restent avec la mention « Vous êtes hors ligne… » ; premier chargement injoignable = « Réessayer ».
- **Textes (fr, en)** : sobres, sans jargon, **à valider** avec la notice ([../conformite/notice-information-familles.md](../conformite/notice-information-familles.md)), le registre
  (traitement 1 bis) et l'AIPD. Les titres de séance sont un texte libre de l'animateur visible de toute la famille du groupe : consigne à porter au registre.
  « Prénom + initiale » : le domaine n'a pas d'initiale du nom (champ facultatif de la fiche, inutilisé) ; le sélecteur montre l'initiale du **prénom** et numérote les homonymes.
  Aucune donnée personnelle dans les journaux (le cubit n'écrit rien, les codes d'erreur sont techniques).
- **Parcours navigateur réel** (`scripts/emulator_e2e.sh`, mode debug, graine étendue : séances planifiées dans deux jours et passages de Tom et de Marc) : un parent de deux
  enfants voit ses deux enfants et seulement eux (ni Marc, ni Camille, ni la séance des adultes), aucune action d'animateur, adresses d'animateur tapées à la main ramenées à
  « Mes enfants » ; la saisie d'un enseignant (client Node, vraies règles) apparaît **sans recharger** (même `performance.timeOrigin`) et les deux enfants ne se mélangent pas ;
  l'élève de 15 ans voit sa progression seule ; le directeur retire le lien : « Accès retiré » apparaît sans recharger.
- **Reste pour FB7 et FB8** : voir la roadmap (ligne FB6). Pour mémoire ici : relecture de la portée de session en cours de séance de travail
  (retrait partiel, nouvel enfant lié sans reconnexion) ; sélecteur par enfant des **séances** (aujourd'hui l'union des groupes du compte) ; initiale du nom si l'AIPD l'admet ;
  assiduité à rouvrir avec la fédération (B2) ; parcours navigateur **hors ligne réel** (coupure du réseau sur le build compilé) ; export des données d'un élève au parent
  (droit d'accès, FB8) ; notification d'une saisie (hors périmètre : pas de Functions sur Spark).


## Notes de réalisation du lot FB7, partie A (2026-10-20, moteur d'import vers un club Firestore ; aucune décision nouvelle de l'utilisateur)

FB7 est livré en deux parties. **Partie A (ici) : le moteur** (plan d'import calculé avant toute écriture, contrôle d'intégrité, correspondance des groupes, droits par rôle, lots idempotents reprenables, marqueur d'import, règles, tests contre l'émulateur). **Partie B** : l'écran d'import, les parcours navigateur, les textes d'interface et de la notice. **Décision 19 réalisée pour l'import** (lots idempotents reprenables, marqueur de reprise) ; la clôture reprenable et l'effacement serveur restent à FB7 (clôture) et FB8 (effacement). `drift` reste le backend par défaut (`DATA_BACKEND`) : la bascule est un lot après FB7. Aucun accès au projet Firebase réel : fakes et émulateurs `demo-cfa-ffb`.

- **Où vit le code** (FSD). Domaine pur, `features/backup_data/domain/club_import/` : `ClubImportPlanner` (le **plan**, sans lire ni écrire le club : l'état du club est un `ClubInventory`), `ImportIntegrity` (contrôle collecté, pas « premier manquement »), `ClubImportRunner` (écriture des lots), `PrepareClubImport` (lit le fichier, contrôle, lit le club, planifie). Le port `ClubImportStore` est implémenté **dans `app/`** (`FirestoreClubImportStore`, `ClubImportOperations`, `ImportMarkerDocument`), câblé **par `DataBackendModule`** (décision 28 : Firestore avec `DATA_BACKEND=firestore`, sinon `UnsupportedClubImportStore` qui refuse tout en `unsupported`, comme `ImportBackup` sous Firestore), non dans la `data` de la feature : une `data` de feature ne peut pas importer les codecs `entities/*/data` (`check_architecture`), ceux-là mêmes que les dépôts utilisent ; aucun SDK Firebase n'est importé hors de `app/platform`. `BackupCodec.decodeForImport` lit les formats 1 à 5 **sans** refuser doublons et références orphelines (le plan les recense tous) et rend l'empreinte SHA-256 du fichier (`shared/lib/sha256.dart`, Dart pur, vérifié aussi sous dart2js) ; **le format d'export est inchangé** (test d'or : les fichiers `app/test/fixtures/backup/club-small-v1…v5.json` sont régénérés par le code courant). Les identifiants déterministes (appartenance, archive) passent dans `shared/lib/document_ids.dart`, partagés par `ClubPaths` et le plan.
- **Le plan** (`ClubImportPlan`) : statut `ready`, `resumable`, `alreadyImported`, `needsDecisions`, `needsConfirmation` ou `blocked` ; rapport sans donnée personnelle (codes, catégories, compteurs, trois identifiants d'exemple ; jamais un prénom ni une remarque), localisé fr + en (`import_report_text.dart`) ; écritures regroupées en **unités atomiques** (une fiche et ses appartenances ne se séparent pas : `teacherEnrolls` lit la fiche `getAfter`) puis en lots. Le plan est **déterministe** (même fichier, mêmes choix, même rôle : mêmes lots, même `planId`) ; **l'existence de documents ne le change jamais** (elle est appliquée à l'écriture : un document présent n'est jamais réécrit, sa fiche reçoit seulement les groupes manquants par `ArrayUnion`) : c'est ce qui rend la reprise possible, et un marqueur d'un autre `planId` refuse la reprise (`planChanged`).
- **Intégrité avant écriture** : doublons (dont les appartenances), références croisées (élève, groupe, saison, séance), passages orphelins, bornes **du domaine et des règles** (`field_limits.dart` : prénom, historique, présents, titre, nom de groupe, identifiants de 64 caractères au plus, numéros d'exercice, date ISO exactement comme `isoText` : test qui compare l'expression à `firestore.rules`) ; identifiant de groupe sans `_` (les règles s'en servent), identifiant de document légal ; références du catalogue (`BackupRules`, une fois le fichier cohérent). Un fichier qui ne se lit pas du tout donne un plan `blocked` avec son motif, jamais une erreur du service.
- **Correspondance des groupes** : chaque groupe du fichier est **créé** (directeur, administrateur), **associé** à un groupe du club, ou — s'il existe déjà sous le même identifiant (UUID) — reconnu sans choix. Deux groupes du fichier sur un même groupe du club : refusé (`mergeNotConfirmed`) sauf choix explicite (`confirmedMerges`). Un groupe associé reçoit les séances, saisies et appartenances du groupe du fichier, avec **son** saison (celle du club) ; l'identifiant déterministe d'une saisie liée (`groupe_AAAAMMJJ_séance`) **suit le groupe du club** (les passages citent l'identifiant final), une saisie libre garde son UUID ; public différent, saison close du groupe associé, date hors saison : refusés. **Séances sans groupe** (et élève sans groupe dont les données — acquis, bilans, acquittements — n'ont pas de séance pour leur donner un groupe) : le plan exige un choix explicite par élément (rattacher à un groupe, ou ignorer) et ne devine jamais.
- **Droits par rôle, dits avant d'écrire** (`_denied`, miroir de `firestore.rules`) : le directeur et l'administrateur écrivent partout dans le club ; l'enseignant n'écrit que dans **ses** groupes, **ni saison, ni groupe, ni archive** ; sa fiche neuve doit avoir toutes ses appartenances **ouvertes**, dans ses groupes, avec `from` égal au début de l'historique de la fiche (`teacherEnrolls`) ; une fiche refusée n'existera pas, **ses passages et ses acquis sont refusés avec elle**. Le plan refuse (`blocked`, `roleDenied` par catégorie) au lieu de n'importer qu'une partie en silence ; seules les saisons et archives d'un enseignant sont écartées, avec l'avertissement `roleScope`.
- **Lots et budget** : 400 écritures au plus **marqueur compris** (399 de données) ; fiche avant ses données (une règle lit la fiche **avant** le lot : `studentExists`, `studentInGroup`) donc jamais dans le même lot ; **plafond quotidien** : le plan calcule les jours nécessaires (`daysNeeded`, moitié des 20 000 écritures par jour de Spark par défaut, laissée au club le jour de l'import) et avertit (`largeImport`) ; une exécution s'arrête avant le lot qui dépasserait le budget **du jour** (le premier lot du jour progresse toujours) et reprend un autre jour. **Le plafond est quotidien, pas par exécution** : le compte du jour est un état persistant de l'appareil (`ImportDailyLedger`, `KeyValueImportDailyLedger`, une clé par compte `AAAA-MM-JJ:n`, jour de l'horloge locale), lu au début de l'exécution et incrémenté après chaque lot (un lot dont l'accusé manque, resté dans la file du SDK, compte aussi) ; « Reprendre » le même jour s'arrête aussitôt (`paused`, zéro écriture), le lendemain l'import continue. Il borne **cet appareil** : le quota Spark est celui du projet (la moitié est laissée au club). **Découverte, mesurée à l'émulateur avec les vraies règles** : les règles ne tolèrent que **20 documents lus par lot** d'écritures (`get`, `exists`, `getAfter`, un même document comptant une fois), dont le `member` et `admins/{uid}` de l'auteur ; un lot de passages qui cite plus de 19 fiches distinctes (18 pour un administrateur ou un enseignant) est **refusé en entier**. Le plan découpe donc aussi par **fiches distinctes** (`ImportLimits.accessBudget`, 18 : passages, acquis, bilans et acquittements ; fiche neuve d'un enseignant plus son groupe, soit 17 fiches) ; la limite est prouvée exacte (17 passent, 18 sont refusées) par `import.test.mjs`. Les lots sont donc plus nombreux que 1992 / 399 pour un fichier dont les passages alternent entre plus de 18 élèves ; l'ordre du fichier est conservé (pas de regroupement par élève : la consigne est un `recordedAt` croissant dans l'ordre du fichier).
- **Marqueur d'import** `clubs/{c}/imports/{fileId}_{uid}` (`fileId` = empreinte SHA-256 du fichier, `uid` = compte de l'auteur : **un marqueur par fichier et par auteur**, voir les correctifs de revue plus bas) : `planId`, `lots`, `done`, `writes`, `restored` (nombre d'élèves dont l'animateur a confirmé le rétablissement), `role`, `state`, `createdBy`, `startedAt`, `updatedAt` ; **aucun identifiant d'élève** (`createdBy` est l'`uid` pseudonyme de l'auteur, comme `createdBy` d'un acquittement : consigné au registre des traitements). Règle (testée à la grille, `matrix.test.mjs`, et mutée) : le premier lot le **crée** avec `done == 1` ; chaque lot suivant l'**avance d'exactement un**, **dans le même lot atomique** que ses écritures ; les autres champs sont figés ; jamais supprimé ; **chaque marqueur n'est lu (`get`) que par son auteur ; la liste est réservée aux gestionnaires** (comparaison de l'identifiant à l'`uid` par chaîne, jamais par une regex construite depuis l'`uid` : un `uid` « .* » ne lit pas le marqueur d'un autre ; test et mutation) ; le `role` du premier lot est celui de son auteur et `createdBy` **égale `request.auth.uid`** à la création. **Seul l'auteur fait avancer son marqueur** (l'identifiant porte son `uid`, aucun gestionnaire n'avance celui d'un autre) et `createdBy` est figé : sans cela un enseignant pouvait pousser le marqueur « running » d'un directeur ou d'un autre enseignant d'un cran sans que le lot soit écrit, et le moteur, croyant le lot écrit, ne l'écrivait jamais (perte silencieuse de passages d'élèves mineurs) ; tests `import.test.mjs` et grille `matrix.test.mjs`. **Abus corrigé à la revue** (voir plus bas) : le marqueur est propre à son auteur, un enseignant ne peut plus bloquer l'import d'un fichier. **Voie d'import et convergence** (le `createIfAbsent` d'une transaction n'existe pas dans un lot) : **le refus d'écraser est porté par les règles, pas par l'inventaire** (lu au début de l'exécution, il peut être périmé : la lecture et le lot ne sont pas atomiques) : chaque document créé par l'import porte `importedAt` (date du serveur, posée à la création seulement : il ne prouve PAS l'origine d'import, n'importe quel animateur peut le poser sur une création ordinaire ; **ajoutée à la liste blanche** de saisons, groupes, appartenances, fiches, archives, séances, acquis, bilans, acquittements) et `importStampValid()` refuse **toute mise à jour** qui pose ou change ce champ (une mise à jour peut le renvoyer inchangé seulement si la marque est **strictement antérieure à `request.time`** : une mise à jour dans la même milliseconde que la création est refusée, ce qui ferme l'écrasement entre deux lots simultanés) ; une écriture d'import sur un document déjà présent (créé entre l'inventaire et le lot par une saisie, une clôture ou un autre import, y compris d'un autre fichier : autre empreinte, autre marqueur) est une mise à jour et le lot est **refusé en bloc**, marqueur inchangé. Passages et saisies le sont déjà par leur `createdAt` figé. La fusion par `ArrayUnion` des groupes d'une fiche existante n'écrit pas `importedAt` et reste permise ; les mises à jour de l'application (fusion, `UpdateOp`) ne changent pas la marque. Test : `import.test.mjs`, « un document créé entre l'inventaire et le lot n'est jamais écrasé », une assertion par collection. Et chaque lot est un **compare-and-swap sur le marqueur** : un lot ne s'applique qu'une fois, qu'il soit rejoué après une coupure, par un second appareil ou par la file d'attente du SDK. Un lot refusé parce que le marqueur a déjà avancé est un **succès** (relu au serveur) ; toute autre erreur laisse le marqueur où il était. Reprise : relire le marqueur, reprendre à `done`. Le même fichier ne s'importe pas deux fois (`alreadyImported`). **Hors ligne** : `commit` attend l'accusé du serveur (jamais `ClubStore.commit`) ; sans réponse en 30 s, l'import est dit interrompu (`unavailable`) et le lot reste dans la file du SDK, appliqué **au plus une fois** ; le parcours navigateur hors ligne est de la partie B.
- **`recordedAt` strictement croissant** : le plan écrit `recordedAt` = date du plan + *i* µs, *i* = rang du passage dans le fichier (les passages ignorés ne laissent pas de trou : le rang est celui du fichier), `createdAt` = date du serveur **du lot** (égale dans un lot, croissante d'un lot à l'autre : relue par `import.test.mjs`) ; l'ordre dérivé est donc celui du fichier. **Limite** : les passages importés se rangent **après** ceux que le club avait déjà (leur `createdAt` est plus récent) ; un acquittement porte l'`uid` de **l'auteur du lot** (une reprise ne se fait qu'avec le même compte ; un autre compte repart du premier lot, sous son propre marqueur et son propre `uid`).
- **Élèves effacés (ADR 0019)** : un import d'un fichier **antérieur à une clôture ou à un effacement** rétablit des élèves effacés. Le plan **détecte ce qu'il peut** et exige une confirmation explicite égale au nombre d'élèves concernés (`needsConfirmation`, `restoredStudents`, `decisions.restoreConfirmed`) : (1) élèves du fichier absents du club alors que le club a une saison **close à la date d'export ou après** ; (2) élèves absents du club et d'une **sauvegarde plus récente** fournie par l'animateur ; (3) saison que le fichier donne pour ouverte alors que le club l'a close : **refus** (`reopensClosedSeason`, comme drift) ; (4) élève dont l'effacement est **en cours** (`erasing`) : refus. **Non détectable** (aucune trace nominative, décision 19 et ADR 0019 : ni journal, ni liste d'identifiants effacés) : un élève effacé **seul** (`EraseStudent`), sans clôture, d'un club où aucune saison n'a été close ; un club **vide** (autre appareil) ; un enseignant ne voit pas les fiches hors de ses groupes (une fiche existante invisible serait prise pour absente : l'écriture serait alors refusée par les règles, lot atomique, marqueur inchangé). Un fichier ancien de plus de 31 jours (fenêtre de migration d'environ un mois, C2) est signalé (`staleFile`) : le travail fait depuis l'export n'y figure pas.
- **Rien d'autre n'est importé** : les **réglages** du fichier ne le sont pas (les réglages du club sont partagés ; avertissement `settingsIgnored`) ; aucun document existant n'est modifié (les règles le garantissent : marque `importedAt`).
- **Vérifié contre l'émulateur** (`scripts/rules_test/import.test.mjs`, appelé par `scripts/rules_test.sh` qui produit avant les écritures avec `app/tool/import_plan_fixture.dart`, planificateur de l'application sur des sauvegardes **fictives**) : un fichier de **1992 écritures** importé par le directeur puis par l'administrateur, lot par lot, relu en entier et comparé au plan ; passages relus dans l'ordre du fichier ; un enseignant importe dans son groupe (66 écritures ; 30 fiches neuves en deux lots), est refusé hors de son périmètre, pour les saisons et groupes, et ne peut pas se dire directeur ; **le miroir du plan** (12 écritures permises à l'enseignant acceptées, 48 refusées refusées une à une et acceptées du directeur) ; la **convergence** (lot rejoué, lot sauté, rejeu par un autre appareil, reprise après N lots par le même compte (autre appareil), import terminé qui n'avance plus, passage non écrasé) ; **jamais d'écrasement** (pour chacune des 11 collections, un document créé entre l'inventaire et le lot fait refuser le lot en bloc, marqueur absent ; le témoin sans document vivant passe) ; **marqueur lié à son auteur** (un enseignant ne fait pas avancer le marqueur d'un directeur ni d'un autre enseignant, seul l'auteur le fait, `createdBy` figé). Ce test a trouvé deux défauts avant la livraison : le budget de 20 lectures par lot, et des passages d'une fiche refusée annoncés permis. **Particularité de l'émulateur** : refuser un lot de 400 créations y prend un temps considérable (il détaille l'évaluation de chacune) ; les refus se prouvent donc sur un extrait du lot (documenté dans le test), les lots acceptés ou rejoués sur des documents existants sont instantanés.
- **Reste à faire en partie B** (voir la roadmap) : écran d'import (choix du fichier, rapport, choix des groupes, des séances sans groupe, confirmation des élèves effacés, avancement, reprise, reprise le lendemain), parcours navigateur (dont hors ligne réel), textes de la notice et de l'aide, sortie de l'import local (`ImportBackup` reste `unsupported` sous Firestore : l'écran aiguille vers `PrepareClubImport`), conservation et suppression du marqueur d'import (aujourd'hui jamais supprimé par l'application : console seule).


### Correctifs de la revue de FB7, partie A (2026-10-20)

- **P1, marqueur propre à son auteur** (abus important). Avant : le marqueur s'appelait `imports/{empreinte}` ; un enseignant pouvait le créer au nom d'un fichier (n'importe quel `planId`, `lots == 1`, état `done`) et le directeur, face à un marqueur d'un autre plan, était bloqué en `planChanged` sans pouvoir importer (seule la console supprime un marqueur). Maintenant : l'identifiant est **`{empreinte}_{uid de l'auteur}`** (`ClubPaths.importMarker(fileId, author)`), et les règles exigent `markerId == fileId + '_' + request.auth.uid` à la création **et** à l'avancement : personne ne crée, ne lit ni n'avance le marqueur d'un autre, gestionnaire compris ; un marqueur forgé sous l'empreinte seule ou sous l'`uid` d'un autre est refusé. Le marqueur porte donc l'`uid` de son auteur **par construction** (en plus de `createdBy`, qui lui est égal). **Conséquence assumée** : l'idempotence entre deux auteurs ne vient plus du marqueur. Un second auteur qui importe le même fichier crée **son** marqueur ; ce qui l'empêche de rien écraser est `importedAt` et les identifiants du fichier (un document présent n'est jamais réécrit, un lot qui tombe dessus est refusé en bloc, marqueur compris) et son plan le voit par l'inventaire (les documents déjà là ne sont pas réécrits). Une reprise d'un même import ne se fait donc qu'avec **le même compte** (autre appareil permis) ; un autre compte repart du lot 0 sur un club déjà en partie écrit. Tests d'attaque (rejoués sur l'émulateur) : T1 un enseignant crée un marqueur terminé au nom du fichier (sous l'empreinte seule, sous l'`uid` du directeur) : refusé ; T2 le marqueur qu'il crée sous **son** `uid` ne touche pas le directeur, qui importe tout ; T3 il ne lit ni n'avance celui du directeur ; grille `matrix.test.mjs` suite `imports` (création à son nom seulement, lecture de son marqueur seulement, avancement refusé à tous sur le marqueur d'un autre) ; mutations dans `testing.md`.
- **P2, identité du plan**. `planId` couvre maintenant le fichier, la taille des lots, **toutes les décisions** (correspondance des groupes, séances rattachées, élèves sans groupe, fusions confirmées) **et le contenu de chaque écriture** (`ImportWrite.content` : clé, groupe, saison et élève dénormalisés, entité complète) lot par lot. Une reprise avec un autre mapping, un autre rattachement ou une autre portée est un autre plan : `planChanged`. Ne s'y trouvent pas : `recordedAt` (il part de l'heure du calcul, qui change d'un jour de reprise à l'autre ; seul l'ordre du fichier compte) et la confirmation des élèves effacés (elle ne fait que rendre le plan exécutable, ce qu'elle rétablit est dans les écritures ; une reprise ne la redemande pas).
- **P3, ce qu'un enseignant ne peut pas voir**. L'inventaire d'un enseignant ne contient que les fiches de ses groupes ; une fiche du fichier déjà présente hors d'eux lui est **invisible** (les règles refusent aussi la lecture d'une fiche absente : présence et absence ne se distinguent pas). Le plan la croirait neuve et annoncerait permises des écritures refusées en bloc à l'exécution. **Le plan le dit avant d'écrire** : `ImportReport.unverifiableStudents` compte les fiches qu'un enseignant créerait sans pouvoir vérifier leur absence, le statut est `needsConfirmation` tant que `ImportDecisions.unverifiedConfirmed` n'égale pas ce nombre (même mécanisme que le rétablissement des effacés ; une reprise ne le redemande pas ; zéro pour un gestionnaire, qui lit tout le club), et le rapport en dit la conséquence (`importUnverifiableNotice`, fr + en) : si l'une existe, le lot est refusé en entier, rien n'est écrit, un directeur doit importer. Prouvé : doubles qui reproduisent la visibilité d'un enseignant (`club_import_planner_visibility_test.dart`, `prepare_club_import_test.dart` : fiche semée hors de ses groupes, requêtes de l'adaptateur) et contre l'émulateur (`import.test.mjs`, « une fiche du fichier qui existe hors des groupes de l'enseignant lui est invisible »). **Partie B** : l'écran présente cette confirmation.
- **P4, lecture du marqueur au serveur**. Le port `DocumentStore` gagne `getFromServer(path)` (`Source.server` dans `FirestoreSdkAccess`, `unavailable` hors ligne, jamais le cache) ; `FirestoreClubImportStore` s'en sert pour le marqueur (`readMarker` et `inventory`) : hors ligne, l'import dit `unavailable` (échec localisé : « interrompu », reprise plus tard) au lieu de croire un cache en retard. Tests : double dont le cache diffère du serveur, cache qui garde un marqueur que le serveur n'a plus, hors ligne.
- **P5, i18n et placement**. Le séparateur « catégorie : message » passe par une clé ARB à paramètres (`importProblemInCategory`, fr « {category} : {message} », en « {category}: {message} »), testée par langue sur des littéraux. `InMemoryImportDailyLedger` (double de test) quitte le domaine de production pour `app/test/support/`.
- **P6, bornes et règles**. (a) Plafond quotidien : tests au coût exact du lot (accepté) et plafond moins un (refusé), mutation `>` en `>=` tuée. (b) `importStampValid()` : une mise à jour ne peut plus poser `importedAt: null` (absent devenant `null`) ni aucune valeur ; la clé n'y figure que si le document la portait avec la même valeur ET une marque **strictement antérieure à `request.time`** (elle peut être ôtée) ; test d'attaque et mutation. **Course fermée (Q1)** : avec la seule égalité, deux lots de deux auteurs créant les mêmes documents à la même milliseconde de serveur voyaient le second comme une mise à jour du premier et l'écrasaient (mesuré : deux lots acceptés dans 20 essais sur 30) ; la marque strictement antérieure le refuse (30 essais en parallèle, 0 écrasement ; l'ancienne règle échoue). (c) **Le plafond quotidien est tenu PAR APPAREIL ET PAR COMPTE** (stockage local clé/valeur) et non pour le projet : un second appareil ou le vidage du stockage le contourne, et le quota Spark, lui, est celui du projet. Dans ce cas Spark refusera les écritures au-delà du quota : l'échec est **visible** (le lot est refusé, l'import dit `failed`) et la **reprise a lieu le lendemain**, sans perte (le marqueur n'a pas avancé).
