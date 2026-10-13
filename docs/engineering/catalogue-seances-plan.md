# Catalogue de séances : plan de mise en œuvre

Statut : **document historique : les composants `StanceDiagram`, `PowerScale` et `CueSideView` cités ci-dessous sont remplacés par `PlayerFigure`, `PowerRatio` et `CueBallTarget` (voir `adr/0005-illustrations-joueur-cible-dosage.md`)** ; accepté et implémenté (lots LB à L7) ; seul L8 reste à faire**, après revue indépendante du code dont les constats sont corrigés ; conception révisée après les décisions de l'utilisateur (2026-10-13). Décision d'architecture : `adr/0004-catalogue-fiches-seances.md`. Format des séances : `../knowledge/05-seances/catalogue/FORMAT.md`. Les lots **LB** (blocs `posture` et `bille-fantome` du catalogue d'entraînement, diagrammes `[Prop]`, marque « Proposition » sur les écrans existants) et **L1** (validateur `app/tool/fiches.dart`, `scripts/sync_fiches.sh`, séance pilote `09-demi-bille-1.yaml`) sont réalisés (2026-10-13) ; le lot **L2** (domaine et données : `SheetId`, `ContactFraction`/`TipPoint` en `shared/lib` avec réexport, `session_sheet_timing`, `ghost_ball_geometry`, union `Illustration`, entité `session_sheet`, parseur strict, `AssetSessionSheetRepository`, test de contrat sur `app/assets/fiches/*`) est réalisé ; `TipPoint` y a reçu ses 9 valeurs (étiquettes l10n fr/en comprises) ; le lot **L3** (composants d'illustration : `ContactStrip`, `GhostAimDiagram`, `CueSideView`, `StanceDiagram`, `PowerScale`, `AngleMark`, `PdfPageChip`, `PresentationScope`, flèche `aim` et annotations de `TableDiagramSpec`, géométrie `angle_geometry` et `cue_side_geometry`, galerie Widgetbook des 10 types, `design-system.md`) est réalisé ; le lot **L7** (rédaction des 29 séances, `fiches.dart --complete` vert, assertion « 29 fichiers et ids figés » activée) est réalisé : **29 séances rédigées**, éléments `[Prop]` à valider par l'animateur (index : `../knowledge/05-seances/README.md`) ; le lot **L4** (consultation : slice `features/browse_sheets` avec `ListSheets`, `GetSheet`, `SheetCatalogueBloc` et `SheetDetailBloc`, vues catalogue groupé par technique et séance en lecture seule avec badges `[Prop]` en contexte, filtre et indicateur « à valider », minutage 90/120 selon le public choisi, sommaire de la séance ; `IllustrationMapper` et `SheetIllustrationView` des 10 types ; pages `sheet_catalogue` et `sheet_detail`, routes `/catalogue` et `/catalogue/:id` (`?audience=`), destination « Séances » du shell, bouton « Suggestion par groupe », bandeau « contenu en français » ; `ProvenanceBadge` et `FrenchContentNotice` ; scénarios 1 à 3, 14 (sommaire), 17 à 19 et 21 (parties du détail), 22 ; test de contrat de rendu sur les 29 séances, fr et en, deux publics, texte à 200 %, tablette en paysage) est réalisé ; le lot **L5** (lien séance planifiée ↔ séance du catalogue : `Session.sheetId`, migration drift v3 minimale et instantané versionné, `sheetId` dans la sauvegarde avec refus `backupInconsistent`, champ « Séance du catalogue » du planificateur groupé par technique avec titre prérempli, `/planner?sheet=` et bouton « Planifier cette séance » du détail, séance liée ou « indisponible » dans la liste ; scénarios 4, 5, 6, 12 (non-régression), 13, 15) est réalisé ; le lot **L6** (séance guidée : slice `features/run_sheet` avec `ResolveRunPlan`, `resultsRecallBlock`, `RunSheetCubit` (étape courante, compteurs et grille locaux, score du jeu, minuteur injectable), `RunSheetSessions` (cubits conservés au-dessus du routeur, clé = séance, public, séance planifiée) et `RunPresentationCubit` ; pages `sheet_guide` (`/catalogue/:id/guide?audience=&session=&step=`) et `sheet_presentation` (`/catalogue/:id/presentation`, route de premier niveau hors du shell) ; bouton « Lancer » du détail et de la liste des séances planifiées ; sommaire, badges `[Prop]` en contexte et sur l'illustration, notation par `/record?main&recall&exercise&from` puis `/record/:sessionId?exercise&from`, retour au guide à la même étape avec les compteurs intacts ; scénarios 7 à 11, 14, 16, 17, 19, 20, 21 dans `session_guide.feature`, plus public de la séance planifiée, adresse de retour extérieure ignorée, séance inconnue, fr ; test de contrat de rendu du guide et de la présentation sur les 29 séances) est réalisé ; le reste n'est pas implémenté (L8).

Contexte : l'application est une **V1 non livrée**. Aucune compatibilité de données n'est à préserver ; le schéma, la sauvegarde et l'import se modifient directement.

Vocabulaire à tenir partout (code, l10n, docs) :

| Terme affiché | Sens |
|---|---|
| Technique | une des 14 notions (posture, puissance, …) ; regroupe 1 à 4 séances |
| Séance du catalogue | contenu du catalogue (29, lecture seule) ; modèle `SessionSheet`, identifiant `<technique>-<k>` |
| Séance planifiée | `Session` (titre, public, séance du catalogue facultative : `sheetId`) |
| Séance suggérée | `/session`, suggestion par groupe existante |
| Séance en cours | `SessionRecord` ouverte pour la saisie |
| Proposition | élément `[Prop]` : non sourcé, à valider par l'animateur |

## 1. Parcours

1. Planifier : choisir un public et une séance précise du catalogue (ou aucune), groupées par technique ; titre prérempli.
2. Consulter : menu « Séances » → catalogue des 14 techniques et de leurs 29 séances → détail en lecture seule (public enfants/adultes sélectionnable, minutage calculé). Filtre « à valider ».
3. Lancer : depuis une séance planifiée (public repris) ou depuis le détail (public choisi) → séance guidée par phases.
4. Pendant la séance : suivre la séance, voir mise en place + description + attendu, montrer les schémas aux élèves (mode présentation), noter les résultats.
5. Relire : parcourir toute la séance (rappel, théorie, exercices, jeu, bilan) sans élèves, avec le badge « Proposition » sur chaque élément non sourcé, pour valider un jeu adapté dans son contexte.

