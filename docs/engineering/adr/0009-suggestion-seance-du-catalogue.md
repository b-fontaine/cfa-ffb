# ADR 0009 — Suggestion ↔ catalogue : proposer la séance du catalogue

- Statut : **accepté** (2026-10-14). Arbitrages S1 à S8 de l'animateur
  intégrés (voir « Arbitrages »). Livré le 2026-10-14. Plan :
  `../suggestion-catalogue-plan.md`. Lot 8 de `../roadmap.md`.
  Prolonge les [ADR 0007](0007-lien-seance-planifiee-saisie-catalogue.md)
  (séance planifiée / saisie / séance du catalogue) et
  [0008](0008-positionnement-initial-bloc-acquis.md) (bloc acquis), et
  s'appuie sur l'[ADR 0004](0004-catalogue-fiches-seances.md) (28 séances).
- Contexte de livraison : application V1 non livrée, aucune compatibilité de
  données à préserver.

## Contexte

La séance suggérée (`planSession`, `features/suggest_session/domain/
session_planner.dart`) calcule un **bloc principal** (`mainBlockId`), des
exercices voisins de l'exercice de tête et un rappel. Elle ne sait rien des
**séances du catalogue** (`SessionSheet`, 29 YAML) : `SessionPlan` n'a ni
`sheetId` ni notion de partie, `SuggestSession` ne lit pas
`SessionSheetRepository`, et `SuggestedSessionPage` ouvre la saisie par
`/record/new?group=&main=&recall=` **sans `sheet`**. Conséquences :

- l'animateur doit retrouver à la main, dans le catalogue, la séance qui
  correspond au bloc suggéré (13 blocs sur 15 ont 2 à 4 parties) ;
- la saisie créée depuis la suggestion a `SessionRecord.sheetId == null` : elle
  ne dit pas quelle partie a été donnée, donc rien ne permet de savoir quelle
  est « la partie suivante » ;
- le lien bloc → séance n'existe que dans le sens inverse
  (`ResolveSheetBlocks`, `resultsRecallBlock`).

Faits du catalogue (contrôlés sur les 28 fichiers) : toute séance est mono-bloc
(`catalogue_block`, et `ref.block` de chaque exercice égal à ce bloc) ; aucune
séance n'est propre à un public (chaque YAML décrit enfants 90 min et adultes
120 min, le public ne change que le rendu) ; `order` 1..29 sans trou ; les
exercices d'un bloc sont répartis en tranches contiguës entre ses parties ;
`quart-finesses` est le seul bloc partagé par deux techniques (`quart-1` puis
`finesse-1`) ; `quantites-de-billes` (`teaching_order` 8) et
`trajectoires-blanche` (`teaching_order` 15) n'ont **aucune** séance (« jamais
de séance propre », `FORMAT.md` § 1.2). Comme `ExerciseCatalogue.nextExercise`
parcourt les exercices dans l'ordre d'enseignement, ces deux blocs deviennent
**notion principale** de tout groupe qui les atteint : « bloc sans séance » est
un **cas nominal**, atteint à chaque cycle, pas un cas marginal.

## Décision

1. **La suggestion garde son calcul et ajoute une proposition de séance.**
   `planSession` n'est pas modifié (le lot 7 et l'ordre d'enseignement restent
   intacts, la fonction reste pure) : une fonction pure **en aval**,
   `suggestSheet`, choisit parmi les séances du bloc principal. Le résultat est
   un champ facultatif du plan : `SessionPlan.sheet` (`SheetSuggestion?`, nul =
   bloc sans séance). `SuggestSession` lit `SessionSheetRepository` et assemble
   les entrées ; la fonction ne lit aucun dépôt.
