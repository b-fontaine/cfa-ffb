# ADR 0007 — Lier séance planifiée, saisie des résultats et séance du catalogue

- Statut : **accepté et implémenté** (2026-10-14). Plan :
  `../seance-planifiee-plan.md`. Lot 6 de `../roadmap.md` ; réalise le lot L9
  de l'ADR 0004 et **remplace sa décision 10** (« pas de lien `SessionRecord`
  ↔ `Session` »).
- Contexte de livraison : application V1 non livrée, aucune compatibilité de
  données à préserver (schéma et sauvegarde modifiés directement).

## Contexte

Une séance planifiée (`Session`) n'a ni date ni groupe ; elle ne porte que son
titre, son public et, depuis l'ADR 0004, la séance du catalogue qu'elle suit.
« Lancer » ouvre la séance guidée, dont « Noter les résultats » redemande
groupe, date et présents à chaque première saisie. La séance saisie
(`SessionRecord`) ne garde que ses blocs principal et de rappel : ni la
planification ni l'historique ne disent quelle séance du catalogue a été
donnée. La boucle de saison (planifier → donner → noter → relire) est donc
coupée en deux endroits.

## Décision

1. *(Amendé le 2026-10-18, décision de l'utilisateur, voir l'[ADR 0024](0024-firebase-source-de-verite-comptes-clubs-roles.md), notes FB4b : **le groupe est
   obligatoire**. `PlanSession` refuse une séance sans groupe (`sessionNeedsGroup`), l'écran n'offre plus « aucun groupe » ni le choix du public, qui est celui du
   groupe ; un club sans groupe doit d'abord en créer un. Les séances sans groupe déjà enregistrées restent lisibles ; reprise au FB7.)*
   **Date et groupe sur la séance planifiée.** `Session.date` est obligatoire
   (jour, proposé au jour courant) ; `Session.groupId` est facultatif. Avec un
   groupe, le public est **celui du groupe** et la date doit tomber dans sa
   saison (`seasonOutsidePeriod`, comme l'ouverture de saisie) ; sans groupe,
   le public reste choisi (club sans groupe, séance à placer). La liste est
   triée par date croissante.
2. **Lien planifiée ↔ saisie dérivé**, sans clé étrangère *(amendé par l'[ADR
   0016](0016-identite-de-la-saisie-par-groupe-jour-et-seance.md) : la saisie
   se retrouve par groupe, jour **et séance du catalogue**, plus par groupe et
   jour seuls)* : une séance
   planifiée est « saisie » quand une `SessionRecord` du même groupe existe le
   même jour, règle déjà appliquée par `OpenOrResumeSession` (une seule saisie
   par groupe et par jour). La ligne planifiée propose « Noter les résultats »
   puis « Résultats saisis ».
3. **La saisie connaît sa séance du catalogue** : `SessionRecord.sheetId`
   (nullable). À l'ouverture, la notion principale et le rappel de résultats
   non fournis sont dérivés de la séance (`catalogueBlock`,
   `resultsRecallBlock`) ; une séance inconnue est refusée (`unknownSheet`). À
   l'affichage, un identifiant inconnu ne lève jamais.
4. **Lancer puis noter sans ressaisir** : le guide lancé depuis une séance
   planifiée (`?session=`) pré-remplit groupe et date de la saisie et transmet
   la séance du catalogue (`sheet`) ; le choix fait dans une saisie précédente
   du même guide reste prioritaire.
5. **Persistance** : schéma drift v4. `planned_sessions` est **recréée**
   (`TableMigration`) avec `date` non nulle (lignes existantes : horodatage de
   création copié tel quel, sans conversion de fuseau) et `group_id` nullable ; `session_records.sheet_id` nullable.
   Sauvegarde JSON de même version : clés `date`, `groupId`, `sheetId` ; le
   groupe doit exister (`backupInconsistent`), public et saison sont vérifiés
   (`backupInvalid`), une séance du catalogue inconnue est refusée
   (`backupUnknownSheet`, planifiée ou saisie).
6. **Placement** : `SheetOption` et `sheetOptionsOf` descendent en
   `entities/session_sheet/domain` (libellé commun à la planification, à la
   saisie et à l'historique) ; `resultsRecallBlock` aussi (règle qui ne dépend
   que de la séance, décision 13 de l'ADR 0004) ; `currentGroups` en
   `entities/group/domain` (règle de `GetClubOverview` réutilisée par la
   planification).

## Alternatives rejetées

- **Clé explicite `SessionRecord.plannedSessionId`** : plus précise si deux
  séances sont planifiées le même jour pour un groupe, mais une colonne, une
  clé de sauvegarde et des références à vérifier de plus, pour un cas que
  l'ouverture de saisie fusionne déjà (une saisie par groupe et par jour).
- **Date facultative** (« séance à dater ») : une planification sans date ne
  se trie ni ne se lie ; le jour courant proposé par défaut suffit.
- **Migration par colonne nullable** pour la date : aurait imposé une date
  facultative dans le domaine ; l'application n'est pas livrée, la table est
  recréée.
- **Dériver les blocs de la séance dans le routeur** : règle métier hors du
  domaine ; `ResolveSheetBlocks` la tient en un endroit, pour le guide comme
  pour la ligne planifiée.

## Conséquences

- Positives : la boucle planifier → lancer → noter → relire est continue ; la
  saisie et l'historique nomment la séance du catalogue ; la friction F6
  disparaît ; les règles de public et de saison sont les mêmes à la
  planification, à l'ouverture et à l'import.
- Coûts : migration v4 (première recréation de table, testée) ; toutes les
  fixtures de `Session` changent (date obligatoire) ; un sélecteur de groupe et
  un champ date dans le formulaire ; libellés fr / en ; adaptation des
  scénarios qui lisaient « Children · 90 min ».
- Limites : ~~le lien dérivé confond deux séances planifiées le même jour pour
  un groupe~~ (dépassé par l'ADR 0016 : seules deux séances **identiques** le
  même jour restent confondues) ; une saisie ouverte sans planification n'apparaît pas comme
  « séance planifiée » (elle reste dans l'historique).

Voir aussi l'[ADR 0009](0009-suggestion-seance-du-catalogue.md) : la saisie
ouverte depuis la séance suggérée reçoit désormais la séance du catalogue
proposée (`sheetId`), et le guide lancé depuis la suggestion connaît le groupe.
