# ADR 0001 — Persistance locale avec drift, Firebase plus tard

- Statut : accepté (2026-10-11), **implémenté (2026-10-12)** ; décision de l'assistant sur la base de `research/persistance-locale.md` et `research/firebase.md`, validable par l'animateur.
- Contexte : un seul animateur, mêmes élèves toute la saison, données de mineurs, 6 plateformes (dont Linux, non supporté par FlutterFire).
- Décision :
  1. Interfaces de repository dans `domain` ; implémentation **drift (SQLite)** dans `data` ; implémentation **in-memory** pour tests/BDD.
  2. Sauvegarde/restauration par **export JSON versionné** (indépendant du schéma SQL).
  3. Schéma prévu pour la synchronisation future : id UUID texte, `createdAt`, `updatedAt`, suppression logique.
  4. **Firebase : plus tard**, seulement si synchronisation multi-appareils voulue ; il se branchera derrière les mêmes interfaces.
- Conséquences : aucune création de projet Firebase requise maintenant ; minimisation des données (prénom, public) ; la persistance web (wasm + worker) demande une vérification dédiée.
- Garde-fou : une suite de tests de contrat unique est exécutée contre toutes les implémentations de repository.

## Mise en œuvre (2026-10-12)

### Compatibilité des outils (vérifiée, pas supposée)

`flutter pub add drift drift_flutter dev:drift_dev` résout sans conflit avec
freezed 4.0.1, injectable_generator 3.1.3, bdd_widget_test 2.1.4 et
build_runner 2.16.1 (drift 2.35.2, drift_dev 2.35.1, drift_flutter 0.3.1,
sqlite3 3.5.2). `dart run build_runner build` exécute drift_dev, freezed,
injectable et bdd_widget_test dans la même passe sans erreur. **Sembast n'est
donc pas nécessaire** : la recommandation de la recherche est confirmée.

Écart avec la recherche : drift_flutter 0.3.1 dépend encore des paquets
`sqlite3_flutter_libs` et `sqlcipher_flutter_libs` (versions `0.6.0+eol` et
`0.7.0+eol`, vides, marquées « Not used anymore »). Ils sont tirés
transitivement ; SQLite vient des build hooks de `sqlite3` 3.x.

### Architecture

- **Domaine** : ports `StudentRepository`, `GroupRepository`, `SeasonRepository`,
  `SessionRecordRepository`, `AttemptRepository`, `AssessmentRepository`,
  `SessionRepository`, tous avec `all()` (ou `getAll()`) et `delete(id)`
  (suppression logique). Ports transverses dans `shared/lib` : `Clock`,
  `UnitOfWork`, `StorageStatus` (+ `StorageImplementation`), `IdGenerator`
  (`UuidV4Generator` en production, `SequentialIdGenerator` en test).
- **Données** : `shared/persistence/` porte la base drift (`AppDatabase`,
  `tables.dart`, `DriftUnitOfWork`, `DriftStorageStatus`, `openAppDatabase`) ;
  chaque entité a son `Drift…Repository` dans `entities/<x>/data/`. Le domaine
  n'importe aucun paquet de données.
- **Environnements get_it/injectable** : `prod` (drift, UUID, ouverture de la
  base au lancement via `@preResolve`) et `test` (dépôts en mémoire,
  identifiants séquentiels). `configureDependencies` est asynchrone.

### Schéma (version 6)

