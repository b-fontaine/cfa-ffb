# Format des séances du catalogue

Statut : **proposé (2026-10-13), révisé après les décisions de l'utilisateur** (voir `docs/engineering/adr/0004-catalogue-fiches-seances.md`). **29 séances rédigées** (lot L7), `fiches.dart --complete` vert ; le pilote `09-demi-bille-1.yaml` (section 9) reste le modèle normatif. Les éléments `[Prop]` restent à valider par l'animateur.

Le catalogue compte **14 techniques**. Chaque technique est enseignée en **une ou plusieurs séances** (ses « parties »), soit **29 séances** au total. Une séance décrit **une partie d'une technique** pour **les deux publics** ; elle est lue par l'application en lecture seule (asset copié par `scripts/sync_fiches.sh`), contrôlée par `app/tool/fiches.dart` (`cd app && dart run tool/fiches.dart [--complete]`, paquet `yaml` de l'application, comme `tool/diagrammes.dart` ; `scripts/` n'a pas de `pubspec.yaml` et n'est que `dart:io`) et par un test de contrat Dart sur les vrais fichiers (V12 et V17 n'y sont vérifiées que par ce test, car elles lisent du code de `app/lib`).

Règle d'or : **ne rien inventer qui se présente comme officiel**. Le contenu sourcé est repris des sources (`[S]` PDF, `[FFB]`, `[Web]`). Le ludique, le minutage, les jeux adaptés et les blocs d'entraînement ajoutés (posture, bille fantôme) sont `[Prop]`, déclarés comme tels et **affichés comme tels, élément par élément, dans l'application** (section 5).

## 1. Techniques, parties et fichiers

### 1.1 Règle des parties

Pour une technique dont le bloc d'entraînement porte `N` exercices (ceux de la technique seulement : pour `quart` et `finesse`, qui se partagent le bloc `quart-finesses`, `N` = 2 chacune) et une recommandation `sessions: {min, max}` :

`parties = borné(ceil(N / 2), min, max)`

- Séance 1 = **introduction** de la notion ; séances suivantes = **approfondissement** (exercices restants, variantes : chevalet sur surface, distances) avec **rappel de la séance précédente**.
- Les exercices du bloc sont répartis en tranches contiguës, dans l'ordre du catalogue, les premières parties recevant l'exercice en plus (`N = 8`, 3 parties : 3 / 3 / 2).
- Si `parties > N`, la technique est invalide (erreur du validateur).
- L'identifiant d'une séance est `<technique>-<k>` (`demi-bille-2`) ; le titre affiché ajoute « séance k/n » (« Demi-bille, séance 2/2 »).

### 1.2 Techniques (14, dans l'ordre d'enseignement `[U]` : rebond sur bande **avant** rejet naturel)

Tableau **calculé depuis `catalogue-entrainement.yaml` après ajout des deux blocs `[Prop]`** (voir ADR 0004, décision 5). Le validateur le recalcule à chaque exécution (il ne lit aucune constante pour le nombre de parties) et un test de contrat vérifie que ce tableau Markdown lui est égal : modifier le catalogue impose de le mettre à jour.

| Rang | `technique` | Titre | Fiche technique | Bloc | Exercices (`N`) | `sessions` | Parties | Répartition | Initiation | Jeu source |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `posture` | Posture, visée et coup de queue | 1 | `posture` `[Prop]` | 1-4 (4) | 1-2 | **2** | 1-2 / 3-4 | 1-4 | 1 (variante 2) `[S]` |
| 2 | `puissance` | La puissance | 2 | `puissance` | 1-4 (4) | 1-2 | **2** | 1-2 / 3-4 | 5 | 3 (ou 4, 5) `[S]` |
| 3 | `bille-fantome` | Viser pour empocher (bille fantôme) | 3 | `bille-fantome` `[Prop]` | 1-4 (4) | 1-2 | **2** | 1-2 / 3-4 | aucune | `[Prop]` d'après jeu 1 |
| 4 | `bille-pleine` | Quantité de bille pleine | 4 | `bille-pleine` | 1-4 (4) | 2-3 | **2** | 1-2 / 3-4 | 6 | 6 `[S]` |
| 5 | `demi-bille` | Quantité demi-bille | 5 | `demi-bille` | 1-4 (4) | 2-3 | **2** | 1-2 / 3-4 | 7 | 7 `[S]` |
| 6 | `trois-quarts` | Quantité trois-quarts de bille | 6 | `trois-quarts` | 1-4 (4) | 1-2 | **2** | 1-2 / 3-4 | 8 | 8 `[S]` |
| 7 | `quart` | Quantité quart de bille | 7 | `quart-finesses` | 1-2 (2) | 1-2 | **1** | 1-2 | 9 | 9 `[S]` |
| 8 | `finesse` | Finesse | 8 | `quart-finesses` | 3-4 (2) | 1-2 | **1** | 3-4 | 9 | 10 `[S]` + contrainte `[Prop]` |
| 9 | `rebond-bande` | Le rebond d'une bille sur une bande | 9 | `rebond-bande` | 1-4 (4) | 2-2 | **2** | 1-2 / 3-4 | 11 | 13 `[S]` |
| 10 | `rejet-naturel` | Le rejet naturel | 10 | `rejet-naturel` | 1-4 (4) | 2-2 | **2** | 1-2 / 3-4 | 12 | `[Prop]` d'après jeu 14 |
| 11 | `coule` | Le coulé | 11 | `coule` | 1-8 (8) | 2-3 | **3** | 1-3 / 4-6 / 7-8 | 13-14 | `[Prop]` d'après jeu 14 |
| 12 | `carreau` | Le carreau | 12 | `carreau` | 1-4 (4) | 1-2 | **2** | 1-2 / 3-4 | 15 | `[Prop]` d'après jeu 14 |
| 13 | `angle-droit` | Le coup à angle droit | 13 | `angle-droit` | 1-4 (4) | 2-3 | **2** | 1-2 / 3-4 | 16 | `[Prop]` d'après jeu 14 |
| 14 | `retro` | Le rétro | 14 | `retro` | 1-10 (10) | 3-4 | **4** | 1-3 / 4-6 / 7-8 / 9-10 | 17-19 | `[Prop]` d'après jeu 14 |