## 2. Routes et menu

Ajouts à `AppRoutes` (`app/lib/app/router.dart`) :

| Route | Page | Remarque |
|---|---|---|
| `/catalogue` | `sheet_catalogue` | techniques groupées, séances en lignes ; destination 3 du shell |
| `/catalogue/:id` | `sheet_detail` | `:id` = identifiant de séance (`demi-bille-2`) ; lecture seule ; boutons « Planifier cette séance » et « Lancer » |
| `/catalogue/:id/guide?audience=children\|adults&session=<id>&step=<n>` | `sheet_guide` | séance guidée ; position dans l'URL ; `audience` absent ou inconnu : repli sur celui de la séance planifiée, sinon `children` ; `step` hors bornes : ramené à la plage ; `id` inconnu : `NotFoundPage` (même traitement que `ExerciseRef.tryParse`) ; `session` facultatif (relecture sans séance planifiée) |
| `/catalogue/:id/presentation?audience=children\|adults&step=<n>` | `sheet_presentation` | plein écran, sans notes animateur ; `audience` obligatoire car les étapes diffèrent par public (théorie adulte seulement) ; ouvert par `push` depuis le guide ; route **de premier niveau, hors `ShellRoute`** (sinon la barre de navigation reste visible) : elle ne lit donc pas le cubit du shell et résout son étape par `ResolveRunPlan(sheet, audience)` + `step` de l'URL |
| `/planner?sheet=<id>` | existant | séance présélectionnée |
| `/record?main=&recall=&exercise=<n>&from=<chemin guide>` | existant | `group` n'est **pas** transmis (inconnu de la séance ; une valeur vide ferait `GroupId('')`) ; `exercise` et `from` ajoutés |
| `/record/:sessionId?exercise=<n>&from=<chemin guide>` | existant | `onOpened` fait `context.go('/record/:id')` : sans propager `exercise` et `from` à cette route (et à `RecordSessionPage.onBack`, aujourd'hui `go('/record')`), le retour au guide et la présélection de l'exercice sont perdus ; `RecordResultsEvent.started` gagne un `initialExercise` facultatif |

Menu (`shell.dart`, 5 destinations conservées) :

- La destination 3 « Séance » devient « Séances » : `_paths[3]` passe à `/catalogue`, la clé l10n `navSession` est renommée (fr et en), `indexOf` renvoie 3 pour `/catalogue*` (et pour `/session`, `/exercises` comme aujourd'hui). Attention : `/planner` reste sur l'index 0 (Accueil) ; un `startsWith` large comme `/session` ne doit pas capter `/catalogue/:id/...`.
- `/session` (suggestion par groupe) : bouton « Suggestion par groupe » en tête du catalogue.
- `/planner` reste accessible depuis l'accueil et depuis le détail d'une séance ; la liste des séances planifiées affiche la séance du catalogue liée et un bouton « Lancer » (« Choisir une séance » si `sheetId == null`).

## 3. Écrans (maquettes)

### 3.1 Catalogue (groupé par technique)

```
+--------------------------------------------------------+
| Séances           [Suggestion par groupe] [À valider o]|
|--------------------------------------------------------|
|  1  Posture, visée et coup de queue                    |
|       Séance 1/2 · Le tireur d'élite   [S][Prop] à valider >|
|       Séance 2/2                       [S][Prop] à valider >|
|  2  La puissance                                       |
|       Séance 1/2                              [S]  >   |
|       Séance 2/2                              [S]  >   |
|  3  Viser pour empocher (bille fantôme)                |
|       Séance 1/2                    [Prop] à valider >  |
|  ...                                                   |
| 14  Le rétro                                           |
|       Séance 1/4 ... Séance 4/4                        |
|--------------------------------------------------------|
| Accueil | Élèves | Saisie | [Séances] | Sauvegarde     |
+--------------------------------------------------------+
```

- Pastille `S` : contenu technique sourcé ; badge « Proposition » + **motifs « à valider »** qui disent quoi valider (jeu, exercices, initiation, rappel ; règle de lien et théorie `[Prop]` en information ; `FORMAT.md` § 5.3). Mesure sur les 29 séances : 18 « à valider », dont 12 pour le jeu. Le ludique, les liens avec la séance précédente et le minutage sont `[Prop]` sur toutes les séances : ils sont badgés **dans le détail et le guide**, pas dans la liste.
- Filtres « À valider seulement » et « Jeux à valider » (bascules exclusives) : n'affichent que les séances concernées, toujours groupées par technique. L'indicateur et les filtres ne s'appuient sur aucune donnée stockée : `reviewReasonsOf(sheet)`, `needsReview` et `gameNeedsReview` sont des fonctions pures.
- Mention « lecture seule » ; aucune action d'édition.

### 3.2 Détail (lecture seule)

```
+--------------------------------------------------------+
| < 9 · Quantité demi-bille, séance 1/2  [Planifier] [Lancer]|
| Thème : Le partage du gâteau  [Proposition]            |
| Public : (Enfants 90 min) ( Adultes 120 min )          |
|--------------------------------------------------------|
| Rappel (~10 min [Proposition]) · Bille pleine, séance 2/2 |
|   • ... • ...        [schéma contact plein]            |
|   Question flash : ...      Réponse : ...              |
| Théorie (~8 + 5 min)                                   |
|   1. Viser la moitié de la bille   [schéma]    [S]     |
|   2. Plein, trois-quarts, demi     [schéma]    [S]     |
| Exercices (~35 min)                                    |
|   E1 Les six parts de gâteau  ~23 min  catalogue 4/6 [S] |
|      Défi : ...  [Proposition]                         |
|   E2 Le tir de précision      ~12 min  catalogue 6/8 [S] |
| Jeu (~20 min) · 8 billes dans une poche   [S] jeu n° 7 |
|   Règle de rappel : ...  [Proposition]                 |
| Bilan (~5 min)                                         |
|--------------------------------------------------------|
| Sources : fiche technique n° 5 [S] ; défis [Proposition]|
+--------------------------------------------------------+
```

Le bascule public ne change que les minutes et les éléments sans poids pour ce public. Pas de champ de saisie. Sur une séance d'un bloc `[Prop]`, chaque exercice porte le badge « Proposition » et la mention que son taux est une proposition.

### 3.3 Séance guidée (tablette en paysage ; téléphone : une colonne)

```
+------------------------------------------------------------------+
| Demi-bille 1/2 · Enfants · 90 min    [Sommaire] [Montrer] [Fin]  |
| o Accueil  o Notion  * Entraînement  o Jeu  o Bilan   ~23 min    |
|------------------------------------------------------------------|
| EXERCICE 1/2 · Les six parts de gâteau  | [schéma de mise en     |
|                                         |  place, animé]         |
| Mise en place : ...                     |  > ||  vitesse 1x      |
| Consigne : ...                          |                        |
| Attendu : le contact se fait en demi    |                        |
| Défi : compléter le gâteau [Proposition]|                        |
| Erreurs fréquentes (animateur) : ...    |                        |
|------------------------------------------------------------------|
| Résultat : cible 4/6 · 5 passages réussis pour valider           |
|   [Noter les résultats]  -> ouvre /record, bloc demi-bille       |
|------------------------------------------------------------------|
| [< Précédent]            Étape 5/9              [Suivant >]      |
+------------------------------------------------------------------+
```

Comportement :

- Étapes ordonnées : rappel (+ question flash) → théorie (une illustration par étape) → initiation → exercices → jeu (règles, variante, lien avec la séance précédente, score à deux colonnes saisi à la main) → bilan (questions + résumé des passes saisies).
- **Parcours complet** : toutes les étapes sont atteignables sans élèves ni séance planifiée ni saisie ; le « Sommaire » liste les étapes et permet de sauter directement (par exemple au jeu) pour le juger en contexte, puis de revenir. Le minuteur est facultatif.
- **Badge « Proposition »** sur chaque élément non sourcé de chaque étape (théorie, exercice et son taux, jeu, défi ludique, variante, règle de lien, minutes de l'étape), avec le texte du badge (pas la seule couleur).
- Minutes affichées par étape = calcul de `FORMAT.md` § 4 ; minuteur indicatif par phase, jamais bloquant (alerte douce à −1 min, mouvement réduit respecté).
- **Montrer** : ouvre la route `/presentation` (`push`, même `audience` et `step`) : illustration seule, grande, légende lisible (titres ≥ 28 pt), sans notes animateur, sans notation ; badge « Proposition » conservé, discret mais visible ; « Fermer » revient au guide à la même étape. Ce n'est pas un état du cubit.
- **Notation d'un exercice** (toujours du catalogue, y compris posture et bille fantôme) : « Noter les résultats » ouvre `/record` avec `main = ref.block`, `exercise = ref.n`, `recall` = bloc de la plus récente séance précédente **dont le bloc diffère du bloc principal** (nul s'il n'y en a pas : `SessionRecord` lève `recallEqualsMainBlock` sinon ; `OpenSession` accepte les deux nuls) et sans `group`. Ainsi, pour une partie `k > 1`, le rappel de résultats est le bloc de la technique précédente, alors que le rappel théorique affiché porte sur la partie `k - 1`. La saisie se fait par élève et par exercice (`RecordAttempt`). La saisie, les taux, le plafond de 2 passages par élève, exercice et séance et la validation à 5 passages restent ceux de `RecordAttempt` ; la séance ne les redéclare jamais.
- **Notation d'une initiation** : compteur ou grille locale, mention explicite « non enregistré dans le suivi » ; conservés en mémoire pendant la séance guidée seulement. Le score du jeu est saisi à la main, lui aussi local.
- Reprise : l'étape courante est dans l'URL (`step`) ; l'état local (compteurs) est dans un `Cubit` **fourni par le `ShellRoute` (ou au-dessus du routeur)**, clé = (séance, public, séance planifiée), parce que la navigation actuelle utilise `context.go`, qui retire la page du guide et détruirait un cubit fourni par la route elle-même. Il survit à un aller-retour par `/record`, et est réinitialisé par « Fin ». Un test de navigation (aller par `/record`, retour par `from`) le vérifie.
- Lisibilité à distance : contraste AA, aucune information portée par la seule couleur, `Semantics` non vide sur chaque illustration et chaque badge.

## 4. Découpage FSD

| Couche | Slice | Contenu |
|---|---|---|
| `shared/lib` | `sheet_id`, `session_sheet_timing`, `illustration`, `ghost_ball_geometry`, `contact_fraction`, `tip_point`, `provenance` | `SheetId` ; calcul de minutage (plus fort reste, Dart pur, budgets lus dans `RulesConfig.shapes`) ; union scellée `Illustration` ; géométrie bille fantôme et quantité dérivée (renvoie un `double`) ; `ContactFraction` et `TipPoint` **déplacés depuis `shared/ui`** (le domaine et `shared/lib` ne peuvent importer que `shared/lib`) ; `ContactFraction` n'est pas réexporté, `TipPoint` l'est par `shared/ui` (sa `direction` y vit) ; `Provenance` (`s`, `ffb`, `web`, `prop`) : type unique de provenance pour le catalogue et les séances |
| `shared/ui` | composants | `ProposalBadge` (texte « Proposition » localisé, sémantique), `ContactStrip`, `CueSideView`, `StanceDiagram`, `PowerScale`, `AngleMark`, flèche `aim` de `TableDiagramSpec`, `TipPoint` étendu ; `PresentationScope` ; un use case Widgetbook par widget public |
| `entities` | `exercise_catalog` (modifié) | `TrainingBlock.source` et `ExerciseSpec.source` (`S` par défaut, `Prop`) ; parseur ; blocs `posture` et `bille-fantome` ; `teachingOrder` renuméroté |
| `entities` | `session_sheet` (nouveau) | `domain` : `SessionSheet` (`technique`, `part`), `SheetTheorySection`, `SheetExercise`, `SheetGame`, `Scoring` scellé (`counter`, `checklist`), `reviewReasonsOf` / `needsReview` / `gameNeedsReview` et `groupByTechnique` / `partCountOf` / `diagramIdsOf` (pures, partagées par les deux features), port `SessionSheetRepository` (`getAll`, `getById`) ; `data` : `SessionSheetYamlParser` (clés ciblées, erreur `invalidSheet`), `AssetSessionSheetRepository` ; `presentation` : `IllustrationMapper` (tous les types ; `diagram_ref` est rendu avec les schémas que la feature a résolus par identifiant ; `table` : construit le `TableDiagramSpec` de `shared/ui`, car le mapper de `exercise_diagram` n'est pas importable), `SheetIllustrationView` |
| `entities` | `session` (modifié) | `Session.sheetId`, repositories mémoire et drift |
| `features` | `browse_sheets` | `ListSheets` (groupées par technique), `GetSheet`, `SheetCatalogueBloc` (filtre « à valider »), vues liste et détail |
| `features` | `run_sheet` | `ResolveRunPlan(sheet, audience)` (minutage, étapes, sommaire), `RunSheetCubit` (étape, minuteur injecté, compteurs locaux, présentation), vues d'étape ; slot `notationBuilder` / callback `onRecord(blockId, recallBlockId)` |
| `features` | `plan_session` (modifié) | `PlanSession(title, audience, sheetId?)`, champ « Séance du catalogue » (liste de `SheetOption` groupée par technique, passée en paramètre) |
| `features` | `backup_data` (modifié) | `sheetId` à l'encodage/décodage ; règle `BackupRules` |
| `features` | `suggest_session`, suivi (vérifiés) | les blocs `[Prop]` entrent dans la suggestion et la progression par `teachingOrder` ; ils portent le badge « Proposition » dans les écrans qui les listent |
| `pages` | `sheet_catalogue`, `sheet_detail`, `sheet_guide`, `sheet_presentation` ; `session_planner` (modifié) | composition ; callbacks de navigation ; fournissent les cubits/blocs et relient la notation (la résolution `ExerciseRef` + identifiant de diagramme se fait dans les features : `GetSheet`, `ResolveRunPlan`) |
| `app` | `router.dart`, `shell.dart`, DI | routes, destination, `BlocProvider`, branchement `data` |

Contraintes respectées :

- `domain` en Dart pur ; `entities/session` n'importe pas `entities/session_sheet` (`SheetId` en `shared/lib`).
- `entities/session_sheet` n'importe ni `exercise_catalog` ni `exercise_diagram` : elle ne porte que `ExerciseRef` (`shared/lib`) et des **identifiants de diagramme** (chaînes ; `DiagramKey` est dans `entities/exercise_diagram`, il n'est donc pas importable) ; la résolution se fait dans les features (`GetSheet`, `ResolveRunPlan`) via `DiagramLibrary.byId`, par leurs dépendances descendantes vers `entities/exercise_diagram` (permises par FSD ; révision de la conception d'origine, qui prévoyait un slot en `pages`). Le statut `[Prop]` d'un exercice est porté par `src` dans la séance (contrôlé égal à `source` du bloc par V13), sans importer `exercise_catalog`.
- `features/run_sheet` n'importe ni `record_results` ni `suggest_session` ; la saisie est composée par `pages`/`app` (callbacks, slot).
- `presentation` n'importe pas `data` ; seule `app` les relie.
- Pas de `StatefulWidget` dans `pages` ; état dans bloc/cubit.
- Assets : `app/assets/fiches/` déclaré dans `pubspec.yaml` (non récursif) ; `app/assets/diagrammes/proposition/` déclaré comme les autres dossiers de diagrammes.
- `scripts/sync_fiches.sh [--check]` (bash) et `app/tool/fiches.dart` (+ `app/test/tool/fiches_test.dart`) ajoutés à `check.sh --fast` (étape en lecture seule : `check_fast_read_only_test` s'applique) et à la CI. Le validateur n'est **pas** dans `scripts/` : celui-ci n'a pas de `pubspec.yaml`, donc pas de `package:yaml`. Les 29 séances étant écrites (fin L7), l'étape est en `--complete`.

## 5. Migration (V1 non livrée : au plus simple)

### 5.1 drift (v2 → v3)

- `PlannedSessions` (`tables.dart`) : `TextColumn get sheetId => text().nullable()();`, sans clé étrangère (les séances du catalogue sont des assets).
- `currentSchemaVersion = 3` ; `from2To3` : `(m, schema) async => m.addColumn(schema.plannedSessions, schema.plannedSessions.sheetId)` dans `stepByStep` (comme `from1To2`, qui passe par `schema.assessments`, l'instantané, et non par la table courante). Aucune transformation de données.
- Régénérer : `dart run drift_dev make-migrations` puis `dart run drift_dev schema generate` → `app/drift_schemas/app_database/drift_schema_v3.json`, `app/test/drift/app_database/generated/schema_v3.dart` et `schema.dart`, `app_database.steps.dart` (générés : jamais édités à la main, le hook `pre-tool-guard` bloque `*.steps.dart`) ; `build_runner` pour `app_database.g.dart`.
- Tests à adapter dans `test/unit/shared/persistence/migration_test.dart` : « version plus récente » passe de `user_version = 3` à `4` ; test d'instantané ; nouveau test v2 → v3 conservant les lignes avec `sheetId == null`.
- `DriftSessionRepository` et le repository mémoire mappent la colonne **en lecture, en insertion et dans le `DoUpdate` de `add`** (c'est le chemin de l'import et de la replanification : l'oublier perd silencieusement la séance liée à la 2e écriture) ; `getAll` ne lève jamais pour un `sheetId` inconnu du catalogue. `repository_contract.dart` couvre : aller-retour avec et sans séance liée, `add` deux fois le même id avec `sheetId` changé puis remis à `null`.
- Mise à jour de `docs/engineering/adr/0001-persistance-locale-drift.md` (schéma v3, migration `from2To3`, règle `sheetId`).
- Downgrade toujours refusé.

### 5.2 Sauvegarde JSON (même format)

- Le format et `BackupCodec.currentVersion` ne changent **pas** (aucun fichier existant à relire) ; aucun test de version n'est modifié.
- Encodeur : écrit `sheetId` (`null` autorisé) pour chaque séance planifiée. Décodeur : `sheetId: _read.optionalString(json['sheetId'])` dans `_decodePlanned` ; un identifiant mal formé (`SheetId` invalide) lève un invariant, traduit en `backupInvalid` par `BackupDecoder`. Aucune distinction « absent / nul » : l'import étant une fusion par identifiant, la valeur du fichier remplace celle de la base, comme pour tout autre champ.
- `BackupRules` : nouvelle méthode `_checkPlanned` (aujourd'hui seuls `sessionRecords`, `attempts`, `assessments` sont contrôlés) : si `sheetId != null`, il doit appartenir aux ids du `SessionSheetRepository` (injecté dans `BackupRules`, qui dépend déjà de `CatalogueRepository`) ; sinon **`backupInconsistent`** avec un message clair, comme `mainBlockId` (`backupInvalid` est réservé aux valeurs qui violent une règle).
- Tests ajoutés : aller-retour avec `sheetId` valide ; `sheetId` inconnu refusé avec `backupInconsistent` et base vide ; `sheetId` de mauvais type refusé avec `backupInvalid`.

### 5.3 Compatibilité fonctionnelle

- Une séance planifiée sans séance du catalogue reste valide (« séance libre »).
- Aucun lien `SessionRecord` ↔ `Session` n'est introduit.

## 6. Scénarios BDD clés (écrits en rouge avant le code)

Les scénarios s'exécutent sur un `SessionSheetRepository` de test (fixtures : au moins 3 techniques chaînées dont une à 2 parties, une séance avec un jeu `[Prop]` et une séance d'un bloc `[Prop]`), pas sur les 29 fichiers réels, qui n'existent qu'à la fin de L7. Les assertions « 14 techniques, 29 séances » et « Posture » sont reprises en acceptation au L8 sur les vrais assets.

1. **Catalogue** : depuis le menu « Séances », je vois toutes les techniques dans l'ordre d'enseignement (rebond sur bande avant rejet naturel), chacune avec ses séances « k/n » ; au L8, 14 techniques et 29 séances.
2. **Lecture seule** : sur « Quantité demi-bille, séance 1/2 », je vois rappel, théorie, exercices, jeu, bilan ; aucun champ de saisie ni bouton « Modifier » ou « Supprimer ».
3. **Public et minutage** : « Adultes » affiche 120 min et la théorie adulte ; « Enfants » affiche 90 min ; la somme des phases vaut la durée.
4. **Planifier avec séance** : je choisis « Puissance, séance 1/2 » pour les enfants ; la séance planifiée apparaît liée au catalogue et 90 min ; le titre est prérempli et reste modifiable (le contenu du catalogue, lui, ne l'est pas).
5. **Planifier sans séance** : la planification libre actuelle fonctionne ; la liste propose « Choisir une séance ».
6. **Choisir la séance 2 d'une technique** : dans le planificateur et dans le catalogue, je sélectionne « Demi-bille, séance 2/2 » ; son rappel porte sur la séance 1/2 et ses exercices sont les restants (3-4) ; la séance planifiée garde cet identifiant.
7. **Lancer** : « Lancer » affiche la phase Accueil avec le rappel et la question flash, puis la Notion avec l'illustration.
8. **Mise en place** : à l'exercice 1, je vois le schéma, la mise en place, la consigne et l'attendu.
9. **Présenter** : « Montrer » ouvre la présentation (route dédiée) : illustration seule, sans notes ni notation ; « Fermer » revient au guidage à la même étape et avec le même public.
10. **Noter** : « Noter les résultats » ouvre la saisie sur le bloc et l'exercice courants (le groupe se choisit à la saisie) ; 5 passages réussis valident l'exercice (règles existantes) ; « Retour à la séance guidée » ramène à la même étape avec les compteurs locaux intacts.
11. **Noter une initiation** : sur une initiation, je compte 3 réussites sur 5 ; la mention « non enregistré » est visible.
12. **Refus d'un 3e passage** : le plafond de 2 passages par élève, par exercice et par séance (`maxPassesPerExercisePerSession`) reste appliqué (non-régression).
13. **Sauvegarde** : export puis import conserve la séance choisie ; un `sheetId` inconnu est refusé (`backupInconsistent`, rien d'écrit).
14. **Étapes** : les cinq phases sont parcourues dans l'ordre ; « Précédent » revient à l'étape précédente ; le sommaire permet de sauter au jeu.
15. **Séance indisponible** : une séance planifiée dont le `sheetId` est inconnu s'affiche « séance indisponible » avec « Choisir une séance », sans erreur.
16. **Première séance** : sur « Posture, séance 1/2 » (order 1), la phase Accueil n'affiche aucun rappel de séance précédente mais l'accueil (règles de conduite, matériel).
17. **Voir un jeu `[Prop]` dans la séance** : sur une séance au jeu adapté, je parcours rappel → théorie → exercices → jeu → bilan ; le jeu, sa règle de lien et les minutes de phase portent le badge « Proposition » dans le détail et dans le guide ; dans la présentation (illustrations seules, sans règles), l'illustration d'un élément `[Prop]` (par exemple le schéma de mise en place du jeu, ou celui d'un exercice d'un bloc `[Prop]`) garde le badge ; les éléments sourcés portent leur pastille `[S]`.
18. **Filtre « à valider »** : j'active le filtre ; seules les séances contenant du contenu `[Prop]` restent, groupées par technique, avec l'indicateur ; je le désactive et toutes reviennent. Une séance sans contenu `[Prop]` n'a pas l'indicateur, bien que son thème et ses défis soient des propositions badgées.
19. **Bloc `[Prop]`** : sur « Posture, séance 1/2 », les exercices portent le badge « Proposition » (taux compris) et la notation ouvre `/record` sur le bloc `posture`.
20. **Rappel de résultats** : en lançant « Demi-bille, séance 2/2 », la saisie reçoit `main = demi-bille` et `recall = bille-pleine` (bloc de la plus récente séance précédente de bloc différent) ; pour « Posture, séance 1/2 », `recall` est nul.

21. **Relire sans élèves** : depuis le détail d'une séance, sans séance planifiée ni élève, « Lancer » ouvre le guide ; je parcours toutes les étapes (rappel, théorie, exercices, jeu, bilan) sans aucune saisie obligatoire, saute du sommaire au jeu puis reviens à l'étape précédente, et « Fin » ne produit aucune erreur ni écriture.
22. **Contenu en français sous interface anglaise** : en `en`, le catalogue et le détail affichent le bandeau « contenu en français » (ADR 0004, décision 12) ; les libellés d'interface restent traduits.

Tests unitaires et de contrat :

- Parseur : clés manquantes, type d'illustration inconnu, `ref` mal formé, clé interdite ; parseur du catalogue : `source` `S`/`Prop`, valeur inconnue refusée.
- Validateur `app/tool/fiches.dart` : un cas fautif par règle V1 à V24 (rouge d'abord) ; séance isolée valide hors `--complete` ; table des parties recalculée depuis un catalogue de test (`N` impair, borne min, borne max, `quart`/`finesse`) ; test de contrat que le tableau de `FORMAT.md` § 1.2 égale le calcul.
- Contrat Dart sur les fichiers réels d'`app/assets/fiches/` : V12 (minutage 90/120 par séance et par public avec `RulesConfig.shapes` par défaut) et V17 (géométrie) ; les autres règles sont rejouées sur les mêmes fichiers ; ids figés et 29 fichiers présents (assertion activée à la fin de L7).
- `session_sheet_timing` : plus fort reste, égalités, somme exacte (valeurs de l'exemple demi-bille-1 : 8/5/7, 8/5/5/7, 23/12, 25/25).
- `ghost_ball_geometry` : valeurs numériques indépendantes (θ = 30° donne 0,5 ; θ = 0 donne 1,0 ; position du fantôme pour une poche donnée).
- `needsReview` : jeu adapté, jeu sans source, exercice `Prop`, théorie `Prop` déclenchent ; thème, défis, variante et lien seuls ne déclenchent pas.
- Choix du bloc de rappel de résultats : partie 1, partie `k > 1`, `quart`/`finesse` (bloc partagé), première séance.
- Port : aucune méthode d'écriture (classe de test `implements` limitée à `getAll` et `getById` ; pas de réflexion en Flutter).
- `RunSheetCubit` : transitions, minuteur à horloge factice, compteurs locaux, reprise via `step`, survie à un aller-retour `/record` (test de routeur).
- Widgets : détail sans champ de saisie ; `ProposalBadge` (texte, sémantique) ; mode présentation ; nouveaux widgets de `shared/ui` (sémantique ; golden facultatif) ; Widgetbook.
- Garde-fous : architecture (dont règle `run_sheet` ↛ `record_results`), couverture ≥ 90 %, `check_l10n`, `sync_fiches.sh --check`, `sync_catalogue.sh --check`, `sync_diagrammes.sh --check`.

## 7. Lots d'implémentation

Définition de « terminé » commune : `scripts/check.sh --full` vert, scénario BDD couvrant le comportement, tests unitaires, aucune chaîne en dur, documentation à jour, aucun `TODO`/`skip`/stub, relecture dans un contexte séparé. Aucun commit sans demande explicite.

| Lot | Contenu | Dépend de | Critères de fin | Agents / skills |
|---|---|---|---|---|
| **L0** Cadrage | Les décisions de produit sont prises (ADR 0004, section Décision). Reste à vérifier : `OpenSession`/`OpenOrResumeSession` avec `recall` nul ou égal à `main` (acquis : `OpenSession` accepte les deux nuls, `SessionRecord` refuse `recall == main`), règle `StatefulWidget` dans `architecture_rules.dart` (absente à ce jour : documentée dans `architecture.md`, pas outillée), faisabilité de `exercise`/`from` sur `/record` et `/record/:sessionId` ; passer ADR 0004 à « accepté ». Déjà établi par lecture du code (à ne pas refaire) : `JsonReader` ignore les clés inconnues ; `Audience` = `children`/`adults` ; `scripts/` sans `pubspec.yaml` donc sans `yaml` (validateur en `app/tool/`) | — | ADR « accepté » ; liste de vérifications cochée avec preuves | `architecte-fsd` (lecture seule), `dev-quality-gates` |
| **LB** Blocs manquants | Ajouter les blocs `posture` et `bille-fantome` à `docs/knowledge/03-exercices/catalogue-entrainement.yaml` : `source: Prop` sur le bloc et chaque exercice, 4 exercices chacun, `sessions: {min: 1, max: 2}`, taux `[Prop]` proches de ceux des blocs voisins, exercices adaptés des fiches `[S]` (initiation 1-4 et fiche technique 1 ; fiche technique 3 et jeu 1 pour la bille fantôme), sans présentation « officielle » ; diagrammes de mise en place `[Prop]` dans `docs/knowledge/03-exercices/diagrammes/proposition/` (une page par bloc, `rank: Prop`, ids `proposition-pNN-eK`, même `FORMAT`) ; `teaching_order` renuméroté (posture 1, puissance 2, bille-fantome 3, bille-pleine 4, …, trajectoires-blanche 15) ; parseur (`source` facultatif, `S` par défaut), `TrainingBlock.source` et `ExerciseSpec.source` ; règles de suggestion et de progression vérifiées (`recall_selector.dart`, `session_planner.dart`) ; tests d'invariants adaptés (`asset_catalogue_repository_test` : 13 blocs / 64 exercices → 15 / 72 et « commence par `puissance` » → `posture` ; `student_sheet.feature` et `student_sheet_test` : « 1 of 64 exercises validated » → 72 ; `catalogue_diagrammes_test` : les 72 exercices illustrés ; `asset_diagram_repository_test` : 103 diagrammes → 103 + les diagrammes `[Prop]` et familles d'identifiants `{entrainement, initiation, jeux, proposition}` ; `diagrammes_format_test` : seuils `_minFiles`/`_minTables` relevés ; scénarios BDD de suggestion relus, leurs étapes « avant `<bloc> n` » suivant l'ordre du catalogue) ; `sync_catalogue.sh` et `sync_diagrammes.sh` (+ `pubspec.yaml`, `tool/diagrammes.dart` : `rank: Prop`, page hors PDF ; le parseur et le validateur exigent `source.file` non vide et `source.page` entier positif : une page `[Prop]` porte `file: "Proposition (hors PDF)"`, `page` = rang de la page proposition, `rank: Prop` ; `success_rate` absent ou égal au taux du bloc ; aucun `bronze`) ; docs : `diagrammes/FORMAT.md` (la règle d'or et le § 3 affirment que tout fichier est une transcription `[S]` : y ajouter le dossier `proposition/`), `diagrammes/README.md` (dossiers, index, totaux), `docs/engineering/architecture.md` (« 64 exercices, tous illustrés »), `03-exercices/entrainement.md` (blocs `[Prop]`), `00-provenance-et-fiabilite.md` (« Écarts connus » : blocs ajoutés hors source), `03-exercices/README.md` (« 13 blocs »), en-tête d'`entrainement.md` (« 13 blocs distincts + 1 doublon, 34 pages » : les blocs `[Prop]` y forment une section distincte, hors des 34 pages du PDF) | L0 | catalogue et asset synchronisés ; `check.sh --full` vert (invariants mis à jour) ; chaque ajout tracé `[Prop]` ; `docs/sources/` intact ; relecture pédagogique indépendante des deux blocs | `connaissances-enrichir`, `dev-tdd`, `dev-quality-gates`, `relecteur-pedagogique` (contexte séparé) |
| **L1** Chaîne de contenu | `app/tool/fiches.dart` (V1-V11, V13-V16, V18-V24 ; modes séance isolée et `--complete` ; structure et parties calculées depuis le catalogue) + `app/test/tool/fiches_test.dart` ; `scripts/sync_fiches.sh` ; `check.sh --fast` (étape lecture seule) et CI ; `pubspec` (`assets/fiches/`) ; séance pilote `09-demi-bille-1.yaml` (de `FORMAT.md` § 9) | LB | validateur vert sur le pilote seul (sans exiger les 28 autres : structure du § 1 calculée) et rouge sur chaque cas fautif ; `sync_fiches.sh --check` vert ; `check.sh --fast` vert | `dev-tdd`, `dev-quality-gates` |
| **L2** Domaine et données | `SheetId`, déplacement de `ContactFraction`/`TipPoint` en `shared/lib` (`ContactFraction` importé directement, `TipPoint` réexporté par `shared/ui` pour sa `direction`), `session_sheet_timing`, union `Illustration`, entité `session_sheet` (`needsReview` comprise), parseur, repository asset ; test de contrat paramétré sur `app/assets/fiches/*` (V12, V17, autres règles ; assertion « 29 fichiers et ids figés » désactivée jusqu'à la fin de L7) | L1 | tests rouge puis vert ; couverture ≥ 90 % ; port sans écriture ; architecture verte après le déplacement des énumérations | `dev-feature`, `dev-tdd`, `architecte-fsd` |
| **L3** Design system | `ProposalBadge`, `ghost_ball_geometry`, `ContactStrip`, `CueSideView`, `StanceDiagram`, `PowerScale`, `AngleMark`, flèche `aim`, `TipPoint` étendu (9 valeurs) ; `docs/engineering/design-system.md`. `IllustrationMapper` est au L4 (il dépend de l'union `Illustration`, L2). Le déplacement de `ContactFraction`/`TipPoint` est fait au L2 : L3 démarre sur cette base pour les widgets qui les utilisent | L0 ; L2 pour `TipPoint` et `ContactFraction` (le reste en parallèle de L1-L2) | un use case Widgetbook par widget ; `check_widgetbook` vert ; sémantique testée | `dev-feature`, `dev-tdd`, `testeur-bdd` |
| **L4** Consultation | `browse_sheets` (liste groupée par technique, filtre « à valider »), `IllustrationMapper` et `SheetIllustrationView`, pages catalogue et détail avec badges, routes, shell (`_paths`, `navSession`), l10n, bandeau « contenu en français » ; scénarios 1 à 3, 18, 22 | L2, L3 | scénarios verts ; navigation par le menu ; aucune action d'écriture exposée ; badge visible sur chaque élément `[Prop]` du détail | `dev-feature`, `dev-bdd` |
| **L5** Lien séance planifiée ↔ séance du catalogue | `Session.sheetId`, migration v3 minimale, `BackupRules`, sélecteur groupé par technique dans le planificateur, affichage « séance indisponible » ; scénarios 4, 5, 6, 13, 15 | L2 (parallèle à L4) | migration et contrats mémoire + drift verts ; instantané v3 versionné | `dev-feature`, `dev-bdd`, `dev-tdd`, `dev-quality-gates` |
| **L6** Séance guidée | `run_sheet`, pages guide et présentation, sommaire, badges en contexte, notation (deep link `exercise`/`from` sur `/record` et `/record/:sessionId`, choix du bloc de rappel, compteur local d'initiation), minuteur, cubits conservés au-dessus du routeur (`RunSheetSessions`) ; scénarios 7 à 12, 14, 16, 17, 19, 20, 21 (sur les vrais assets) | L4, L5 | scénarios verts ; `check.sh --full` vert ; état conservé après aller-retour `/record` | `dev-feature`, `dev-bdd`, `dev-tdd`, `architecte-fsd`, `testeur-bdd` |
| **L7** Rédaction des 29 séances (par vagues, **dans l'ordre d'enseignement** : `recall.reuse` et `link_previous` exigent les illustrations de la séance `previous`) | Vague A : posture-1, posture-2, puissance-1, puissance-2, bille-fantome-1, bille-fantome-2, bille-pleine-1, bille-pleine-2 (8) ; pilote demi-bille-1 (vient de L1) ; vague B : demi-bille-2, trois-quarts-1, trois-quarts-2, quart-1, finesse-1, rebond-bande-1, rebond-bande-2 (7) ; vague C : rejet-naturel-1, rejet-naturel-2, coule-1, coule-2, coule-3, carreau-1, carreau-2, angle-droit-1, angle-droit-2, retro-1, retro-2, retro-3, retro-4 (13, jeux `[Prop]`) | L1 (parallèle à L2-L6) | `fiches.dart --complete` vert sur 29 séances ; assertion « 29 fichiers et ids figés » activée ; relecture pédagogique indépendante par vague sans blocage ; `docs/sources/` intact ; chaque `[Prop]` tracé ; chaque exercice des blocs couvert par exactement une séance | `concepteur-seance`, `relecteur-pedagogique` (contexte séparé), `connaissances-enrichir`, `seance-planifier` en référence |
| **L8** Finition | Accessibilité (contrastes, cibles tactiles, mouvement réduit, badges), tablette paysage, docs (`architecture.md`, `quality-gates.md`, glossaire, `progression-par-cycles.md` : la bille fantôme y est « intégrée aux séances plein/demi », alors qu'elle a sa technique propre), `check.sh --fast` en `--complete`, acceptation des scénarios 1, 16 et 19 sur les vrais assets, revues finales | L6, L7 | tous garde-fous verts ; revues `architecte-fsd` et `testeur-bdd` sans réserve bloquante | `dev-quality-gates`, `architecte-fsd`, `testeur-bdd` |
| **L9** (facultatif) | Persistance des compteurs d'initiation et de jeu ; lien `SessionRecord` ↔ `Session` ; marque « relu » persistante (voir section 10) | L8, décision utilisateur | selon décision | `dev-feature` |

Avancement (vérifié par `scripts/check.sh --full`) : **LB, L1, L2, L3, L4, L5, L6 et L7 réalisés** ; L8 (finition) et L9 (facultatif) restent à faire. Le guide de l'animateur (`../guide-animateur.md`) décrit le catalogue, la planification avec une séance, le lancement, la présentation, la notation et la validation des propositions.

Parallélisme : LB puis L1 puis L2 ; L3 (widgets) en parallèle dès L0, sauf les éléments qui utilisent `ContactFraction`/`TipPoint` (après le déplacement du L2) ; L4 après L2 et L3 ; L5 après L2 (parallèle de L4) ; L6 après L4 et L5 ; L7 dès L1, en parallèle de L2-L6 ; L8 en dernier.

## 8. Risques

- **Précision des schémas** : générés, non à l'échelle, `[Prop]`, non validés par un animateur ; chaque illustration porte `alt` et `caption`, et prend la provenance de l'élément qui la référence (badge « Proposition » si cet élément est `[Prop]`) ; les diagrammes des blocs `[Prop]` aussi.
- **Source enrichie** : deux blocs `[Prop]` dans un catalogue dérivé de `[S]` ; risque de les confondre avec du fédéral. Mitigation : champ `source: Prop` obligatoire, badge dans toute l'application, entrée « Écarts connus », V19.
- **Migration drift** : première migration non triviale, données de club (mineurs) ; colonne nullable, test de migration avec données, pas de downgrade.
- **Contenu non sourcé** : six techniques sans jeu source (bille fantôme, rejet naturel, coulé, carreau, angle droit, rétro) et la finesse sans jeu dédié (jeu n° 10 générique) ; adaptations `[Prop]` affichées comme telles, à valider par l'utilisateur dans l'application ; 18 séances sur 29 « à valider » (mesuré), dont 12 pour le jeu.
- **Volume** : 29 séances, environ 80 illustrations ; goulot = relecture indépendante, d'où les vagues du L7.
- **Séances multiples d'une technique** : risque de redites entre parties ; V23 impose une variante de jeu différente, la relecture vérifie l'approfondissement réel.
- **Deux sens de « séance »** : voir vocabulaire ; libellés l10n dédiés.
- **FSD** : composition par `pages`/`app` et slots ; risque de complexité de DI, mitigé par le cubit parent et les callbacks.
- **Couverture et Widgetbook** : tout widget et page nouveaux y sont soumis.
- **Lisibilité en salle** : tailles de police et contrastes à valider sur matériel réel (non vérifiable ici).

## 9. Décisions retenues (par l'utilisateur, 2026-10-13)

1. **Menu** : « Séance » devient le catalogue (« Séances ») ; la suggestion par groupe reste un bouton en tête du catalogue ; 5 destinations.
2. **Blocs manquants** : quand une technique n'a pas de bloc d'entraînement, on en crée un (`posture`, `bille-fantome`), explicitement `[Prop]` (lot LB).
3. **Plusieurs séances par technique** : calculées par `borné(ceil(N / 2), min, max)` ; 29 séances ; l'animateur délègue le découpage.
4. **Validation des propositions dans l'application, en contexte** : badge « Proposition », indicateur et filtre « à valider », parcours complet de la séance.
5. **Rappel** : théorique sur la séance précédente (partie `k - 1` pour `k > 1`) ; résultats : bloc de la plus récente séance précédente de bloc différent ; toutes les techniques ont un bloc.
6. **V1 non livrée** : pas de compatibilité de données ; migration drift minimale ; sauvegarde d'un seul format ; `sheetId` inconnu = erreur claire.
7. **Contenu en français seulement** ; interface fr/en ; illustrations générées, aucune photo PDF ; contenu en lecture seule.
8. **Minutage calculé par poids** (jamais écrit) : les minutes sont indicatives et `[Prop]`.
9. **Numérotation ADR** : 0004 (0003 existe déjà).

## 10. Points ouverts (réellement discutables)

Aucun n'est tranché ; chacun a une option recommandée.

1. **Marque « relu » persistante.** Valider une proposition dans l'application ne laisse aucune trace : le contenu `[Prop]` reste `[Prop]` jusqu'à ce que la source YAML soit modifiée. Option recommandée pour la V1 : pas de marque persistante (le filtre « à valider » liste ce qui reste à relire ; la validation se traduit par une modification du YAML, puis le badge s'efface ou la source est citée) ; alternative : une table locale de séances « relues » (lot L9).
2. **Granularité des compteurs locaux** (initiation, jeu) : par élève ou par groupe ? Par élève est cohérent avec le suivi mais alourdit le guidage ; non persistant dans tous les cas.
3. **Séance déjà ouverte le même jour.** `OpenOrResumeSession` remplace `mainBlockId`/`recallBlockId` d'une séance du même groupe et du même jour ; lancer deux séances le même jour (par exemple les parties 1 et 2 d'une technique) écrase la notion ou produit `recall == main`. Le comportement actuel est conservé (le choix du bloc de rappel évite `recallEqualsMainBlock`), à vérifier au L0.
4. **Défis ludiques chiffrés.** V10 interdit les taux dans `expected` et `instruction`, pas dans `playful.challenge` : un défi « 5 sur 8 » peut être pris pour le taux de la source. Option : badge « Proposition » systématique à côté du défi (prévu) et relecture.
5. **Posture : première séance « courte ».** `progression-par-cycles.md` conseille une séance courte (risque de rejet) ; `posture-1` dure 90 ou 120 min. Option : théorie réduite et poids plus forts à l'initiation et au jeu (déjà possible par les poids) ; à confirmer à la relecture.
6. **Taux et nombre d'exercices des blocs `[Prop]`.** 4 exercices et `sessions: {1, 2}` sont des valeurs de conception ; les taux sont inspirés des blocs voisins. À confirmer par l'animateur à la relecture du lot LB ; toute modification recalcule le tableau des parties (V2).