- Chaque agrégat : `id` UUID texte unique, `seq` (ordre d'insertion stable,
  clé primaire), `createdAt`, `updatedAt`, `deletedAt` (suppression logique :
  la ligne reste, les lectures l'ignorent, une nouvelle sauvegarde la rétablit).
- Données minimales : prénom et public ; aucune date de naissance. Seule
  donnée libre : `assessments.comment` (remarque facultative sur un bilan de
  maturité, **500 caractères au plus**, `MaturityAssessment.maxCommentLength`),
  ajoutée en version 2. Elle peut nommer un mineur : elle suit donc la
  minimisation (facultative, bornée, jamais exigée, effacée avec l'élève).
- `planned_sessions.sheet_id` (version 3, texte nullable) : identifiant de la
  séance du catalogue suivie par une séance planifiée (`demi-bille-2`). Les
  séances du catalogue sont des assets : pas de clé étrangère. Nul = séance
  libre. La lecture ne lève jamais pour un identifiant inconnu du catalogue
  (l'affichage dit « séance indisponible ») ; le chemin d'écriture de `add`
  (insertion **et** `DoUpdate`) l'écrit, sans quoi une replanification ou un
  import perdrait le lien. À l'import, un identifiant inconnu est refusé
  (`backupInconsistent`, `BackupRules`).
- `planned_sessions.date` (version 4, texte non nul, ADR 0007) : jour de la
  séance planifiée ; `planned_sessions.group_id` (version 4, nullable) : groupe
  qui la suivra, sans clé étrangère (groupes supprimés logiquement, l'affichage
  dit « groupe indisponible ») ; `session_records.sheet_id` (version 4,
  nullable) : séance du catalogue notée par la saisie, même règle de lecture
  que `planned_sessions.sheet_id` (jamais d'échec, import refusé si inconnue).
- `block_acquisitions` (version 5, ADR 0008) : marqueur « bloc acquis au
  positionnement » (`student_id`, `block_id`, `date` jour normalisé, `source`
  texte), index `acquisitions_by_student`. Aucune clé étrangère : l'élève est
  supprimé logiquement et le bloc est un asset du catalogue. Effacée
  physiquement avec l'élève (`EraseStudent`, suppressions logiques comprises) ;
  à l'import, bloc inconnu refusé (`backupUnknownBlock`).
- `backup_exports` (version 6, lot U6) : date de la dernière sauvegarde
  réellement enregistrée (`id` auto-incrémenté, `exported_at` en ISO 8601,
  `attempt_count` = passages du club à cet instant) ; la ligne la plus récente
  fait foi. Hors conventions d'agrégat (ni UUID, ni `seq`, ni colonnes
  d'audit) : donnée locale à l'appareil, **absente du fichier de sauvegarde**,
  inchangée par un import.
- Dates stockées en texte ISO 8601 (relues à l'identique, locale ou UTC).
- Tables enfants (`student_audience_changes`, `group_memberships`,
  `session_presences`) remplacées avec leur parent. Aucune clé étrangère entre
  agrégats (le domaine ne l'impose pas) ; `PRAGMA foreign_keys = ON`.

### Migrations

- `schemaVersion = 7` (`AppDatabase.currentSchemaVersion`). Instantanés
  `app/drift_schemas/app_database/drift_schema_v1.json` à
  `drift_schema_v7.json`,
  helpers générés `app/test/drift/app_database/generated/` (`dart run drift_dev
  make-migrations`, puis `dart run drift_dev schema generate`).
- Migration `from1To2` (`stepByStep`) : ajoute `assessments.comment`
  (nullable) ; `from2To3` ajoute `planned_sessions.sheet_id` (nullable, aucune
  transformation de données) ; `from3To4` **recrée** `planned_sessions`
  (`TableMigration`, première migration avec transformation : `date` prend
  `created_at` **tel quel** pour les lignes existantes, instant UTC compris,
  sans conversion en heure locale ; `group_id` nulle) et ajoute
  `session_records.sheet_id` ; `from4To5` crée la table `block_acquisitions` et
  son index (additive) ; `from5To6` crée la table `backup_exports` (additive) ; `from6To7` crée la
  table `app_settings` (une ligne, additive, ADR 0012).
  Tests
  (`test/unit/shared/persistence/migration_test.dart`) : le schéma créé par le
  code égale les instantanés v1 à v7, une base v1 migre vers v2, une base v2
  vers v3, une base v3 vers v4 une base v4 vers v5 et une base v5 vers v6 et une base v6 vers v7 en gardant ses lignes (la
  séance planifiée prend sa date de création, la séance saisie reste sans séance
  du catalogue, les tables ajoutées démarrent vides),
  une base créée depuis un instantané est lisible, et l'ouverture d'une base
  d'une version plus récente (v8) est **refusée** (`DowngradeNotSupported`). Chaque
  évolution suivante ajoute son instantané, son `fromNToN+1` et son test.

### Sauvegarde JSON (`features/backup_data`)

- Format `billard-cfa-backup`, `schemaVersion` **propre** (2 ; 1 et 2 sont lus, la clé facultative
  `data.settings` porte les réglages du club, ADR 0012), indépendant du
  schéma SQL ; `exportedAt` informatif. Pas de métadonnées de persistance
  (horodatages, suppressions logiques) dans le fichier.
- `ExportBackup` / `ImportBackup` : cas d'usage du domaine ; `BackupCodec`
  (encodeur, décodeur, unicité des identifiants, références résolues).
- Import : **fusion par identifiant** (idempotent), validation complète avant
  la première écriture, puis une `UnitOfWork` (une transaction SQLite).
  Refus sans écriture : fichier illisible ou trop grand (`backupUnreadable`),
  version inconnue (`backupVersionUnsupported`), valeur ou entité invalide
  (`backupInvalid`), doublon ou référence orpheline (`backupInconsistent`).
- Bornes (fichier hostile ou corrompu) : 10 Mo de texte au plus
  (`BackupCodec.maxContentLength`, contrôlé par le sélecteur de fichier avant
  toute lecture en mémoire), imbrication JSON de 12 niveaux au plus, 500
  caractères par chaîne et 50 000 éléments par liste (`JsonReader`).
- Règles métier rejouées avant écriture (`BackupRules`) : exercice présent au
  catalogue (`backupInconsistent`), élève présent à la séance du passage
  (`backupInconsistent`), au plus `maxPassesPerExercisePerSession` passages
  par (séance, élève, exercice) et `passIndex` unique (`backupInvalid`),
  séance dans la période de sa saison, public identique à celui du groupe,
  saison identique à celle du groupe, blocs connus, bilan non daté du futur.
  Un passage dont le total est inférieur aux tentatives de la fiche est
  toléré à l'import (il ne compte jamais comme réussi) ; la saisie le refuse.

### Web

- `app/web/sqlite3.wasm` (release `sqlite3-3.5.2`, version consignée dans
  `app/web/sqlite3.wasm.version`) et `app/web/drift_worker.js` (identique au
  fichier du paquet drift 2.35.2). `dart run scripts/sync_web_assets.dart`
  les synchronise ; `--check` (inclus dans `scripts/check.sh`) échoue si le
  worker diffère du paquet résolu ou si la version du wasm ne suit pas
  `pubspec.lock`.
- `flutter build web --release` réussit et publie les deux fichiers.
- Le navigateur choisit le stockage (OPFS, IndexedDB, mémoire) :
  `StorageStatus.implementation` l'expose (`persistent == false` en mémoire),
  avec `degradationReasons` ; l'interface doit avertir et proposer l'export JSON
  (écran à faire). OPFS exige les en-têtes COOP `same-origin` et COEP
  `require-corp` ; sans eux, repli IndexedDB. Non vérifié dans un navigateur
  réel dans cette passe (build web seulement).

### Garde-fous

- Suite de contrat unique (`test/contract/`) exécutée contre l'implémentation
  en mémoire **et** drift (`NativeDatabase.memory`) : repositories et
  export/import (aller-retour, idempotence, fusion, refus sans écriture).
- Atomicité : un échec d'écriture en cours d'import annule tout (test drift
  dédié). L'implémentation en mémoire a la même garantie : les dépôts
  inscrivent chaque écriture dans un journal d'annulation porté par la zone de
  l'unité de travail (`InMemoryJournal`), rejoué en ordre inverse si le corps
  lève. La suite de contrat vérifie l'annulation (créations, remplacements,
  suppressions, unités imbriquées) sur les deux implémentations.

### Effacement et conservation (données de mineurs)

- **Effacement physique d'un élève** (`EraseStudent`, écran « Effacer cet
  élève » de la fiche, confirmation obligatoire) : `DELETE` SQL des lignes de
  l'élève, de son historique de public, de ses appartenances, de ses présences,
  de ses passages et de ses bilans, **y compris les lignes supprimées
  logiquement**. Tout ou rien (`UnitOfWork`). Les groupes et séances restent,
  sans l'élève. La suppression logique (`deletedAt`) reste réservée à la
  synchronisation future ; elle n'est pas un effacement.
- **Durée de conservation** `[Prop]` (à valider par l'animateur ; **remplacée le
  2026-10-16** par la décision FB 8 de la roadmap, saison en cours puis
  suivante, appliquée par la clôture de saison de l'[ADR 0019](0019-cloture-de-saison-archive-agregee-et-effacement-en-lot.md)) : les données
  d'un élève sont conservées pour la saison en cours puis effacées à la fin de
  la saison ou à la demande de l'élève ou de ses parents ; aucune donnée ne
  quitte l'appareil sans export volontaire. Les fichiers de sauvegarde déjà
  exportés ne sont pas touchés : l'animateur les supprime lui-même.
- **Aucune copie automatique hors appareil** : Android `allowBackup="false"`
  (`AndroidManifest.xml`), dossier Documents iOS exclu des sauvegardes iCloud
  (`AppDelegate.swift`, `isExcludedFromBackup`). Le test
  `app/test/tool/platform_privacy_test.dart` vérifie ces deux réglages ; la
  prise en compte par iOS n'est pas vérifiable hors macOS.
