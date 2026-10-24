# Plan du lot FB8, partie B (suppression de compte, marqueurs, purge à la clôture)

> **Décisions de l'animateur du 2026-10-24** (toutes sur la recommandation du cadrage) :
> **D1** le dernier directeur d'un club ne peut pas supprimer son compte : refus côté application, le successeur est créé par l'administrateur (invitation de directeur) ; aucune règle de promotion n'est ouverte.
> **D2** les durées de conservation des comptes adultes (parent, enseignant 12 mois, directeur) restent **organisationnelles, sans date** : le `member` disparaît au retrait ou à la clôture ; **la tranche B4 n'existe pas**.
> **D3** les invitations échues se listent par un `list` borné au club (`clubId ==`), pour l'administrateur et le directeur, **avec le rôle imposé par la règle** (un directeur ne lit pas les codes de directeur) ; attaque testée.
> **D4** nettoyage des marqueurs par leur auteur à la suppression de son compte (B1, B2) **et** filet : tout gestionnaire supprime un marqueur de plus de **90 jours** après `updatedAt` (B5), durée à valider par le DPO.
> **D5** `createdBy` d'un acquittement garde l'identifiant de l'auteur après la suppression de son compte (pseudonyme sans compte) ; limite déclarée au registre et dans la notice.
> **D6** l'échéance (`expireOn`, bandeau, blocage de la saisie, purge forcée par l'administrateur, demande d'effacement d'un parent) **reste en C** ; la notice est corrigée pour ne rien promettre tant que ce n'est pas livré.
>
> Ce plan est le résultat d'un cadrage en lecture seule (quatre cartographies recoupées). Les numéros de ligne et les constats sont **à revérifier au démarrage de chaque tranche**.

# Plan FB8 partie B (lecture seule, aucune implémentation)

Méthode : j'ai recoupé les quatre cartographies. Je n'ai relu moi-même dans le code que les lignes de `firestore.rules`, `docs/engineering/roadmap.md` et ADR 0025 (décisions 6 et 7). Le reste vient des explorateurs et doit être revérifié au démarrage de chaque tranche. Les numéros de ligne divergeaient entre explorateurs. Vérifié par grep : `members` `allow delete` à `firestore.rules:429`, `imports` `delete: if false` à `:762`, `operations` `delete` à `:823`, `invitations` `list: false` à `:893`, suppression d'une invitation à `:924`, `expireOn` seulement à `:536`. Un grep sur `app/lib` ne donne aucune occurrence de `expireOn`.

## 1. Périmètre et non-périmètre

**Dans B (cinq objets)**
1. Suppression d'un compte (e-mail et mot de passe) et de ses données de club. Réauthentification, purge Firestore, puis suppression Auth, d'après ADR 0025 décision 7(e).
2. Durée de vie des marqueurs `imports/{empreinte}_{uid}` et `operations/{empreinte}_{uid}` d'un auteur disparu ou d'une opération abandonnée.
3. Purge des invitations échues ou utilisées à la clôture (décision 6 : « purgée à la clôture de saison »).
4. Purge des comptes adultes à la clôture (parent, enseignant, directeur), sous réserve de la décision D2.
5. Mises à jour de documents (§6) et tests de règles (grille, attaques, mutations).

**Reste en C (écarté ici, sauf décision D6)**
- Export du droit d'accès (`ExportStudentData`), qui n'existe nulle part dans `app/lib`.
- App Check (ADR 0025 décision 8) et MFA.
- Relecture de la portée de session.
- Demande d'effacement d'un parent par document (7(d)), sauf décision D6.
- Échéance portée par les données : `expireOn` généralisé, bandeau, blocage de la saisie, purge forcée par l'administrateur (7(a)), sauf décision D6.
- La roadmap (`:402`, `:471`) ne dit nulle part ce qui revient à C. Ce découpage est une proposition à valider.

**Hors B dans tous les cas**
- Le compte Auth d'un administrateur : suppression en console, comme dit par `procedure-droits-et-effacement.md:45`. L'application doit refuser et expliquer. À confirmer, point mineur.
- `AppDatabase.currentSchemaVersion` reste à 12 (P7). Les règles et index changent, donc republication avant tout déploiement du build (D2 de la roadmap).

## 2. Décisions à soumettre avant d'écrire du code

