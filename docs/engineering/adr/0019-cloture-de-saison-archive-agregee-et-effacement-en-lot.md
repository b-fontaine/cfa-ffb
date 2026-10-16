# ADR 0019 — Clôture de saison : archive agrégée non nominative, effacement en lot, groupes multiples ; schéma v9, sauvegarde v4

- Statut : **accepté et livré le 2026-10-16 sur les défauts proposés** des points `[U]` U11-1 à U11-15 du plan
  [../saisons-groupes-plan.md](../saisons-groupes-plan.md) (lot 11) ; la **confirmation de l'animateur** reste à recueillir (écarts
  de livraison : plan § 12). Complète l'[ADR 0001](0001-persistance-locale-drift.md)
  (effacement physique ; sa durée de conservation `[Prop]` est remplacée par la décision FB 8 de la roadmap : la saison en
  cours et la suivante), l'[ADR 0003](0003-suivi-des-eleves.md) (mêmes élèves toute la saison) et suit le patron
  des [ADR 0012](0012-reglages-du-club.md) et [0013](0013-acquittement-des-alertes.md) pour la migration et la sauvegarde.

## Contexte

Les élèves sont des mineurs ; l'application ne stocke que prénom et public. Rien ne permet de clore une saison :
le 1er septembre, tous les élèves de l'an passé apparaissent « sans groupe » et leurs données restent indéfiniment.
L'effacement existe élève par élève (`EraseStudent`). On veut clore la saison, garder des chiffres utiles
(séances, assiduité, réussite par exercice) **sans** garder d'identité, effacer en lot avec confirmation, reconduire
les autres élèves, et pouvoir tenir plusieurs groupes par public et déplacer un élève sans perdre son historique.

## Décision

1. **Clôture** : `Season.closedOn` (jour, nullable). `CloseSeason` est **une seule unité de travail** : archive
   calculée **avant** l'effacement, archive enregistrée, saison close (fin ramenée au jour de clôture si elle est
   postérieure), élèves choisis effacés physiquement (mêmes données que `EraseStudent`), saison suivante préparée,
   séances planifiées postérieures supprimées. `Season.isOpenOn(date)` (non close et dans la période) remplace
   `contains` pour « saison en cours » et « travail nouveau » ; `BackupRules` garde la période seule (données
   historiques).
2. **Archive agrégée** : par saison et par public, séances / présences / présences possibles / élèves distincts /
   passages ; par exercice, élèves distincts / passages / billes empochées / tentées, **uniquement si au moins 3
   élèves distincts** (constante du domaine, pas un réglage). Aucun identifiant d'élève, prénom, groupe ni date de
   séance. Un public de moins de 3 élèves présents ne garde que son nombre de séances et d'élèves (pas de présences ni de
   passages). Tables `season_archive_audiences` et `season_archive_exercises`, remplacées en bloc par saison.
3. **Aucune trace nominative de l'effacement** : ni journal, ni liste d'identifiants effacés, même
   pseudonymisés. Le résultat est un nombre affiché à l'écran.
4. **Proposition d'effacement déterministe** (`proposeClosure`) : inactif dans la saison, ou première inscription
   antérieure à la saison (conservation = saison en cours + suivante) → « Effacer » ; sinon « Reconduire ». Sont
   proposés les élèves de la saison **et** ceux qu'aucune saison ouverte ne place (jamais placés, ou gardés par une
   clôture sans saison suivante), pour que leurs données ne restent jamais hors de toute clôture.
   La règle propose, l'animateur décide ligne par ligne. Sauvegarde **proposée, non bloquante**, avec avertissement
   sur son contenu nominatif.
5. **Groupes** : plusieurs groupes par (saison, public), nom unique dans la saison (règle de cas d'usage, sans
   contrainte SQL), suppression seulement d'un groupe vide sans séance. `MoveStudent` clôt l'appartenance à la
   veille de la date d'effet et ouvre l'autre à cette date (même saison, même public, date après la dernière
   présence dans l'ancien groupe). Aucune donnée copiée : l'historique suit l'élève (passages) et la séance
   (présences).
6. **Schéma v9**, migration additive `from8To9` (colonne `seasons.closed_on`, deux tables d'archive).
   **Sauvegarde 4** (`supportedVersions = {1, 2, 3, 4}`) : `seasons[].closedOn` facultatif, `seasonArchives`
   obligatoire dans un fichier 4 et refusée dans un fichier 1 à 3 ; un import qui apporte une saison sans
   `closedOn` alors que ce club l'a close est **refusé** (`backupReopensClosedSeason`, avant toute écriture :
   l'effacement des mineurs ne s'annule pas par un import) ; l'archive d'un fichier remplace celle en place. Une application plus ancienne refuse un fichier 4.

## Alternatives écartées

- **Archive nominative chiffrée ou « pseudonymisée »** (identifiant haché, liste d'effacés) : un identifiant
  conservé relie un ancien fichier de sauvegarde à une personne ; contourne l'effacement réel.
- **Archive par groupe** : un groupe de deux ou trois enfants est reconnaissable ; le public suffit aux
  statistiques du club.
- **Recalculer l'archive à la demande** : impossible, les présences et passages ont été effacés avec les élèves.
- **Clôture bloquée tant qu'une sauvegarde n'est pas faite** : peut empêcher une clôture légitime (stockage
  indisponible) ; l'avertissement et la proposition en tête d'assistant suffisent.
- **Seuil d'archive réglable** (lot 9) : permettrait d'abaisser la protection des mineurs ; c'est une règle.
- **Effacer d'office tous les élèves à la clôture** : détruirait le parcours des élèves qui reviennent, valeur
  centrale de l'application (ADR 0003).
- **Supprimer logiquement les élèves** : la suppression logique n'est pas un effacement (ADR 0001).
- **Un service d'effacement dans une couche commune** plutôt que deux cas d'usage à parité testée : voir plan § 6.

## Conséquences

- Positives : fin de saison sans « élèves sans groupe » ; données de mineurs bornées dans le temps ; statistiques
  d'activité conservées sans identité ; groupes et déplacements sans migration de données.
- Coûts : migration v9 et format 4 ; sept sites de `contains` à remplacer ; un assistant de six étapes ; un test de
  parité d'effacement ; dans le futur Firestore (FB8), l'atomicité de la clôture est à reconstruire (lots de 500
  écritures, état reprenable).
- Limites assumées : **importer un fichier antérieur à la clôture sur un club vide (autre appareil) rétablit les
  élèves effacés** : sur un club qui a clos la saison, l'import est refusé, mais un club vide ne garde rien de
  nominatif qui permette de le savoir ; les fichiers déjà exportés ne sont pas touchés (à supprimer
  par l'animateur) ; aucun âge n'étant stocké, tous les élèves sont traités comme mineurs.
- Garde-fous : contrat commun du dépôt d'archive ; test de migration v8 → v9 ; effacement physique étendu à la
  clôture ; parité d'effacement avec `EraseStudent` ; absence d'identifiant dans l'archive ; codec 1 à 4 ;
  import atomique ; scénarios BDD du plan § 7.
