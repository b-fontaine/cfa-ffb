# Plan du lot U9 : fiche élève, vue élève et vue de groupe (avec le reste utile du lot 10)

Statut : **livré le 2026-10-16** (lots F1 à F8 ; domaine et persistance d'abord, puis
les écrans). Le plan est conservé tel que conçu ; les écarts de livraison sont au
§ 9. **Reporté, hors de cette livraison : le lot 10b** (note de jeu, compteurs
d'initiation et de jeu persistés, étape de la séance en cours persistée ; voir la
[roadmap](roadmap.md)). Les décisions U9-1 à U9-11 sont tranchées par l'animateur
(2026-10-16) : voir le § 9. Décisions : [ADR 0013](adr/0013-acquittement-des-alertes.md) (acquittement,
schéma v8, sauvegarde v3) et
[ADR 0014](adr/0014-fiche-en-parcours-vue-eleve-et-vue-de-groupe.md) (écrans).
Le plan suit le patron de [aujourdhui-plan.md](aujourdhui-plan.md)
et de [positionnement-initial-plan.md](positionnement-initial-plan.md).
Sources lues : [roadmap.md](roadmap.md) (U9, lot 10),
[ux/plan-ux-proposition.md](ux/plan-ux-proposition.md) (§ 4 « U9 », § 6 Q1 à
Q8), [ux/recommandations-design.md](ux/recommandations-design.md) (R14, R15, § 4),
[ux/audit-ux-ui.md](ux/audit-ux-ui.md) (T7, E1 à E5), ADR
[0003](adr/0003-suivi-des-eleves.md), [0008](adr/0008-positionnement-initial-bloc-acquis.md),
[0010](adr/0010-roles-de-couleur-bleu-tapis-et-accent.md),
[0012](adr/0012-reglages-du-club.md), le code de `pages/student_sheet`,
`pages/students`, `features/track_progress`, `features/place_student`,
`entities/exercise_result`, `shared/ui`, `shared/persistence` (schéma v7) et
`features/backup_data` (format 2).

Constats du code qui cadrent le plan :

- Le catalogue compte **15 blocs et 70 exercices** (4 à 10 exercices par bloc :
  `retro` 10, `coule` 8, `trajectoires-blanche` 6, `bille-fantome` 2, les
  autres 4). « Une ligne par technique » = **un bloc du catalogue** (c'est ce
  que montre le schéma de R14). Le « 0 sur 72 » de l'audit est devenu « 0 sur
  70 » depuis ; la clé est `sheetValidatedTotal`.
- Toute la dérivation passe par `StudentProgress.derive` (entité
  `exercise_result`, **10 appelants**) ; les alertes affichées passent par
  `StudentProgress.activeAlerts` (déjà filtrées des exercices acquis) puis
  `watchedStudents` (entité, partagé accueil et bilan).
- `BlockProgress.of` (feature `track_progress`) porte aujourd'hui le statut de
  bloc à 5 valeurs ; la carte de chaleur d'un groupe en aurait besoin depuis
  une autre slice, ce qui impose de descendre cette dérivation dans
  `entities/exercise_result` (même patron que `watchedStudents`).
- `attendanceOf` (assiduité d'un élève) existe ; **aucune assiduité de groupe**.
- `groupFailureSharePercent` n'est lu que par `selectRecall` (suggestion).
- « Compteurs d'initiation, grille acquis et score du jeu » existent **en
  mémoire seulement** dans `RunSheetCubit` ; « note de jeu » n'existe que comme
  `gameNote` du plan de séance suggérée (aucun champ saisi). Rien n'est stocké.
- Le prochain numéro d'ADR libre est **0013** ; le schéma drift est en **v7**,
  le format de sauvegarde en **2** (`supportedVersions = {1, 2}`).

---

## 1. Périmètre exact : U9 retenu, lot 10 découpé

| Élément | Origine | Décision | Pourquoi |
|---|---|---|---|
| Parcours en cases (technique × exercice) | U9 / R14 | **U9** | cœur du lot ; corrige T7 et E2 |
| En-tête « en cours / prochain / alerte » | U9 / R14 | **U9** | idem |
| Courbes repliées, actions rares en bas | U9 / R14 | **U9** | E3, E4 |
| Vue « à montrer à l'élève » | U9 / Q6 | **U9** | décision Q6 déjà tranchée |
| Carte de chaleur technique × élève | U9 / R15, lot 10 | **U9** | E5 |
| Assiduité du groupe | lot 10 | **U9** | n'existe pas ; donnée déjà en base (présences) |
| Alertes de groupe (« 4 élèves sur 8 ») | report d'U7 | **U9** | `groupFailureSharePercent` est déjà un réglage (lot 9) |
| Acquittement d'une alerte | lot 10 / R14 | **U9** | scénario U9 « Une alerte peut être acquittée » ; seule partie qui touche le schéma |
| Note de jeu de la séance | lot 10 | **reporté au lot 10b** | voir ci-dessous |
| Compteurs d'initiation et de jeu persistés | lot 10 | **reporté au lot 10b** | voir ci-dessous |

**Reporter la note de jeu et les compteurs persistés (lot 10b).** Aucun écran
d'U9 ne les lit : ni la fiche, ni la vue élève, ni la grille de groupe. Ils
relèvent de la **séance en cours** (`RunSheetCubit`, `RunSheetSessions`) et
recoupent la décision `[U]` non tranchée **U-5** du plan « Aujourd'hui »
(« séance en cours après rechargement : perdue ou persistée ») : les livrer ici
trancherait U-5 en silence. « Note de jeu » n'est pas définie (texte libre ?
score A / B du guide ? champ du `SessionRecord` ?) ; un texte libre sur des
mineurs est une donnée personnelle qui demande son propre ADR (minimisation,
sauvegarde, effacement). Les ajouter ferait d'U9 un lot à deux migrations et
deux ADR, donc une revue trop large. Le lot 10b garde : note de jeu,
compteurs et grille persistés, étape de la séance en cours (U-5), schéma v9.
La roadmap (point 10) est reformulée en **10a (livré avec U9)** et **10b**.