Total : **29 séances**. Les blocs `posture` et `bille-fantome` **existent** dans `catalogue-entrainement.yaml` (lot LB, `source: Prop`, 4 exercices chacun, `sessions: {min: 1, max: 2}`) ; le tableau a été **recalculé depuis le fichier du catalogue le 2026-10-13** (15 blocs, 72 exercices : 29 parties, résultat identique). Si le catalogue change, ce tableau est recalculé. `quart` et `finesse` ont une partie chacune : leur somme (2) respecte le maximum du bloc partagé (2). Les blocs `quantites-de-billes` et `trajectoires-blanche` ne sont pas des techniques : ils peuvent servir de rappel transversal ou d'exercice de synthèse, jamais de séance propre.

Jeux : une séance d'une technique à plusieurs parties reprend le jeu source de la technique **avec une autre variante** (`playful_variant`, V23), ou un jeu voisin `[S]` ; le choix est fait à la rédaction.

### 1.3 Séances (29) et fichiers

Un fichier par séance : `docs/knowledge/05-seances/catalogue/NN-<technique>-<k>.yaml`, `NN` = `order` sur 2 chiffres, de 01 à 29, sans trou.

| order | `id` | Exercices (`ref.n`) | `previous` |
|---|---|---|---|
| 1 | `posture-1` | 1-2 | `null` |
| 2 | `posture-2` | 3-4 | `posture-1` |
| 3 | `puissance-1` | 1-2 | `posture-2` |
| 4 | `puissance-2` | 3-4 | `puissance-1` |
| 5 | `bille-fantome-1` | 1-2 | `puissance-2` |
| 6 | `bille-fantome-2` | 3-4 | `bille-fantome-1` |
| 7 | `bille-pleine-1` | 1-2 | `bille-fantome-2` |
| 8 | `bille-pleine-2` | 3-4 | `bille-pleine-1` |
| 9 | `demi-bille-1` | 1-2 | `bille-pleine-2` |
| 10 | `demi-bille-2` | 3-4 | `demi-bille-1` |
| 11 | `trois-quarts-1` | 1-2 | `demi-bille-2` |
| 12 | `trois-quarts-2` | 3-4 | `trois-quarts-1` |
| 13 | `quart-1` | 1-2 | `trois-quarts-2` |
| 14 | `finesse-1` | 3-4 | `quart-1` |
| 15 | `rebond-bande-1` | 1-2 | `finesse-1` |
| 16 | `rebond-bande-2` | 3-4 | `rebond-bande-1` |
| 17 | `rejet-naturel-1` | 1-2 | `rebond-bande-2` |
| 18 | `rejet-naturel-2` | 3-4 | `rejet-naturel-1` |
| 19 | `coule-1` | 1-3 | `rejet-naturel-2` |
| 20 | `coule-2` | 4-6 | `coule-1` |
| 21 | `coule-3` | 7-8 | `coule-2` |
| 22 | `carreau-1` | 1-2 | `coule-3` |
| 23 | `carreau-2` | 3-4 | `carreau-1` |
| 24 | `angle-droit-1` | 1-2 | `carreau-2` |
| 25 | `angle-droit-2` | 3-4 | `angle-droit-1` |
| 26 | `retro-1` | 1-3 | `angle-droit-2` |
| 27 | `retro-2` | 4-6 | `retro-1` |
| 28 | `retro-3` | 7-8 | `retro-2` |
| 29 | `retro-4` | 9-10 | `retro-3` |