**D1. Dernier directeur et successeur** (ADR 0025 7(e) : « un directeur désigne un successeur » ; ADR 0024 décision 14)
- Constat : rien ne permet à un directeur de promouvoir (`firestore.rules:405-426`, test `escalation.test.mjs:80-85`). Seul l'administrateur crée un directeur (`invite_director`). La procédure dit « l'application l'impose », ce qui est faux aujourd'hui et invérifiable côté règle, car une règle ne compte pas les membres.
- Options :
  - (a) La suppression d'un directeur est refusée par le client tant qu'aucun autre directeur n'existe (`MemberRepository.membersOf`). Le successeur est créé par l'administrateur. Les règles autorisent l'auto-suppression d'un directeur et la course entre deux directeurs est déclarée.
  - (b) Amender la décision 14 : le directeur promeut un enseignant. Cela change les règles de création et de mise à jour de `members` et le test d'escalade.
  - (c) La règle interdit l'auto-suppression d'un directeur, qui passe toujours par l'administrateur.
- Recommandation : (a). Elle n'ouvre aucune escalade de privilège et ne demande aucun amendement. Le filet est `invite_director`, documenté. Elle change la procédure (« l'application l'impose, le successeur vient de l'administrateur ») et demande un test de règle qui dit explicitement que l'application seule fait foi.

**D2. Durées de la décision 6 (« à confirmer ») et modèle de calcul**
- Constat : le `member` est supprimé au retrait, donc « 12 mois après le dernier rattachement » n'a aucune date à lire. Le compte Auth ne se purge pas depuis un client sur Spark. Le compte parent est déjà tenu par ricochet (`ClubStudentPurge._accountOperations`, `app/lib/app/club_student_purge.dart:154-176`).
- Options :
  - (a) Ne rien ajouter : le `member` disparaît au retrait ou à la clôture, et le compte Auth sans club est dit « sans donnée de club ». Les 12 mois deviennent une limite organisationnelle déclarée.
  - (b) Champ `expireOn` sur `members`, posé ou repoussé à la clôture, avec purge des échus par le directeur.
  - (c) Champ `detachedAt` sur un `member` conservé. Cela va contre la minimisation (aucune trace).
- Recommandation : (a) pour parents, enseignants et directeurs, plus (b) seulement si l'utilisateur ou le DPO veut une date vérifiable. Rien ne s'écrit avant confirmation `[U]` datée des durées. Si (b) est retenu, la tranche B4 existe, sinon elle disparaît et le travail se réduit à un texte de procédure.

**D3. Invitations échues : comment les énumérer**
- Constat : `list: false` (`firestore.rules:893`), collection à la racine (écart avec ADR 0024 ligne 83, reconnu ligne 291). Le journal local est limité à 20 entrées par appareil.
- Options :
  - (a) `list` borné au club (`clubId ==` dans la requête) pour l'administrateur et le directeur, avec `role in directorMemberRoles()` pour le directeur.
  - (b) Purger seulement les invitations utilisées, retrouvées par `member.invitationCode`. Les expirées s'éteignent d'elles-mêmes et le registre le déclare.
  - (c) Ne rien purger et amender la décision 6.
- Recommandation : (a), avec la contrainte de rôle. Sans elle, un directeur énumérerait les codes de directeur créés par l'administrateur et s'en servirait pour fabriquer un second directeur : c'est une escalade de privilège à tester en attaque. Les index sont automatiques, car il n'y a qu'une égalité. (b) est le repli sans changement de règle.

**D4. Durée de vie d'un marqueur d'import ou d'opération abandonné**
- Constat : `imports` n'est supprimable par personne (`delete: false`, `:762`). `operations` n'est supprimable que par son auteur (`:823`) et listable que par lui (`:808`). Un auteur disparu ou une clôture abandonnée laisse un marqueur définitif.
- Options :
  - (A) Suppression à la clôture, par n'importe quel gestionnaire du club.
  - (B) Suppression par n'importe quel gestionnaire après une ancienneté sur `updatedAt`, bornée par la règle (`resource.data.updatedAt < request.time - durée`).
  - (C) Nettoyage par l'auteur à la suppression de son compte, avant la suppression de son `member`.
