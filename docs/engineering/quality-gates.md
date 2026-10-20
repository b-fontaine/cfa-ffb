# Garde-fous qualité (100 % déterministes, sans IA)

Source de vérité unique : **`scripts/check.sh`**. Les hooks git, le hook agent
(`.claude/settings.json`, événement `Stop`) et la CI l'appellent ; aucune règle
n'est dupliquée ailleurs.

```bash
scripts/check.sh --fast   # ~5 s : format, analyse, scripts, architecture, séances (lecture seule)
scripts/check.sh --full   # ports des émulateurs libres (échec immédiat sinon) + fast + l10n + règles Firestore (émulateurs) + tests + couverture + Widgetbook (~1 min ; Node, Java et `npm ci` requis)
COVERAGE_MIN=95 scripts/check.sh --full   # relever le seuil de couverture

scripts/sync_catalogue.sh [--check]       # copie / vérifie le catalogue (docs/knowledge -> app/assets)
scripts/sync_diagrammes.sh [--check]      # copie / vérifie les diagrammes à table (docs/knowledge -> app/assets)
scripts/sync_fiches.sh [--check]          # copie / vérifie les séances du catalogue (docs/knowledge -> app/assets)
(cd app && dart run tool/fiches.dart [--complete])   # valide les séances (FORMAT.md § 7)
scripts/rules_test.sh                     # règles Firestore contre l'émulateur (Node, Java, npm ci, dart : produit d'abord les écritures du plan d'import)
scripts/web_smoke.sh [--build]            # build web compilé + vrai SDK Auth contre l'émulateur (+ Google Chrome)
scripts/emulator_e2e.sh                   # application (debug) + émulateurs Auth et Firestore + graine, dans Chrome (+ Flutter)
```

## Tableau des garde-fous