La séance précédente d'une séance de partie `k > 1` est la partie `k - 1` ; celle d'une partie 1 est **la dernière partie de la technique précédente**.

Cette structure (techniques, bloc, plage d'exercices pour `quart`/`finesse`, fiches techniques, fiches d'initiation) est **aussi codée dans `app/tool/fiches.dart`** ; le nombre de parties et la répartition sont **calculés** depuis le catalogue. C'est ce qui permet de valider une séance isolée tant que les 29 ne sont pas écrites (V2, V3 et mode `--complete`). Les `id` ne sont jamais renommés ni supprimés (une séance planifiée les référence) ; si le catalogue change et modifie le nombre de parties, le tableau et les fichiers sont mis à jour dans le même changement.

## 2. Convention générale

- Clés en anglais, valeurs en français. Encodage UTF-8, indentation 2 espaces.
- Publics : clés `children` (90 min) et `adults` (120 min).
- `src` : `S`, `FFB`, `Web` ou `Prop`. Une `ref` texte libre précise (fiche, page).
- Un texte destiné aux élèves enfants est court (voir règle V16).
- Le ludique (`playful`, `theme`, `playful_variant`), les poids et les minutes sont `[Prop]` **par définition** : ils ne portent pas de `src`, mais l'application affiche le badge « Proposition » pour chacun (section 5).

## 3. Schéma

```yaml
version: 1
id: <technique>-<k>               # a-z, 0-9, tiret ; stable à vie ; unique
order: 1..29                      # rang global dans le catalogue (section 1.3)
technique: <slug>                 # une des 14 techniques de la section 1.2
part: <k>                         # 1..parties de la technique
title: <titre de la technique>    # identique pour toutes les parties ; « séance k/n » ajouté à l'affichage
technical_sheets: [<n>, ...]      # fiches techniques fédérales (docs/knowledge/02-techniques)
previous: <id de séance>|null     # séance d'ordre order-1 ; null seulement pour order 1
catalogue_block: <blockId>        # bloc de catalogue-entrainement.yaml ; jamais null
notion: <une phrase : la notion principale unique>   # identique pour toutes les parties
theme:                            # habillage ludique, fil rouge de la technique
  name: <2 à 4 mots>              # identique pour toutes les parties
  pitch: <1 à 2 phrases>          # peut évoluer (épisode k)
recall:                           # phase welcome ; porte sur la séance `previous`
  points: [<2 à 4 puces courtes>]   # order 1 : accueil (règles de conduite, matériel), pas de rappel : voir V22
  question: {ask: <question orale>, answer: <réponse attendue>}
  reuse: {sheet: <id de séance>, illustration: <id>}   # reprend un schéma de la séance `previous` (facultatif ; interdit pour order 1)
  src: S|FFB|Web|Prop
theory:                           # phase notionAndInitiation (1re partie)
  sections:
    - id: <slug local>
      title: <titre>
      weight: {children: <n>, adults: <n>}   # absent = non affiché pour ce public
      body: [<phrases courtes>]
      adult_extra: [<phrases>]               # affiché seulement pour les adultes (facultatif)
      key_point: <une phrase à retenir>
      demo: <geste à montrer>|null
      illustrations: [<id>, ...]
      src: S|FFB|Web|Prop
initiation:                       # phase notionAndInitiation (2e partie, facultative)
  - id: <slug local>
    initiation_sheet: <n>         # numéro de fiche d'initiation (initiation.md)
    title: <titre>
    weight: {children: <n>, adults: <n>}
    setup: <mise en place>
    goal: <consigne à l'élève>
    expected: <attendu observable>
    scoring: <Scoring>
    illustration: <id>|null       # id d'une illustration de la séance (éventuellement de type diagram_ref)
    src: S|FFB|Web|Prop
illustrations:                    # liste fermée de types, voir section 6
  - {id: <slug local>, type: <type>, ...params, caption: <légende affichée>, alt: <texte alternatif>}
training:                         # phase training
  exercises:
    - id: <slug local>
      ref: {block: <blockId>, n: <n>}           # ExerciseRef du catalogue ; obligatoire ; n dans la tranche de la séance (section 1.3)
      diagram: <id de diagramme>                # ex. entrainement-p05-e1, proposition-p01-e1 (DiagramLibrary.byId) ; obligatoire
      title: <titre court>
      weight: {children: <n>, adults: <n>}
      setup: <mise en place : où poser billes et blanche ; ni taux, ni type de chevalet, ni nombre de billes (V10)>
      instruction: <ce que fait l'élève>
      expected: <ce qui est attendu : qualitatif ; le taux vient du catalogue>
      mistakes: [{symptom: <...>, fix: <...>}]  # 0 à 3, lecture animateur
      playful: {hook: <accroche>, challenge: <défi>}   # obligatoire sur chaque exercice (V20) ; [Prop]
      passes: 1|2                                # ≤ 2 (invariant de séance)
      src: S|Prop                                # S pour un bloc sourcé, Prop pour posture et bille-fantome (V13)
game:                             # phase game
  title: <titre>
  source_game: <n>|null           # numéro dans jeux.md
  adapted: true|false             # true => src: Prop
  players: <texte>
  materials: <texte>|null
  setup_illustration: <id>|null
  rules: [<règles courtes>]
  scoring: <comment on compte>
  end: <fin de partie>
  playful_variant: <variante ludique>
  link_previous: {notion_of: <id de previous>, rule: <règle qui rejoue la notion de la séance précédente>, note: <pourquoi>}   # obligatoire sauf order 1 ; [Prop] par définition (V14)
  weight: {children: <n>, adults: <n>}
  adaptation: {children: <texte>|null, adults: <texte>|null}
  src: S|Prop
review:                           # phase review
  prompts: [<2 à 3 questions de retour>]
sources:
  - {rank: S|FFB|Web, file: <nom du fichier>, page: <n>|null, note: <...>}
uncertainties: [<texte>]          # hypothèses non résolues (facultatif)
```