- Recommandation : C obligatoire dans B1 et B2, car c'est le seul cas où l'auteur est présent. B comme filet pour les abandons et les auteurs déjà partis, avec une durée proposée de 90 jours après `updatedAt`, à valider par le DPO. Je ne retiens pas A : un marqueur d'import `done` effacé fait disparaître `alreadyImported`, et `restored` n'est calculé que si le marqueur est absent (`club_import_planner.dart:224` d'après un explorateur). Des élèves effacés peuvent alors être rétablis, seule la confirmation explicite restant comme garde. Pour les imports, la durée est donc le vrai sujet : l'utilisateur doit dire si 90 jours suffisent.

**D5. `createdBy` des acquittements après suppression du compte de l'auteur**
- Constat : seuls les acquittements (`:659-669`) et les invitations portent un auteur. Les passages et les saisies n'en ont pas.
- Options : (a) laisser l'uid, qui devient un pseudonyme sans compte, avec la limite déclarée au registre ; (b) règle de retrait du champ par le gestionnaire ; (c) supprimer les acquittements de l'auteur.
- Recommandation : (a). C'est le moins de code et de règles. Il demande de dire la limite au registre et dans la notice.

**D6. L'échéance est-elle dans B ?** (`expireOn`, bandeau, blocage de saisie, purge forcée par l'administrateur, demande d'effacement d'un parent)
- Constat : rien n'existe, et la notice (`notice-information-familles.md:63`, `:134`) annonce déjà « alerte puis blocage ».
- Options : (a) tout dans B ; (b) B limité à la purge à la clôture, organisationnelle, le reste en C, et la notice est corrigée pour ne rien promettre ; (c) le reste en C et la notice est maintenue comme « projet à valider ».
- Recommandation : (b). ADR 0025 7(b) dit que la garantie est organisationnelle. Le blocage de saisie touche règles et routeur, soit un lot à part. Il faut alors corriger la notice dans B6.

## 3. Tranches livrables (B1 à B6)

