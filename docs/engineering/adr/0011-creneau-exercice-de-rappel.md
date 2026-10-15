# ADR 0011 — Créneau d'exercice de rappel dans les séances du catalogue

- Statut : **accepté** (2026-10-15), décision 7 de l'animateur `[U]`
  (`docs/knowledge/08-lacunes-et-questions-ouvertes.md`). Prolonge les
  [ADR 0004](0004-catalogue-fiches-seances.md) (catalogue, 28 séances) et
  [0007](0007-lien-seance-planifiee-saisie-catalogue.md) (bloc du rappel de
  résultats).
- Contexte de livraison : application V1 non livrée, aucune compatibilité de
  données à préserver.

## Contexte

Trois règles se contredisaient :

- le mémento `[S]` : un exercice est joué **2 fois au maximum** dans une
  séance et « peut être rejoué dans les séances suivantes » ;
- la décision `[U]` du 2026-10-11 : un exercice est **validé après plusieurs
  passages réussis** (5 par défaut, réglable) ;
- le catalogue : chaque exercice n'appartient qu'à **une seule** séance
  (règle V5 de `FORMAT.md`), avec `passes: 1` ou `2`, et le catalogue occupe
  la saison entière.

Un exercice ne pouvait donc jamais atteindre les passages requis en suivant le
catalogue. L'application savait déjà noter des passages sur un **bloc de
rappel de résultats** (`resultsRecallBlock`, ADR 0007) et suggérer une notion
à rappeler par élève (R5, `selectRecall`), mais la séance guidée n'avait aucune
étape pour le faire.

## Décision

1. **Un créneau de rappel par séance, à partir de la 2e.** Chaque séance
   d'`order > 1` déclare `training.recall_slot: {weight, passes}` (règle V28).
   Le créneau est un **emplacement** : il ne nomme aucun exercice. Il est
   `[Prop]` par définition (poids et minutes), comme le reste du minutage.
2. **L'exercice est choisi à l'exécution, d'après le suivi des élèves**,
   par une fonction pure `chooseRecallExercise` (`features/run_sheet/domain`) :
   - candidats : les exercices des séances d'`order` inférieur, de la plus
     récente à la plus ancienne, et dans chaque séance du dernier exercice au
     premier ;
   - élèves considérés : les membres du groupe de la séance planifiée
     (`?session=`) à sa date ; sans séance planifiée, les élèves du public du
     guide ; sans élève, personne ;
   - choix : l'exercice que **le plus d'élèves n'ont pas encore validé**
     (validé par passages ou acquis au positionnement, ADR 0008) ; à égalité,
     le plus récent. Sans élève, ou si tout est validé, le dernier exercice de
     la séance précédente (révision).
3. **Place et minutes.** Le créneau est la **dernière** étape de la phase
   d'entraînement, après les exercices de la séance : la notion du jour
   d'abord, le rappel ensuite. Ses minutes viennent du budget de la phase
   d'entraînement, réparties au plus fort reste avec les exercices
   (`FORMAT.md` § 4) ; les passages cumulés restent bornés à 2 par séance
   (`maxPassesPerExercisePerSession`).
4. **Saisie.** « Noter les résultats » depuis le créneau ouvre la saisie sur
   l'exercice choisi ; son bloc devient le bloc de rappel de la saisie quand il
   diffère du bloc principal (le bloc dérivé de l'ADR 0007 sert de valeur par
   défaut sinon). Rien n'est enregistré sans saisie.
5. **Présentation.** Le créneau se montre aux élèves par le schéma de mise en
   place de l'exercice choisi, comme un exercice ordinaire.

## Conséquences

- 27 fichiers du catalogue gagnent un `recall_slot` ; le validateur
  (`tool/fiches.dart`, V28) exige sa présence dès `order > 1` et son absence
  à la première séance ; le test de contrat vérifie le minutage avec le
  créneau.
- `SessionSheet.recallSlot` (nullable, présent si et seulement si `previous`
  l'est), `SheetTiming.recallExercise`, `RunStepKind.recallExercise`,
  `RunPlan.recallExercise` (origine, exercice, taux, élèves en attente).
- Les scénarios du guide qui comptaient les étapes gagnent une étape.
- Rejeté : **abaisser la validation à 2 passages** (fragile, un bon jour
  suffit) et **valider hors catalogue** dans des séances libres (aucune place
  dans une saison de 28 séances).