Un exercice d'entraînement a **toujours** un `ref` (tous les blocs existent, y compris les deux blocs `[Prop]`) et une notation par le suivi (`RecordAttempt`) : il n'y a plus de champ `scoring` ni `initiation_sheet` sur les exercices. Pour un bloc `[Prop]`, `setup`, `instruction` et `expected` s'appuient sur les fiches d'initiation, de jeux et techniques `[S]` correspondantes, **sans les présenter comme officiels**.

`Scoring` (union fermée), utilisé **uniquement par les éléments d'initiation** :

| `mode` | Champs | Sens | Persistance |
|---|---|---|---|
| `counter` | `of: <n>` | « réussis sur n essais » compté pendant la séance | non, éphémère |
| `checklist` | `criteria: [<critères observables>]` | cases « acquis / à retravailler » | non, éphémère |

Les exercices du catalogue sont notés par `RecordAttempt` : taux, chevalet, mention bronze, plafond (2 passages par élève, exercice et séance) et validation (5 passages réussis par défaut) y sont lus ou appliqués ; la séance ne les redéclare jamais.

## 4. Phases et minutage (calculé, jamais écrit)

| Phase `SessionPhase` | Éléments | Minutes (enfants / adultes) |
|---|---|---|
| `welcome` | `recall` (le rappel occupe toute la phase) | 10 / 10 |
| `notionAndInitiation` | `theory.sections` puis `initiation` | 20 / 25 |
| `training` | `training.exercises` | 35 / 50 |
| `game` | `game` | 20 / 25 |
| `review` | `review` | 5 / 10 |

Les budgets de phase viennent de `RulesConfig.shapes` (valeur par défaut : `defaultSessionShapes`, `[Prop]`) : c'est la configuration injectée qui fait foi à l'exécution, pas la constante. Le test de contrat (Dart, sur les valeurs par défaut) les relit dans le code ; rien n'est recopié dans la séance ni dans `app/tool/fiches.dart`.

Répartition dans une phase pour un public : on ne retient que les éléments dont `weight[audience]` est présent et ≥ 1 ; minutes d'un élément = `budget × poids / Σ poids`, arrondies par la **méthode du plus fort reste** ; en cas d'égalité, l'élément le plus haut dans le fichier reçoit la minute. Somme exacte par construction ; total = 90 ou 120. Les minutes sont `[Prop]` : l'application les affiche approximatives (« ~23 min ») avec le badge « Proposition » sur l'en-tête de phase.

## 5. Provenance et affichage « Proposition »

### 5.1 Ce qui est `[Prop]`

| Élément | `src` autorisé |
|---|---|
| rappel, théorie, initiation, jeu repris tel quel | `S`, `FFB`, `Web` selon la source réelle |
| exercice d'un bloc sourcé | `S` |
| exercice d'un bloc `posture` ou `bille-fantome` (taux, consignes, diagrammes `[Prop]`) | `Prop` obligatoire ; adapté de fiches `[S]` citées dans `sources` ; jamais présenté comme « officiel » |
| jeu adapté (`adapted: true`) | `Prop` obligatoire ; `source_game` indique le jeu d'origine |
| jeu sans source | `Prop`, `source_game: null` |
| `game.link_previous`, `game.playful_variant`, `game.adaptation` | `Prop` implicite, **même si** `game.src: S` : `src: S` ne couvre que `title`, `rules`, `scoring` et `end` repris de `jeux.md` |
| thème, défis (`playful`), poids, minutes | `Prop` implicite |

### 5.2 Affichage (détail, guide, présentation)

L'utilisateur doit pouvoir **juger chaque proposition dans son contexte** : le badge « Proposition » (texte, pas la seule couleur) est affiché sur **chaque** élément non sourcé, dans les trois vues :