| Garde-fou | Commande | `--fast` | `--full` | Hook git | CI (job) |
|---|---|:-:|:-:|---|---|
| Génération de code (build_runner, gen-l10n) | `scripts/generate.sh` | si manquant | oui | via check | quality / test / build-web |
| Catalogue : asset identique à la source | `scripts/sync_catalogue.sh --check` | oui | oui | pre-commit | quality |
| Diagrammes : assets identiques à la source (pages à table uniquement, aucun fichier en trop, chaque dossier déclaré dans `app/pubspec.yaml`) | `scripts/sync_diagrammes.sh --check` | oui | oui | pre-commit | quality |
| Fiches de séance : assets identiques à la source (fichiers `NN-<id>.yaml` seulement, aucun fichier en trop, dossier déclaré dans `app/pubspec.yaml`) | `scripts/sync_fiches.sh --check` | oui | oui | pre-commit | quality |
| Fiches de séance : règles V1 à V24 de `FORMAT.md` § 7, structure et parties calculées depuis le catalogue, tableaux du § 1 à jour (lecture seule) | `dart run tool/fiches.dart --complete` (dans `app/` ; exige les 28 séances ; sans l'option, contrôle seulement les fichiers présents ; `--structure` affiche la structure) | oui | oui | pre-commit | quality |
| Fichiers web drift : `drift_worker.js` = paquet résolu, `sqlite3.wasm` = version verrouillée | `dart run scripts/sync_web_assets.dart --check` | oui | oui | pre-commit | quality |
| SDK web Firebase servi en local ([ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md), décision 30, FB5a) : version épinglée = celle de `firebase_core_web` résolu, empreinte SHA-256 de chaque fichier de `app/web/firebasejs/`, carte d'import exacte et placée avant tout script, aucun import interne non couvert | `dart run scripts/sync_firebase_sdk.dart --check` (met à jour : sans `--check`) | oui | oui | pre-commit | quality |
| PWA : manifeste (champs, couleurs = thème, icônes `any`/`maskable` présentes et de la bonne taille, orientation libre), `index.html`, service worker, aucune URL externe ; icônes régénérées à l'identique | `dart run scripts/pwa.dart check` et `dart run scripts/generate_pwa_icons.dart --check` | oui | oui | pre-commit | quality |
| Comportement du service worker et du pont de mise à jour (précache et reprise, HTML refusé, purge des anciens caches, activation seulement sur demande, autre onglet, `/__/` non intercepté, worker non stampé), contrat Dart/JS du pont | `node --test scripts/pwa_js_test.mjs` (Node requis) | oui | oui | pre-commit | quality |
| Index Firestore ([ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md), lot FB4) : toute requête `collectionGroup(...)` du code a son exemption `COLLECTION_GROUP` dans `firestore.indexes.json`, toute requête composée (`where` + `orderBy` sur des champs différents) son index composite ; nom non littéral = échec ; le port `DocumentStore` et ses trois réalisations sont les seules exemptions | `dart run tool/check_indexes.dart` (dans `app/`) | oui | oui | pre-commit | quality |
| Règles Firestore ([ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md), lots FB1 et FB3) : **règles complètes du modèle** ; grille rôle × action × collection × 12 acteurs (anonyme, e-mail non vérifié, invité sans member, élève, deux parents, deux enseignants, enseignant d'un autre club, directeur, directeur d'un autre club, administrateur), invitations à usage unique par lot (réutilisation, expiration, mauvais club ou rôle, e-mail non vérifié), élévation de privilège, **liste blanche de champs par collection** et bornes de chaque valeur (juste en dessous, juste au-dessus ; champ inconnu, texte de 900 Ko, étiquette hors liste refusés), **donnée d'un élève écrite par un enseignant seulement si l'élève est de SON groupe**, refus par défaut (chemins hors modèle, anonyme et adresse non vérifiée sur tout le modèle), **couverture du modèle** (`scripts/rules_test/model.json` : chaque collection de l'ADR a son `match`, sa ligne dans l'ADR et sa grille ; aucune collection non documentée), budget de 10 `get()` mesuré, graine des émulateurs avec de vrais jetons (la graine refuse tout hôte non local et tout projet hors `demo-…`), aucune autorisation inconditionnelle ni date d'expiration, preuves de sensibilité ; **mutations à la main** sur une copie (`RULES_FILE`), consignées dans [testing.md](testing.md) | `scripts/rules_test.sh` (`firebase emulators:exec` + `node --test --test-concurrency=1 scripts/rules_test/`) | — | oui | pre-push | test (ubuntu + macOS) ; **import d'une sauvegarde (FB7a)** : marqueur d'import (compare-and-swap de chaque lot), écritures du plan de l'application jouées contre les vraies règles (`import.test.mjs`, fichier de 1992 écritures, enseignant, miroir du plan, convergence, budget de 20 documents lus par lot) |
| Fumée du build web compilé ([ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md), lot FB2) : le build release (`scripts/build_web.sh`) chargé dans Chrome avec le vrai SDK `firebase_auth` ; démarrage jusqu'à l'écran de connexion, échec générique (mauvais mot de passe, adresse inconnue), lien d'invitation `/join/<code>` qui ouvre l'inscription avec le code (FB3), connexion **jusqu'à l'accueil du club retenu sur l'appareil** (assertion de succès), session conservée au rechargement, déconnexion ; appels d'authentification renvoyés à l'émulateur ; **Firestore n'est pas émulé** (le build compilé l'interroge, les appels sont refusés : sans club retenu, « Service injoignable », éprouvé à part comme chemin d'échec) ; tout autre hôte refusé | `scripts/web_smoke.sh --build` (`firebase emulators:exec` + `node --test scripts/web_smoke/`) | — | oui | pre-push | test (ubuntu + macOS) |
| Application + émulateurs Auth et Firestore + graine (lot FB3, [ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md)) : l'application en **mode debug** (`flutter run -d web-server --dart-define=FIREBASE_EMULATOR=true`, projet `demo-cfa-ffb` : le build `--profile` est inutilisable avec `firebase_auth_web`, la release refuse l'émulateur) chargée dans Chrome ; la directrice de la graine se connecte (vrai jeton de l'émulateur), l'application lit ses appartenances **sous les règles** et « Mon club » affiche l'équipe semée ; un parent atterrit sur « Mes enfants », sans « Mon club » ; tout hôte autre que localhost refusé (SDK web et moteur servis en local, `flutter run --no-web-resources-cdn`, FB5a ; seule la police de repli demandée à `fonts.gstatic.com` en debug est refusée sans faire échouer) | `scripts/emulator_e2e.sh` (`firebase emulators:exec` + graine + `flutter run` + `node --test scripts/emulator_e2e/`) | — | oui | pre-push | test (ubuntu + macOS) |
| Authentification Firebase contre l'émulateur Auth ([ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md), lot FB2) : adresse non vérifiée à la création, mauvais mot de passe et adresse inconnue (codes que l'application regroupe), adresse déjà utilisée, 6 caractères seulement côté serveur, courriels de vérification et de réinitialisation émis, adresse inconnue sans courriel | `scripts/rules_test.sh` (le même appel, `scripts/rules_test/auth_emulator.test.mjs`) | — | oui | pre-push | test (ubuntu + macOS) |
| Confidentialité de la plateforme ([ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md), [0025](adr/0025-comptes-et-donnees-de-mineurs-conformite.md)) : sauvegardes Android et iCloud désactivées, `firebase.json` (e-mail seul, `europe-west9`, émulateurs locaux), `firestore.rules` sans accès ouvert, plateformes Android / iOS / web seulement, aucune URL hors domaines Firebase dans `lib/` et `web/`, aucun SDK de mesure, release qui refuse l'émulateur | `app/test/tool/platform_privacy_test.dart` (avec les tests) | — | oui | pre-push | test |
| Build Android debug (incompatibilités natives des plugins FlutterFire ; sans signature) | `flutter build apk --debug` (dans `app/`) | — | — | — | build-android |
| Formatage | `dart format --output=none --set-exit-if-changed` (lib, test, tool, scripts) | oui | oui | pre-commit | quality |
| Analyse statique stricte | `flutter analyze --no-pub --fatal-infos` (`very_good_analysis` + strict-casts/inference/raw-types) | oui | oui | pre-commit | quality |
| Analyse des scripts Dart (paquet `scripts/`, mêmes règles `very_good_analysis` que l'application, [ADR 0022](adr/0022-dette-outillage-scripts-wasm-mutation.md)) | `dart pub get` puis `dart analyze --fatal-infos .` dans `scripts/` | oui | oui | pre-commit | quality |
| Architecture FSD + Clean | `dart run tool/check_architecture.dart` (dans `app/`) | oui | oui | pre-commit | quality |
| Séances générées | `dart run scripts/validate_seances.dart seances` | oui | oui | pre-commit | quality |
| Registre des traitements ([ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) FB6, [ADR 0025](adr/0025-comptes-et-donnees-de-mineurs-conformite.md)) : `scripts/rules_test/family_reads.json` (listes `famille` et `connexion`) fait foi des lectures d'un parent ou d'un élève ; chaque chemin (collection ou document, sans `clubs/{club}/` ni segment variable : `students`, `attempts`, `settings/main`, `clubs/{club}`, `admins/{uid}`, `members`…) doit être nommé **entre apostrophes inverses dans le traitement 1 bis** de `conformite/registre-des-traitements.md` ; une mention ailleurs ne compte pas. **Limite assumée** : le contrôle ne vérifie que les NOMS de collections ou de documents, pas la liste des champs de chacun (un champ ajouté à une forme de `firestore.rules` n'est pas signalé) ni l'unicité de `members` (la requête de groupe et le document y partagent le même nom) ; l'exhaustivité des champs reste une relecture à faire avant la validation par le DPO. Mutation prouvée sur une copie du registre (une mention retirée, un chemin ajouté à la liste, une mention hors section : le contrôle échoue), `app/test/tool/check_family_register_test.dart` | `dart run scripts/check_family_register.dart` | oui | oui | pre-commit | quality |
| l10n fr/en : mêmes clés | `dart run scripts/check_l10n.dart app/lib/shared/l10n` | — | oui | pre-push | test |
| Forme des workflows GitHub (`app/test/tool/workflows_test.dart`, le dépôt n'a pas `actionlint`) : actions épinglées par empreinte, aucune clé JSON de compte de service, déploiement des règles et des index jamais déclenché par une pull request, tests avant déploiement, index avant règles, hébergement après règles et index (`needs`), `id-token: write` limité au job de déploiement ; mode d'emploi et étapes de l'utilisateur : [deploiement-firestore.md](deploiement-firestore.md) | `flutter test` (dans `app/`) | — | oui | pre-push | test (ubuntu + macOS) |
| Tests BDD + unitaires | `flutter test --no-pub --coverage` (dans `app/`) | — | oui | pre-push | test (ubuntu + macOS) |
| Couverture de lignes ≥ 90 % | `dart run scripts/check_coverage.dart 90 app` | — | oui | pre-push | test |
| Widgetbook : génération, format, analyse stricte | `scripts/generate_widgetbook.sh` puis `dart format` / `flutter analyze --fatal-infos` (dans `widgetbook/`) | — | oui | pre-push | widgetbook |
| Widgetbook : un use case par widget, code généré à jour | `dart run scripts/check_widgetbook.dart app widgetbook` | — | oui | pre-push | widgetbook |
| Build web : CanvasKit local, service worker hors ligne stampé (liste de précache = contenu du build), fichiers indispensables | `scripts/build_web.sh` (`flutter build web --release --no-web-resources-cdn`, puis `pwa.dart stamp` et `verify`) ; `firebase.json` rejoue `pwa.dart verify` en `predeploy` | — | — | — | build-web, déploiements Firebase |
| Build web Widgetbook | `flutter build web --release` (dans `widgetbook/`) | — | — | — | widgetbook |
| Dépendances verrouillées | `flutter pub get --enforce-lockfile` (quand `CI=true`) | — | oui en CI | — | tous |

Hooks git : `.githooks/pre-commit` → `--fast`, `.githooks/pre-push` → `--full`
(installés par `scripts/setup.sh` : `git config core.hooksPath .githooks`).
Hook agent : l'événement `Stop` lance `scripts/check.sh --fast` lorsque `app/` ou
`scripts/` ont changé ; l'agent ne déclare jamais « terminé » avec un garde-fou rouge.

## Prérequis de l'outillage Firebase (FB1)

Le garde-fou « règles Firestore » exige **Node >= 24.12** (`package.json` : `engines` ;
`@firebase/rules-unit-testing` 6.0.0, `playwright-core` 1.64.1), **Java >= 21** (les émulateurs de `firebase-tools` 15
refusent Java < 21) et les dépendances épinglées (`package.json` + `package-lock.json`, `npm ci`).
`scripts/rules_test.sh` **échoue avec un message explicite** (code 1) si `node`, `java`, `npx`, `dart` (les écritures de l'import viennent de l'application : `app/tool/import_plan_fixture.dart`, FB7) ou
`node_modules` manquent ou sont trop anciens : jamais de saut silencieux. `scripts/setup.sh` fait les
mêmes vérifications puis `npm ci`. Les trois lanceurs d'émulateurs (`rules_test.sh`, `web_smoke.sh`, `emulator_e2e.sh`) partagent leurs contrôles dans `scripts/lib/prereqs.sh` (Node, Java, firebase, playwright-core, Chrome).

- **Versions réellement testées** (poste de développement du 2026-10-17) : Node 26.12.0, Java 27
  (OpenJDK, Homebrew), `firebase-tools` 15.34.0, `@firebase/rules-unit-testing` 6.0.0, `firebase` 13.0.0.
  La borne basse « Java 21 » (ADR 0024, décision 20) est celle que `firebase-tools` impose ; **la CI
  utilise Java 21 (Temurin)**, ce poste n'a pas pu l'exécuter en local. Plage acceptée par le script : Java >= 21 sans borne haute.
- Projet des tests : `demo-cfa-ffb` (préfixe `demo-` : aucun appel au projet réel) ; les tests refusent de
  s'exécuter hors de l'émulateur local (hôte `FIRESTORE_EMULATOR_HOST` obligatoire et local).
  Ports (`firebase.json`, bloc `emulators`) : Auth 9099, Firestore 8080, interface désactivée,
  `singleProjectMode`. Aucun déploiement n'est lancé par ces scripts.
- `scripts/emulator_e2e.sh` exige les mêmes prérequis que `scripts/web_smoke.sh` plus **Flutter** (il compile l'application en debug, ~1 à 2 min) et un port libre (`E2E_PORT`, 8099 par défaut) ; il arrête l'application et les émulateurs en sortant, même en cas d'échec.
- `scripts/web_smoke.sh` exige en plus **Google Chrome** (installé d'office sur les exécuteurs GitHub ubuntu et macOS ; aucun téléchargement de navigateur : `playwright-core` pilote le Chrome installé) et construit le web release (~1 min) ; il échoue explicitement si Chrome, `playwright-core` ou le build manquent.
- `--fast` est **inchangé** : il n'exige ni Java ni `node_modules` (seul Node est requis, pour le service worker).
- Le job CI `test` installe Node 24 et Java 21 (`setup-node`, `setup-java`), lance `npm ci` puis `check.sh --full`.

## Détail des contrôles

- **Analyse** : `app/analysis_options.yaml` inclut `very_good_analysis` ; seules
  `public_member_api_docs` et `unnecessary_type_name_in_constructor` sont désactivées
  (documentation interne, syntaxe de constructeur compatible freezed/injectable).
  Tout `info` fait échouer (`--fatal-infos`). Le code généré est exclu de l'analyse.
- **Architecture** : règles de [architecture.md](architecture.md). Le vérificateur
  est lui-même testé (`app/test/tool/architecture_rules_test.dart`).
- **Index Firestore** : `app/tool/check_indexes.dart` lit `lib/` (hors fichiers générés) et `../firestore.indexes.json`. Pour chaque instruction qui nomme une
  collection (`collectionGroup('c', field: 'f', ...)` ou `.collectionGroup('c').where('f', ...)`, `.collection('c')`) ou qui vit dans un fichier important le SDK :
  une requête de groupe exige l'exemption de champ `c.f` à portée `COLLECTION_GROUP` (`fieldOverrides`) ; une requête composée exige un index composite
  (`indexes`) de la collection, champs d'égalité puis tris dans l'ordre de la requête. Les `where` / `orderBy` des listes Dart et de drift ne sont pas concernés.
  Limite : analyse **textuelle** d'instructions à noms littéraux ; un nom non littéral est une **violation** (jamais deviné). Les requêtes à un seul champ
  d'égalité sur une collection (`DocumentStore.query`) n'ont besoin d'aucun index. Le contrôle est testé (`app/test/tool/check_indexes_test.dart`) : sur le dépôt
  réel, et par **mutation** (la copie de `firestore.indexes.json` sans l'exemption `members.uid` fait échouer le contrôle sur `store_memberships_source.dart` ;
  un index composite retiré d'une fixture le fait échouer). Ce que le contrôle ne prouve pas : que l'index soit **déployé** (`firebase deploy --only firestore:indexes`,
  à faire par l'utilisateur) ni que la requête ait la forme prévue à l'exécution ; l'émulateur n'impose pas les index.
- **Fiches de séance** : `app/tool/fiches.dart` valide chaque fichier du
  catalogue (`docs/knowledge/05-seances/catalogue/`) contre `FORMAT.md` § 7 et
  recalcule la structure (14 techniques, parties, tranches, séance précédente)
  depuis `catalogue-entrainement.yaml` : aucune constante pour le nombre de
  parties. Par défaut, chaque fichier présent est contrôlé ; `--complete`
  exige en plus les 28 séances (fin du lot L7) : c'est le mode de `check.sh` et de la CI. V12 (minutage) et V17
  (cohérence géométrique de `ghost_aim`) relèvent du test de contrat Dart.
  Testé par `app/test/tool/fiches_test.dart` (un cas rouge par règle) et
  `app/test/tool/sync_fiches_test.dart`.
- **Séances** : `scripts/validate_seances.dart` vérifie front matter (`public`,
  `duree_minutes`), cohérence public/durée (enfants 90 min, adultes 120 min),
  déroulé minuté contigu de 0 à la durée, étiquettes de source `[S]/[FFB]/[Web]/[Prop]`
  et ordre des phases Notion → Entraînement → Jeu. Code de sortie 1 en cas d'échec.
- **Couverture** : exclut `*.g.dart`, `*.freezed.dart`, `*.config.dart`, `l10n/generated`,
  `lib/main.dart` et `lib/app/di/injection.dart` ; échoue si un fichier de `lib/`
  n'est jamais chargé par un test.
- **Contrastes** : `app/test/unit/shared/ui/theme/contrast_test.dart` (exécuté avec
  les tests) recalcule les ratios WCAG des paires `onX/X` ; voir
  [design-system.md](design-system.md).
- **Widgetbook** : projet séparé `widgetbook/` (analyse stricte
  `very_good_analysis`). `scripts/check_widgetbook.dart` exige un use case par
  widget public et vérifie que `main.directories.g.dart` référence tous les
  use cases. Le build web est exécuté en CI (job `widgetbook`) ; en local :
  `cd widgetbook && flutter build web`.
- **Code généré** : jamais versionné (`.gitignore`), toujours régénéré par
  `scripts/generate.sh` (app) et `scripts/generate_widgetbook.sh` (Widgetbook) ;
  il n'y a donc pas de dérive à contrôler.

## Autres contrôles

- **Lecture seule de `--fast`** : `app/test/tool/check_fast_read_only_test.dart`
  copie le dépôt utile dans un dossier temporaire (`rsync`), y dépose un fichier mal formaté, lance le
  `scripts/check.sh --fast` **de la copie**, exige l'échec du formatage et
  prouve que la copie (chemin, taille, date de modification de chaque fichier)
  est identique avant/après. Le vrai arbre n'est jamais écrit : une exécution
  concurrente (hook, IDE, autre agent) ne peut pas échouer à cause du test.
- **Tests des garde-fous** : `app/test/tool/` exerce chaque script avec des
  entrées limites (`validate_seances_test`, `check_coverage_test`,
  `check_l10n_test`, `check_widgetbook_test`, `architecture_rules_test`).

- **Paquet `pdf`** (ADR 0021) : `tool/architecture` refuse `package:pdf/widgets.dart`,
  `package:pdf/src/` et `package:printing/` dans `lib/`, et tout `package:pdf/`
  hors de `features/export_sheet/data/` (cas rouges dans `architecture_rules_test`).
- **SDK de plateforme** (règle 9 d'[architecture.md](architecture.md)) : `firebase_auth`, `firebase_core` et
  `cloud_firestore` hors de `lib/app/platform/` (`firebase_core` aussi par le fichier généré `firebase_options.dart`), et
  `shared_preferences` hors de `lib/app/platform/shared_preferences_key_value_store.dart`, font échouer
  `tool/check_architecture.dart` (cas rouges dans `architecture_rules_test`).

## Hors périmètre actuel : mutation testing

Le mutation testing a été **retiré le 2026-10-12** (décision de l'animateur) : il
dépassait plusieurs heures sur la base de code actuelle (≈ 1250 mutants, suite
complète par mutant) et sera réintroduit plus tard, après mesure des performances.
Aucun script, seuil, job CI ni dépendance n'y est associé aujourd'hui ; la
qualité des tests repose sur la couverture, la relecture par l'agent `testeur-bdd`
et les tests de contrat. **Réévalué le 2026-10-17** ([ADR 0022](adr/0022-dette-outillage-scripts-wasm-mutation.md)) :
décision maintenue (580 fichiers de production, 431 de test, la durée ne s'est pas
améliorée) ; la mutation ciblée à la main sur les fichiers touchés est la pratique
en vigueur, avec une condition de réexamen écrite.

## Politique

- Pas de `skip`, `.only`, test factice, `// ignore` sans justification.
- Un garde-fou rouge se corrige à la source ; on ne baisse pas un seuil pour passer.
- Toute nouvelle règle de qualité s'ajoute dans `scripts/check.sh` (donc hooks + CI
  + agent d'un coup) et dans ce tableau.
