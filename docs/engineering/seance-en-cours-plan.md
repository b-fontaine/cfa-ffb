# Plan de conception : séance en cours persistée (lot 10b)

Statut : **livré** (2026-10-17, voir § 17 « Réalisation et écarts » ; les §§ 1 à 16 sont la conception d'origine, corrigée là où le § 17 le dit). Solde la décision **U-5** de
[aujourdhui-plan.md](aujourdhui-plan.md) et l'ancien report « compteurs et score persistés (G7) » de
[guide-mener-plan.md](guide-mener-plan.md) § 2. Décision structurante : [ADR 0020](adr/0020-seance-en-cours-persistee-locale-hors-sauvegarde.md).
S'appuie sur les ADR [0013](adr/0013-acquittement-des-alertes.md), [0014](adr/0014-fiche-en-parcours-vue-eleve-et-vue-de-groupe.md),
[0015](adr/0015-guide-mener-route-modes-origine.md) et [0019](adr/0019-cloture-de-saison-archive-agregee-et-effacement-en-lot.md).
Schéma drift actuel : **v9** ; format de sauvegarde actuel : **v4**.

## 1. Périmètre

**Dans le lot 10b**

1. Persister, par séance guidée en cours : **étape**, **compteurs d'initiation**, **grille « acquis »** (critères cochés),
   **score du jeu** (A / B), **minuteur** (secondes écoulées, restauré en pause), et **l'identifiant de la saisie** ouverte
   depuis le guide (`recordId`, jamais ses élèves ni ses absents).
2. Reprise après rechargement web ou fermeture de l'application : la séance réapparaît dans « Séances en cours » d'Aujourd'hui
   et rouvre à l'étape, avec ses compteurs.
3. Effacement : « Terminer », « Recommencer », « Abandonner », éviction, péremption, effacement d'un élève, clôture de saison.

**Hors du lot, dit explicitement**

- **La note de jeu en texte libre reste au roadmap, non livrée** (décision de l'animateur du 2026-10-16). Un texte libre sur des
  mineurs est une donnée personnelle de nature différente (le texte peut nommer un enfant, une santé, un comportement) : il exige
  son propre ADR (finalité, durée, effacement, visibilité, sauvegarde). Rien dans ce lot ne prépare une colonne de texte libre ;
  le point 10 du roadmap garde la ligne « note de jeu ».
- Le **mode** du guide (Mener / Relecture) : il est dans l'adresse (`?mode=`), ADR 0015, pas dans la progression.
- La synchronisation entre appareils (Firebase, lots FB) : l'état en cours est local à l'appareil.

## 2. Constat sur le code actuel

- `RunSheetCubit` (`features/run_sheet/presentation/bloc`) porte `step`, `counts` (`Map<String,int>`), `checked`
  (`Map<String,Set<int>>`), `scoreA/B`, `timerSeconds/timerRunning`, `recordChoice` (identifiant de saisie, groupe, date,
  **ensemble d'absents `StudentId`**), `mode`, `resumeOffered`.
- `RunSheetSessions` (singleton, au-dessus du routeur) garde au plus 4 cubits par `RunKey(sheetId, audience, sessionId, group)`
  et les expose à Aujourd'hui (`snapshot()` → `RunningSession`, uniquement si `status == ready` et `hasProgress`).
  Au rechargement web le registre est vide : tout est perdu, seule l'adresse (`?step=`, `?mode=`) survit.
- Les compteurs et la grille sont **par initiation**, jamais par élève : aucun `StudentId` dans la progression, sauf
  `recordChoice.absent`.
- `finish()` remet l'état à zéro ; `release(key)` ferme et retire le cubit ; l'éviction ferme le plus ancien.
- Le minuteur est indicatif (`TimerChip`), remis à zéro au changement de phase, mis en pause à la sortie de la page.

## 3. Décisions de conception

| # | Décision | Pourquoi |
|---|---|---|
| D1 | **Une table `run_progress`** (schéma **v10**), une ligne par `RunKey`. Pas de fichier, pas de `localStorage` | Une seule source de vérité (drift, ADR 0001) ; fonctionne pareil natif et web (wasm/IndexedDB) ; testable avec la même suite de contrat que les autres dépôts |
| D2 | **Aucun identifiant d'élève dans la table.** `recordChoice` n'est pas stocké : on garde `recordId`, et groupe, date et absents sont relus de la saisie (`SessionRecordRepository.byId`) à la reprise | La saisie existe déjà et son effacement est déjà géré (`eraseStudent`) ; copier les absents créerait un second dépôt nominatif à effacer |
| D3 | **Sauvegarde inchangée (reste v4)** et l'import ne touche pas à `run_progress` | État transitoire propre à l'appareil, comme `backup_exports` ; l'y mettre ressusciterait à l'import l'état d'un élève effacé (le fichier est hors de portée de l'effacement, ADR 0001) et le figerait pendant des mois. Voir § 6 |
| D4 | **Écriture à chaque changement utile** (étape, compteur, case, score, `recordId`), **minuteur en points de contrôle** : toutes les 10 s tant qu'il tourne, à la pause, au changement de phase | Une écriture par tape est négligeable ; une écriture par seconde ne l'est pas. Perte maximale au rechargement : 10 s de minuteur |
| D5 | **Minuteur restauré en pause**, à la dernière valeur enregistrée, sans rattrapage de l'horloge murale | Un rattrapage afficherait « dépassé de 45 min » après une nuit ; ne pas redémarrer seul évite un minuteur qui court sans que l'animateur regarde (U4 : jamais bloquant, jamais surprenant) |
| D6 | **On ne persiste que si `hasProgress`** (étape > 0, une réussite, un critère, un score). Sinon la ligne est supprimée | Même règle que la liste d'Aujourd'hui ; le minuteur seul n'est pas de la progression |
| D7 | **Reprise par le mécanisme existant** : `syncFromRoute` offre la reprise (`resumeOffered`) quand la séance a de la progression et que l'adresse n'impose pas d'étape ; une adresse avec `?step=` l'emporte | Aucun nouveau parcours ; le rechargement sur `?step=3` garde l'étape de l'adresse et retrouve compteurs et score |
| D8 | **Péremption à 7 jours** `[Prop]` (`updatedAt`), purge au démarrage | Une séance abandonnée sans « Abandonner » ne doit pas rester indéfiniment (minimisation) ; 7 jours couvrent un cycle hebdomadaire |
| D9 | **La couche entité `entities/run_progress`** (domaine + données) porte le port et son implémentation ; la feature `run_sheet` l'utilise | FSD : `manage_students` (`EraseStudent`) doit pouvoir l'effacer sans importer une autre feature |
| D10 | **Échec d'écriture non bloquant** : l'état en mémoire reste la vérité de la session ; l'échec est journalisé, aucune boîte de dialogue | Perdre la reprise est moins grave que bloquer l'animateur au milieu d'une séance |

## 4. Modèle de données

### 4.1 Domaine (`entities/run_progress/domain`, Dart pur)

```dart
/// Identité d'une séance guidée en cours (équivalent persistable de RunKey).
@freezed
abstract class RunProgressKey with _$RunProgressKey {
  const factory RunProgressKey({
    required SheetId sheetId,
    Audience? audience,
    String? sessionId,   // séance planifiée
    GroupId? groupId,
  }) = _RunProgressKey;

  /// Forme texte stable, unique : "sheet|audience|session|group" (vides pour null).
  String get encoded;
}

@freezed
abstract class RunProgress with _$RunProgress {
  const factory RunProgress({
    required RunProgressKey key,
    @Default(0) int step,
    @Default({}) Map<String, int> counts,
    @Default({}) Map<String, Set<int>> checked,
    @Default(0) int scoreA,
    @Default(0) int scoreB,
    @Default(0) int timerSeconds,
    SessionId? recordId,        // saisie ouverte depuis le guide
    required DateTime updatedAt,
  }) = _RunProgress;
}

abstract interface class RunProgressRepository {
  Future<void> save(RunProgress progress);                 // remplace par clé
  Future<List<RunProgress>> all();                         // plus récent d'abord
  Future<void> delete(RunProgressKey key);
  Future<void> eraseLinked({Set<GroupId> groups, Set<SessionId> records}); // effacement
  Future<int> purgeOlderThan(DateTime limit);              // péremption
}
```

Invariants du domaine (constructeur, `InvariantViolation`) : `step`, scores, compteurs ≥ 0 ; scores ≤ 999 ; `timerSeconds` ≥ 0 ;
pas de clé `counts` vide. Les bornes **dépendantes de la séance** (compteur ≤ `scoring.of`, étape ≤ dernière étape,
initiations qui existent encore) ne sont pas du domaine de l'entité : elles sont réappliquées à la reprise (§ 5.3).

### 4.2 Schéma drift v10

Table `RunProgressEntries` (`shared/persistence/tables.dart`), **sans** `AuditColumns` : pas de suppression logique (un état
en cours supprimé doit être réellement supprimé, ADR 0001 « Effacement »), pas de synchronisation à prévoir.

| Colonne | Type | Note |
|---|---|---|
| `runKey` | texte, clé primaire | `RunProgressKey.encoded` |
| `sheetId` | texte | séance du catalogue (asset : pas de clé étrangère) |
| `audience` | texte nul | |
| `sessionId` | texte nul | séance planifiée, pas de clé étrangère (suppression logique) |
| `groupId` | texte nul | idem ; sert à l'effacement par groupe |
| `recordId` | texte nul | idem ; sert à l'effacement par saisie |
| `step` | entier | |
| `countsJson` | texte | `{"initiationId": n}` |
| `checkedJson` | texte | `{"initiationId": [0, 2]}` |
| `scoreA`, `scoreB` | entiers | |
| `timerSeconds` | entier | |
| `updatedAt` | texte (`IsoDateTimeConverter`) | |

Index sur `groupId` et sur `recordId` (effacement). JSON plutôt que tables filles : de petites cartes lues et écrites d'un
bloc, jamais interrogées en SQL ; un convertisseur de type unique, testé, les (dé)sérialise et **rejette** toute valeur
mal formée (la ligne est alors supprimée à la lecture, jamais d'exception à l'ouverture).

**Migration `from9To10`** : `m.createTable(schema.runProgressEntries)` + index. Pas de transformation de données, aucune
ligne existante touchée. Procédure (voir la mémoire « Pièges de développement Flutter ») : modifier `tables.dart`, passer
`currentSchemaVersion` à 10, `dart run drift_dev make-migrations` (génère `drift_schemas/…v10.json`,
`app_database.steps.dart` et les tests générés), puis écrire l'étape `from9To10`. Fichiers générés jamais édités à la main.

## 5. Comportement

### 5.1 Écriture (`RunSheetCubit`)

Le cubit reçoit un `RunProgressRepository` (injectable) et un `Clock`. Un `onChange` compare l'ancien et le nouvel état sur les
champs persistés ; s'ils diffèrent, la progression dérivée est enregistrée, **sérialisée** (une chaîne de futures : deux
écritures ne se doublent jamais, la dernière gagne). Règles :

- `hasProgress == false` après un changement (ex. compteur remis à 0, retour à l'étape 0) : `delete(key)`.
- Tick du minuteur : on n'écrit que quand `timerSeconds % 10 == 0`, à `timerToggled` (pause) et à `timerPaused`, et quand
  `showStep` change de phase (remise à 0).
- `recordChosen` : écrit `recordId` seul (le groupe, la date, les absents ne sont pas stockés, D2).
- `finish()` / `restart()` : `delete(key)` avant d'émettre l'état vierge. `RunSheetSessions.release` : idem (idempotent).
- Éviction (au-delà de 4) : le cubit évincé supprime sa ligne (le plafond reste une règle d'usage, pas de fuite de données).

### 5.2 Registre et démarrage (`RunSheetSessions`)

- `Future<void> restore()` : purge les lignes de plus de 7 jours (D8), lit `all()`, garde les 4 plus récentes (supprime le
  reste), crée pour chacune un cubit **hydraté** (`RunSheetCubit.restored(progress, …)`), puis lance `load()` du déroulé.
  Appelé une fois au démarrage, **sans bloquer** `runApp` ; `RunningSessionsCubit.refresh()` attend `restore()` terminée
  avant de lire `snapshot()` (l'accueil n'affiche donc jamais une liste incomplète).
- Un `RunKey` déjà ouvert par la route avant la fin de `restore()` : `of(key)` attend la même restauration (un seul cubit par clé).

### 5.3 Reprise et données périmées

À la fin du chargement du déroulé (`load()`), l'état hydraté est **réconcilié** avec la séance réelle :

| Cas | Traitement |
|---|---|
| `step` au-delà de la dernière étape (séance du catalogue raccourcie) | ramené par `plan.clamp` |
| Initiation absente de la séance | entrée de `counts` / `checked` supprimée |
| Compteur > `scoring.of` | ramené à `of` |
| Critère hors de la grille | indice retiré |
| Séance du catalogue introuvable ou séance planifiée supprimée (`NotFound` du déroulé) | **ligne supprimée**, séance non listée |
| `recordId` dont la saisie n'existe plus (ou supprimée) | `recordId` retiré ; sans groupe ni date retenus, la saisie repart des valeurs de la séance planifiée (`recordDefaults`) |
| `recordId` valide | `recordChoice` reconstruit : groupe, date et **absents lus de la saisie** (donc jamais plus que ce que la saisie contient) |

Toute correction est réécrite dans la même passe. La reprise est ensuite proposée comme aujourd'hui (`resumeOffered`).

### 5.4 Où l'état en cours peut apparaître

Seulement dans l'application, sur l'appareil. Aujourd'hui liste le titre de la séance, la phase, l'étape et le groupe/la date
de la séance planifiée (comme avant, aucun nom d'élève). Aucun export, aucune sauvegarde (D3).

## 6. Sauvegarde : pourquoi ne pas passer à la v5

Le format reste **v4** ; `BackupCodec.supportedVersions` et l'encodeur/décodeur ne changent pas.

1. **Nature de la donnée** : transitoire (7 jours au plus), liée à un appareil et à un minuteur ; une sauvegarde sert à
   retrouver le *club* (élèves, séances données, bilans), pas un écran ouvert.
2. **RGPD** : un fichier exporté est hors de l'effacement (ADR 0001). Y mettre l'état en cours ferait survivre à l'effacement
   d'un élève tout ce qui lui est lié (voir § 7) et le réinjecterait à l'import.
3. **Import** : il est additif (sauvegarde par id) et ne vide pas `run_progress`. Les liens (`groupId`, `recordId`, `sessionId`)
   sont revalidés à la reprise (§ 5.3) : un import qui supprimerait une saisie ne laisse pas d'orphelin affiché.
4. **Coût de compatibilité** : un format v5 ferait refuser le fichier par les anciennes versions pour une donnée sans valeur de
   restauration.

Conséquence assumée : changer d'appareil ou restaurer une sauvegarde **ne reprend pas** une séance en cours. Si l'animateur le
demande plus tard, c'est un nouvel ADR (et alors format v5, `data.runProgress` facultatif, lecture rétrocompatible comme
`settings` en v2).

## 7. Effacement RGPD

Principe : la ligne ne contient aucun élève (D2), mais elle **peut en dire quelque chose** : le score ou un compteur d'un
groupe d'un seul élève, ou d'une saisie où il était présent, est son résultat. L'exigence « l'état en cours d'un élève effacé
doit disparaître » est donc traitée par le lien, pas par un identifiant :

- `EraseStudent.eraseRecords` (la liste unique des dépôts nominatifs, utilisée aussi par la clôture via `StudentEraser`) gagne
  `RunProgressRepository`. **Avant** d'effacer les présences et les appartenances, il calcule :
  - `groups` = groupes dont l'élève a été membre (`GroupRepository.all()` filtré sur `memberships`, y compris les périodes
    closes) ;
  - `records` = saisies où l'élève était présent (`SessionRecordRepository.forStudent`) ;
  puis appelle `eraseLinked(groups: …, records: …)` : toute ligne dont `groupId` ou `recordId` y figure est **effacée
  physiquement**. Coût assumé : effacer un élève pendant une séance de son groupe fait perdre l'état en cours de cette séance
  (rare, signalé par le message de confirmation existant `[Prop]`, une ligne à ajouter en fr + en).
- **Clôture de saison** : elle passe par `StudentEraser` pour chaque élève effacé → même chemin, aucun code de plus. Les séances
  planifiées supprimées par la clôture (`dropPlanned`) rendent leurs lignes orphelines : elles sont supprimées à la reprise (§ 5.3).
- **Parité** : `erasure_parity_test` (ADR 0019) est étendu : après `EraseStudent` et après `CloseSeason`, aucune ligne de
  `run_progress` ne référence un groupe ou une saisie de l'élève ; une ligne d'un autre groupe reste.
- **Effacement tout ou rien** : `eraseLinked` s'exécute dans l'unité de travail existante.
- **Minimisation** : fin de séance, abandon, péremption à 7 jours (D8), éviction.
- Ce qui n'est pas couvert, dit honnêtement : une séance en cours sans groupe ni saisie (relecture seule) n'a aucun lien avec un
  élève et n'est pas touchée ; les fichiers de sauvegarde déjà exportés ne contiennent pas cet état (D3).

## 8. FSD et composition

| Couche | Créer | Modifier |
|---|---|---|
| `shared/persistence` | `RunProgressEntries` (tables), convertisseur JSON, migration `from9To10` | `app_database.dart` (liste des tables, version 10) |
| `entities/run_progress` | `domain/` (`RunProgressKey`, `RunProgress`, `RunProgressRepository`), `data/drift_run_progress_repository.dart` (`env: prod`), `data/in_memory_run_progress_repository.dart` | |
| `features/manage_students` | | `EraseStudent` (+ `RunProgressRepository`, calcul des liens) |
| `features/run_sheet` | `domain/reconcile_run_progress.dart` (fonction pure § 5.3), `RunProgress` ↔ état (mappeur) | `RunSheetCubit` (écriture, hydratation), `RunSheetSessions` (`restore`, éviction), `RunningSessionsCubit` (attend la restauration) |
| `app` | appel de `restore()` au démarrage | `student_eraser.dart` inchangé |

Imports vers le bas uniquement ; `run_sheet` et `manage_students` n'importent que `entities/run_progress`.

## 9. i18n

Une seule chaîne nouvelle (clé identique en fr et en) : la mention du message de confirmation d'effacement d'un élève
(« l'état d'une séance en cours de son groupe est aussi effacé »). Aucune autre : la reprise utilise la bannière existante
(`resumeOffered`) et la liste « Séances en cours » de l'accueil.

## 10. Scénarios BDD (à écrire d'abord, les voir échouer)

`test/bdd/session_guide_resume.feature` (nouveau) ; la base du monde de test est `test/support/run_sheet_world.dart`, avec un
`Given the app is restarted` qui reconstruit le graphe d'injection **sur la même base** (simule le rechargement).

1. *Counters survive a restart* : réussites comptées à l'initiation, redémarrage, rouvrir → mêmes compteurs.
2. *Checked criteria survive a restart* (grille « acquis »).
3. *Game score survives a restart* (A 3, B 5).
4. *The step survives a restart* : étape 4, redémarrage, Aujourd'hui liste « étape 4 sur n », « Reprendre » rouvre l'étape 4.
5. *The address step wins over the saved step* : `?step=2` avec 4 enregistré → étape 2, compteurs gardés.
6. *The timer is restored paused* : 0:42 écoulées avant le redémarrage, après : 0:40 à 0:42 selon le point de contrôle, en pause.
7. *Ending the session forgets it* : « Terminer » → redémarrage → plus de séance en cours, compteurs à zéro.
8. *Starting over forgets it* (« Recommencer »).
9. *Abandoning from Today forgets it* après redémarrage.
10. *Nothing saved without progress* : ouvrir le guide, rien toucher, redémarrage → pas de séance en cours.
11. *A deleted planned session is not resumed* : séance planifiée supprimée entre-temps → absente d'Aujourd'hui.
12. *A shortened catalogue session is clamped* : étape enregistrée au-delà de la fin → dernière étape (test de contrat avec
    un déroulé tronqué).
13. *The linked record is restored without copying students* : saisie ouverte avec un absent, redémarrage, retour à la saisie →
    l'absent est présélectionné (lu de la saisie).
14. *Erasing a student erases the running session of their group* : élève dans le groupe, séance en cours, effacement de l'élève
    → redémarrage → aucune séance en cours pour ce groupe ; la séance d'un autre groupe est intacte.
15. *Closing a season erases linked running sessions*.
16. *A stale running session is purged after 7 days* (horloge de test).
17. *Importing a backup keeps the running session* (non-régression de D3 : pas touchée, liens revalidés).

Scénarios existants à relire (aucun supprimé) : `session_guide.feature` (« Terminer », « Recommencer »),
`session_guide_mode.feature`, `home.feature` (« Séances en cours »), `student_erasure` (message de confirmation).

## 11. Tests

**Domaine / entité (unitaires, TDD rouge → vert)**
- `RunProgressKey.encoded` stable, injectif (cas `|` dans un identifiant : interdit par l'invariant ou échappé, un test dit lequel).
- Invariants de `RunProgress` (négatifs, scores > 999, compteur nul/vide).
- `reconcileRunProgress` : un test par ligne du tableau § 5.3, plus l'idempotence (réconcilier deux fois = une fois).

**Contrat de dépôt** (`test/contract/run_progress_contract.dart`, joué sur drift et en mémoire par `drift_contract_test` et
`in_memory_contract_test`) : sauvegarde/relecture complète, remplacement par clé, `delete`, ordre de `all()`, `eraseLinked` par
groupe et par saisie (et ne touche pas le reste), `purgeOlderThan` (borne exclusive), ligne JSON corrompue → ignorée et supprimée.
`RepositoryHarness` gagne `runProgress`.

**Migration** (`test/unit/shared/persistence/migration_test.dart`) : v9 → v10 crée la table vide, conserve toutes les lignes des
autres tables ; base v10 neuve = base migrée (schéma identique) ; `DowngradeNotSupported` inchangé.

**Cubit** : écriture à chaque champ persisté ; pas d'écriture pour un changement de mode ou de `resumeOffered` ; minuteur
(écriture à 10 s, à la pause, pas à 3 s, avec `RunTicker` factice) ; écritures sérialisées (deux écritures lentes, dernière
gagne) ; échec d'écriture sans exception visible (D10) ; `finish` supprime ; hydratation puis `load()` réconcilie.
`RunSheetSessions` : `restore` (4 plus récentes, péremption, orphelin supprimé), éviction supprime la ligne, `of` pendant la
restauration ne crée pas de doublon.

**Effacement** : `erase_student_test` (liens par groupe et par saisie, ordre : calcul avant effacement des présences),
`erasure_parity_test` étendu, test de clôture de saison.

**Sauvegarde** : `backup_contract` — un export après progression **ne contient pas** `runProgress` (codec inchangé, v4) et un
import ne vide pas la table (garde de D3).

**Mutation (pour les tests écrits après coup)** : après le vert, muter à la main et constater un test rouge à chaque mutation :
`% 10` du point de contrôle (→ `% 11` ou supprimé), `hasProgress` (→ `true`), filtre `memberships` de l'effacement (→ ignorer
les périodes closes), calcul des liens **après** l'effacement des présences, borne de `purgeOlderThan` (`<` ↔ `<=`), clamp de
l'étape, suppression de la ligne à `finish`. Un mutant survivant = test manquant, à écrire avant de conclure.

## 12. Lots d'implémentation (ordre ; garde-fous verts à chaque fin de lot)

1. **Lot A, schéma et dépôt** : feature file de contrat → `RunProgress*` domaine (TDD) → table + `make-migrations` + migration
   + test de migration → dépôts drift et mémoire + contrat → `RepositoryHarness`.
2. **Lot B, effacement** : tests rouges de `EraseStudent` et de la parité → implémentation → message de confirmation i18n.
3. **Lot C, écriture** : scénarios 1 à 3, 7, 8, 10 rouges → cubit (mappeur, onChange, sérialisation, minuteur).
4. **Lot D, reprise** : scénarios 4 à 6, 9, 11 à 13 → `reconcileRunProgress`, `restore`, `RunningSessionsCubit`, câblage au démarrage.
5. **Lot E, effacement et péremption bout en bout** : scénarios 14 à 17.
6. **Lot F, docs et vérification** : roadmap, ADR 0020 en « livré », `guide-mener-plan` § 2 et `aujourdhui-plan` U-5 soldés, mutation,
   `scripts/check.sh --full`, parcours web Playwright (§ 14).

## 13. Risques

| # | Risque | Parade |
|---|---|---|
| R1 | Régression du guide (≈ 35 scénarios existants) : le cubit gagne une dépendance | Dépôt en mémoire par défaut dans `run_sheet_world` ; lot C lancé sur `session_guide*` avant toute reprise |
| R2 | Écritures concurrentes ou désordonnées (IndexedDB asynchrone) | Chaîne de futures sérialisée, test dédié |
| R3 | Un état hydraté incompatible avec une séance du catalogue modifiée | Réconciliation pure et testée (§ 5.3) ; en cas de doute, la ligne est supprimée plutôt que reprise de travers |
| R4 | Données personnelles indirectes (score d'un groupe d'un élève) | Effacement par lien (§ 7), péremption, jamais exporté ; reste à valider par l'animateur (U10b-3) |
| R5 | `restore()` au démarrage retarde l'accueil | Non bloquant ; `refresh()` attend, mesure au parcours web ; au plus 4 résolutions de déroulé (assets) |
| R6 | Deux onglets web ouverts sur la même base | Dernière écriture gagne (même clé) ; même limite que le reste de l'application, non traitée |
| R7 | Le journal d'échec d'écriture est muet pour l'animateur | Assumé (D10) ; si le parcours web montre des échecs réels, ajouter un indicateur discret |

## 14. Parcours web de confirmation (à faire à l'implémentation)

Build web, `http.server`, Playwright à 390 × 844 et 1024 × 768 (voir la mémoire « Tester l'app en web »). Séquence : lancer une
séance planifiée, compter, cocher, scorer, avancer, lancer le minuteur ; **recharger** ; vérifier Aujourd'hui, la reprise, les
compteurs, le minuteur en pause ; « Terminer » puis recharger ; console sans erreur ni avertissement.

## 15. Points qui demandent une décision `[U]` de l'animateur

Défauts appliqués si rien n'est dit.

| # | Question | Défaut proposé |
|---|---|---|
| U10b-1 | Péremption d'une séance en cours non terminée | **7 jours** |
| U10b-2 | Minuteur après rechargement | **en pause**, à la dernière valeur (± 10 s), pas de rattrapage |
| U10b-3 | Effacer un élève efface l'état en cours de **toute séance de son groupe** (et de ses saisies) | **oui** (prudent pour des mineurs) |
| U10b-4 | Reprendre une séance en cours sur un autre appareil / après restauration de sauvegarde | **non** (hors sauvegarde, ADR 0020) |
| U10b-5 | Note de jeu en texte libre | **reportée** (décision déjà prise ; ADR dédié nécessaire) |

## 16. Reste au roadmap après ce lot

La **note de jeu** de la séance (texte libre, score A / B nommé, ou champ du `SessionRecord`) : non livrée, ligne conservée au
point 10. Le score A / B *en cours* est désormais persisté, mais il n'est toujours **pas** enregistré dans le bilan d'une séance
terminée : « Terminer » l'efface (comportement actuel inchangé).

## 17. Réalisation et écarts (2026-10-17)

**Livré** : table, dépôts, effacement, cubit, registre, démarrage, i18n, documentation. **Non committé** (consigne).

### Écarts par rapport à la conception

| Conception | Réalisé | Pourquoi |
|---|---|---|
| Table `run_progress` | `run_progress_entries` (classe `RunProgressEntries`) | nom dérivé par drift, cohérent avec les autres tables |
| Port : `save`, `all`, `delete`, `eraseLinked(groups, records)`, `purgeOlderThan` | + `byKey` ; `eraseLinked` prend aussi `plannedSessions` | chaque cubit relit sa propre ligne ; **lacune du plan** : un guide lancé d'une séance planifiée ne porte que l'identifiant de cette séance (pas son groupe) dans sa clé, donc l'effacement par groupe ne l'atteignait pas. `EraseStudent` calcule aussi les séances planifiées des groupes de l'élève (dépendance `SessionRepository` en plus) |
| Le cubit parle au dépôt | `RunProgressKeeper` (`features/run_sheet/domain`) : dépôt + saisies + groupes + horloge, `RunRecordLink` | un seul point de contact, testable sans le cubit |
| `restore()` crée des cubits hydratés ; `of` attend la restauration | chaque cubit **relit lui-même** sa ligne au premier `load()`/`syncFromRoute()` ; `restore()` crée les cubits et les charge | un seul cubit par clé **par construction** (la question « hors plan » est tranchée, test dédié) ; les restaurés précèdent les guides déjà ouverts, qui restent les plus récents |
| Séance planifiée supprimée = `NotFound` du déroulé | le déroulé **se résout** sans séance planifiée (comportement existant) ; le cubit détecte `sessionId != null && planned == null`, ouvre le guide à neuf et oublie la ligne | constat à la réalisation (le § 5.3 supposait `NotFound`) ; la fiche, elle, existe |
| `close()` | ne **attend pas** les écritures ; `discard()` (abandon, éviction, `release`) les attend | une fermeture qui attend gèle les tests dont le cubit est fermé hors de leur zone ; les écritures demandées vont à leur terme de toute façon |
| `RepositoryHarness.runProgress` pour tout le contrat | contrat léger `runProgressContract` (comme les acquittements) ; le harnais n'a `runProgress` que pour la garde de sauvegarde | cohérence avec `acknowledgementContract` |
| Message de confirmation : « une ligne à ajouter » | texte de `eraseConfirmBody` complété (fr + en), même clé | une seule chaîne |
| Scénarios 12 et 17 en BDD | 12 : tests unitaires (`reconcile_run_progress_test`, `run_sheet_cubit_persistence_test`) ; 17 : `backup_contract` (sur drift et en mémoire) | les assets ne se raccourcissent pas en BDD ; l'import de sauvegarde n'a pas d'écran dans ce monde |
| Minuteur « 0:40 à 0:42 » | restauré **à la valeur exacte de la pause** ; la granularité de 10 s ne joue qu'à un arrêt brutal | la sortie de page met en pause et écrit à l'instant ; testé en unitaire (10 s, 13 s à la pause, 7 s à la sortie) |

### Scénarios BDD (`session_guide_resume.feature`, 19) et tests

- 19 scénarios, tous verts : compteurs, grille, score, étape, rechargement sur l'adresse, étape de l'adresse qui l'emporte,
  reprise proposée sans étape, minuteur en pause, terminer, recommencer, abandonner, rien sans progression, séance planifiée
  supprimée, saisie restaurée avec son absent, péremption à 8 jours (et 6 jours conservés), effacement d'un élève (son groupe /
  un autre groupe), clôture de saison. Pas de nouvelle chaîne i18n hors `eraseConfirmBody` (scénario dans `students.feature`).
- Unitaires : clé et invariants, JSON strict, lignes illisibles (drift), contrat de dépôt (drift et mémoire), migration v9 → v10
  et instantané v10, réconciliation, `RunProgressKeeper`, cubit (écriture, minuteur, oubli, sérialisation, disque en échec,
  reprise), registre (restauration, plafond, éviction, accueil), effacement (`erase_student_test`, `erasure_parity_test`,
  `physical_erasure_test`), garde de sauvegarde (v4, rien exporté, import sans effet).
- **Honnêteté sur le rouge** : le rouge constaté est celui de l'absence du code (erreurs de compilation) pour le domaine, la
  réconciliation, le dépôt, le cubit, le registre ; un rouge sur assertion pour l'effacement (constructeur ajouté sans
  comportement), le message de confirmation, la séance planifiée supprimée et la restauration sans état vide. Les scénarios BDD
  ont été écrits **après** les tests unitaires du cubit (non avant) ; leurs premiers passages ont échoué (grille à 4 critères,
  étape du score, abandon, séance planifiée supprimée, bug de zone de test, voir plus bas). Les tests de lignes illisibles, de
  garde de sauvegarde et de `physical_erasure_test` sont **après coup** : couverts par la mutation.

### Mutation (à la main, 35 mutants, tests ciblés)

Tous **tués**, sauf un mutant équivalent : point de contrôle `% 10` (→ `% 11`), `hasProgress` toujours vrai, filtre des
appartenances closes, liens calculés **après** l'effacement des présences, bornes de péremption (mémoire et drift), étape non
bornée, oubli sans progression, séances planifiées / saisies / groupes ignorés (`EraseStudent` et drift), restauration sans
péremption / sans plafond / absente (BDD), compteur non plafonné, absents inversés, réécriture sans saisie, séance planifiée
supprimée non détectée, minuteur non restauré, reprise non proposée, clé non injective, `release` / éviction sans oubli,
écritures non sérialisées, accueil qui n'attend pas la restauration, hydratation coupée (unité et BDD), lignes illisibles
conservées, JSON non strict, `RunKey.fromProgress` sans groupe. **Un mutant a survécu au premier passage** (`RunKey.fromProgress`
sans groupe) : test ajouté, mutant tué. **Un mutant était équivalent** (le garde `_hydrating` de `onChange` : l'hydratation a
toujours lieu avant l'arrivée du déroulé, `plan == null` suffit) : le garde mort a été supprimé.

### Parcours web (Playwright, build release, 390 × 844)

`/#/catalogue/posture-1/guide?audience=children&step=5` : 2 réussites, minuteur lancé puis mis en pause, **rechargement de la
page** → « Étape 6 sur 10 », « 2 réussites sur 4 », minuteur à la valeur de la pause (19:10), **en pause**. Aujourd'hui, après
un second rechargement : carte « En cours », « Étape 6 sur 10 », « Reprendre à l'étape 6 » ; la reprise rouvre l'étape 6 avec ses
compteurs. « Terminer la séance » puis rechargement : plus de carte « En cours ». Console : 0 erreur, 0 avertissement.
**Non vérifié** : 1024 × 768, une séance planifiée d'un groupe réel dans le navigateur (couverte en BDD), le score et la grille au
navigateur (couverts en BDD), deux onglets (R6, non traité).

### Points qui restent `[U]`

U10b-1 à U10b-5 : appliqués sur leurs défauts, **aucune réponse de l'animateur** à ce stade.

### Limites (en plus de l'ADR 0020)

- Un test BDD qui crée des cubits sous `tester.runAsync` les rend impossibles à fermer dans la zone du test (leur fermeture
  attend des flux réels) : `relaunchApp` restaure donc dans la zone du test, ce qui suppose les assets en cache
  (`UiWorld.prepare`).
- Écarts de la mesure R5 (« l'accueil attend la restauration ») : non chronométrée ; la restauration ne résout que les 4 séances
  gardées.