## 2. Décisions de conception (proposées)

### D1. Modèle du parcours et états d'une case

- **Ligne** = un bloc du catalogue, dans l'ordre d'enseignement ; **case** =
  un exercice. Le total de cases est celui du catalogue (70 aujourd'hui, jamais
  codé en dur).
- **États d'une case exercice** (enum `ExerciseCellState`, entité
  `exercise_result`, fonction pure `exerciseCells(progress, block)`) :

| État | Règle (priorité dans cet ordre) | Rendu (forme + texte, jamais la couleur seule) |
|---|---|---|
| `acquired` | l'exercice est dans `acquiredExercises` (ADR 0008) | plein bleu-tapis clair, **icône « acquis »**, libellé « acquis au positionnement » |
| `validated` | résultat validé par passages | plein bleu-tapis, **coche** |
| `inProgress` | au moins un passage, non validé | **hachuré**, nombre de passages réussis dans la case (« 2 ») |
| `todo` | aucun passage | contour vide |

  Marqueurs sans quatrième couleur : `alerted` (alerte active, non acquittée,
  sur un `inProgress` : petite icône d'attention, ton `attention` de
  l'ADR 0010, **jamais rouge**) et `current` (anneau : l'exercice « en cours »
  de l'en-tête). Un exercice d'un bloc acquis **repris par des passages**
  reprend son état dérivé des passages (ADR 0008, décision 5) ; le texte de
  ligne garde « N exercices repris » (existant).
- **État d'une ligne** : la dérivation du statut de bloc descend dans
  `entities/exercise_result` (`techniqueSummary(block, progress)` → compteurs
  `validated`, `acquired`, `inProgress`, `todo`, `alerted`, et `BlockStatus` à
  5 valeurs **inchangées**). `BlockProgress.of` l'appelle : **une seule
  source** pour la fiche et la carte de chaleur, les tests existants de
  `BlockProgress` servent de filet. `BlockStatus` migre vers l'entité (réexport
  depuis `track_progress` le temps du déplacement).