2. **Règle déterministe de choix.** Entrées de `suggestSheet` (7) :
   `mainBlockId`, `head` (exercice de tête), `sheets`
   (`Iterable<SessionSheet>` : il faut `catalogueBlock`, `order` et
   `exercises[].ref`, que `SheetOption` ne porte pas), `groupSessions`,
   `attemptCountBySession` (nombre de passages rattachés à chaque saisie),
   `today` (`Clock`), `validatedByAll`. Le public ne filtre pas.
   1. *Candidates* `C` : séances dont `catalogueBlock == mainBlockId`, triées
      par `order`. `C` vide → aucune proposition (repli S8).
   2. *Faites* `D` : séances de `C` désignées par au moins une saisie du groupe
      **faite** (S7, ci-dessous) ; un identifiant inconnu du catalogue est
      ignoré.
   3. *Sans objet* `O` : séances de `C` dont **tous** les exercices sont
      validés (ou acquis, lot 7) par **chaque** élève attendu. Dépend donc de
      `expectedStudents` : ajouter ou retirer un élève peut changer la séance
      proposée (voulu). `validatedByAll` est l'intersection des
      `StudentProgress.validated` ; pour **zéro** élève, c'est l'ensemble vide
      (jamais « tout »), fonction pure `validatedByAll(progress)` testée ;
      `planSession` lève de toute façon `noStudents` avant. La séance qui
      contient l'exercice de tête n'est **jamais** sans objet.
   4. *À faire* `P = C \ D \ O`.
   5. `P` non vide : la séance de `P` **qui contient l'exercice de tête** (S1),
      sinon la **première** de `P` par `order`.
   6. `P` vide : la séance de `C` qui contient l'exercice de tête, raison
      `repeat`, étiquetée « déjà donnée le … » (S4). Par construction elle
      existe : un test de couverture du catalogue réel garantit que tout
      exercice d'un bloc à séances est contenu dans exactement une de ses
      séances ; si malgré tout elle manque, `suggestSheet` renvoie `null` (pas
      de branche « dernière séance »).
3. **Une partie « faite » (S7)** est un `SessionRecord` du groupe avec
   `sheetId` **et** au moins un `ExerciseAttempt` rattaché
   (`AttemptRepository.forSession`), **daté d'aujourd'hui ou avant** (jour
   calendaire local). Ouvrir la saisie puis revenir en arrière crée un
   `SessionRecord` sans passage (`OpenSession`, `OpenOrResumeSession`) : il ne
   compte pas. Une saisie sans `sheetId` ne compte pas (S2) ; une séance
   **planifiée** non saisie ne compte pas (S5, hors lot). Plusieurs saisies
   pour une même séance : `lastGivenOn` est la date de la plus récente.
   Précise « la saisie est la preuve » de l'ADR 0007.
4. **Exercices affichés (S3).** Si la séance proposée contient l'exercice de
   tête, `plan.exercises` reste celui du calcul par élève. Sinon (cas
   `nextPending` : tête dans une partie faite), `SuggestSession` remplace
   `plan.exercises` par les exercices **de la séance non validés par tout le
   groupe**, et la carte signale l'exercice de tête en note (« L'exercice de
   tête n° 2 relève d'une partie déjà donnée »). Aucune incohérence entre la
   liste et la séance transmise à la saisie.
5. **La proposition mène au guide puis à la saisie pré-remplie.** Actions :
   « Ouvrir la séance » (`AppRoutes.sheet`), « Lancer la séance guidée »
   (`AppRoutes.guide(sheetId, audience:, group:)`, S6), « Planifier »
   (`AppRoutes.plan`), et « Saisir les résultats » transmet `sheet` via un
   constructeur testable `AppRoutes.recordFromSuggestion({group, main, recall,
   sheet})`. Le rappel **suggéré** (échec / alerte) reste prioritaire sur le
   rappel dérivé de la séance (`OpenSession` ne dérive que les blocs absents,
   ADR 0007).
6. **Bloc sans séance (S8) : repli explicite et utile.** Message « Aucune séance
   du catalogue pour cette notion » + exercices du bloc (suggestion actuelle) ;
   aucune séance inventée, pas de partie voisine proposée ; « Saisir les
   résultats » (sans `sheet`) et « Planifier » (sans séance présélectionnée)
   restent disponibles ; pas d'« Ouvrir » ni « Lancer ».
7. **Échec de chargement du catalogue de séances : la suggestion échoue.**
   `SuggestSession` est sous `runGuarded` et le catalogue est un asset embarqué,
   comme le catalogue d'exercices déjà lu : un échec est un défaut de
   l'application, pas une condition d'exécution. Dégrader sans séance
   afficherait à tort « aucune séance pour cette notion ». L'écran d'erreur
   existant s'applique (scénario unitaire dédié).
8. **Pas de migration drift, pas de changement de sauvegarde.** Tout est dérivé
   de données déjà persistées (`SessionRecord.sheetId`, schéma v4 ;
   `ExerciseAttempt.sessionId` ; catalogue en asset).
