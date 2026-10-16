# ADR 0013 — Acquittement d'une alerte (« Vu ») : entité liée au dernier passage, schéma v8, sauvegarde v3

- Statut : **accepté (livré, 2026-10-16)** : domaine, persistance et sauvegarde, puis l'interface (bouton « Vu »,
  « Rétablir », fiche en parcours : [ADR 0014](0014-fiche-en-parcours-vue-eleve-et-vue-de-groupe.md)). Conception :
  [../fiche-eleve-plan.md](../fiche-eleve-plan.md) (D6). Complète l'[ADR 0003](0003-suivi-des-eleves.md)
  (alertes R4), l'[ADR 0008](0008-positionnement-initial-bloc-acquis.md) (patron de l'entité d'état, hors
  passages) et l'[ADR 0012](0012-reglages-du-club.md) (patron du format de sauvegarde versionné).
- Décisions `[U]` appliquées par défaut (2026-10-16) : U9-4 (portée), U9-5 (l'élève disparaît de
  « À surveiller » après « Vu »), U9-11 (un import d'un ancien format efface les acquittements en place).
  Confirmées par l'animateur le 2026-10-16 : l'import **fusionne** par identifiant (il ne remplace pas les
  données du club) ; seul un ancien format 1 ou 2 efface les acquittements en place. Le lot 10b (note de jeu,
  compteurs persistés, étape de séance persistée) est **reporté**, non livré.

## Contexte

Une alerte d'échecs consécutifs (R4) reste affichée tant que l'exercice n'est pas réussi. Sur « Aujourd'hui »,
dans le bilan et dans la liste des élèves, l'animateur qui a déjà vu l'alerte et décidé quoi faire ne peut pas
la retirer : la liste « À surveiller » finit par ne plus rien dire. Le lot 10 de la roadmap prévoit donc un
acquittement. L'état n'est ni un passage (les courbes, les échecs consécutifs et la validation ne doivent pas
le voir), ni un résultat dérivé : c'est une décision de l'animateur à conserver.

## Décision

1. **Entité** `AlertAcknowledgement` (`entities/exercise_result`) : `id`, `studentId`, `exercise`
   (`ExerciseRef`), `lastAttemptId` (dernier passage de l'exercice au moment du « Vu »), `date` (jour, horloge
   injectée par l'appelant, normalisé `dateOnly`). Aucune clé étrangère : suppression logique, exercices issus
   d'un asset, passage visé éventuellement supprimé ensuite.
2. **Règle de levée** : `StudentProgress.derive(acknowledgements:)` ne retient, par exercice, que le « Vu » le
   plus récent, et seulement tant que l'alerte est active **et** que le dernier passage de l'exercice est
   `lastAttemptId`. Tout nouveau passage (un échec de plus), ou la suppression / correction de ce dernier
   passage (ADR 0006), fait réapparaître l'alerte ; une réussite la résout, l'acquittement reste dormant. Les
   niveaux d'alerte, les échecs consécutifs et les courbes ne changent pas : seul `activeAlerts` masque.
3. **Portée** : le « Vu » masque l'alerte sur les surfaces de **surveillance** (cinq appelants de `derive` qui
   affichent une alerte : `ListWatchedStudents` pour l'accueil, `reviewSession` pour le bilan,
   `GetClubOverview` pour la liste, `GetStudentReport` et `GetStudentSheet` pour la fiche), donc l'élève
   disparaît de « À surveiller » s'il n'a pas d'autre alerte, le bloc « à revoir » repasse « en cours » et la
   case n'est plus marquée. Il **ne modifie pas** la notion à rappeler ni la séance suggérée (le jugement
   pédagogique ne dépend pas du fait que l'animateur ait vu), ni le retour de saisie en direct, ni les alertes
   de groupe (qui ne lisent que les derniers passages).
4. **Cas d'usage** `AcknowledgeAlert` (élève et exercice connus, alerte **active** : sinon
   `alertNotActive` ; un exercice acquis au positionnement ou déjà vu n'a pas d'alerte active) et
   `RestoreAlert` (supprime logiquement tous les acquittements de l'élève pour l'exercice, dormants compris ;
   `NotFound('acknowledgement')` s'il n'y en a aucun). Un « Vu » ultérieur crée un nouvel acquittement. Tout
   ou rien (unité de travail). `AcknowledgementBloc` (patron de `PlacementBloc`) fournit `today` à partir de
   l'horloge.
5. **Stockage** : table drift `alert_acknowledgements` (`AuditColumns`, `student_id`, `block_id`,
   `exercise_number`, `last_attempt_id`, `date`, index `acknowledgements_by_student`), schéma **v8**, migration
   `from7To8` par `createTable` + `createIndex`, instantané `drift_schema_v8.json`. Port
   `AcknowledgementRepository` (ajout idempotent par identifiant, lecture par élève, suppression logique,
   `eraseStudent` physique, `eraseAll` physique), implémentations en mémoire et drift, **suite de contrat
   commune**.