Chaque tranche suit AGENTS.md : scénario `.feature` écrit et vu rouge avant le code, TDD unitaire, FSD (`app > pages > widgets > features > entities > shared`, aucun import entre slices d'une même couche), aucune chaîne en dur, clés fr et en identiques, fichiers générés non édités. Commits en français, un par intention, et seulement sur demande de l'utilisateur. Chaque tranche se termine par `scripts/check.sh --full` vert.

### B1. Marqueurs : nettoyage par l'auteur (prérequis de B2)
- **Objectif** : un compte peut lister et supprimer ses propres marqueurs, sans affaiblir l'idempotence entre auteurs.
- **Scénarios BDD**
  - Un directeur retire ses marqueurs d'opération terminés ou abandonnés.
  - Un enseignant retire ses marqueurs d'import.
  - Le marqueur d'un autre compte n'est jamais touché.
- **Domaine, tests unitaires**
  - Port « mes marqueurs » par club.
  - Pour les opérations, `FirestoreOperationStore` liste déjà les siens (`app/lib/app/firestore_operation_store.dart:55`).
  - Pour les imports, un équivalent dans `app/lib/app/firestore_club_import_store.dart`, avec lecture, liste filtrée et suppression.
- **Règles** (`firestore.rules`, bloc `imports` ~738-762)
  - `allow list` pour `mayImport` si `resource.data.createdBy == request.auth.uid`. Le `list` actuel pour `manages` est à conserver ou restreindre selon D4.
  - `allow delete` du sien : suffixe de l'identifiant égal à l'uid, `markerId[65:] == request.auth.uid`.
  - Le commentaire « Jamais supprimé (console seule) » devient faux et est à réécrire.
- **Tests d'émulateur** (`scripts/rules_test/import.test.mjs`, `matrix.test.mjs`)
  - Inverser le test actuel (`matrix.test.mjs:653-657`, d'après un explorateur).
  - Attaques : supprimer le marqueur d'un autre ; supprimer avec un compte non vérifié ; un parent ou un élève ; l'enseignant d'un autre club ; une liste sans filtre `createdBy`.
  - Mutations pour chaque garde, `budget.test.mjs`.
- **Fichiers par couche** : `shared/lib/operations/` (port, si utile), `app/lib/app/*` (adaptateurs), `docs` (§6).
- **Risque** : l'auteur vivant peut rejouer un import terminé. À accepter et à écrire dans le registre.

### B2. Suppression d'un compte
- **Objectif** : un utilisateur supprime son compte et ses données de club, avec l'ordre sûr de la cartographie « compte ».
- **Ordre** : écran de confirmation, réauthentification **avant toute écriture**, contrôles (en ligne, aucune écriture non envoyée, pas administrateur, pas dernier directeur selon D1), puis pour chaque club de `membershipsOf` : révocation de ses invitations en attente (journal local), suppression de ses marqueurs (B1), et son `members` **en dernier**. Ensuite `User.delete()`, puis les mêmes nettoyages locaux que `signOut`.
- **Scénarios BDD**
  - Un enseignant supprime son compte.
  - Un parent de plusieurs élèves supprime son compte et aucune fiche n'est touchée.
  - Un élève de 15 ans ou plus supprime son compte et sa fiche reste au club.
  - Un directeur sans successeur est refusé.
  - Un directeur avec successeur est accepté.
  - Un administrateur est refusé avec explication.
  - Mot de passe faux.
  - Hors ligne : refus.
  - Purge interrompue puis reprise sans danger.
  - Compte sans club (« Aucun club », élève déjà effacé) : la suppression est proposée.
- **Domaine, tests unitaires**
  - `AuthRepository` : `reauthenticate({password})` et `deleteAccount()` (`app/lib/entities/account/domain/auth_repository.dart:9-26`).
  - `auth_failure.dart` : un code de connexion trop ancienne, sachant qu'`invalidCredentials` existe déjà pour un mauvais mot de passe.
  - Données et SDK : `auth_sdk.dart`, `firebase_auth_sdk.dart`, `firebase_auth_repository.dart` (`_transportFailure`), `InMemoryAuthRepository`, `app/test/support/fake_firebase_gateway.dart`.
  - Contrat : `app/test/unit/entities/account/data/auth_repository_contract_test.dart` à étendre.
  - Cas d'usage `DeleteOwnAccount` dans une feature (par exemple `features/sign_in/domain/` ou `features/manage_account/`), sans import d'une autre feature.
  - `AuthCubit.deleteAccount` (`app/lib/app/auth/auth_cubit.dart`) en réutilisant `_signingOut`, `_memory`, `_issued`, `_local`. Sans `_signingOut`, `_onAccount(null)` (`:284-298`) prendrait la suppression pour une perte de session ailleurs.
  - `Capability` de suppression dans `app/lib/shared/lib/role_policy.dart`, administrateur exclu.
- **Règles**
  - `members` : `allow delete` du titulaire, `verified() && request.auth.uid == memberId`, en plus de l'existant (`:429`).
  - Selon D1, directeur autorisé (contrôle client) ou refusé.
  - Inverser `escalation.test.mjs:72-75` (« on ne s'efface pas pour mieux revenir ») et `matrix.test.mjs:289-295`.
  - La création d'un `members` exige toujours invitation, directeur ou administrateur : le retour n'est donc pas ouvert, ce qu'un test doit prouver.
- **Tests d'émulateur**
  - Grille par rôle.
  - Attaques : supprimer le `members` d'un collègue ; compte non vérifié ; se supprimer puis se recréer sans invitation ; supprimer le `members` d'un autre club ; la suppression de l'administrateur reste refusée (`admins`, `write: false`, `:316-321`).
  - `auth_emulator.test.mjs` pour la suppression réelle après purge.
  - Parcours `scripts/emulator_e2e/`.
- **Interface**
  - `account_section.dart` (`app/lib/features/sign_in/presentation/ui/`), bouton « Supprimer mon compte ».
  - Boîte de dialogue : mot de passe, texte qui dit ce qui est supprimé et ce qui reste au club.
  - Câblage dans `app/lib/app/router.dart` à `:1354`, et sur les écrans sans club (`:569`, `:678`, `:726`, `:734`, `:1458`).
  - Pages `access_denied_page.dart`, `join_page.dart`, `select_club_page.dart`.
  - Widgetbook si un composant est ajouté.
- **Textes fr+en** (`app/lib/shared/l10n/app_fr.arb` et `app_en.arb`, puis gen-l10n) : titre et corps de confirmation, champ mot de passe, refus (dernier directeur, administrateur, hors ligne, écritures non envoyées), mot de passe incorrect, succès, reprise.
- **Risques**
  - Les écritures hors ligne « réussissent » en file locale : il faut l'accusé du serveur avant `User.delete()`. Aucun port actuel ne l'expose (`SendStatus`, FB5), à étudier au démarrage.
  - `membershipsOf` ignore les clubs au nom illisible (`store_memberships_source.dart:44-45`) : cas de test.
  - `clearPersistence` peut échouer avec plusieurs onglets (`_erasurePending` à réutiliser).

### B3. Purge des invitations à la clôture (dépend de D3)
- **Objectif** : à la clôture, supprimer les invitations utilisées et échues du club.
- **Scénarios BDD**
  - La clôture supprime les invitations utilisées et échues du club.
  - Une invitation valide d'un autre club n'est pas touchée.
  - Une invitation encore valide n'est pas supprimée.
  - Une purge interrompue se reprend.
- **Domaine, tests unitaires**
  - `InvitationRepository` : `purgeable(club)` et `purge(codes)` (`app/lib/entities/invitation/domain/` et `data/store_invitation_repository.dart`).
  - Une étape de plus dans `SeasonClosureOperation` (`app/lib/features/close_season/domain/season_closure_operation.dart`), via `OperationRunner`, lots de 400 et plafond quotidien.
  - Si une nouvelle valeur d'`OperationKind` est choisie, il faut élargir `operation_marker.dart:10-15` et `operationMarkerShape` (`stage <= 8`). Sinon l'étape reste dans la clôture.
- **Règles**
  - `invitations` : `allow list` borné au club.
  - Pour le directeur, contrainte `resource.data.role in directorMemberRoles()` (attaque à tester).
  - Pour l'administrateur, aucune restriction de rôle.
  - La suppression existe déjà (`:924`).
- **Tests d'émulateur**
  - `invitations.test.mjs` : le test actuel qui exige le refus de `list` est à inverser.
  - Attaques : un directeur liste les invitations de directeur ; liste sans filtre `clubId` ; liste d'un autre club ; enseignant, parent ou élève ; compte non vérifié.
  - Mutations, `model.json`, `model_coverage.test.mjs`, `bounds.test.mjs`.
- **Interface** : l'aperçu de la clôture (`app/lib/pages/season_closure/`) dit combien d'invitations sont purgées. Textes fr+en.
- **Risque** : le directeur voit des codes encore valables (non directeur). C'est un choix de sécurité à valider, voir D3.

### B4. Comptes adultes à la clôture (seulement si D2 = (b))
- **Objectif** : purger les `members` échus du club à la clôture.
- **Scénarios BDD**
  - Un parent dont le dernier enfant est effacé disparaît (déjà tenu par ricochet, à prouver par test).
  - Un enseignant ou un directeur échu est proposé à la purge.
  - Un compte reconduit voit son échéance repoussée.
- **Domaine** : `Member` reçoit `expireOn` (`app/lib/entities/membership/domain/member.dart`) ; calcul à la clôture (`propose_closure.dart`, `planNextSeason`). Il n'existe pas de lien explicite entre saisons, la règle de calcul est à définir (piste : valeur = fin de N+1 posée à la clôture de N).
- **Règles** : `memberShape` autorise `expireOn` (timestamp, typé). `studentShape` (`:536`) le liste déjà sans type : à typer. Vérifier si la mise à jour du `member` par le directeur autorise ce champ.
- **Filtre « échu »** : `QueryFilter` n'a que l'égalité (`document_store.dart:121-160`), donc tri en mémoire ou nouveau filtre d'inégalité. `tool/check_indexes.dart` doit rester vert.
- **Si D2 = (a)** : cette tranche se réduit à la procédure et à la notice (aucun code).

### B5. Filet d'âge pour les marqueurs abandonnés (dépend de D4)
- **Objectif** : un gestionnaire supprime un marqueur dont `updatedAt` dépasse la durée retenue, même d'un autre auteur.
- **Scénarios BDD**
  - Un directeur nettoie le marqueur ancien d'un compte supprimé.
  - Un marqueur récent n'est pas supprimé.
  - Un enseignant n'y a pas accès.
- **Règles** : `allow delete` des blocs `operations` et `imports` pour `manages` avec `resource.data.updatedAt < request.time - duration`. `list` borné par ancienneté (requête de plage sur un champ, index automatique).
- **Tests d'émulateur** : attaques (marqueur récent, enseignant, club étranger, `updatedAt` falsifié), mutations. Test à ajouter : suppression d'un marqueur abandonné par un tiers (`operations.test.mjs:258` ne couvre aujourd'hui que le refus).
- **Risque** : une durée trop courte casse une reprise légitime.

### B6. Documents et conformité (peut accompagner chaque tranche)
Voir §6. Doivent être cohérents avant la validation P1.

## 4. Plan de vérification

- Pour chaque tranche : scénario rouge vu, puis `scripts/check.sh --fast` pendant le travail et `scripts/check.sh --full` avant de conclure (tests, couverture, l10n, Widgetbook, tests de règles).
- Règles : `scripts/rules_test.sh` (Node 24.12 ou plus, Java 21, `npm ci`, échec explicite sinon). Chaque garde ajoutée a sa mutation et son attaque.
- `dart run scripts/sync_*.sh --check` si un asset est touché, `tool/check_indexes.dart` pour les index.
- Parcours navigateur : `scripts/emulator_e2e.sh` sous émulateurs Auth et Firestore avec la graine (club « Démo »). Scénarios : suppression d'un enseignant, d'un parent à deux enfants, refus du dernier directeur, reprise après interruption entre purge et suppression Auth.
- Relecture dans un contexte séparé (CLAUDE.md du projet) : `architecte-fsd` et `testeur-bdd` pour le code, jamais par l'auteur.
- Rappel : les hooks bloquent les fichiers générés, `docs/sources/` et la configuration des garde-fous. Si un hook bloque, corriger la cause.

## 5. Risques et inconnues

- **Accusé du serveur** : aucun port n'expose l'accusé d'une écriture isolée hors ligne. À examiner dans `SendStatus`/FB5 (non lu par les explorateurs) avant B2.
- **Projet réel** : ne jamais écrire sur le projet de production (mémoire h5). Les essais se font sous émulateur avec un projet `demo-…`.
- **Spark** : pas de Cloud Functions. Le TTL est « non vérifié, non nécessaire » (ADR 0025 ligne 112). La garantie de durée reste organisationnelle. MFA par TOTP dépend d'Identity Platform (hors B).
- **Compte Auth orphelin** : un compte sans club n'est purgeable que par son titulaire. À dire dans le registre et la notice (180 jours chez Google).
- **Course sur le dernier directeur** : deux directeurs qui se suppriment simultanément laissent un club sans directeur. Le filet est `invite_director` par l'administrateur.
- **Clôture interrompue d'un autre auteur** : seul l'auteur la reprend (`roadmap.md:471`). Le filet B5 atténue, ne résout pas.
- **Plafond quotidien** (`DailyWriteLedger`, compteur local `import.writes.{uid}`) : non lu par le serveur, donc inchangé par la purge de marqueurs. Je n'ai pas vérifié s'il est vidé à la déconnexion (non vérifié par l'explorateur non plus).
- **Durées** : toutes à valider par le responsable de traitement ou le DPO. P1 reste bloquant pour la première invitation réelle, B ne le lève pas. Il faut respecter P6 (pas de fusion sur `main` pendant la fenêtre de migration) et P7.
- **Rôle de l'administrateur** : n'a pas de `members`, `admins/{uid}` en `write: false`. Si un jour il est supprimé hors console, `admins/{uid}` reste orphelin.

## 6. Incohérences relevées entre documents et code

1. **Suppression de compte** : `procedure-droits-et-effacement.md:41-45` fait supprimer son `members` par le parent ou l'enseignant. Les règles ne le permettent pas (`firestore.rules:429`).
2. **Successeur du directeur** : « l'application l'impose » (procédure:44, ADR 0025 7(e)). Aucun code, et les règles empêchent un directeur d'en créer un autre (`:405-426`).
3. **Document de demande d'effacement** (procédure:8, ADR 0025 7(d)) présenté comme acquis ; ni collection, ni écran. Un parent ne peut rien écrire hors son nom affiché.
4. **Export du droit d'accès** présenté comme acquis ou imminent (procédure:14, ADR décision 11, notice, AIPD) ; `ExportStudentData` n'existe pas.
5. **`expireOn`** : ADR 0025 7(a) dit « chaque document porte `expireOn` » ; seul un nom toléré dans `studentShape` (`:536`), et les marqueurs n'ont ni `expireOn` ni `createdAt`.
6. **Notice** (`:63`, `:134`) annonce alerte puis blocage de la saisie ; rien n'existe.
7. **Registre 4 ter (`:117`) et 4 bis (`:102`)** disent que l'administrateur peut supprimer un marqueur. Les règles ne le permettent pas, seule la console le peut. Le registre 4 bis dit aussi que les marqueurs sont lisibles en liste par le directeur, puis que chaque marqueur n'est lisible que par son auteur : à préciser (`get` du sien, `list` pour `manages` sur les imports, `list` du sien sur les opérations).
8. **Idempotence** : le registre justifie la conservation du marqueur d'import par l'idempotence d'un même compte, alors que l'ADR 0024:729 (P1) dit que l'idempotence entre auteurs ne vient plus du marqueur.
9. **Marqueur orphelin** : une clôture supprime son seul marqueur ; celui d'un autre auteur reste « jusqu'à sa prochaine opération sur cet élève », qui n'existe plus.
10. **Invitations** : ADR 0024:83 les place sous `clubs/{c}` ; code et règles les ont à la racine (écart reconnu en `:291` et dans `store_invitation_repository.dart:21-22`). ADR 0025 les purge « à la clôture » alors que `list: false` l'empêche. ADR 0024 décision 27 omet « acceptée, révoquée » que la table de l'ADR 0025 cite.
11. **Durées d'invitation** : ADR 0025 dit 48 h pour un enseignant ; le domaine applique 48 h à enseignant, directeur et administrateur (`invitation.dart:23-28`). Règles 49 h et 169 h contre domaine 48 h et 7 jours (tolérance d'horloge d'une heure, voulue, à documenter).
12. **Chemin** : les docs écrivent `shared/lib/operations/`, le répertoire est `app/lib/shared/lib/operations/`.
13. **`ClubRepository`** (`club_repository.dart:5-7`) dit que l'administrateur « supprime » ; il n'a ni `delete` ni purge, alors que `firestore.rules:344` permet `clubs delete` à l'administrateur.
14. **Statut de l'âge de 15 ans** : « confirmé » dans ADR 0025:104 mais « à vérifier à la source » dans la roadmap P1 (`:426`) ; `conformite/README.md:56` ne l'énumère pas parmi les non vérifiés.
15. **Roadmap** : l'encadré d'état (origin/main supposé à 87102d4, commits H5 locaux) contredit le `git status` initial de la session (branche à jour, dernier commit ae58ceb). Il est probablement périmé, ainsi que D2, D5 et D8 qui en dépendent. Vérification impossible sans `git fetch`.
16. **Périmètre** : roadmap `:402` écrit « invitations échues, comptes parents », `:471` ajoute « enseignants et directeurs » ; B et C ne sont pas distingués.
17. **Mises à jour de conformité manquantes** : `conformite/README.md` ne trace que FB6 alors que le registre contient 4 bis, 4 ter et FB7c ; l'AIPD et la notice (2026-10-17) ne mentionnent ni `erasing`, ni les marqueurs ; le statut daté de la procédure ne reflète pas la partie A ; `check_family_register` ne vérifie que les noms de chemins.
18. **Documents à mettre à jour avec B** : ADR 0024 (notes FB8b, décisions 19 et 27), ADR 0025 (décision 6 confirmée et datée, 7(a), 7(d), 7(e), « Limites assumées » ligne 153), procédure (§ suppression d'un compte `:41-45`, § purge de fin de saison `:47-53`), registre (traitements 2, 4 bis, 4 ter), notice (fr et en), `aipd-brouillon.md` (R3, R8), `dpa-et-sous-traitants.md`, `conformite/README.md`, `docs/guide-animateur.md` (rien sur la suppression de compte aujourd'hui), `roadmap.md` (`:402`, `:469-471`, `:484`), `testing.md` (section FB8, ~707-739), `quality-gates.md`.

Fichiers de référence : `/home/bfontaine/github/cfa-ffb/firestore.rules`, `/home/bfontaine/github/cfa-ffb/AGENTS.md`, `/home/bfontaine/github/cfa-ffb/docs/engineering/roadmap.md`, `/home/bfontaine/github/cfa-ffb/docs/engineering/adr/0025-comptes-et-donnees-de-mineurs-conformite.md`.