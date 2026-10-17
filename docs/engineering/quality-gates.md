# Garde-fous qualité (100 % déterministes, sans IA)

Source de vérité unique : **`scripts/check.sh`**. Les hooks git, le hook agent
(`.claude/settings.json`, événement `Stop`) et la CI l'appellent ; aucune règle
n'est dupliquée ailleurs.

```bash
scripts/check.sh --fast   # ~5 s : format, analyse, scripts, architecture, séances (lecture seule)
scripts/check.sh --full   # fast + l10n + tests + couverture + Widgetbook (~40 s)
COVERAGE_MIN=95 scripts/check.sh --full   # relever le seuil de couverture

scripts/sync_catalogue.sh [--check]       # copie / vérifie le catalogue (docs/knowledge -> app/assets)
scripts/sync_diagrammes.sh [--check]      # copie / vérifie les diagrammes à table (docs/knowledge -> app/assets)
scripts/sync_fiches.sh [--check]          # copie / vérifie les séances du catalogue (docs/knowledge -> app/assets)
(cd app && dart run tool/fiches.dart [--complete])   # valide les séances (FORMAT.md § 7)
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
| PWA : manifeste (champs, couleurs = thème, icônes `any`/`maskable` présentes et de la bonne taille, orientation libre), `index.html`, service worker, aucune URL externe ; icônes régénérées à l'identique | `dart run scripts/pwa.dart check` et `dart run scripts/generate_pwa_icons.dart --check` | oui | oui | pre-commit | quality |
| Comportement du service worker et du pont de mise à jour (précache et reprise, HTML refusé, purge des anciens caches, activation seulement sur demande, autre onglet, `/__/` non intercepté, worker non stampé), contrat Dart/JS du pont | `node --test scripts/pwa_js_test.mjs` (Node requis) | oui | oui | pre-commit | quality |
| Formatage | `dart format --output=none --set-exit-if-changed` (lib, test, tool, scripts) | oui | oui | pre-commit | quality |
| Analyse statique stricte | `flutter analyze --no-pub --fatal-infos` (`very_good_analysis` + strict-casts/inference/raw-types) | oui | oui | pre-commit | quality |
| Analyse des scripts Dart | `dart analyze --fatal-infos scripts` | oui | oui | pre-commit | quality |
| Architecture FSD + Clean | `dart run tool/check_architecture.dart` (dans `app/`) | oui | oui | pre-commit | quality |
| Séances générées | `dart run scripts/validate_seances.dart seances` | oui | oui | pre-commit | quality |
| l10n fr/en : mêmes clés | `dart run scripts/check_l10n.dart app/lib/shared/l10n` | — | oui | pre-push | test |
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

## Détail des contrôles

- **Analyse** : `app/analysis_options.yaml` inclut `very_good_analysis` ; seules
  `public_member_api_docs` et `unnecessary_type_name_in_constructor` sont désactivées
  (documentation interne, syntaxe de constructeur compatible freezed/injectable).
  Tout `info` fait échouer (`--fatal-infos`). Le code généré est exclu de l'analyse.
- **Architecture** : règles de [architecture.md](architecture.md). Le vérificateur
  est lui-même testé (`app/test/tool/architecture_rules_test.dart`).
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

## Hors périmètre actuel : mutation testing

Le mutation testing a été **retiré le 2026-10-12** (décision de l'animateur) : il
dépassait plusieurs heures sur la base de code actuelle (≈ 1250 mutants, suite
complète par mutant) et sera réintroduit plus tard, après mesure des performances.
Aucun script, seuil, job CI ni dépendance n'y est associé aujourd'hui ; la
qualité des tests repose sur la couverture, la relecture par l'agent `testeur-bdd`
et les tests de contrat.

## Politique

- Pas de `skip`, `.only`, test factice, `// ignore` sans justification.
- Un garde-fou rouge se corrige à la source ; on ne baisse pas un seuil pour passer.
- Toute nouvelle règle de qualité s'ajoute dans `scripts/check.sh` (donc hooks + CI
  + agent d'un coup) et dans ce tableau.