- **Total sans « 0 sur 70 »** : l'en-tête dit « n techniques terminées sur 15 »
  et « n exercices validés » ; « sur 70 » ne figure qu'en légende du parcours.
  Un élève sans aucun validé ni acquis voit « Parcours à commencer » (le zéro
  n'est jamais présenté comme un score). Corrige T7 ; reste `[U]` U9-3.
- **Interaction** : taper une case ouvre une **feuille basse** avec la courbe de
  l'exercice (`ExerciseCurveCard` réutilisée) ou « pas encore pratiqué » ; taper
  le titre d'une ligne ouvre le détail du bloc (séances passées, « en retard »,
  date d'acquisition). Les actions de positionnement (« Marquer le bloc
  acquis », « Retirer l'acquis ») passent dans un menu ⋮ de 48 dp par ligne
  (libellés et sémantique inchangés).
- **Mise en page** : sous 600 dp, titre au-dessus des cases (qui passent à la
  ligne) ; dès 600 dp, titre à gauche (≈ 180 dp) et cases à droite. Cases de
  **48 × 48 dp** minimum. Légende à quatre entrées toujours visible sous le
  titre « Parcours ». Hauteur attendue sous 390 dp : ≈ 1 100 dp pour 15 lignes
  (contre ≈ 1 500 dp), à mesurer par test de widget et à la capture Playwright.

### D2. En-tête « en cours / prochain / alerte »

- **En cours** = `catalogue.nextExercise(validated:)` (premier non validé dans
  l'ordre d'enseignement, règle R2 « on ne saute jamais »), affiché avec ses
  pastilles `PassDots` en lecture seule (réussis sur `passesRequired`). C'est
  le même exercice que la séance suggérée : l'animateur voit ce que
  l'application va proposer.
- **Prochain** = le premier non validé **après** « en cours » dans le même
  ordre ; absent quand il n'y en a pas.
- Cas limites : aucun passage → « À commencer » (même exercice) ; tout validé →
  « Niveau 1 terminé », ni en cours ni prochain.
- **Alerte** = l'alerte la plus alarmante de l'élève (même règle que
  `watchedStudents` : persistante avant attention, échecs décroissants, ordre
  d'enseignement), « +N autres » si besoin, bouton **Vu** (48 dp). Après
  acquittement : ligne calme « Alerte vue le 12 oct. » avec « Rétablir ».
  Sans alerte, la ligne n'existe pas (pas de « Aucune alerte »).
- La carte « Notion à rappeler » (autre slice, injectée par la page) et
  l'assiduité de l'élève passent sous l'en-tête, en lignes courtes ; « Modifier
  le prénom », « Bilan de maturité », « Effacer » descendent en bas (E4).

### D3. Carte de chaleur technique × élève et son alternative textuelle

- **Grille** : **lignes = techniques** (15, ordre d'enseignement),
  **colonnes = élèves** membres du groupe **à la date du jour**
  (`Group.isMemberOn(today)`), tri alphabétique du prénom puis identifiant.
  Sous 600 dp : colonne des techniques fixe (≈ 112 dp), élèves en défilement
  horizontal (cases de 48 dp) ; en tablette tout tient. Une dernière ligne
  « Présences » (n / m) par élève, issue de `attendanceOf`.
- **Cellule** (technique, élève) : état de ligne de D1 + fraction « n/m »
  (validés + acquis sur exercices du bloc), toujours en texte. « Chaleur » =
  quatre paliers de teinte bleu-tapis (0, moins de la moitié, moins de tout,
  tout) **doublés** de la fraction, de l'icône « acquis » (bloc entièrement
  acquis) et de l'icône d'attention (alerte active). Aucun rouge.
- **Alternative textuelle (jamais optionnelle)** :
  1. chaque cellule porte un `Semantics` complet : « Léa, Demi-bille : 3
     exercices sur 4 validés, alerte en cours » ;
  2. chaque ligne porte un résumé : « Demi-bille : 5 élèves sur 8 ont terminé,
     2 en cours, 1 à commencer » ;
  3. une section **« Résumé en texte »**, visible et repliable (pas
     cachée aux voyants), liste par technique les prénoms par état ; elle
     sert aussi à imprimer ou lire sans la grille ;
  4. la grille est exposée comme tableau (en-têtes de lignes et de colonnes).
- **Interaction** : taper une cellule ouvre la fiche de l'élève ; taper
  l'en-tête d'un élève idem. Pas d'action d'écriture dans la grille.
- **Entrée** : bouton « Voir la grille du groupe » sur chaque carte de groupe de
  « Élèves » (`ClubList` reçoit un callback `onOpenGroup`, la page câble la
  route). Route `/students/groups/:groupId`, **dans le shell** (destination
  « Élèves » active), retour vers `/students`.

### D4. Assiduité du groupe (définition exacte)

- **Séances comptées** : les `SessionRecord` du groupe (`forGroup`) datées au
  plus tard à `asOf` (= aujourd'hui, horloge injectée), toutes saisons
  confondues pour ce groupe (un groupe appartient à une saison). Pas de
  fenêtre glissante par défaut (`[U]` U9-6).
- **Pour chaque séance** : dénominateur = nombre d'élèves membres **à la date
  de la séance** (`isMemberOn(student, session.date)`) ; numérateur = présents
  parmi eux. **Taux du groupe** = Σ numérateurs / Σ dénominateurs, affiché en
  « 41 présences sur 48 possibles (85 %) » et « 6 séances » ; liste des
  dernières séances (« 12 oct. 7/8 »). Zéro séance → « Aucune séance saisie »
  (pas de 0 %).
- Un élève arrivé en cours de saison n'est pas pénalisé (même règle que
  `attendanceOf`) ; un ancien membre compte pour les séances où il l'était,
  mais n'est plus une colonne.
- Fonction pure `groupAttendance({sessions, group, asOf})` dans
  `features/track_group/domain` ; test avec horloge fixe, séance future ignorée,
  arrivée en cours de saison, départ en cours de saison.

### D5. Alertes de groupe

- **Définition** : pour chaque technique (bloc) et un groupe, parmi les
  **membres actuels** : n élèves dont le **dernier passage** sur la technique
  (résultat le plus récent du bloc, exercices acquis exclus) a échoué
  (`ExerciseResult.lastFailed`), **dans les `recallStaleSessions` dernières
  séances du groupe** (réglage existant, défaut 4 : évite qu'un échec vieux de
  trois mois alerte). Alerte si `n × 100 ≥ groupFailureSharePercent × membres`
  **et** `n ≥ 2` (une alerte portant sur un seul élève est une alerte
  individuelle ; champ `RulesConfig.minGroupFailures`, défaut 2, invariant ≥ 1,
  **non exposé** à l'écran Réglages ni persisté, `[U]` U9-7).
- **Même numérateur que la suggestion** : la règle « dernier passage échoué
  parmi les élèves, acquis exclus » descend dans `entities/exercise_result`
  (`blockFailedStudents`) et `selectRecall` l'appelle sans fenêtre (comportement
  inchangé, test de parité) ; l'alerte ajoute fenêtre et garde-fou. Un seul
  endroit pour ce que « échouer » veut dire.
- **Affichage** : « 4 élèves sur 8 ont manqué « Demi-bille » à leur dernier
  passage », ton `attention`, trié par part décroissante puis ordre
  d'enseignement ; en tête de la vue de groupe (toutes) et sur « Aujourd'hui »
  (3 au plus, lien vers la grille). Pas d'acquittement des alertes de groupe
  (elles se recalculent à chaque séance), pas dans le bilan de séance (`[U]`
  U9-10).
- L'acquittement d'une alerte **individuelle** ne modifie pas l'alerte de
  groupe (elle ne lit pas les alertes, seulement les derniers passages).

### D6. Acquittement d'une alerte

- **Modèle** : entité `AlertAcknowledgement` (`entities/exercise_result`) :
  `id`, `studentId`, `exercise` (`ExerciseRef`), `lastAttemptId` (dernier
  passage de l'exercice au moment du « Vu »), `date` (jour, horloge injectée,
  normalisé `dateOnly`). Ce n'est ni un passage ni un résultat : les courbes,
  `consecutiveFailures` et la validation ne le voient pas (même esprit que
  `BlockAcquisition`, ADR 0008).
- **Règle de levée** : une alerte est **acquittée** tant que le dernier passage
  de l'exercice est `lastAttemptId`. Tout nouveau passage la fait réapparaître
  si c'est un échec (le compteur reflète alors l'échec de plus) ; une réussite
  la résout de toute façon. Supprimer ou corriger ce dernier passage (ADR 0006)
  fait aussi réapparaître l'alerte : côté prudent, sans cascade à écrire dans
  `record_results`.
- **Effet** : `StudentProgress.derive` reçoit `acknowledgements` (liste, vide
  par défaut) ; `activeAlerts` exclut les alertes acquittées. Par propagation :
  - `watchedStudents` (donc « À surveiller » de l'accueil et du bilan, ADR
    U7) : l'élève disparaît s'il n'a plus d'autre alerte ;
  - badge d'alertes de la liste « Élèves » (`alertCount`) ;
  - statut de bloc « À revoir » (`BlockStatus.toReview` repasse en cours) ;
  - en-tête de la fiche (ligne « Alerte vue ») et marqueur `alerted` des cases.
  **Inchangés** : la sélection de la notion à rappeler et la séance suggérée
  (le jugement pédagogique ne dépend pas du fait que l'animateur ait vu),
  le retour de saisie en direct. `[U]` U9-4.
- **Appelants à mettre à jour** (ceux qui affichent une alerte) :
  `get_club_overview`, `list_watched_students`, `get_student_report`,
  `get_student_sheet`, `get_session_review`. Les autres (`suggest_*`,
  `record_attempt`, `load_validated_exercises`, `get_week_summary`,
  `get_session_overview`) gardent la valeur par défaut ; un test par surface
  verrouille le comportement (voir § 7).
- **Réversibilité** : « Rétablir » supprime logiquement l'acquittement
  (convention des repositories) ; un « Vu » ultérieur en crée un nouveau, le
  plus récent par (élève, exercice) gagne. Aucun acquittement possible sans
  alerte active (`alertNotActive`, nouveau code) ni sur un élève ou un exercice
  inconnu (`NotFound`, `unknownExercise`).
- **Stockage** : ADR **0013**. Table drift `alert_acknowledgements`
  (`AuditColumns`, `student_id`, `block_id`, `exercise_number`,
  `last_attempt_id`, `date` ; index `acknowledgements_by_student` ; **pas de
  clé étrangère**, comme `block_acquisitions`), schéma **v8**, migration
  `from7To8` par `createTable`, instantané via `drift_dev make-migrations`
  (puis suppression du stub de test généré). Ports in-memory et drift derrière
  `AcknowledgementRepository`, test de contrat commun.
- **Sauvegarde** : format **3** (`supportedVersions = {1, 2, 3}`), clé
  `data.alertAcknowledgements`. Absente d'un fichier 1 ou 2 : liste vide (un
  import fusionne par identifiant avec les données du club ; seul un ancien
  format, sans liste, efface les acquittements en place : un acquittement visant
  un passage absent de la restauration serait faux) ;
  **présente dans un fichier 1 ou 2 : refus** (`backupInvalid`, patron du
  `withSettings` de l'ADR 0012). Contrôles : élève existant et exercice connu
  (`backupInconsistent`, `backupUnknownBlock`) ; un `lastAttemptId` orphelin est
  toléré (acquittement dormant). Import refusé **sans écriture partielle**
  (même `UnitOfWork` que le reste). Une application plus ancienne refuse un
  fichier 3 (`backupVersionUnsupported`) plutôt que de perdre les « Vu ».
- **Effacement d'un élève** (`EraseStudent`) : suppression physique de ses
  acquittements, y compris supprimés logiquement ; scénario dédié.

### D7. Vue « à montrer à l'élève »

- **Route** `/students/:studentId/show`, **hors du shell** (comme
  `/catalogue/:id/presentation`) : pas de barre de navigation, donc aucun
  chemin vers les autres élèves depuis cet écran. Page `pages/student_showcase`.
  Entrée : bouton « Montrer à l'élève » dans l'en-tête de la fiche.
- **Contenu strict** (décision Q6) : le **prénom**, le **parcours** (les 15
  lignes et leurs cases, mêmes états que D1) et, en tête, « Ton exercice en
  cours » avec ses pastilles de **réussites** (jamais les échecs). Un
  message d'encouragement neutre est proscrit ; seul le fait est dit (« 12
  exercices validés »).
- **Exclus, structurellement** : alertes et acquittements, états « à revoir »
  (une ligne alertée s'affiche « en cours »), notes d'animateur, bilan de
  maturité, assiduité, scores et courbes, dates, public (badge), noms des autres
  élèves, notion à rappeler, actions de positionnement, boutons d'écriture. La
  garantie est **de type**, pas d'affichage : le cas d'usage `GetStudentShowcase`
  renvoie un modèle `StudentShowcase` qui n'a aucun champ pour ces données (il
  ne lit ni `AssessmentRepository` ni `SessionRecordRepository`).
- **Sortie** : bouton « Terminer » (≥ 48 dp, en tête) qui revient à la fiche ;
  retour système identique. Pas de code PIN par défaut (`[U]` U9-9). Cases non
  interactives (aucune courbe accessible), sémantique complète. Aucune
  persistance de « l'état montré ».
- **Confidentialité** : l'écran ne mentionne aucun autre élève ; l'URL contient
  l'identifiant opaque de l'élève. Test d'imports qui interdit à la slice
  `student_showcase` d'importer `maturity_assessment`, `session_record`, `group`
  et la file d'alertes.

## 3. Slices FSD et composition (aucun import latéral)

| Couche | Slice | Contenu |
|---|---|---|
| `shared/ui` | (composants) | `PathCell` (case : état, texte court, sémantique, 48 dp, cible optionnelle), `PathLegend`, `CellGrid` (tableau fixe + défilement horizontal, en-têtes sémantiques). Prennent un enum **d'interface** (`PathCellState`), jamais une entité. |
| `entities` | `exercise_result` | `exercise_cell.dart` (états + `exerciseCells`), `technique_summary.dart` (`BlockStatus` déplacé), `alert_acknowledgement.dart`, `acknowledgement_repository.dart`, `block_failures.dart` (`blockFailedStudents`), `StudentProgress.derive(acknowledgements:)` ; `data/` in-memory et drift |
| `features` | `track_progress` (modifiée) | `StudentSheet` : `header` (en cours, prochain, alerte), `path` ; widgets `StudentSheetHeader`, `PathList`, `ExerciseSheetCurve` ; `BlockProgress.of` appelle `techniqueSummary` |
| `features` | `acknowledge_alert` (nouvelle) | `AcknowledgeAlert`, `RestoreAlert`, `AcknowledgementBloc` (patron de `place_student`) |
| `features` | `student_showcase` (nouvelle) | `GetStudentShowcase`, `StudentShowcase`, `ShowcaseCubit`, `ShowcaseView` |
| `features` | `track_group` (nouvelle) | `GetGroupOverview`, `GroupGrid`, `groupAttendance`, `groupFailureAlerts`, `ListGroupAlerts`, `GroupOverviewCubit`, `GroupAlertsCubit`, `GroupHeatMap`, `GroupAlertsCard` |
| `features` | `manage_students` (modifiée) | `ClubList` : callback `onOpenGroup` |
| `pages` | `student_sheet` (modifiée) | compose `track_progress` + `place_student` + `acknowledge_alert` + rappel ; bouton « Montrer » |
| `pages` | `student_showcase`, `group_overview` (nouvelles) | une slice de feature chacune, plus callbacks de navigation |
| `pages` | `students`, `home` (modifiées) | bouton de groupe ; carte `GroupAlertsCard` à côté de `WatchedStudentsCard` |
| `app` | routeur, DI | routes `/students/:id/show` (hors shell) et `/students/groups/:groupId` (shell) ; providers ; `injection.config.dart` régénéré |

Règles vérifiées : `track_group` et `student_showcase` partagent leurs règles
**uniquement par `entities`** ; `acknowledge_alert` ne connaît pas
`track_progress` (la page injecte `onAcknowledge` / `onRestore` à l'en-tête,
comme le positionnement) ; le domaine reste en Dart pur avec `asOf` en
paramètre (l'horloge `DateTime Function() today` est fournie par la couche
`app`, comme pour le positionnement).

## 4. Lots d'implémentation (ordre ; chaque lot livrable et vert)

Chaque lot : scénarios `.feature` **d'abord**, constat explicite du rouge,
tests unitaires avant le code, `scripts/check.sh --fast` à chaque lot,
`--full` aux lots F2, F4, F6 et F8. Les revues `architecte-fsd` et
`testeur-bdd` se font en contexte séparé à F8 (et après F2, qui change le
schéma).

1. **F1 Règles pures de l'entité** : `ExerciseCellState` et `exerciseCells`,
   `techniqueSummary` (+ déplacement de `BlockStatus`, `BlockProgress.of`
   délègue), `AlertAcknowledgement` et `derive(acknowledgements:)`,
   `blockFailedStudents` (+ `selectRecall` l'appelle). Aucun écran. Tests
   unitaires d'abord, dont la parité de `selectRecall`.
2. **F2 Persistance v8 et sauvegarde v3** (ADR 0013) : port, in-memory, drift,
   `from7To8`, instantané, contrat commun, codec/decoder/encoder/références,
   effacement d'élève, aller-retour, fichiers 1 et 2 sans clé, clé refusée dans
   1 et 2, import refusé sans écriture partielle. `check.sh --full`.
3. **F3 Acquittement de bout en bout** : `AcknowledgeAlert`, `RestoreAlert`,
   bloc, bouton « Vu » sur l'alerte **existante** de la fiche, propagation aux
   cinq appelants, scénarios accueil / bilan / liste. Livrable seul : le
   dispositif fonctionne avant la refonte visuelle.
4. **F4 Fiche en parcours** : `PathCell`, `PathLegend`, `PathList`, en-tête,
   feuille de courbe, courbes repliées, actions rares en bas, libellé du total,
   menu ⋮ du positionnement, Widgetbook (états × thèmes × texte 200 %).
5. **F5 Vue élève** : `GetStudentShowcase`, page, route hors shell, bouton
   d'entrée, test d'imports interdits.
6. **F6 Vue de groupe** : `CellGrid`, `GetGroupOverview`, assiduité, grille,
   résumé en texte, entrée depuis « Élèves », route.
7. **F7 Alertes de groupe** : `groupFailureAlerts` (fenêtre, garde-fou),
   `ListGroupAlerts`, ligne en tête de la vue de groupe et carte « Aujourd'hui ».
8. **F8 Finition** : capture Playwright (web, sémantique), clés fr + en,
   `design-system.md`, `architecture.md`, `testing.md`, guide animateur, index
   ADR et `docs/engineering/README.md`, roadmap (U9 et 10a livrés, 10b créé),
   audit (T7, E1 à E5 soldés), revues séparées, `check.sh --full`.

## 5. Scénarios BDD à écrire d'abord (titres)

`student_sheet.feature` (existant, adapté)
1. The path shows one row per technique and one cell per exercise.
2. A cell is empty, hatched, full or acquired, each with its own text.
3. A block marked as acquired at placement shows full acquired cells.
4. An exercise taken back after placement shows its passes, the rest stays acquired.
5. The header shows the exercise in progress, the next one and the alert.
6. A student with no pass sees « Path to start », not « 0 of 70 ».
7. A finished level shows « Level 1 completed » and no next exercise.
8. Tapping a cell opens the curve of its exercise with a text alternative.
9. The curves are folded by default and the rare actions are at the bottom.
10. A technique row keeps the placement actions in its menu.
11. Every cell and button is at least 48 dp.

`alert_acknowledgement.feature` (nouveau)
12. Three failed passes show an alert with a « Seen » button.
13. Acknowledging an alert removes it from the header and the watched students of the home.
14. An acknowledged alert is removed from the session review and from the student list.
15. A new failed pass brings the acknowledged alert back with the new count.
16. A passed pass resolves the alert and the acknowledgement stays dormant.
17. An acknowledged alert can be restored.
18. Acknowledging does not change the recalled notion nor the suggested session.
19. Acknowledgements survive a backup export and import.
20. A backup of the previous format imports with no acknowledgement.
21. Erasing a student erases the acknowledgements.

`student_showcase.feature` (nouveau)
22. The showcase shows the first name and the path only.
23. The showcase shows neither alert, nor maturity comment, nor attendance, nor other students.
24. A block to review is shown as in progress.
25. The pass dots show the successful passes only.
26. Finishing the showcase goes back to the sheet.
27. The showcase has no navigation bar.

`students.feature` / `group_overview.feature`
28. A group card offers its grid.
29. The grid shows technique by student with a fraction in every cell.
30. A cell is described as text with the student, the technique and the state.
31. A text summary lists the students of each technique.
32. Tapping a cell opens the student sheet.
33. The group attendance counts the present members over the possible ones.
34. A student who joined later is not penalised in the attendance.
35. A group without session says there is no session instead of 0 %.
36. Four students out of eight failing a technique raise a group alert.
37. Failing students who stopped practising long ago raise no group alert.
38. A single failing student raises no group alert.
39. The home lists at most three group alerts with a link to the grid.
40. The grid scrolls horizontally under 600 dp with a fixed technique column.

Tests unitaires et de contrat (avant le code de chaque lot) : états de case
(priorité acquis > validé > en cours > à faire, reprise après positionnement),
`techniqueSummary` (parité avec les tests existants de `BlockProgress`),
acquittement (levée par nouveau passage, par suppression du passage, plus
récent gagne, exercice acquis, jamais sans alerte active), `blockFailedStudents`
(parité `selectRecall`), `groupAttendance` (horloge fixe, séance future,
arrivée / départ en cours de saison), `groupFailureAlerts` (seuil à 50 % et à
100 %, fenêtre, garde-fou à 2), contrat in-memory et drift, migration v7 → v8
(SQL brut sur base intermédiaire), codec 1 / 2 / 3, test d'imports de
`student_showcase`, test `StudentShowcase` sans champ sensible.

## 6. Points qui demandent une décision `[U]` de l'animateur

Au moment de la conception, aucun n'était tranché et le plan supposait la proposition par défaut ; l'animateur a tranché le 2026-10-16 (voir le § 9).

| # | Question | Proposition par défaut |
|---|---|---|
| U9-1 | Reporter note de jeu et compteurs persistés au lot 10b ? | **oui** (§ 1) |
| U9-2 | « En cours » = premier exercice non validé (R2) plutôt que le dernier exercice pratiqué | **R2** : cohérent avec la séance suggérée |
| U9-3 | Remplacer « n sur 70 » par « n techniques terminées sur 15 » et « n exercices validés », « sur 70 » en légende seulement | **oui** |
| U9-4 | Portée de l'acquittement : masque la surveillance (accueil, bilan, liste, fiche) mais pas la notion à rappeler ni la séance suggérée ; réapparaît à tout nouveau passage ; permis aussi sur une alerte persistante | **oui** |
| U9-5 | Après « Vu », l'élève disparaît de « À surveiller » (plutôt que d'y rester marqué « vu ») | **disparaît** |
| U9-6 | Assiduité du groupe sur toutes ses séances saisies (plutôt que les 5 dernières) | **toutes**, liste des dernières séances en plus |
| U9-7 | Alerte de groupe : dénominateur = membres actuels ; fenêtre = `recallStaleSessions` dernières séances ; au moins 2 élèves | **oui** (le « 2 » est un champ de `RulesConfig`, `minGroupFailures`, absent des Réglages) |
| U9-8 | Grille : techniques en lignes, élèves en colonnes ; entrée par un bouton sur chaque carte de groupe (pas d'onglet) | **oui** |
| U9-9 | Vue élève : pastilles de réussites de l'exercice en cours, aucun badge de public, sortie par simple bouton (pas de code ni d'appui long) | **oui** ; **aucun badge « Proposition »** (tranché le 2026-10-16) |
| U9-10 | Alertes de groupe sur « Aujourd'hui » (3 au plus) mais pas dans le bilan de séance ; aucun acquittement des alertes de groupe | **oui** |
| U9-11 | Un import de sauvegarde d'un ancien format efface les acquittements en place | **oui** |

## 7. Risques et parades

| Risque | Parade |
|---|---|
| Un appelant de `StudentProgress.derive` oublie `acknowledgements` : une alerte « vue » réapparaît sur une surface | un scénario ou test par surface (accueil, bilan, liste, fiche) ; liste des 5 appelants figée dans ce plan ; revue `architecte-fsd` |
| Déplacer `BlockStatus` et `techniqueSummary` casse les écrans et tests de `track_progress` | F1 sans UI, parité avec les tests existants de `BlockProgress`, réexport transitoire |
| Fiche trop longue ou carte de chaleur illisible sur téléphone | mesures dans des tests de widget (390 × 844) et capture Playwright ; sinon repli : techniques terminées repliées |
| Alerte de groupe en désaccord avec la suggestion de rappel | numérateur partagé (`blockFailedStudents`), test de parité |
| La couleur porte le sens dans la grille | forme + fraction + sémantique + résumé en texte ; test d'absence de rouge d'état (ADR 0010) |
| Fuite de données dans la vue élève | modèle sans champ sensible, test d'imports, scénario 23 |
| Migration v8 oubliée en sauvegarde ou en effacement | contrat commun, aller-retour, scénarios 19 à 21, import sans écriture partielle |
| Casse du `RulesConfig` lu à la création | les cubits de groupe sont recréés à la navigation ; aucun singleton ne conserve un `RulesConfig` (test d'architecture de l'ADR 0012) |
| Lot trop gros pour une revue | huit lots F1 à F8 livrables séparément ; 10b hors périmètre |

## 8. Garde-fous et contraintes rappelés

BDD rouge puis TDD vert (le constater et le dire, y compris ce qui n'a pas pu
l'être) ; fichiers générés (`*.freezed.dart`, `*.g.dart`, `injection.config.dart`,
l10n, instantané drift) uniquement par `build_runner`, `flutter gen-l10n` et
`drift_dev` ; clés ARB identiques fr et en ; aucun `TODO`, `skip` ni stub ;
aucun contournement de garde-fou ; `docs/knowledge` et `docs/sources` intacts ;
pas de rouge comme état ; cibles ≥ 48 dp ; ne pas committer sans demande.

## 9. Livraison : écarts au plan (2026-10-16)

Livré : tout le périmètre du § 1 sauf la note de jeu et les compteurs persistés
(**lot 10b**, voir la [roadmap](roadmap.md)), reportés comme prévu (U9-1).

Écarts, dans l'ordre où le code les a imposés :

| Plan | Livré | Pourquoi |
|---|---|---|
| `techniqueSummary(block, progress)` prend un bloc | prend `blockId` et `List<ExerciseRef>` | le vérificateur d'architecture refuse `entities/exercise_result` → `entities/exercise_catalog` (même couche) ; `TrainingBlock.exerciseRefs` fait le lien |
| assiduité par élève via `attendanceOf` | valeur `Attendance` unique dans `shared/lib`, calculée par `attendanceOf` (fiche) et par `groupAttendance` (`track_group`) | pas de lien entre slices d'une même couche ; une seule valeur pour les deux, la règle d'appartenance reste `Group.isMemberOn` (revue : `MemberAttendance` supprimé) |
| « un import remplace les données du club » | un import **fusionne** par identifiant ; seul un fichier d'**ancien format** (1 ou 2) efface les acquittements en place | l'import n'a jamais remplacé : il fusionne ; **fusion confirmée par l'animateur (2026-10-16)** ; U9-11 ne vaut que pour l'ancien format |
| `ExerciseSeries.alert` inchangé | `none` pour une alerte vue | pour qu'aucun écran ne l'affiche plus |
| fenêtre des alertes de groupe : `recallStaleSessions` dernières séances | de la date de la `recallStaleSessions`-ième dernière séance du groupe à aujourd'hui, bornes comprises | précision du plan |
| `toStart` = rien de validé ni d'acquis | **aucun passage et rien d'acquis** | un élève qui a échoué trois fois n'est pas « à commencer » ; il voit « 0 sur 15 techniques terminées » (les faits), pas un score masqué |
| liste des élèves : « n sur 70 exercices validés » (non traitée par le plan) | « Parcours à commencer » ou « n exercices validés » (`StudentSummary.toStart`) | le constat T7 vise aussi la liste |
| une ligne : titre, statut, fraction, séances, pourcentage | titre, fraction « 3/4 », statut **seulement** s'il dit plus que commencé ou non, séances et exercices lus par la sémantique | 2 640 dp mesurés avec statut et résumé sur chaque ligne ; ≈ 1 770 dp ensuite |
| menu ⋮ par ligne | menu ⋮ **à la suite des cases**, absent d'une technique maîtrisée par passages | une ligne de moins par technique |
| hauteur attendue ≈ 1 100 dp à 390 dp | **≈ 1 770 dp** (parcours seul, carte comprise, mesuré) ; **écart accepté par l'animateur (2026-10-16)** | 70 cases de 48 dp à six par ligne occupent ≈ 900 dp avant les titres ; le repli « techniques terminées repliées » n'est **pas** livré (il masquerait les cases « acquis » qu'exigent les scénarios) |
| grille exposée comme tableau | pas de rôles `table` / `row` / `cell` : nom accessible complet par cellule, résumé par ligne, résumé en texte, légende | la grille est coupée en une colonne fixe et une zone qui défile ; les rôles exigent une hiérarchie que cette coupe ne donne pas |
| résumé en texte « visible et repliable » | replié par défaut, entête de 48 dp | quinze lignes de texte sous une grille déjà haute |
| `ShowcaseCell` : numéro et état | + `passed` (réussites seulement) | le nom accessible d'une case commencée dit « 2 réussites sur 5 » |
| légende « Acquis » | « Issu du positionnement » (fr) / « From placement » | éviter la collision avec le statut « Acquis » (maîtrisé, fr) et « Acquired at placement » |
| cellule de carte de chaleur 48 dp | 56 dp (colonne de 64 dp) | place pour la fraction et les marqueurs ; ≥ 48 dp |
| `ClubList` : bouton « Voir la grille du groupe » | « Grille du groupe » / « Group grid », nom accessible « Ouvrir la grille de <groupe> » | texte court, nom complet pour la voix |

Décisions `[U]` : valeurs par défaut appliquées, tranchées par l'animateur le 2026-10-16 (U9-1, U9-9, U9-11 et les deux écarts `toStart` et hauteur du parcours) :

| # | Défaut appliqué | Statut |
|---|---|---|
| U9-1 | note de jeu et compteurs persistés au lot 10b | **tranché : reporté** (lot 10b, non livré) |
| U9-2 | « en cours » = premier exercice non validé (R2) | appliqué |
| U9-3 | « n techniques terminées sur 15 » et « n exercices validés » ; « sur 70 » en légende | appliqué, avec l'écart `toStart` ci-dessus (règle « à commencer » actuelle **validée** le 2026-10-16) |
| U9-4, U9-5 | portée de l'acquittement ; l'élève disparaît de « À surveiller » | appliqués (ADR 0013) |
| U9-6 | assiduité du groupe sur toutes ses séances, cinq dernières en liste | appliqué |
| U9-7 | alerte de groupe : membres actuels, fenêtre `recallStaleSessions`, au moins 2 élèves (`RulesConfig.minGroupFailures`, hors Réglages) | appliqué |
| U9-8 | grille : techniques en lignes, élèves en colonnes ; bouton par groupe | appliqué |
| U9-9 | vue élève : pastilles de réussites, aucun badge de public, « Terminer » sans code | **tranché : pas de badge « Proposition » dans la vue élève** (2026-10-16) ; le titre d'une case n'est plus suffixé de « Proposition » non plus. La provenance reste signalée partout où l'animateur prépare ou relit (séances, fiche, saisie) : aucune règle du dépôt (AGENTS.md, `00-provenance-et-fiabilite.md`) n'impose le badge dans une vue destinée à l'élève, qui ne présente aucune règle fédérale |
| U9-10 | alertes de groupe sur « Aujourd'hui » (trois au plus), pas dans le bilan | appliqué |
| U9-11 | un import d'un ancien format efface les acquittements en place | appliqué (l'import d'un format 3 fusionne par identifiant, confirmé) |

Vérification : `scripts/check.sh --full` vert (format, analyse, architecture, l10n 741 clés fr = en, suite BDD et
unitaires, couverture de lignes 98,4 % pour un seuil de 90 %, Widgetbook : 120 composants, 186 use cases) ; l'application
web a été parcourue (390 × 844) sur un club d'essai : liste, grille du groupe, fiche, vue élève (sans barre
de navigation) et arbre d'accessibilité. Ce parcours web n'avait **aucun passage** : les états « commencé »,
« validé », alerte et « Vu » ne sont vérifiés que par les tests de widget et les scénarios BDD.