6. **Sauvegarde JSON** : format **3** (`supportedVersions = {1, 2, 3}`), clé `data.alertAcknowledgements`
   **obligatoire** dans un fichier 3 et **refusée** (`backupInvalid`) dans un fichier 1 ou 2. Décodage d'un
   fichier 1 ou 2 : `BackupSnapshot.alertAcknowledgements == null` ; l'import **efface alors les
   acquittements en place** (dans la même `UnitOfWork` que le reste : rien n'est effacé si l'import échoue) ;
   pour un fichier 3 les acquittements du fichier sont ajoutés à ceux en place (fusion par identifiant,
   comme le reste). Contrôles avant toute écriture : élève présent dans le fichier (`backupInconsistent`),
   identifiant unique (`backupInconsistent`), bloc inconnu (`backupUnknownBlock`), numéro absent du bloc
   (`backupInconsistent`), date postérieure à aujourd'hui ou avec heure (`backupInvalid`). Un `lastAttemptId`
   sans passage correspondant est **toléré** (acquittement dormant). Une application plus ancienne refuse un
   fichier 3 (`backupVersionUnsupported`) plutôt que de perdre les « Vu ».
7. **Effacement d'un élève** (`EraseStudent`) : suppression physique de ses acquittements, y compris
   supprimés logiquement.
8. **Source unique de « échouer »** : `blockFailedStudents` (entité) est appelée par `selectRecall` et par les
   alertes de groupe ; la dérivation d'une case (`exerciseCells`) et d'une technique (`techniqueSummary`,
   `BlockStatus` déplacé dans l'entité) sert la fiche, la vue élève et la carte de chaleur. Ces fonctions
   prennent des listes de `ExerciseRef` et non un `TrainingBlock` : l'entité `exercise_result` n'importe pas
   `exercise_catalog` (même couche). `TrainingBlock.exerciseRefs` fournit la liste.
9. **Rappel et alerte de groupe : seuils distincts, volontairement.** Le motif de rappel « échec de groupe »
   n'utilise que la part (`reachesGroupFailureShare`) ; l'alerte de groupe exige en plus `minGroupFailures`
   élèves. Dans un groupe de 2, un seul échec recommande donc de rappeler la technique sans lever d'alerte.
   Choix verrouillé par `recall_selector_test` (« group failure when at least 50 percent of students failed »).

## Alternatives écartées

- **Un drapeau sur l'alerte ou sur le passage** : un passage n'est pas modifié après coup (faits), et l'alerte
  est dérivée, pas stockée.
- **Acquittement sans lien avec un passage** (« ne plus jamais me montrer cette alerte ») : l'alerte
  disparaîtrait même quand l'élève échoue encore ; la ré-apparition automatique est le comportement voulu.
- **Masquer aussi le rappel et la séance suggérée** : l'animateur qui a « vu » ne dit pas que l'élève a
  maîtrisé la notion ; la suggestion suit les derniers passages.
- **Fusionner un fichier 1 ou 2 sans toucher aux acquittements** : un acquittement visant un passage disparu
  de la restauration serait faux ; effacer à l'import d'un ancien format est cohérent avec « restaurer l'état
  du fichier ». Décision `[U]` U9-11, confirmée le 2026-10-16.
- **Note de jeu et compteurs persistés** dans ce lot : reportés au lot 10b (aucun écran d'U9 ne les lit,
  ils recoupent la décision U-5 de « Aujourd'hui », et un texte libre sur des mineurs demande son propre ADR).

## Conséquences

- Les cas d'usage qui affichent une alerte reçoivent un `AcknowledgementRepository` (constructeurs
  modifiés) ; un oubli ferait réapparaître une alerte vue sur une surface : un test par surface le verrouille
  (`list_watched_students`, `get_club_overview`, `get_session_review` et `review_session`,
  `get_student_report`, `get_student_sheet`) et des scénarios BDD (`alert_acknowledgement.feature`).
- La base grossit d'une ligne par « Vu » (jamais purgée automatiquement ; supprimée avec l'élève).
- Le format de sauvegarde passe à 3 ; `ImportSummary.alertAcknowledgements` compte les acquittements du
  fichier.

## Garde-fous

Contrat commun in-memory / drift (`acknowledgement_contract.dart`) ; test de migration v7 → v8 (SQL brut sur
la base intermédiaire, instantané v8) ; effacement physique (`physical_erasure_test.dart`) ; codec 1 / 2 / 3,
clé refusée dans les formats 1 et 2, clé obligatoire dans le 3 ; import d'un ancien format sans écriture
partielle (`atomic_import_test.dart`) ; scénarios BDD du domaine (levée, rétablissement, dormant, sauvegarde,
effacement, rappel inchangé).