- théorie, initiation, rappel avec `src: Prop` ; exercice `src: Prop` (avec la mention que son taux est une proposition) ; jeu adapté ou sans source ;
- `playful` (accroche et défi), `theme`, `link_previous`, `playful_variant`, `adaptation` ;
- minutes de chaque phase.

Les éléments sourcés portent la pastille `[S]`, `[FFB]` ou `[Web]`. Un élément `[Prop]` n'est jamais présenté comme règle fédérale. La présentation (mode « Montrer ») ne montre que des illustrations : elle garde le badge, discret mais visible, sur l'illustration d'un élément `[Prop]` (une illustration prend la provenance de l'élément qui la référence : exercice d'un bloc `[Prop]`, jeu adapté, théorie `[Prop]`). Les règles du jeu, la règle de lien et les minutes ne s'y affichent pas : elles se jugent dans le guide et le détail.

### 5.3 Indicateur « à valider »

L'application calcule, pour chaque séance, des **motifs** `[Prop]` (fonction pure `reviewReasonsOf`, rien n'est stocké) et la liste les affiche en texte à côté du badge « Proposition », pour dire **quoi** valider :

| Motif | Condition | Déclenche l'indicateur et le filtre |
|---|---|---|
| Jeu | `game.adapted: true`, `source_game: null` ou `game.src: Prop` | oui (et filtre « Jeux à valider ») |
| Exercices | un exercice `src: Prop` (blocs `posture` et `bille-fantome`) | oui |
| Initiation | un élément d'initiation `src: Prop` | oui |
| Rappel | `recall.src: Prop` | oui |
| Règle de lien | `game.link_previous` ajouté à un jeu sourcé `[S]` | non (information) |
| Théorie | une section `src: Prop` montrée aussi aux adultes | non (information) |

