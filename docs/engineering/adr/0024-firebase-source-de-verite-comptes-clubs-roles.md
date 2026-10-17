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
| `clubs/{c}/memberships/{studentId_from}` (appartenance datée) | — | lecture de ses groupes | lecture, écriture | idem | — |
| `clubs/{c}/students/{id}` (prénom, initiale, public) | lecture de la fiche liée (`studentIds`) | lecture de ses groupes ; crée | lecture, écriture, effacement | idem | — |
| `clubs/{c}/sessions/{id}` (séance planifiée) | lecture des séances de ses groupes | lecture, écriture de ses groupes | club | idem | — |
| `clubs/{c}/records/{id}` (saisie, assiduité, étiquettes) | **aucune lecture** (expose les camarades présents) | lecture, écriture de ses groupes | club | idem | — |
| `clubs/{c}/attempts/{id}` (un passage) | lecture de ceux de la fiche liée | lecture, écriture de ses groupes | club | idem | — |
| `clubs/{c}/acquisitions/{id}` | lecture de celles de la fiche liée (`studentIds`) ; `GetStudentShowcase` lit `AcquisitionRepository.forStudent` | ses groupes | club | idem | — |
| `clubs/{c}/assessments/{id}`, `acknowledgements/{id}` | — (bilans et alertes exclus par B2) | ses groupes | club | idem | — |
| `clubs/{c}/archives/{season_public}` (archive agrégée) | — | lecture | lecture, écriture à la clôture | idem | — |

« Ses groupes » = `members/{uid}.groupIds` ; « sa fiche » = `members/{uid}.studentIds`. Les noms exacts des champs et des collections sont
figés par les tests de règles de FB3, pas par ce tableau. Le catalogue, les fiches et les diagrammes restent des **assets**.
15. **Conflits (B5)** : dernier écrit gagne **par document** pour les scalaires (nom, réglages, titre) ; les listes datées
    (`audienceHistory`, appartenances) sont des **documents ajoutés, sans réécriture** ; suppression **physique** par défaut ;
    `deletedAt` seulement s'il a un sens métier ; l'acquittement « Vu » est **partagé par club** et enregistre l'`uid`. Les méthodes
    `idsEver*` de l'effacement par lien (ADR 0020) sont à réexpliquer sur les appartenances closes. `backupReminderDays` est retiré en
    FB5 pour les clubs synchronisés. Les **réglages du club** (`RulesConfig`) sont séparés des **préférences d'appareil** (A11).

### A6 — Rattachement parent et élève

16. Rôle **`guardian`** distinct de `student`. Le lien vit dans **`members/{uid}.studentIds`** : un seul `get()` donne rôle et périmètre.
    Un parent dont les enfants sont dans deux clubs a **un `member` par club**. Le parent garde la lecture quand l'élève de 15 ans a son
    compte ; le directeur peut la retirer. Un tableau `linkedUids` sur la fiche n'est ajouté que si un écran en a besoin.
    Un uid = **un rôle par club** : le cumul parent et enseignant dans un même club n'est pas prévu. **À valider : l'animateur, avant FB3**
    (défaut : rôle unique ; le rôle en liste serait un amendement).

### A7 — Identité des données et atomicité (amendements 0006, 0016, 0019)

17. **ADR 0006 amendé** : un **passage est un document** ; `passIndex` est **dérivé** (tri par date, `createdAt` serveur, identifiant) au lieu
    d'être stocké et renuméroté. La correction en place d'un passage reste possible ; la suppression ne renumérote plus rien.
    `ExerciseAttempt` et `ExerciseResult.derive` changent ; ce changement précède FB4.
18. **ADR 0016 amendé** : une saisie liée à une séance du catalogue reçoit un **identifiant déterministe** (groupe, jour, séance du
    catalogue) : deux appareils qui la créent écrivent le même document. Une saisie libre garde un UUID. Le transfert silencieux d'une
    saisie vers une autre séance du catalogue devient explicite.
19. **ADR 0019 amendé** : `UnitOfWork` devient un **`WriteBatch`** pour les petits cas ; la clôture de saison, la purge et l'import sont
    des **lots idempotents reprenables** (500 écritures par lot, marqueur de reprise, reprise après coupure). Les garanties « tout ou
    rien » et « aucune trace nominative » de l'ADR 0019 deviennent : atomicité **par lot**, et **marqueur `erasing` transitoire** sur la
    fiche pendant un effacement en cours, supprimé avec elle ; ni journal ni liste d'identifiants effacés (pas de tombstone).
    Les décisions d'atomicité sont testées dans la suite de contrat.

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
    l'émulateur**), sans flavors natifs ; bascule de production à la fin de FB4 ; ordre : réglages, élèves / groupes / saisons, séances /
    saisies / passages, puis acquisitions, acquittements, bilans, archives.
29. **Déploiement des règles (B6)** : tests de matrice complète (rôle × action) et de refus par défaut **obligatoires** ; déploiement par la
    CI protégé par ces tests, avec protection de branche, **après FB3** (compte de service élargi) ; manuel d'ici là.
30. **SDK web (B7)** : chargé depuis `gstatic.com` en FB1 (non bloquant au démarrage), **servi localement, épinglé et précaché avant FB5**
    si le plugin l'accepte (à vérifier en FB1) ; `--wasm` toujours non adopté, sans COOP ni COEP (ADR 0022).
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
  - **C3 (FB8)** App Check en surveillance puis strict ; fournisseur web à lister au registre (reCAPTCHA ajoute Google comme destinataire de
    l'IP) ; MFA pour directeur et admin à étudier.
  - **C4 (FB5)** persistance hors ligne activée partout, cache vidé à la déconnexion, avertissement appareil partagé, pastille discrète
    « À jour / Envoi en attente (n) / Hors ligne ». **Libellés fr/en à valider : l'animateur.**
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
