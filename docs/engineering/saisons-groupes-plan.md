# Plan d'exécution : Saisons et groupes (lot 11)

Statut : **livré le 2026-10-16** (11a, 11b, 11c) **sur les défauts proposés** des
points `[U]` (§ 3) ; l'animateur ne les a pas encore confirmés : s'il en corrige
un, le § 12 dit où il pèse. Écarts de livraison et résultats : § 12. Sources : [roadmap](roadmap.md) (lot 11, décisions FB du
2026-10-16), [ADR 0001](adr/0001-persistance-locale-drift.md) (effacement,
conservation `[Prop]`), [ADR 0003](adr/0003-suivi-des-eleves.md),
[ADR 0007](adr/0007-lien-seance-planifiee-saisie-catalogue.md),
[ADR 0012](adr/0012-reglages-du-club.md),
[ADR 0013](adr/0013-acquittement-des-alertes.md),
[ADR 0014](adr/0014-fiche-en-parcours-vue-eleve-et-vue-de-groupe.md),
[ADR 0016](adr/0016-identite-de-la-saisie-par-groupe-jour-et-seance.md) ;
décisions structurantes de ce lot : [ADR 0019](adr/0019-cloture-de-saison-archive-agregee-et-effacement-en-lot.md)
(accepté sur les défauts).

Le lot couvre trois sujets : (a) clôture de saison, (b) plusieurs groupes par
public, (c) déplacer un élève de groupe. Ordre de livraison : **11a** (b + c,
aucune migration) → **11b** (a, domaine + persistance + sauvegarde) → **11c**
(a, interface).

## 1. Constats sur le code (vérifiés le 2026-10-16)

### Groupes

- Le **modèle autorise déjà** plusieurs groupes par (saison, public) :
  `Group` n'a aucune contrainte d'unicité, la table `groups` non plus, et
  `Group.admit` / `Group.release` gèrent des appartenances datées
  (`Membership.from` / `to`).
- Mais **aucun cas d'usage ne permet d'en créer un second**. `EnrollStudent`
  reprend `existing.first` (le premier groupe de la saison pour ce public, ou en
  crée un nommé d'après le public) ; `ChangeAudience._destination` fait de même.
  Aucun écran ne crée, renomme ni supprime un groupe, ni ne déplace un élève.
  Le « un seul groupe par public » est donc un fait d'implémentation, pas une
  règle du domaine.
- Les consommateurs sont déjà par groupe : `GetClubOverview` (cartes de groupe),
  `GetGroupOverview` (grille, assiduité, alertes de groupe), `OpenOrResumeSession`
  et l'identité de saisie (groupe, jour, séance : ADR 0016), `PlanSession`
  (`groupId` facultatif), `ListJourneyGroups` (marqueur ✓ / ▶ / ○ d'U8),
  `SuggestSession` (ADR 0009). Seul le **nom** du groupe peut manquer à
  l'affichage quand deux groupes ont le même public (à vérifier écran par écran,
  § 8).
- Les appartenances sont des périodes : `isMemberOn(student, date)` et
  `membersOn(date)` sont la **sélection unique** des membres (ADR 0014 § 6).

### Saisons

- `Season` = libellé + période, sans état. Une saison « finit » seulement parce
  que `contains(today)` devient faux. Il n'y a **ni clôture, ni archive**.
- Sept sites lisent `season.contains(...)` : cinq pour « les saisons en cours »
  (`GetClubOverview`, `ListGroupAlerts`, `ListPlannableGroups`,
  `ListJourneyGroups`, `EnrollStudent._seasonOf`) et deux pour « le travail
  nouveau tient dans la saison » (`OpenOrResumeSession`, `PlanSession`).
  `BackupRules` s'en sert aussi, pour valider des données **historiques**
  (période seule, à ne pas durcir).
- **Conséquence aujourd'hui, sans clôture** : le 1er septembre, la saison
  précédente cesse d'être « en cours », `EnrollStudent` en crée une nouvelle, et
  **tous les élèves de l'an passé apparaissent « sans groupe »** (leurs
  appartenances sont dans les groupes de l'ancienne saison). La clôture doit donc
  aussi **reconduire** les élèves, pas seulement effacer.
- Les passages (`Attempts`) ne portent **pas** de saison : ils sont par élève et
  par séance (`sessionId` → `SessionRecord.seasonId`). Un élève conservé garde
  son parcours entier (cohérent avec « mêmes élèves toute la saison », ADR 0003).

### Effacement

- `EraseStudent` (`features/manage_students`) efface physiquement, en une unité
  de travail : passages, bilans, blocs acquis, acquittements, présences,
  appartenances, historique de public, élève, y compris les lignes supprimées
  logiquement. Les séances et les groupes restent, sans l'élève. Les fichiers de
  sauvegarde déjà exportés ne sont pas touchés (ADR 0001).
- Les **présences** disparaissent avec l'élève : ce qu'on peut dire de
  l'assiduité d'une saison **après** effacement n'existe plus. Une « archive pour
  les statistiques » doit donc être **calculée avant** d'effacer et stockée en
  agrégats ; il n'y a aucun moyen de la reconstruire ensuite.
- Aucun âge n'est stocké (donnée minimale : prénom et public). Tous les élèves
  sont traités comme des mineurs.
- L'import de sauvegarde **fusionne par identifiant** (ADR 0013, confirmé le
  2026-10-16) : importer un fichier antérieur à la clôture **ressuscite** les
  élèves effacés. Voir § 3 (U11-12) : limite assumée, pas contournable sans
  conserver de trace nominative.

### Décision FB déjà prise (roadmap, 2026-10-16)

« Conservation : la saison en cours et l'année suivante, puis effacement ;
effacement à la demande à tout moment (remplace la durée `[Prop]` de l'ADR
0001). » Le lot 11 en est l'application locale (drift) ; le même cas d'usage
devra exister côté Firestore en FB3 / FB8 (§ 9).

## 2. Décisions de conception

### 2.1 Groupes (11a, sans migration)

1. **Création, renommage, suppression** : feature `manage_groups`
   (`CreateGroup`, `RenameGroup`, `DeleteGroup`). Un groupe appartient à une
   saison **ouverte** et à un public (immuable après création). Le **nom est
   unique dans la saison**, comparé sans casse ni espaces de bord
   (`InvariantCode.groupNameTaken`). Pas de colonne ni d'index : la règle est
   dans le cas d'usage.