Les éléments `[Prop]` par définition (thème, défis, variante, poids, minutes) sont badgés en contexte mais ne sont pas des motifs. Une **glose** (section de théorie `[Prop]` réservée aux enfants, c'est-à-dire sans poids adulte) n'en est pas un non plus.

*Mesure sur les 29 séances* (2026-10-13) : en comptant toute la théorie `[Prop]`, **29 séances sur 29** étaient « à valider » (24 avec une théorie adulte `[Prop]`, 16 avec une règle de lien sur un jeu sourcé) : l'indicateur et le filtre ne discriminaient rien. Avec la règle ci-dessus : **18 séances « à valider »**, dont **12 pour le jeu** (filtre « Jeux à valider »). Le décompte est vérifié par le scénario du catalogue réel (`session_catalogue.feature`).

## 6. Illustrations : types autorisés (liste fermée)

Repère de table : celui de `docs/knowledge/03-exercices/diagrammes/FORMAT.md` (x ∈ [0, 8], y ∈ [0, 4], origine en haut à gauche, rayon de bille 0.1, poches `tl tm tr bl bm br`). Chaque illustration porte `caption` (affichée aux élèves) et `alt` (non vide). **Illustrations générées uniquement** : aucune photo de PDF.

| `type` | Paramètres | Rendu | Statut |
|---|---|---|---|
| `diagram_ref` | `diagram` : identifiant d'un diagramme transcrit (ex. `initiation-p07-e1`, `jeux-p07-g1`, `proposition-p01-e1`) ; la clé `id` reste l'identifiant local de l'illustration | `TableDiagramPlayer`, résolu par `DiagramLibrary.byId` dans la feature (`GetSheet`, `ResolveRunPlan`) | existant |
| `table` | `balls[]`, `ghosts[]`, `arrows[]`, `zones[]`, `sequence[]` (mêmes clés et même forme que `diagrammes/FORMAT.md`) | `TableDiagram(Player)` | existant ; le mapper de `entities/exercise_diagram` n'est pas importable (même couche) : `session_sheet` construit lui-même le `TableDiagramSpec` de `shared/ui` |
| `contact` | `fraction`: `full\|three_quarter\|half\|quarter\|thin`, `tip_point` | `BallContactDiagram` | existant ; `tip_point` à étendre (voir ci-dessous) |
| `contact_strip` | `fractions[]`, `highlight` | rangée de `BallContactDiagram` | nouveau `ContactStrip` |
| `ghost_aim` | `cue: [x,y]`, `object: [x,y]`, `pocket`, `fraction` | table + bille fantôme + ligne de visée | nouveau : flèche `aim`, bille fantôme calculée |
| `cue_side` | `tip_point`, `cue_height`: `high\|level\|low` | vue de côté bille + queue | nouveau `CueSideView` |
| `stance_top` | `view`: `top`, `annotations[]` | vue de dessus schématique (pieds, axe queue-épaule, main de chevalet) ; pas de silhouette | nouveau `StanceDiagram` |
| `power_scale` | `levels`: 1-5, `highlight`, `distance_label` | échelle de puissance | nouveau `PowerScale` |
| `angle` | `kind`: `bounce\|natural_rejection\|right_angle`, `vertex: [x,y]`, `rays[]` | marque d'angle sur une table | nouveau `AngleMark` |
| `pdf_ref` | `file`, `page` | pastille « voir page n du PDF » (jamais d'image) | nouveau, texte seul |

`tip_point` : `center`, `top`, `bottom`, `left`, `right`, `top_left`, `top_right`, `bottom_left`, `bottom_right` (les 4 diagonales sont à ajouter à `TipPoint`).

Contrainte d'architecture : `ContactFraction` et `TipPoint` vivent aujourd'hui dans `shared/ui` ; or le modèle `Illustration` (domaine, `shared/lib`) et la géométrie ne peuvent importer que `shared/lib`. Les deux énumérations pures sont donc **déplacées en `shared/lib`** (`ContactFraction` tel quel, importé directement depuis `shared/lib` partout : aucun réexport ; `TipPoint` sans `Offset`, la `direction` devenant une extension de `shared/ui`, qui réexporte l'énumération). La provenance `[S]`/`[FFB]`/`[Web]`/`[Prop]` est un **type unique** `Provenance` (`shared/lib`), partagé par le catalogue d'entraînement et les séances : les deux contenus ne peuvent pas diverger sur cette notion.

Géométrie de `ghost_aim` (fonction pure en `shared/lib`, testée par valeurs indépendantes) :

- Bille fantôme : `G = O - 2r · unit(P - O)`, où `O` = centre de la bille cible, `P` = centre de la poche, `r = 0.1`.
- Angle de coupe `θ` = angle entre `G - C` (queue-fantôme, `C` = blanche) et `P - O`.
- Quantité de bille dérivée : `f = 1 - sin θ` (identique à `ContactFraction.centerOffset = 2 (1 - overlap)` en rayons) ; `θ = 0` donne `full` (1.0) ; `θ = 30°` donne `half` (0.5, en accord avec la déviation ≈ 30° de la fiche technique n° 5) ; `θ ≈ 14.5°` donne `three_quarter` ; `θ ≈ 48.6°` donne `quarter`.
- Valeur nominale : `ContactFraction.overlap` (1, 0.75, 0.5, 0.25 et `thin` = 0.05 ; `thin` correspond à θ ≈ 71.8°). La fonction de `shared/lib` renvoie `f` (un `double`) ; la comparaison à l'étiquette se fait dans le test de contrat.
- Étiquette admise si `|f - valeur nominale| ≤ 0.07`.

Interdits : toute clé `photo`, `image`, `path`, `url`, `asset` **au niveau de l'illustration** (la clé `path` des éléments de `arrows[]`, polyligne de la trajectoire, est la forme du FORMAT des diagrammes et reste permise).

## 7. Règles de validation (vérifiables par outil)

Chaque règle est numérotée ; `app/tool/fiches.dart` et le test de contrat citent le numéro dans leur message. Le validateur a deux modes : par défaut il contrôle chaque fichier présent (contre la structure du § 1, calculée depuis le catalogue, pour les séances absentes) ; avec `--complete` il exige en plus les 29 fichiers (fin du lot L7). Une illustration `pdf_ref` seule ne se présente pas aux élèves (texte pour l'animateur) : une étape qui n'a qu'un renvoi est lisible dans le guide mais n'est pas « présentable ». Les règles V12 et V17 ne sont vérifiées que par le test de contrat Dart. Le validateur contrôle en plus (règle `T1`) que les tableaux des § 1.2 et § 1.3 sont égaux à la structure calculée depuis le catalogue, et `dart run tool/fiches.dart --structure` affiche cette structure.

| N° | Règle |
|---|---|
| V1 | `version == 1` ; clés obligatoires présentes ; aucune clé inconnue |
| V2 | `id` = `<technique>-<part>`, unique, slug valide, égal au nom de fichier sans `NN-` ; `technique`, `part` et `order` conformes à la structure du § 1, **recalculée depuis `catalogue-entrainement.yaml`** (nombre de parties, répartition ; `parties > N` est une erreur) ; nom de fichier préfixé de `NN` = `order` ; `--complete` : les 29 `order` présents, sans trou |
| V3 | `previous` = `id` de la séance d'`order - 1` dans la structure du § 1 (fichier présent ou non) ; `null` si et seulement si `order == 1` |
| V4 | `catalogue_block` non nul, égal au bloc de la technique ; chaque exercice d'entraînement a un `ref` ; `ref.block == catalogue_block` ; `ref.n` existe dans ce bloc |
| V5 | Les `ref.n` de la séance appartiennent à la tranche attribuée par le § 1 (parties, `quart` = 1-2, `finesse` = 3-4), sans doublon ; `--complete` : l'union des séances d'une technique couvre toute sa plage |
| V6 | Chaque `diagram` et chaque `diagram_ref.diagram` est un `id` présent dans `diagrammes/**` ; pour un exercice, le diagramme est de `kind: exercise`, de `sheet` = titre du bloc et d'`exercise` = `ref.n` ; pour un bloc `[Prop]`, il est dans `diagrammes/proposition/` et de `rank: Prop` |
| V7 | Chaque identifiant d'illustration cité existe ; chaque illustration a un `alt` non vide et une `caption` ; `type` dans l'énumération ; `recall.reuse` désigne une illustration existante de la séance `previous` (contrôlé seulement si ce fichier est présent ; toujours en `--complete`) |
| V8 | Aucune clé de la liste d'interdits de la section 6 au niveau de l'illustration (pas dans `arrows[].path`) ; aucun chemin de fichier image |
| V9 | `scoring` d'un élément d'initiation ∈ {`counter`, `checklist`} avec ses paramètres (`of` ≥ 1 ; `criteria` non vide) |
| V10 | `passes ∈ {1, 2}` ; dans `setup`, `instruction` et `expected` d'un exercice, sont interdits : le motif `\d+\s*/\s*\d+` (taux), le mot `chevalet` (type lu dans le catalogue), un nombre de billes (`\d+ billes?` ou « un, deux … dix » suivi de « bille(s) » ; écrire « les billes du schéma ») et le mot `bronze` |
| V11 | Pour chaque public : au moins 1 section de théorie, au moins 2 exercices distincts affichés, exactement 1 jeu affiché (`game.weight` défini pour les deux publics) ; poids entiers ≥ 1 |
| V12 | Calcul de minutage (test de contrat Dart uniquement) : pour chaque séance et chaque public, la somme des phases vaut 90 (children) ou 120 (adults), et chaque élément affiché reçoit au moins 1 minute |
| V13 | Chaque élément (rappel, section de théorie, initiation, exercice, jeu) porte `src` ; `game.adapted == true` implique `src == Prop` ; `game.source_game` existe dans `jeux.md` quand non nul ; `src` d'un exercice = `source` de son bloc dans le catalogue (`S` par défaut, `Prop` pour `posture` et `bille-fantome`) |
| V14 | `game.link_previous` présent pour `order > 1`, avec `notion_of` = `previous`, `rule` et `note` non vides ; absent pour `order == 1` |
| V15 | `notion` tient en une seule phrase (aucun `. ` ni `;` interne, ≤ 25 mots) ; `technical_sheets` est cohérent avec le § 1 |
| V16 | Texte enfants : chaque élément de `body` ≤ 60 mots ; `key_point` ≤ 20 mots |
| V17 | `ghost_aim` (test de contrat Dart uniquement) : fraction dérivée cohérente avec l'étiquette (section 6) ; coordonnées dans [0,8] × [0,4] ; l'outil `fiches.dart` ne contrôle que les bornes |
| V18 | `sources` non vide ; tout `rank: S` cite un fichier présent dans `docs/sources/` ; un exercice `src: Prop` a au moins une source `[S]` citée dont il est adapté |
| V19 | Le mot `officiel` (insensible à la casse) n'apparaît dans aucun élément `src: Prop`, `playful`, `theme` ni `game` adapté ; aucun chemin `docs/sources/` hors de `sources[].file` (l'intégrité de `docs/sources/` est garantie par le hook `pre-tool-guard`, pas par ce validateur) |
| V20 | `theme` présent ; `playful` (`hook` et `challenge` non vides) sur **chaque** exercice ; `game.playful_variant` non vide |
| V21 | `initiation_sheet` d'un élément d'initiation existe dans `initiation.md` (`src` ≠ Prop si repris tel quel) ; la fiche d'initiation citée appartient à la technique (§ 1.2) |
| V22 | `order == 1` : `recall.reuse` absent, `previous` nul et `link_previous` absent ; `order > 1` : `recall.points` porte sur `previous` (relecture indépendante) et `recall.reuse.sheet == previous` quand présent ; pour `part > 1`, `previous` est la partie `part - 1` de la même technique |
| V23 | Cohérence des parties d'une technique : mêmes `technique`, `title`, `notion`, `theme.name`, `catalogue_block` et `technical_sheets` ; `part` de 1 à n sans trou (`--complete`) ; `game.playful_variant` différente de celle de la partie précédente |
| V24 | Toute illustration est citée par une section de théorie, une initiation ou le jeu (`setup_illustration`), ou reprise en rappel (`recall.reuse`) par la séance suivante : une illustration jamais citée n'est jamais visible. Contrôlée quand la séance suivante est présente |

Hors outil (relecture indépendante par `relecteur-pedagogique`) : une seule notion, charge cognitive enfants, ton ludique, exactitude face aux sources, pertinence des blocs `[Prop]` (voir aussi la validation par l'utilisateur dans l'application, section 5).

## 8. Contrôles de l'application (hors séance)

- Lecture seule : le port `SessionSheetRepository` n'expose que `getAll` et `getById`. Pas de réflexion (`dart:mirrors` est absent de Flutter) : le test déclare une classe `implements SessionSheetRepository` qui ne définit que ces deux méthodes, ce qui ne compile plus si le port gagne une méthode abstraite (écriture comprise).
- Aucun écran de formulaire sur les séances (test de widget : aucun `TextField`, `Checkbox` ni bouton de modification/suppression sur catalogue et détail ; la notation locale n'existe que dans le guidage). Le titre d'une séance planifiée reste modifiable : c'est la séance planifiée, pas le contenu du catalogue.
- `previous` forme une chaîne sans cycle de 29 séances (tests de contrat sur les vrais assets, mêmes règles V2-V3).
- Les ids sont stables : un test de contrat fige la liste des 29 ids (une séance planifiée peut les référencer).
- `reviewReasonsOf` (motifs « à valider », § 5.3) : fonction pure testée sur fixtures et mesurée sur les 29 séances réelles ; le badge « Proposition » est testé sur détail, guide et présentation.

## 9. Exemple normatif : `09-demi-bille-1.yaml`

Le fichier `09-demi-bille-1.yaml` de ce dossier est l'exemple complet et normatif : première des deux séances de la technique `demi-bille` (exercices 1-2 du bloc). Il est validé par `app/tool/fiches.dart` (vert) et sert de modèle aux séances suivantes ; il n'est pas recopié ici pour n'avoir qu'une seule source. Ses contenus reprennent `jeux.md` (jeu n° 7), `initiation.md` (fiche 7), `02-techniques/03-viser-et-quantites-de-bille.md` (fiches n° 4 et 5, pages 14 et 15 du PDF) et le bloc `demi-bille` du catalogue ; les identifiants de diagramme et les pages PDF ont été relevés dans `diagrammes/` (entraînement pages 5-6, initiation et jeux page 7). La séance `demi-bille-2` (exercices 3-4, `order` 10) approfondit : rappel de la partie 1, chevalet sur surface, distances ; elle n'est pas encore écrite.

Points que le modèle fixe pour les séances suivantes :

- Les consignes d'exercice désignent « la rouge du schéma », « les jaunes du schéma » et jamais un nombre de billes (V10) ; les défis ludiques sont écrits en bloc YAML (une virgule dans un mapping en ligne casse l'analyse).
- Une illustration `diagram_ref` (clé `diagram`) rend la mise en place de l'initiation (`initiation[].illustration`) et du jeu (`game.setup_illustration`) sans recopier les positions.
- `recall.reuse` cite une illustration de la séance précédente : ici `contact-plein`, que `bille-pleine-2` définit (V7). Une séance ne recopie pas l'illustration de la précédente.
- Le jeu `src: S` ne couvre que le titre, les règles, le score et la fin du jeu repris de `jeux.md` ; `link_previous`, `playful_variant` et `adaptation` restent `[Prop]` (§ 5).
- Un texte pédagogique qui n'est pas dans la fiche (glose pour les enfants, exemple) n'est **jamais** glissé dans une section `src: S` : il forme sa propre section `src: Prop` (ici `mot-tangente`, enfants seulement), ce qui déclenche l'indicateur « à valider » (§ 5.3) et le badge « Proposition ».
- La notation d'une initiation reprend le but de la fiche : `counter` pour « empocher 2 billes » (`of: 2`) ; une exigence que la fiche ne formule pas (« l'élève explique ») n'est pas notée.
- Les mises en place des `[Prop]` du jeu (composition des groupes, place de la noire, tirage au sort, limite de temps, jetons) vont dans `game.adaptation`, `playful_variant` ou `link_previous` ; `game.rules`, `scoring` et `end` restent ceux de `jeux.md`. La règle de lien est écrite comme une **exception explicite** aux règles `[S]` et le jeu se joue tel quel sans elle.
- `recall.reuse` du pilote vise `contact-plein` de `bille-pleine-2`, séance écrite depuis (lot L7) : la référence est contrôlée par V7, toujours en `--complete`.

Minutage calculé de cet exemple (le fichier ne les contient pas) :

| Phase | Public | Éléments (poids) | Minutes |
|---|---|---|---|
| welcome | enfants / adultes | rappel | 10 / 10 |
| notionAndInitiation | enfants (20) | tangente 3, mot-tangente 1 `[Prop]`, comparer 2, ini-7 3 | 7 / 2 / 4 / 7 |
| notionAndInitiation | adultes (25) | tangente 3, comparer 2, fantome 2, ini-7 3 | 8 / 5 / 5 / 7 |
| training | enfants (35) | e1 2, e2 1 | 23 / 12 |
| training | adultes (50) | e1 1, e2 1 | 25 / 25 |
| game | enfants / adultes | jeu | 20 / 25 |
| review | enfants / adultes | bilan | 5 / 10 |

Totaux : enfants 10 + 20 + 35 + 20 + 5 = 90 ; adultes 10 + 25 + 50 + 25 + 10 = 120.