9. **Libellé** : `sheetPartLabel` existant (« Séance 2/2 », déjà utilisé par
   planification, saisie et catalogue) précédé du titre de `SheetOption` ; pas
   de nouvelle clé de partie.
10. **Placement FSD.** `suggestSheet` et `SheetSuggestion` dans
    `features/suggest_session/domain` (aucun import d'une autre feature ;
    `SessionSheet`, `SheetOption`, `sheetOptionOf` viennent de
    `entities/session_sheet`). Liens guide / planificateur / saisie câblés par
    `app/router.dart` (callbacks de la page). Le guide connaît le groupe (S6) :
    paramètre `group` sur `AppRoutes.guide`, champ `group` de `RunKey`,
    `_runKey` / `_guideKey` du routeur, `RunSheetSessions` (clé), donc
    `features/run_sheet` est dans le périmètre.

## Alternatives rejetées

- **Modifier `planSession` pour qu'il raisonne par séance** : refait un calcul
  arbitré aux lots 5 à 7 et le couple au catalogue de séances.
- **Séance proposée = toujours la première non faite** (lecture littérale de la
  roadmap, S1) : ignore l'exercice de tête. L'écart n'apparaît que sur un
  groupe **hétérogène** : bloc `coule` (`coule-1` 1-3, `coule-2` 4-6), l'élève A
  a validé 1 à 3, l'élève B n'a rien validé, l'exercice de tête vaut 5.
  `coule-1` n'est pas sans objet (B n'a pas validé 1-3) : « première de `P` »
  propose `coule-1`, « contient la tête » propose `coule-2`. Avec un groupe
  homogène ayant validé 1 à 3, `coule-1` est sans objet et les deux règles
  convergent : ce n'est pas le scénario discriminant. Rejetée (S1).
- **Dériver la « partie suivante » du nombre de saisies du bloc** : magique,
  faux dès qu'une partie est sautée ou refaite.
- **Compter les séances planifiées** (S5) ou **les saisies sans passage**
  (S7) comme faites : une planification ou une saisie ouverte n'est pas une
  séance donnée.
- **Éviter les blocs sans séance dans `nextExercise`** : change le suivi des
  élèves, hors périmètre.
- **Stocker la séance proposée** : donnée dérivable, périmée dès qu'une saisie
  arrive.
- **Garder `plan.exercises` quand la séance ne contient pas la tête** (S3
  initial) : liste et séance incohérentes.

## Conséquences

- Positives : une seule action de la suggestion à la saisie, la saisie note la
  séance suivie ; aucune migration ; fonction pure testable table par table.
- Coûts : `SessionPlan` gagne un champ (régénération freezed), `SuggestSession`
  lit deux dépôts de plus (`SessionSheetRepository`, passages par saisie du
  groupe) et une horloge ; vue, page (callback `onRecord` à 4 arguments, doc
  et tests existants de la page mis à jour), routeur, `RunKey`, libellés
  fr / en, scénarios BDD, cas Widgetbook.
- Limites : les saisies **sans** `sheetId` ou sans passage ne comptent pas ; un
  groupe dont tout l'historique est sans `sheetId` repart de la partie
  contenant sa tête (tête = 1 : partie 1) ; la suggestion ne dit pas quels
  blocs ont été sautés (limite de l'ADR 0008).

## Arbitrages de l'animateur (2026-10-14)

| N° | Question | Décision |
|----|----------|----------|
| S1 | Règle de choix | Partie contenant l'exercice de tête d'abord, sinon première à faire. |
| S2 | Saisie sans séance du catalogue | Ne compte pas. |
| S3 | Exercices affichés | Si la séance ne contient pas la tête : exercices non validés de la séance + note sur la tête. |
| S4 | Toutes parties faites | Partie contenant la tête, « déjà donnée le … ». |
| S5 | Planifiée non saisie | Ne compte pas, hors lot. |
| S6 | Groupe au guide | Oui : `group` sur `AppRoutes.guide`, dans le lot. |
| S7 | « Faite » | `sheetId` + au moins un passage rattaché, daté d'aujourd'hui ou avant. |
| S8 | Bloc sans séance | Message explicite + exercices du bloc, Saisir et Planifier conservés. |
