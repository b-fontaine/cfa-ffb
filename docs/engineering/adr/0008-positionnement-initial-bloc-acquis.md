# ADR 0008 — Positionnement initial : marquer un bloc acquis sans passage

- Statut : **accepté** (2026-10-14), conception ; implémentation à faire.
  Plan : `../positionnement-initial-plan.md`. Lot 7 de `../roadmap.md`.
  Complète l'[ADR 0003](0003-suivi-des-eleves.md) (règles de suivi) et suit le
  patron des [ADR 0006](0006-historique-et-correction-des-passages.md) et
  [0007](0007-lien-seance-planifiee-saisie-catalogue.md).
- Contexte de livraison : application V1 non livrée, aucune compatibilité de
  données à préserver (schéma et sauvegarde modifiés directement).
- Décisions de l'animateur `[U]` du 2026-10-14 : A1 à A5 ci-dessous ; A5 a été
  précisée par deux arbitrages (reprise **par exercice**, comparaison « même
  jour ou après »).

## Contexte

Un exercice n'est « validé » que par `passesRequired` passages réussis
(`ExerciseResult.derive`, ADR 0003). Un élève qui arrive en cours d'année, ou
qui joue déjà, n'a aucun passage : `StudentProgress.validated` est vide,
`ExerciseCatalogue.nextExercise` renvoie le premier exercice du premier bloc
(« posture »), la séance suggérée (`planSession`) repart de zéro et la fiche
affiche « 0 / 72 » toute la saison. La seule issue actuelle est de saisir des
passages fictifs, ce qui fausse courbes, alertes, assiduité de bloc et
`sessionsSpent`.

## Décision

1. **Action sur la fiche élève d'abord (A1).** Chaque ligne de bloc de la
   fiche (`BlockProgressList`) propose « Marquer le bloc acquis » ; un bloc
   déjà marqué propose « Retirer l'acquis ». Pas de parcours de positionnement
   en lot à la création de l'élève dans ce lot (voir Alternatives).
2. **État distinct stocké (A2), jamais de passages fictifs.** Nouvelle entité
   `BlockAcquisition` : identifiant, élève, bloc du catalogue, **date** du
   positionnement (jour), **source** (`placement`, énumération extensible).
   Elle n'est ni un `ExerciseAttempt` ni un `ExerciseResult` : courbes,
   passages, `passIndex` et alertes ne la voient pas.
3. **Granularité : le bloc entier (A3).** Un marqueur porte sur un bloc ; les
   15 blocs du catalogue sont éligibles (blocs `[Prop]` compris, avec leur
   pastille). Pas de marquage d'un exercice isolé.