2. **Suppression** : refusée si le groupe a un membre à la date du jour
   (`groupNotEmpty`) ou une séance saisie (`groupHasRecords`) ; sinon suppression
   logique (aucune donnée personnelle ne s'y attache). Pas d'« archivage » de
   groupe : un groupe qui a servi reste, vide, dans sa saison et disparaît de
   l'écran quand la saison est close.
3. **Choix du groupe à l'inscription et au changement de public** : règle pure
   `chooseGroup` (`entities/group/domain`) : un groupe demandé est accepté s'il
   est de la bonne saison, du bon public et ouvert ; sans demande, un seul
   candidat est pris, **plusieurs candidats** lèvent
   `groupChoiceRequired` (l'interface a alors affiché un sélecteur) ; aucun
   candidat crée le groupe comme aujourd'hui. `EnrollStudent` et `ChangeAudience`
   reçoivent `groupId` / `destinationGroupId` facultatif. Un seul groupe par
   public reste donc le **parcours sans clic de plus** (comportement actuel
   inchangé).
4. **Déplacer un élève** : cas d'usage `MoveStudent(studentId, toGroupId, on)`,
   même saison **et même public** (le public suit l'historique de l'élève ; en
   changer reste `ChangeAudience`). Algorithme (une unité de travail) :
   - l'élève a une appartenance **ouverte** dans le groupe d'origine, sinon
     `membershipNotOpen` ; destination ≠ origine ; pas déjà membre de la
     destination (`membershipAlreadyOpen`) ;
   - `on` est **strictement postérieur** au début de l'appartenance ouverte et au
     **dernier jour où l'élève a été présent** dans une séance du groupe
     d'origine (`moveBeforeLastPresence`) : on ne réécrit pas une séance déjà
     saisie ; `on` ≤ fin de la saison ;
   - `origin.release(to: on − 1 jour)` puis `destination.admit(from: on)` : les
     deux méthodes existent déjà. La période d'origine reste intacte jusqu'à la
     veille, celle de destination commence à `on`, sans chevauchement.
5. **Historique conservé, par construction** : passages et acquis sont par
   **élève** ; les présences sont par **séance** (et la séance par groupe). Rien
   n'est copié ni réécrit. La grille et l'assiduité du groupe d'origine
   continuent de compter l'élève sur les séances antérieures à `on` (parce
   que `membersOn(date)` lit les périodes) ; ils cessent de le compter ensuite.
   **À verrouiller par scénario** : `GroupAttendance.possible` doit utiliser les
   membres **à la date de chaque séance**, pas ceux du jour (vérification du code
   au démarrage de 11a ; si ce n'est pas le cas, correction dans le même lot,
   test rouge d'abord).
6. **Interface** : sur la carte de groupe, menu ⋮ (renommer, supprimer s'il est
   vide) ; bouton « Nouveau groupe » (nom + public) à côté de « Ajouter un
   élève » ; sur la fiche élève, action « Changer de groupe » (feuille basse :
   groupes du même public et de la même saison, date d'effet proposée au jour
   courant) ; sélecteur de groupe dans le formulaire d'inscription **seulement**
   quand le public a plusieurs groupes. Aucune écriture dans la vue élève.

### 2.2 Clôture de saison (11b domaine, 11c écran)

**Parcours** (assistant `/more/seasons/:seasonId/close`, hors cadre de navigation
comme la présentation, pour éviter qu'un geste quitte l'assistant à mi-chemin) :

1. **Récapitulatif** : saison, période, nombre de séances, de présences, d'élèves
   par public ; avertissement si la date du jour précède la fin de la saison
   (clôture anticipée : la fin est ramenée à ce jour).
2. **Sauvegarde proposée** : bouton « Exporter une sauvegarde » (réutilise
   `ExportBackup` via le bloc de la page Sauvegarde, composé par la page), état
   « Sauvegarde du jour faite » lu du marqueur d'export. **Proposée, non
   bloquante** (U11-9) ; le texte dit en clair que ce fichier contient les
   prénoms des élèves qui vont être effacés, qu'il est à garder en lieu sûr puis
   à supprimer, et que l'importer sur un club vide (un autre appareil) les
   rétablirait.
3. **Choix par élève** : liste des élèves de la saison, un interrupteur
   « Reconduire / Effacer » par ligne, deux boutons en haut « Tout reconduire »
   et « Tout effacer ». Proposition **déterministe** (règle pure
   `proposeClosure`, § 2.2.3), motif écrit sur la ligne (« Absent de toute
   séance cette saison », « Inscrit avant cette saison : conservation limitée à
   la saison suivante », « Reconduit »).
4. **Options** : « Préparer la saison suivante » (coché par défaut : reconduit
   les groupes sous le même nom et y replace les élèves reconduits) ;
   « Supprimer les séances planifiées postérieures à la clôture » (coché, avec
   leur nombre).
5. **Confirmation** : boîte « Effacer définitivement N élèves ? Cette action est
   irréversible. Les résultats de la saison sont conservés sans aucun nom. » avec
   un bouton rouge-d'accent désactivé tant qu'une case « J'ai compris » n'est pas
   cochée (couleur : rôle d'accent, ADR 0010 ; le bouton ne dit pas « Supprimer »
   seul mais « Effacer N élèves et clore »). Si N = 0, pas de boîte rouge, un
   simple « Clore la saison ».
6. **Résultat** : « Saison 2025-2026 close : N élèves effacés, M reconduits, K
   groupes préparés », sans aucun prénom (ils n'existent plus), et proposition
   d'exporter une sauvegarde **après** clôture (fichier sans les élèves effacés).

#### 2.2.1 Cas d'usage

- `PrepareSeasonClosure(seasonId, today)` → `ClosurePlan` : saison, chiffres de
  l'archive à venir (aperçu), une `ClosureProposal` par élève de la saison
  (`StudentId`, prénom, `ClosureChoice` proposé, `ClosureReason`).
- `CloseSeason(seasonId, closedOn, erase: Set<StudentId>, prepareNext, dropPlanned)`
  → `ClosureResult` (compteurs seulement). **Une seule `UnitOfWork`**, tout ou
  rien, dans cet ordre : (1) calculer l'archive à partir des données **complètes** ;
  (2) l'enregistrer ; (3) poser `Season.closedOn` et ramener `endDate` à
  `closedOn` si elle est postérieure ; (4) effacer physiquement chaque élève de
  `erase` ; (5) si `prepareNext` : créer la saison suivante, ses groupes
  homonymes, clore les appartenances ouvertes des élèves **reconduits** à
  `closedOn` et les admettre dans le groupe homonyme à partir du début de la
  saison suivante ; (6) si `dropPlanned` : supprimer logiquement les séances
  planifiées de la saison postérieures à `closedOn`.
- Validations : saison inconnue (`NotFound`), déjà close (`seasonAlreadyClosed`),
  `closedOn` ≤ début de saison (`invalidPeriod`), `erase` ⊄ élèves de la saison
  (`NotFound`). Un échec à n'importe quelle étape annule tout, **y compris
  l'archive** (test de contrat sur les deux implémentations, patron de
  `UnitOfWork`).
- **Saison suivante** : début = le plus tardif du 1er septembre suivant la
  clôture et du lendemain de `closedOn` ; fin = 31 août de l'année scolaire
  correspondante ; libellé « AAAA-AAAA+1 » ; si une saison qui la recouvre existe
  déjà, elle est réutilisée (règle de `EnrollStudent._seasonOf`, extraite en
  `entities/season/domain` pour ne pas la dupliquer).
- **`Season.isOpenOn(date)`** = non close et `contains(date)`. Les cinq sites
  « saisons en cours » et les deux sites « travail nouveau » l'utilisent ;
  `BackupRules` garde `contains` (données historiques). Une saison close refuse
  toute nouvelle saisie, planification ou inscription (`seasonClosed`).

#### 2.2.2 Archive agrégée, non nominative

Aucune ligne de l'archive ne porte d'identifiant d'élève, de prénom, de date de
séance individuelle ni de nom de groupe. Contenu, **par public** (enfants /
adultes) et par saison :

| Niveau | Champs | Règle |
|---|---|---|
| Public | séances données, présences, présences possibles, élèves distincts présents, passages | toujours conservé |
| Exercice (bloc, numéro) | élèves distincts, passages, billes empochées, billes tentées | **seulement si au moins 3 élèves distincts** (`minCohortForFigures = 3`, constante du domaine, pas un réglage) |

Le seuil de 3 évite qu'une ligne « 1 élève adulte, 4 passages » décrive en fait
une personne reconnaissable. Il n'y a pas de ventilation par groupe (un groupe
de deux enfants serait lui aussi trop petit). Les chiffres d'archive servent aux
écrans « Saisons passées » (§ 2.4) et, plus tard, à comparer d'une saison à
l'autre ; ils ne servent **jamais** à recalculer un parcours d'élève.

Les `SessionRecord` (date, groupe, public, séance du catalogue) **restent** après
l'effacement, sans présences : ils ne nomment personne, et l'historique des
séances et les chiffres « séances données » continuent de fonctionner.
`SessionRecord.present` est alors vide pour les élèves effacés (contrat existant
de `eraseStudent`).

#### 2.2.3 Proposition d'effacement (règle pure `proposeClosure`)

Pour chaque élève ayant une appartenance dans un groupe de la saison, **et**
pour chaque élève que plus rien ne place dans une saison ouverte (aucune
appartenance ouverte dans un groupe d'une saison non close : élève jamais
placé, ou gardé par une clôture sans saison suivante) — sans quoi ses données
ne seraient jamais proposées à l'effacement (`closureCandidates`, § 12.1) :

| Condition (dans cet ordre) | Choix proposé | Motif |
|---|---|---|
| aucune présence dans une séance de la saison | Effacer | `inactive` |
| première inscription (`audienceHistory.first.effectiveFrom`) antérieure au début de la saison | Effacer | `retentionExpired` (décision FB 8 : saison en cours et suivante) |
| sinon | Reconduire | `carriedOver` |

L'animateur peut tout inverser ligne par ligne : la règle **propose**, elle ne
décide pas (mêmes principes que le bilan de maturité, ADR 0003). Un élève passé
en « Reconduire » alors que sa conservation est échue affiche le motif en clair,
sans bloquer (U11-7).

### 2.3 Rien d'autre n'est conservé de l'identité

Pas de « journal d'effacement » nominatif, pas de liste d'identifiants effacés
(même pseudonymes : un identifiant qu'on garde permet de relier un fichier de
sauvegarde ancien à une personne). Le seul compte rendu est un **nombre**,
affiché à l'écran de résultat et non stocké. Conséquence assumée : sur un club
vide (autre appareil), rien n'empêche l'import d'un ancien fichier de rétablir
ces élèves ; sur un club qui a clos la saison, l'import est refusé
(`backupReopensClosedSeason`, U11-12, § 12.1).

### 2.4 Écran « Saisons passées »

Entrée « Saisons » sous « Plus » (à côté de Sauvegarde et Réglages, lot U6) :
liste des saisons closes (libellé, période, date de clôture), détail par public
avec les chiffres de l'archive, tableau des exercices (lignes sous le seuil
absentes, avec la phrase « Les exercices pratiqués par moins de 3 élèves ne sont
pas détaillés »). Lecture seule, aucun prénom. Page `pages/season_archive`,
feature `track_seasons`.

