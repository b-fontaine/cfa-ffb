# ADR 0006 — Historique des séances saisies et correction des passages

> **Amendé par [ADR 0024](0024-firebase-source-de-verite-comptes-clubs-roles.md)** (2026-10-17). La décision « passages renumérotés » est **amendée** : `passIndex` est dérivé (tri par date, `createdAt` serveur, identifiant) et un passage est un document (décision 17). Les règles de correction en place restent ; la suppression ne renumérote plus. Le texte ci-dessous est conservé tel qu'il a été décidé.

- Statut : **accepté** (2026-10-14), en cours d'implémentation. Plan :
  `../historique-seances-plan.md`. Lot 5 de `../roadmap.md`.
- Contexte de livraison : application V1 non livrée, aucune compatibilité de
  données à préserver.

## Contexte

Les passages sont enregistrés par séance (`SessionRecord`, `ExerciseAttempt`,
ADR 0003) mais aucune vue ne liste les séances données : l'onglet
« Résultats » ouvre le formulaire d'ouverture, et un passage mal saisi (billes
ou tentatives) ne peut être ni corrigé ni retiré. Les résultats, alertes et
suggestions en dérivent pourtant pour toute la saison.

## Décision

1. **`/record` liste les séances saisies** (plus récente en premier) et mène à
   chaque séance (`/record/:sessionId`). Le formulaire d'ouverture passe à
   **`/record/new`**, déclarée avant `/record/:sessionId` ; la séance guidée et
   la suggestion y envoient avec les mêmes paramètres.
2. **Un passage se corrige en place** (billes, tentatives) avec les invariants
   de la saisie (`totalBelowSheet`, bornes de l'entité) ; le port
   `AttemptRepository.add` remplace déjà un id connu, aucune méthode n'est
   ajoutée. La date et l'index du passage ne changent pas.
3. **Un passage se supprime** (suppression logique existante) et les passages
   restants du même élève, du même exercice et de la même séance sont
   **renumérotés** `1..n` dans une unité de travail. Raison : `RecordAttempt`
   attribue `passIndex = passages déjà saisis + 1` et `ExerciseResult.derive`
   trie par `(date, passIndex)` ; sans renumérotation, deux passages pourraient
   partager un index et la chronologie deviendrait ambiguë.
4. **Assiduité** sur la fiche élève : séances où l'élève était présent sur les
   séances de ses groupes aux dates où il en était membre. Fonction pure, sans
   port supplémentaire.
5. Hors décision : modifier les présents d'une séance passée (reste possible
   en rouvrant le même groupe à la même date, `OpenOrResumeSession`) ; supprimer
   une séance entière (à décider si le besoin apparaît).

## Alternatives rejetées

- **Suppression seule, correction par ressaisie** (comme les séances
  planifiées) : perd l'index et la place du passage dans la séance ; la
  correction d'une faute de frappe est le cas le plus fréquent.
- **Conserver les trous d'index après suppression** : simple mais contredit le
  calcul de `RecordAttempt` et rend l'ordre des passages dépendant de l'ordre
  d'enregistrement en base.
- **Un onglet supplémentaire « Historique »** : le shell garde cinq
  destinations (ADR 0004) ; l'historique est la vue naturelle de « Résultats ».
- **Ajouter `byId` et `update` au port `AttemptRepository`** : inutile, la
  saisie connaît toujours la séance (`forSession`) et `add` est idempotent.

## Conséquences

- Positives : une séance saisie est relisible et corrigible ; les résultats
  dérivés (validation, alertes, rappel, suggestion) se recalculent d'eux-mêmes ;
  aucune migration ; sauvegarde inchangée.
- Coûts : trois cas d'usage, un bloc, trois widgets et une page avec leurs
  tests, cas Widgetbook et libellés fr / en ; adaptation des scénarios qui
  visaient `/record`.
- Limites : les actions par ligne se distinguent par leur position quand deux
  passages ont le même score ; la correction ne touche ni la date ni l'index.
