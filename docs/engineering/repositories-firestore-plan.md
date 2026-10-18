# Plan : dépôts Firestore (lot FB4)

Statut : **partie 1/3 livrée** (2026-10-18), sous émulateurs et doubles seulement. **Aucune base de production touchée.** Décisions :
[ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) (décisions 14, 15, 17 à 19, 28 ; note de réalisation FB4a pour les écarts). Aucune décision nouvelle.

## Découpage en trois parties

| Partie | Contenu | État |
|---|---|---|
| 1 | Erreurs d'ouverture de session ; garde-fou d'index ; fondation (chemins, club résolu à l'appel, requêtes, sélecteur de backend) ; suite de contrat sur Firestore ; dépôts **settings**, **student**, **group (+ appartenances)** ; règle `audienceHistory` | **fait** |
| 2 | Dépôts saisons, archives, séances planifiées, saisies, passages, acquisitions, acquittements, bilans ; `UnitOfWork` Firestore (lot) ; identifiants déterministes ; création d'élève par un enseignant | à faire |
| 3 | Bascule de production ; contrat complet ; sauvegarde et effacement ; parcours navigateur | à faire |

## Ce que la partie 1 pose

- **`ClubPaths`** (`shared/persistence`) : tous les chemins d'un club ; aucun dépôt n'en compose un à la main. Appartenance : `clubs/{c}/memberships/{groupId_studentId_from}`.
- **`ClubStore`** : `DocumentStore` + `ActiveClubScope`. Le club est lu à **chaque appel** ; sans club actif, `ServiceFailure(denied, 'no-active-club')`. Offre `role`, `manages`,
  `groupIds`, `studentIds` et `commit` par lots de 500.
- **`DocumentStore.query(collection, filtre)`** : égalité ou `array-contains-any` sur **un** champ (jamais d'index composite). Implémenté par la mémoire, `FirestoreDocumentStore`
  et `FirestoreSdkAccess`.
- **Codecs** (`student_document`, `group_document`, `settings_document`, `document_values`) : dates en ISO 8601 (fuseau et microsecondes conservés, texte accepté par les règles), champs de la
  liste blanche seulement, document mal formé = `ServiceFailure(other)` qui nomme le champ.
- **`DataBackend`** (`app/data_backend.dart`) : `--dart-define=DATA_BACKEND=firestore`, défaut drift, valeur inconnue = erreur. `DataBackendModule` aiguille settings, student et group ;
  les dépôts drift sont enregistrés sous leur type concret.

## Cartographie des dépôts migrés

| Port | Document(s) | Écriture | Lecture par rôle |
|---|---|---|---|
| `SettingsRepository` | `clubs/{c}/settings/main` | directeur, administrateur | tout membre |
| `StudentRepository` | `clubs/{c}/students/{id}` (même document que `StudentDirectory`) | gestionnaire (l'enseignant crée avec un groupe : partie 2) | gestionnaire : liste ; enseignant : `array-contains-any` ; parent, élève : fiches liées |
| `GroupRepository` | `clubs/{c}/groups/{g}` + `clubs/{c}/memberships/{…}` + `groupIds` des fiches | gestionnaire | gestionnaire : liste ; enseignant : ses groupes et leurs appartenances ; parent, élève : groupe sans appartenances |

Budget de lectures : `GroupRepository.save` lit le groupe, les appartenances du groupe et chaque fiche concernée ; `all()` d'un gestionnaire : 2 lectures de collection ;
`StudentRepository.save` : 1 lecture. Écritures : un lot par `save` (500 au plus par lot).

## Reste pour la partie 2

1. Dépôts : `SeasonRepository`, `SeasonArchiveRepository`, `SessionRepository`, `SessionRecordRepository`, `AttemptRepository` (un document par passage, `passIndex` dérivé : décision 17,
   qui change `ExerciseAttempt` et `ExerciseResult.derive`), `AcquisitionRepository`, `AcknowledgementRepository`, `AssessmentRepository` ; identifiant déterministe d'une saisie liée
   à une séance du catalogue (décision 18).
2. `UnitOfWork` en `WriteBatch` pour les petits cas (décision 19) ; les dépôts de la partie 1 écrivent déjà par lot mais ne participent pas encore à un `UnitOfWork` partagé.
3. Création d'une fiche par un enseignant : les règles exigent au moins un de ses groupes à la création, le dépôt écrit `groupIds: []` (refus, testé dans `repositories.test.mjs`) : le cas
   d'usage « ajouter un élève à un groupe » devra écrire fiche et appartenance dans un même lot.
4. Contrat complet : `RepositoryHarness` sur Firestore une fois tous les ports migrés.

## Reste pour la partie 3

Bascule (`DATA_BACKEND=firestore` par défaut en production) ; `RulesStore` rechargé à l'activation d'un club (aujourd'hui chargé au démarrage, avant la session) ; sauvegarde
(`backup_codec`) et `StudentEraser` côté serveur (FB7, FB8) ; contrat complet sur Firestore ; parcours navigateur application + émulateurs avec les dépôts Firestore ; déploiement des
règles et des index par l'utilisateur (rien n'est déployé).