## 3. Points `[U]` : défaut retenu

| # | Question | Défaut retenu |
|---|---|---|
| U11-1 | Plusieurs groupes par public et par saison, nom unique dans la saison | **oui** |
| U11-2 | Inscription / changement de public : sélecteur de groupe seulement s'il y en a plusieurs pour le public | **oui** |
| U11-3 | Déplacement : même saison et même public ; date d'effet proposée au jour courant, strictement après le début de l'appartenance et la dernière présence dans l'ancien groupe | **oui** |
| U11-4 | Un groupe ne se supprime que vide et sans séance saisie ; il se renomme librement | **oui** |
| U11-5 | Le déplacement ne copie ni ne réécrit rien (historique de présence par séance, parcours par élève) | **oui** (par construction) |
| U11-6 | Archive : agrégats par public ; lignes par exercice seulement à partir de 3 élèves distincts ; aucun groupe, aucune date de séance, aucun identifiant | **oui** |
| U11-7 | Proposition d'effacement : inactifs de la saison et inscrits avant la saison (conservation = saison en cours + suivante, décision FB 8) ; modifiable ligne par ligne | **oui** |
| U11-8 | « Préparer la saison suivante » (groupes homonymes, élèves reconduits replacés) coché par défaut | **oui** |
| U11-9 | Export de sauvegarde **proposé, non bloquant** avant la clôture, avec avertissement sur le contenu nominatif | **oui** (alternative : bloquant tant qu'aucune sauvegarde du jour) |
| U11-10 | Clôture possible à tout moment après le début de la saison ; anticipée = fin ramenée au jour de clôture ; irréversible (hors import d'un ancien fichier) | **oui** |
| U11-11 | Séances planifiées postérieures à la clôture supprimées (case cochée, nombre affiché) | **oui** |
| U11-12 | **Révisé (§ 12.1)** : importer un fichier qui donne pour ouverte une saison close dans ce club est **refusé** (`backupReopensClosedSeason`) ; sur un club vide, l'import rétablit les élèves effacés (limite assumée). Ancien défaut : l'import rouvrait la saison et supprimait son archive | **oui**, documenté sur l'écran de sauvegarde et dans l'assistant |
| U11-13 | Aucun journal d'effacement nominatif ni liste d'identifiants effacés | **oui** |
| U11-14 | Entrée « Saisons » sous « Plus » | **oui** |
| U11-15 | Carte discrète « Clôturer la saison 2025-2026 » sur « Aujourd'hui » quand une saison dont la fin est passée n'est pas close | **oui** (U7) |

## 4. Persistance : schéma v9

Migration **additive**, `from8To9`, aucune donnée existante transformée :

```dart
from8To9: (m, schema) async {
  await m.addColumn(schema.seasons, schema.seasons.closedOn); // nullable
  await m.createTable(schema.seasonArchiveAudiences);
  await m.createTable(schema.seasonArchiveExercises);
},
```

- `seasons.closed_on` : texte ISO nullable (`IsoDateTimeConverter`), jour de
  clôture. Nul = ouverte.
- `season_archive_audiences` : `season_id`, `audience`, `session_count`,
  `presence_count`, `possible_presence_count`, `student_count`,
  `attempt_count` ; clé primaire (`season_id`, `audience`). Pas de
  `AuditColumns` : agrégat calculé une fois, remplacé en bloc par saison.
- `season_archive_exercises` : `season_id`, `audience`, `block_id`,
  `exercise_number`, `student_count`, `attempt_count`, `potted`, `total` ; clé
  primaire (`season_id`, `audience`, `block_id`, `exercise_number`). Pas de clé
  étrangère vers le catalogue (asset) ; `student_count >= 3` imposé par la
  construction de l'agrégat **et** vérifié à l'import.
- Port `SeasonArchiveRepository` (`entities/season/domain`) : `save(SeasonArchive)`
  (remplace tout l'archive de la saison), `bySeason`, `all`, `delete(seasonId)`.
  Implémentations en mémoire et drift, **suite de contrat commune**.
- Procédure : monter `currentSchemaVersion` à 9, tables dans `tables.dart`,
  `dart run drift_dev make-migrations` (instantané `drift_schema_v9.json`,
  `app_database.steps.dart`, `schema_v9.dart` ; **supprimer le stub
  `test/drift/app_database/migration_test.dart`** généré), puis `build_runner`.
  Aucun fichier généré édité à la main.
- Test de migration v8 → v9 en SQL brut sur la base intermédiaire (une saison
  existante garde `closed_on` nul ; deux tables vides ; instantané v9).
- `physical_erasure_test.dart` étendu : après `CloseSeason`, aucune table n'a de
  ligne portant un des identifiants effacés, **y compris `season_archive_*`**
  (qui n'en portent aucun par construction) et les lignes supprimées
  logiquement.

L'ADR 0016 réservait « schéma v9, sauvegarde v4 » à un éventuel
`SessionRecord.plannedSessionId`, **écarté** : ces numéros sont pris par ce lot ;
si le lien explicite revient, il prendra v11 / sauvegarde v5 (la v10 est prise par le lot 10b).

## 5. Sauvegarde : format 4

Patron des ADR 0012 et 0013 :

- `BackupCodec.currentVersion = 4`, `supportedVersions = {1, 2, 3, 4}`.
- `data.seasons[].closedOn` : jour ISO, **facultatif dans les quatre formats**
  (absent = ouverte). Contrôles : pas avant `startDate`, pas d'heure.
- `data.seasonArchives` : liste d'objets `{ seasonId, audiences: [...],
  exercises: [...] }`, **obligatoire (éventuellement vide) dans un fichier 4,
  refusée (`backupInvalid`) dans un fichier 1 à 3**. Une application plus ancienne
  refuse un fichier 4 (`backupVersionUnsupported`) plutôt que de perdre les
  clôtures en silence.
- Contrôles avant toute écriture : `seasonId` présent dans le fichier **et**
  `closedOn` non nul (`backupInconsistent`) ; un seul bloc par saison ;
  compteurs entiers ≥ 0, `presenceCount ≤ possiblePresenceCount`, `potted ≤ total` ;
  bloc d'exercice inconnu (`backupUnknownBlock`) ou numéro absent du bloc
  (`backupInconsistent`) ; ligne d'exercice avec moins de 3 élèves (`backupInvalid`).
- Import (même `UnitOfWork`) : l'archive d'une saison du fichier **remplace**
  celle en place (idempotent) ; une saison du fichier **sans** `closedOn` qui
  est close en place est **refusée** (`backupReopensClosedSeason`, avant toute
  écriture, U11-12 révisé au § 12.1). Un fichier 1 à 3 ne touche pas aux archives
  des saisons en place.
- `BackupSnapshot.seasonArchives` (liste, obligatoire à la construction : un
  oubli ne compile pas, patron `blockAcquisitions`) ; `Season.closedOn` dans le
  codec ; `ImportSummary.seasonArchives`.
- Les groupes, appartenances et séances voyagent déjà (format 1) : le
  déplacement d'un élève et les groupes multiples **ne changent pas** le format.

## 6. Placement FSD

| Pièce | Couche | Remarque |
|---|---|---|
| `Season.closedOn`, `isOpenOn`, `SeasonArchive` (+ lignes), `nextSeasonAfter`, `SeasonArchiveRepository` | `entities/season` | `nextSeasonAfter` extrait de `EnrollStudent._seasonOf` |
| `chooseGroup`, `normalizedGroupName`, `Group.rename` | `entities/group` | règles pures |
| `manage_groups` : `CreateGroup`, `RenameGroup`, `DeleteGroup`, `MoveStudent` + blocs | `features` | n'importe que des entités |
| `close_season` : `PrepareSeasonClosure`, `CloseSeason`, `proposeClosure`, `buildArchive`, bloc de l'assistant | `features` | voir le point « effacement » ci-dessous |
| `track_seasons` : `ListSeasonArchives`, bloc | `features` | lecture seule |
| `pages/season_closure`, `pages/season_archive`, retouches `pages/students`, `pages/student_sheet`, `pages/home` | `pages` | **la page compose** `ExportBackup` (feature `backup_data`) et l'assistant : une feature n'importe pas une autre |
| `shared/ui` : `ClosureChoiceTile` (interrupteur à libellé accessible), `ArchiveFigureTable` | `shared` | + cas d'usage Widgetbook |

**Point d'architecture à trancher à la relecture `architecte-fsd`** : `CloseSeason`
efface des élèves comme `EraseStudent` (feature `manage_students`), et deux
features ne s'importent pas. Option retenue par défaut : `CloseSeason` liste
elle-même les mêmes dépôts (sept `eraseStudent` / `erase`) ; le risque est
qu'un nouveau dépôt nominatif soit ajouté à l'un et pas à l'autre. Parade : un
test **de parité** (`erasure_parity_test`) qui, pour chaque dépôt exposant
`eraseStudent`, vérifie que les **deux** cas d'usage le vident, et le test
physique sur toutes les tables drift à colonne `student_id`. Alternative
écartée tant que l'architecte ne l'impose pas : extraire un service d'effacement
dans une couche commune, ce qui ouvre une nouvelle couche pour sept lignes.

## 7. Scénarios BDD (à écrire d'abord, un `.feature` chacun)

Locale `en`, « aujourd'hui » = lundi 12 octobre 2026 (`UiWorld.today`) ;
domaine par `TrackingWorld` (assets préchargés sous `tester.runAsync`).

### `groups_management.feature` (11a)

1. Créer un second groupe d'enfants « Mercredi » dans la saison.
2. Un nom déjà pris dans la saison (casse et espaces ignorés) est refusé.
3. Renommer un groupe ; le nouveau nom apparaît sur la carte et dans la grille.
4. Un groupe avec membres ne se supprime pas ; vide et sans séance, il se supprime ;
   avec une séance saisie, il ne se supprime pas.
5. Inscrire un élève : un seul groupe pour le public, aucun sélecteur ;
   deux groupes, le sélecteur apparaît et le choix est respecté.
6. Changement de public avec deux groupes adultes : le groupe de destination
   est demandé.
7. Le nom du groupe est affiché partout où deux groupes ont le même public
   (Aujourd'hui, planification, marqueur de parcours, saisie).

### `student_move.feature` (11a)

8. Déplacer un élève : il quitte le groupe d'origine (carte, grille) et rejoint
   la destination dès la date d'effet.
9. Son parcours (cases, validés, alertes, acquittements, bilans) est identique avant
   et après.
10. L'assiduité du groupe d'origine compte encore ses présences passées ; la
    destination ne compte que les séances à partir de la date d'effet.
11. Une date d'effet antérieure à sa dernière présence dans l'ancien groupe est
    refusée.
12. Déplacer vers un groupe d'un autre public est refusé (le message renvoie
    au changement de public).
13. Une saisie du même jour que le déplacement : l'élève est proposé dans le
    groupe où il est membre à la date de la saisie.
14. Déplacer vers le groupe où il est déjà membre est refusé.

### `season_closure.feature` (11b, 11c)

15. L'assistant propose d'abord l'export de sauvegarde ; l'état « sauvegarde du
    jour faite » se lit après l'export.
16. Propositions : un élève sans présence → « Effacer » ; un élève inscrit avant
    la saison → « Effacer » avec son motif ; les autres → « Reconduire ».
17. Chaque proposition est modifiable ; les boutons « Tout reconduire » et
    « Tout effacer » s'appliquent à toute la liste.
18. Confirmation : le bouton reste désactivé tant que « J'ai compris » n'est pas
    coché ; le nombre d'élèves effacés est écrit dans la boîte.
19. Après la clôture : les élèves effacés n'existent plus nulle part (liste,
    fiche inaccessible, grille, présences des séances), aucun prénom n'apparaît
    dans « Saisons passées ».
20. Les élèves reconduits gardent leur parcours entier et sont dans le groupe
    homonyme de la saison suivante.
21. L'archive donne les séances, présences et passages par public ; un exercice
    pratiqué par 2 élèves n'a pas de ligne, par 3 il en a une.
22. Une saison close refuse une nouvelle saisie, planification ou inscription
    (message dédié) ; une inscription crée la saison suivante.
23. Une clôture anticipée ramène la fin de saison au jour de clôture ; les
    séances planifiées postérieures sont supprimées.
24. Échec simulé d'une étape : rien n'est effacé, aucune archive n'est écrite,
    la saison reste ouverte.
25. Sauvegarde : export puis import (aller-retour) conservent clôture et archive ;
    import d'un fichier antérieur : élèves rétablis, saison rouverte, archive
    supprimée.
26. « Aujourd'hui » propose de clôturer une saison terminée ; la carte disparaît
    après la clôture.

## 8. Tests unitaires et garde-fous (TDD, rouge constaté)

Un test **rouge avant** chaque règle, et le dire honnêtement dans le compte rendu
de livraison. Les tests écrits **après coup** (par exemple pour combler
`proposeClosure` si une règle est découverte à l'écran) sont validés par
**mutation** (inverser un seuil, retirer une étape, vérifier que le test casse).

| Zone | Tests |
|---|---|
| `chooseGroup` | demandé accepté / refusé (autre saison, autre public, close) ; un candidat ; plusieurs sans demande ; aucun |
| `CreateGroup` / `RenameGroup` / `DeleteGroup` | unicité insensible à la casse, saison close refusée, suppression refusée (membres, séances) |
| `MoveStudent` | cas nominal ; origine non ouverte ; même groupe ; déjà membre ; autre public ; date avant début, avant dernière présence ; tout ou rien |
| Assiduité après déplacement | `possible` par séance avec les membres **à la date de la séance** (test de non-régression de l'existant) |
| `proposeClosure` | tableau § 2.2.3, y compris l'ordre des conditions (un inactif inscrit avant la saison porte le motif `inactive`) |
| `buildArchive` | agrégats par public, seuil de 3 (2 / 3 / 4 élèves), billes empochées / tentées, élève présent sans passage, passage d'un élève hors saison ignoré, aucun identifiant dans le résultat |
| `CloseSeason` | ordre (archive calculée **avant** l'effacement : test qui échouerait si les deux étapes étaient inversées) ; effacement physique ; reconduction ; saison suivante réutilisée si elle existe ; clôture anticipée ; séances planifiées ; déjà close ; tout ou rien sur les deux implémentations |
| `Season.isOpenOn` | close, hors période, ouverte ; les sept sites |
| Contrat | `SeasonArchiveRepository` (in-memory / drift) ; remplacement par saison ; suppression |
| Migration | v8 → v9 en SQL brut ; instantané v9 |
| Effacement | `physical_erasure_test` étendu ; `erasure_parity_test` entre `EraseStudent` et `CloseSeason` |
| Sauvegarde | codec 1 / 2 / 3 / 4 ; clé refusée dans 1 à 3, obligatoire dans 4 ; contrôles du § 5 ; import atomique (aucune écriture partielle) ; réouverture par import ancien ; `ImportSummary` |
| Architecture | `close_season` et `manage_groups` n'importent aucune autre feature ; la page de clôture est la seule à composer `backup_data` |
| i18n | clés fr et en identiques (assistant, erreurs `groupNameTaken`, `groupNotEmpty`, `groupHasRecords`, `groupChoiceRequired`, `moveBeforeLastPresence`, `seasonClosed`, `seasonAlreadyClosed`) |
| Accessibilité | l'interrupteur « Reconduire / Effacer » porte le prénom dans son nom accessible ; la boîte de confirmation annonce le nombre ; cibles de 48 dp |
| Widgetbook | `ClosureChoiceTile`, `ArchiveFigureTable` |

Fin de lot : `scripts/check.sh --full` vert, `dart run scripts/validate_seances.dart`
inchangé, couverture lignes au moins égale à l'existante, aucun `TODO`, `skip` ou
`solo`. Relectures dans des contextes séparés : `architecte-fsd` (placement, point
du § 6), `testeur-bdd` (scénarios 1 à 26, mutation), et une relecture dédiée à
la **minimisation** (aucun prénom ni identifiant dans l'archive, les journaux de
test, les libellés d'erreur et la sortie `toString` des modèles d'archive).

## 9. Impacts sur les autres lots

| Lot | Impact |
|---|---|
| **U7 Aujourd'hui** (livré) | carte « Clôturer la saison » (U11-15) ; avec deux groupes du même public, la carte « prochaine séance » et les lignes d'alertes de groupe **nomment le groupe** (scénario 7) ; `ListPlannableGroups` ne propose que les saisons ouvertes |
| **U8 Catalogue / Préparer** (livré) | le marqueur de parcours ✓ / ▶ / ○ est déjà par groupe (`ListJourneyGroups`) ; avec deux groupes de même public, il en liste deux, libellés par leur nom ; saisons closes exclues |
| **U9 Fiche et vue de groupe** (livré) | la fiche gagne « Changer de groupe » et affiche le nom du groupe courant ; la grille et l'assiduité lisent les membres **à la date** (verrouillé par le scénario 10) ; une fiche d'élève effacé devient une route introuvable (`NotFound`), déjà gérée ; les alertes de groupe suivent les membres du jour : un déplacement les déplace avec l'élève |
| **D1 / ADR 0016** | l'identité (groupe, jour, séance) distingue enfin deux groupes qui jouent la même séance le même jour ; ADR 0016 : la mention « schéma v9, sauvegarde v4 » devient obsolète (§ 4) ; une saisie d'un groupe supprimé ne peut pas exister (suppression refusée si séances) |
| **U6 Navigation** | « Plus » : trois entrées (Sauvegarde, Réglages, Saisons) |
| **Lot 9 Réglages (ADR 0012)** | aucun réglage nouveau (le seuil de 3 et la règle de conservation sont des règles, pas des paramètres, pour ne pas laisser régler la protection des mineurs à la baisse) |
| **Lot 15 hors ligne** | la nouvelle table et la nouvelle route sont dans le build ; le précache est recalculé par `scripts/pwa.dart` ; l'assistant fonctionne hors ligne (aucun réseau) |
| **Lot 10b (reporté)** | si la note de jeu (texte libre sur des mineurs) est un jour livrée, elle est effacée avec l'élève et **absente de l'archive** ; à écrire dans son ADR |
| **FB3 / FB8 (Firestore)** | `CloseSeason` devient un traitement par lot sur Firestore (sans Cloud Functions : Spark) lancé depuis l'application ; l'archive agrégée est un document par (club, saison) ; l'atomicité n'existe plus (limite de 500 écritures par lot) : prévoir un état « clôture en cours » reprenable ; le format de sauvegarde 4 reste le format de portabilité (FB7) |
| **Documentation** | `architecture.md` (entités, features, règle des sept sites), `testing.md` (parité d'effacement), ADR 0001 (la conservation `[Prop]` est remplacée par la décision FB 8 et l'ADR 0019), `roadmap.md` (lot 11 en trois sous-lots 11a / 11b / 11c, puis livré), README des ADR |

## 10. Risques et parades

| Risque | Parade |
|---|---|
| Effacement par erreur d'élèves à conserver | proposition modifiable, nombre en toutes lettres dans la confirmation, case « J'ai compris », sauvegarde proposée en tête d'assistant, tout ou rien |
| L'animateur croit que l'archive est effacée avec les élèves, ou l'inverse | le texte de l'assistant et de l'écran « Saisons passées » dit : « résultats conservés sans aucun nom » |
| Fichier de sauvegarde pré-clôture qui contient encore les élèves | avertissement dans l'assistant, sur l'écran de sauvegarde et dans l'écran de résultat ; la suppression du fichier reste à l'animateur (ADR 0001) |
| Ré-identification par recoupement d'agrégats | seuil de 3, pas de groupe, pas de date de séance, tests de non-présence d'identifiant |
| `CloseSeason` oublie un futur dépôt nominatif | `CloseSeason` n'a plus de liste : elle efface par le port `StudentEraser`, relié dans `app` à `EraseStudent.eraseRecords` ; test de parité du câblage + test physique sur toutes les tables à `student_id` |
| Une saison close reste utilisable par un chemin oublié | `isOpenOn` aux sept sites + scénario 22 par site |
| Élèves « sans groupe » au 1er septembre sans clôture | carte « Clôturer » sur Aujourd'hui ; un élève sans groupe reste réaffectable par « Changer de groupe » depuis la saison ouverte (à couvrir au scénario 8 : origine = aucun groupe) |
| Clôture anticipée puis saisie d'une séance oubliée | refusée (`seasonClosed`) ; plus de recours par import d'un ancien fichier sur ce club (U11-12 révisé) |

## 11. Plan d'exécution

1. **11a Groupes** (aucune migration, aucun changement de sauvegarde) :
   vérifier l'assiduité par date (§ 2.1.5), `chooseGroup`, `manage_groups`,
   sélecteurs, « Changer de groupe », noms de groupe partout. BDD 1 à 14.
2. **11b Clôture, domaine** : `Season.closedOn` / `isOpenOn` aux sept sites, schéma
   v9, `SeasonArchiveRepository`, `buildArchive`, `proposeClosure`, `CloseSeason`,
   sauvegarde 4, import (réouverture). Scénarios domaine 16, 19 à 25.
3. **11c Clôture, écrans** : assistant, « Saisons passées », carte Aujourd'hui,
   Widgetbook, parcours web (Playwright, voir la mémoire du projet), `check.sh
   --full`, relectures séparées, mise à jour de la roadmap et des ADR.

Rien n'est committé tant que l'utilisateur ne le demande pas.

## 12. Écarts de livraison et résultats (2026-10-16)

**Résultat réel** : `scripts/check.sh --full` vert (5 304 tests BDD et
unitaires, couverture de lignes 98,4 % pour un seuil de 90 %, Widgetbook : 138
composants, 210 use cases, l10n : 872 clés identiques en fr et en). Rien n'est
committé.

**Écarts par rapport au plan** (aucun ne change un défaut `[U]`) :

- **Routes** : `/seasons` (« Saisons passées », dans le cadre, sous « Plus ») et
  `/seasons/:seasonId/close` (assistant, hors cadre), à côté de `/backup` et
  `/settings`, et non `/more/seasons/…`.
- **Assistant** : une seule page défilante en cinq sections numérotées (pas un
  assistant à étapes) ; l'état « Sauvegarde faite » est celui de l'export de la
  séance d'écran, pas le marqueur d'export. L'export web télécharge le fichier
  mais `file_picker` ne rend pas d'emplacement : l'écran dit alors « Export
  annulé » (comportement de l'écran Sauvegarde avant ce lot, non corrigé ici).
- **Choix du groupe** : le sélecteur de l'inscription et du changement de public
  apparaît **après** `groupChoiceRequired` (réactif), pas d'emblée ; avec un seul
  groupe, aucun clic de plus.
- **`MoveStudent`** place aussi un élève **sans groupe** (appartenance ouverte
  dans une saison close, ou départ antérieur) : le plan § 10 le demandait, le § 2.1
  l'oubliait. Le dernier jour « pris » est la fin de sa dernière appartenance.
- **Saison suivante** : `nextSeasonAfter` commence le lendemain de la fin de la
  saison close (ramenée au jour de clôture si anticipée), au 1er septembre si ce
  lendemain tombe en juillet ou en août ; une clôture anticipée dans l'année
  scolaire donne un libellé « 2026-2027 (2) ». Les élèves reconduits rejoignent la
  saison suivante **dès son premier jour** (même si la clôture a lieu plus tard ;
  l'ancienne appartenance finit la veille) : trouvé au parcours web, test rouge
  écrit puis corrigé.
- **Effectif d'une saison pas encore commencée** : `GetClubOverview` et
  `GetGroupOverview` (qui reçoit `SeasonRepository`) lisent l'effectif au premier
  jour de la saison ; sans cela, les élèves reconduits d'une clôture de juin
  apparaîtraient « sans groupe » tout l'été.
- **Archive vide** : une saison sans séance ne laisse aucune ligne
  (`bySeason` rend `null`) ; `ListSeasonArchives` la liste « sans chiffres ».
- **`Season.closedOn`** : jamais avant le début ; peut suivre la fin. Les séances
  planifiées d'une saison close ne sont bornées que par son début à l'import
  (elles survivent à la clôture si la case est décochée).
- **Ajouts** : `GetClosableSeason`, `ClosableSeasonSection` (carte composée par
  la couche app), `SectionCard.trailing`, `GroupChoicePicker`,
  `ClosureChoiceTile`, `ArchiveFigureTable`, message de refus propre aux codes
  `membershipNotOpen`, `membershipAlreadyOpen` et `audienceMismatch` (ils tombaient
  sur le message générique).
- **Limite de bord** : une inscription le jour même d'une clôture anticipée
  crée la saison suivante qui commence le lendemain (l'élève est inscrit dès
  aujourd'hui, mais aucune saisie n'est possible avant demain).

**Rouges constatés (honnêtement)** : les tests unitaires des règles (`chooseGroup`,
`Group.rename`, `CreateGroup`, `RenameGroup`, `DeleteGroup`, `MoveStudent`,
`Season.isOpenOn`, `nextSeasonAfter`, `buildArchive`, `proposeClosure`,
`CloseSeason`, codec 4, dépôts d'archive, migration v8 → v9, blocs) ont été écrits
**avant** le code ; leur rouge est constaté (échec de compilation pour une API
absente, ou assertion pour les six sites `isOpenOn` des listes, de
`OpenSession` et de `PlanSession`). **Les scénarios BDD n'ont pas été vus rouges à
l'exécution** : leurs steps ont été écrits après le code du domaine, pas avant ;
ils ont été validés par mutation (ci-dessous).

**Mutation** (pour tout test écrit après coup) : 24 mutations appliquées une à une
puis annulées, **toutes tuées** (une, `MoveStudentDialog` ignorant le groupe
choisi, a d'abord survécu : le scénario « Among several groups… » a été ajouté).
Inversion de l'ordre des conditions de `proposeClosure`, seuil d'archive
décalé de un, effacement avant le calcul de l'archive, déplacement le jour de la
dernière présence, assiduité calculée sur l'effectif du jour, `isOpenOn` sans la
clôture, suppression d'un groupe qui a des séances, import qui ne rouvre pas, libellés
inversés de `ClosureChoiceTile`, bouton de confirmation sans case « J'ai compris »,
séance planifiée du jour de la clôture supprimée, `chooseGroup` qui prend le premier
de plusieurs, `closedOn` perdu par le dépôt drift, carte d'accueil sans action,
groupe choisi non envoyé (inscription, changement de public), effectif du jour
seul pour une saison préparée, libellé de saison répété, saison close réutilisée à
l'inscription, colonne des billes inversée, sélecteur de groupe sans effet,
archive d'une saison ouverte acceptée à l'import, groupe actuel proposé comme
destination.

**Parcours web (Playwright, build release servi en local, captures hors dépôt)** :
1280 × 800 et 390 × 844, club vide créé de zéro (schéma v9 à la création) : inscription de
cinq élèves, « Nouveau groupe », « Changer de groupe » (Eve → Mercredi), choix du
groupe à l'inscription quand deux groupes conviennent, renommage, suppression
refusée (groupe avec élèves) puis acceptée (groupe vide), séance saisie avec trois
présents, saut de date au 15 septembre 2027 (horloge du navigateur) : carte
« Clôturer la saison », assistant (proposition, interrupteurs au nom accessible
« Eve : Effacer », bouton de la boîte désactivé tant que « J'ai compris » n'est
pas cochée), compte rendu sans prénom, « Saisons passées » (1 séance, 3 présences
sur 4 possibles, aucun nom), élèves reconduits dans le groupe de la saison suivante,
carte disparue. Une base du navigateur peuplée par la version précédente (schéma v8) s'est
ouverte sans erreur dans le nouveau build (migration v8 → v9 en conditions
réelles, premier passage). Trois défauts trouvés et corrigés grâce au parcours :
élèves « sans groupe » après une clôture tardive, « 1 séances » au singulier,
badge de public répété dans l'archive. Non vérifié : lecteur d'écran réel (seul
l'arbre d'accessibilité de Playwright est lu), hors ligne avec service worker
estampillé, import d'un fichier d'avant la clôture dans le navigateur (couvert
par le contrat et le BDD).

**Relectures dans des contextes séparés (`architecte-fsd`, `testeur-bdd`,
minimisation)** : **non faites** : cette séance n'avait aucun moyen de lancer un
sous-agent. Les garde-fous automatiques couvrent une partie : architecture FSD
(`tool/check_architecture.dart` vert), test de parité d'effacement, absence de
prénom ou d'identifiant dans l'archive (domaine, SQLite, JSON de sauvegarde), mutations ci-dessus.
Le point d'architecture du § 6 (deux cas d'usage d'effacement à parité) est
implémenté tel quel, **sans l'arbitrage de `architecte-fsd`**.

**Reste à faire** : confirmer ou corriger les quinze points `[U]` ; passer les trois
relectures séparées ; décider si l'export web doit dire « Sauvegarde faite »
(correction de `FilePickerBackupFiles` sur le web, hors lot) ; FB3 / FB8 (clôture
Firestore reprenable, § 9).

### 12.1 Corrections après relectures architecture et tests (2026-10-16)

Les relectures ont été faites ensuite, dans des contextes séparés ; leurs
remarques sont appliquées (rien n'est committé) :

- **Bloquant** : `DeleteGroup` refuse un groupe visé par une séance planifiée
  (`groupHasPlanned`, fr/en, scénario BDD) ; sinon la sauvegarde exportée
  contenait une séance planifiée vers un groupe absent et ne se réimportait plus.
- **Effacement des mineurs** : (1) `closureCandidates` ajoute aux propositions les
  élèves qu'aucune saison ouverte ne place (`CloseSeason` accepte aussi de les
  effacer) ; (2) l'import d'un fichier qui rouvrirait une saison close ici est
  refusé (`backupReopensClosedSeason`), le comparatif ne demande aucune donnée
  nominative ; reste hors de portée un club vide, documenté dans l'assistant ;
  (3) un public de moins de 3 élèves présents ne garde que son nombre de séances
  et d'élèves (invariant de `AudienceArchive`, donc aussi vérifié au décodage
  d'une sauvegarde 4 et à la lecture SQLite ; une archive déjà stockée avec
  des chiffres sous le seuil serait refusée à la lecture : le lot n'est pas
  livré).
- **Parité d'effacement** : port `StudentEraser` (`close_season/domain`), relié
  dans `lib/app/student_eraser.dart` à `EraseStudent.eraseRecords` ; la liste de
  dépôts de `CloseSeason` est supprimée.
- **Mineurs** : constante `AppRoutes.closeSegment` ; une clé ICU par phrase
  (`closureRecapLine`, `closureSummary`, `archiveExerciseLabel`) ; suffixe de nom
  de groupe et de libellé de saison calculé jusqu'à un nom libre
  (`firstFreeName`) ; « reconduits » ne compte plus les élèves déjà sortis de leur
  groupe ; règle `plannedAfterClosure` partagée entre l'aperçu et l'effet ;
  bornes de `isOpenOn` et clôture au lendemain du début testées (l'entité accepte
  le jour de début, `CloseSeason` exige le lendemain).
- **Non repris** : reformulation en français métier des codes dans les `.feature`
  (`keep`, `groupNotEmpty`…), jugée coûteuse (steps à renommer) ; une mutation
  par `.feature` écran à consigner ; relecture `architecte-fsd` du port
  `StudentEraser` (contexte séparé, à faire).