4. **Effet sur le suivi (A4).**
   - Tous les exercices d'un bloc acquis comptent comme validés tant qu'aucun
     passage ne reprend la main sur eux (A5) : ils entrent dans « n / 72 »
     (`StudentReport.validatedCount`) et dans `StudentProgress.validated`, donc
     `nextExercise` et `planSession` les sautent.
   - L'**ordre d'enseignement est inchangé** (rebond sur bande puis rejet
     naturel, décision `[U]` de l'ADR 0003) : seul ce qui est acquis est
     ignoré, on ne réordonne jamais le reste.
   - Le statut d'un bloc est un cinquième statut distinct,
     **« Acquis au positionnement »** (`BlockStatus.acquiredAtPlacement`), avec
     sa date ; il n'est jamais confondu avec « Acquis » (validé par passages).
   - Un bloc entièrement acquis n'est jamais « en retard » (`overdue` faux),
     n'est pas candidat au rappel (aucun résultat) et les alertes antérieures
     de ses exercices acquis ne sont plus actives.
5. **Réversible, et les passages reprennent la main exercice par exercice
   (A5).**
   - « Retirer l'acquis » supprime logiquement le marqueur (convention des
     repositories) ; on peut le poser de nouveau.
   - Un exercice d'un bloc marqué est **acquis** tant qu'aucun passage de
     l'élève sur **cet exercice** n'est daté **le même jour que le
     positionnement ou après** (comparaison sur `dateOnly`, `>=`). Dès qu'un tel
     passage existe, cet exercice se dérive de ses résultats comme avant ; les
     **autres exercices du bloc restent « acquis au positionnement »**. « n / 72 »
     ne chute donc que de l'exercice repris, jamais du bloc entier.
   - Statut du bloc : « Acquis au positionnement » tant que tous ses exercices
     sont acquis ; dès qu'un exercice est repris, le bloc se dérive de ses
     résultats, avec comme exercices validés l'union des exercices validés par
     passages et des exercices encore acquis (« Acquis » si cette union couvre
     le bloc). La fiche indique « Acquis au positionnement le … ; N exercices
     repris par les passages saisis depuis ».
   - Le marqueur reste stocké ; fonction pure, aucune écriture au moment de la
     saisie.
   - À la saisie (`RecordAttempt`), un passage qui reprend la main sur un
     exercice acquis ne déclenche pas `justValidated` ; le retour de saisie
     signale la reprise (`resumedFromPlacement`) et `nextExercise` est
     recalculé (l'exercice repris redevient à valider).
6. **Règles de saisie.** Élève connu (`NotFound('student')`), bloc connu du
   catalogue (`unknownBlock`, code existant), date **non future**
   (`dateInFuture`, comme le bilan de maturité), un seul marqueur non supprimé
   par couple (élève, bloc) (`blockAlreadyAcquired`, nouveau code). La date est
   un `DateTime` normalisé par `.dateOnly` (`shared/lib/date_only.dart`) ;
   l'entité refuse une date non normalisée.
7. **Persistance.** Schéma drift **v5** : table `block_acquisitions`
   (colonnes d'audit, `student_id`, `block_id`, `date`, `source`, index par
   élève), migration `from4To5` par `createTable`. Sauvegarde JSON : clé
   `blockAcquisitions` **obligatoire** (une clé absente est refusée par
   `backupInvalid`, comme les autres listes ; aucune compatibilité avec des
   fichiers antérieurs, `BackupCodec.currentVersion` et `supportedVersions`
   inchangés). Effacement d'un élève
   (`EraseStudent`) : suppression physique de ses marqueurs.
8. **Placement.** Entité `entities/block_acquisition` (domain + data) ;
   feature `features/place_student` (cas d'usage, bloc, boîte de dialogue) ;
   la dérivation reste dans `entities/exercise_result` (`StudentProgress`) et
   `features/track_progress` (`BlockProgress`, `StudentReport`). La page
   `student_sheet` compose le bloc de la nouvelle feature (aucune feature
   n'importe une autre feature).
9. **Un oubli de branchement est impossible.** `StudentProgress.derive` reçoit
   le paramètre **obligatoire** `acquisitions` : les six appelants
   (`GetStudentSheet`, `GetStudentReport`, `GetClubOverview`, `SuggestSession`,
   `SuggestRecall`, `RecordAttempt`) cessent de compiler tant qu'ils n'ont pas
   lu `AcquisitionRepository`. `BackupRules` ne l'appelle pas (simple mention
   dans un commentaire).

## Alternatives rejetées

- **Passages fictifs** (5 passages réussis par exercice) : pollue courbes,
  alertes, assiduité de bloc et `justValidated` ; indistinguable d'un vrai
  résultat ; contredit la règle « un seul chemin pour valider ».
- **Indicateur booléen sur l'élève ou sur le bloc du catalogue** : le
  catalogue est un asset en lecture seule, et un booléen perd la date et la
  source (utiles à la relecture et à une sauvegarde).
- **Marquer un exercice isolé** : multiplie les gestes (72 exercices) pour un
  besoin qui est « il maîtrise tout le bloc ». Une extension reste possible
  (`BlockAcquisition` porterait un numéro d'exercice facultatif) sans casser le
  modèle.
- **Parcours de positionnement en lot** (grille 15 blocs × élèves, à la
  création de l'élève ou en début de saison) : utile mais plus gros ; la fiche
  couvre le besoin et la grille s'appuiera sur les mêmes cas d'usage (lot
  ultérieur de la roadmap).
- **Le marqueur supprime ou désactive de lui-même au premier passage** (écriture
  lors de la saisie) : couple la saisie au suivi et rend la règle dépendante de
  l'ordre des écritures ; la dérivation pure est testable et rejouable.
- **Un acquis qui masque définitivement les passages ultérieurs** : un élève
  surestimé à la rentrée resterait « acquis » malgré des échecs répétés.
- **Reprise du bloc entier au premier passage** (formulation initiale de A5) :
  un seul passage de rappel ferait chuter « n / 72 » de tout le bloc ;
  remplacée par la reprise exercice par exercice (arbitrage de l'animateur).
- **Compter l'acquis hors de « n / 72 »** : l'objectif de la roadmap est que la
  fiche ne reste pas à « 0 / 72 » ; l'animateur a tranché (A4) de le compter,
  le libellé distinct évite la confusion.

## Conséquences

- Positives : suivi et suggestion corrects dès la première séance d'un élève
  non débutant ; aucune donnée fictive ; réversible ; sauvegarde et effacement
  couverts.
- Coûts : une entité, un repository (contrat + deux implémentations), une
  migration v5 testée, un statut de bloc de plus (tous les `switch` de
  `BlockStatus` à compléter), une feature avec bloc et boîte de dialogue,
  libellés fr / en, cas Widgetbook.
- Limites : un passage saisi le jour du positionnement reprend la main sur son
  exercice (un animateur qui marque l'acquis après avoir saisi la séance du
  jour verra cet exercice repris : il peut retirer et reposer le marqueur ou
  corriger le passage) ; un passage daté d'avant le positionnement ne reprend
  pas la main ; un bloc partiellement repris mêle exercices acquis et exercices
  à passages, sans distinction visuelle fine par exercice dans ce lot ; un
  bloc acquis n'a pas de courbe ; la séance suggérée ne dit pas
  quels blocs ont été sautés (pointé dans le plan, § 9) ; le positionnement
  est par élève, pas par groupe.
