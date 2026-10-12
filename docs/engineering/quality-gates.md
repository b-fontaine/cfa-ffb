# Garde-fous qualité (100 % déterministes, sans IA)

Source de vérité unique : **`scripts/check.sh`**. Les hooks git, le hook agent
(`.claude/settings.json`, événement `Stop`) et la CI l'appellent ; aucune règle
n'est dupliquée ailleurs.

```bash
scripts/check.sh --fast   # ~5 s : format, analyse, scripts, architecture, séances (lecture seule)
scripts/check.sh --full   # fast + l10n + tests + couverture + Widgetbook + mutation complète (~30 min mesurées)
SKIP_MUTATION=1 scripts/check.sh --full   # tout sauf la mutation (~40 s)
MUTATION_ARGS="--changed origin/main" scripts/check.sh --full   # mutation ciblée
COVERAGE_MIN=95 scripts/check.sh --full   # relever le seuil de couverture

scripts/mutation.sh                       # mutation complète (~30 min mesurées)
scripts/mutation.sh --changed [base-ref]  # fichiers lib/ modifiés vs base-ref (défaut HEAD) + non suivis
scripts/mutation.sh --files lib/a.dart …  # fichiers explicites
scripts/mutation.sh --jobs 3 --files …    # 3 copies : ~14 s/mutant mesurés (~18 s avec 1 worker)
scripts/sync_catalogue.sh [--check]       # copie / vérifie le catalogue (docs/knowledge -> app/assets)
```

## Tableau des garde-fous

| Garde-fou | Commande | `--fast` | `--full` | Hook git | CI (job) |
|---|---|:-:|:-:|---|---|
| Génération de code (build_runner, gen-l10n) | `scripts/generate.sh` | si manquant | oui | via check | quality / test / mutation / build-web |
| Catalogue : asset identique à la source | `scripts/sync_catalogue.sh --check` | oui | oui | pre-commit | quality |
| Fichiers web drift : `drift_worker.js` = paquet résolu, `sqlite3.wasm` = version verrouillée | `dart run scripts/sync_web_assets.dart --check` | oui | oui | pre-commit | quality |
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
| Mutation testing ≥ 85 % | `scripts/mutation.sh` (`mutation_test`, `app/mutation-test.xml`, copie temporaire de `app/`) | — | oui | pre-push | mutation (PR : `--changed`, hebdo/manuel : complète) |
| Build web | `flutter build web --release` | — | — | — | build-web |
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
- **Séances** : `scripts/validate_seances.dart` vérifie front matter (`public`,
  `duree_minutes`), cohérence public/durée (enfants 90 min, adultes 120 min),
  déroulé minuté contigu de 0 à la durée, étiquettes de source `[S]/[FFB]/[Web]/[Prop]`
  et ordre des phases Notion → Entraînement → Jeu. Code de sortie 1 en cas d'échec.
- **Couverture** : exclut `*.g.dart`, `*.freezed.dart`, `*.config.dart`, `l10n/generated`,
  `lib/main.dart` et `lib/app/di/injection.dart` ; échoue si un fichier de `lib/`
  n'est jamais chargé par un test.
- **Mutation** : `mutation_test` (mutations par règles regex, commande
  `flutter test --fail-fast -x tooling` par mutant). Seuil `failure="85"` dans
  `app/mutation-test.xml`, appliqué au score **global**.
  - **Copie temporaire** : `scripts/mutation.sh` copie `app/` (et `scripts/`) dans
    `mktemp -d`, y mute les fichiers et supprime la copie à la sortie (`trap`,
    même en cas d'échec ou d'interruption). L'arbre de travail n'est **jamais**
    modifié ; le script compare une empreinte de `lib/`, `test/`, `tool/` avant et
    après et échoue si elle diffère. On peut donc lancer d'autres tâches en parallèle.
  - **Rapports** : `app/build/mutation-report/summary.md` (score global et chaque
    mutant non détecté : fichier, ligne, mutation) et
    `app/build/mutation-report/part-N/mutation-test-report.html` (rapport détaillé).
  - **Mode ciblé** : `--changed [base-ref]` génère un `mutation-test.xml`
    temporaire limité aux `lib/**.dart` modifiés (`git diff` contre le merge-base
    avec `base-ref`, plus les fichiers non suivis ; hors code généré,
    `main.dart`, `injection.dart`). Sans fichier modifié : sortie 0 immédiate.
  - **Répartition par mutant** : un passage à blanc énumère les mutants, qui sont
    répartis par blocs de lignes entre `--jobs N` workers (chacun sa copie,
    plafonné à `nproc - 2`). Le total testé doit égaler le total énuméré.
  - **Tests exclus** : les tests tagués `tooling` (`app/dart_test.yaml`, scripts
    shell du dépôt) sont exclus des mutants ; ils tournent avec `flutter test`.
  - **Parallélisme : pas de gain mesuré** (voir ci-dessous) ; le défaut est
    `--jobs 1` (un seul worker, `flutter test` utilise alors tous les cœurs).
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

## Mutation : mesures, mutant équivalent, CI

- **Durée mesurée** (portable i7-1255U, 12 threads, 140 mutants, suite complète
  par mutant) : mutation **complète ≈ 30 min** (29 min 36 s, 1 worker) ; mutation
  **ciblée** ≈ 10 à 13 s par mutant (127 s pour un fichier de 16 mutants).
  Ces temps croissent avec le nombre de mutants et la durée de la suite.
- **Parallélisme par copies : aucun gain mesuré** sur cette machine. Mêmes
  mutants, mêmes tests :

  | Jeu | Workers | Durée | Par mutant |
  |---|---|---|---|
  | 26 mutants | 1 | 246 s | 9,5 s |
  | 26 mutants | 10 | 295 s | 11,3 s |
  | 38 mutants | 3 | 493 s | 13,0 s |

  `flutter test` occupe déjà tous les cœurs (≈ 4 cœurs en moyenne) ; plusieurs
  copies se disputent le CPU et recompilent chacune à froid. L'option `--jobs N`
  reste disponible pour une machine avec plus de cœurs réels (défaut 1).
- **Mutants équivalents documentés** (score global du dernier run complet :
  **139 / 140 = 99,3 %**, seuil 85 %) :

  | Fichier | Ligne | Mutation | Justification |
  |---|---|---|---|
  | `lib/shared/ui/theme/app_theme.dart` | 42 | `Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget,)` : règle `builtin.function.arg3` | Le « mutant » est textuellement identique au code source (les deux arguments sont la même constante et la règle permute le 3e élément, vide, avec le 2e) : aucun comportement ne change, aucun test ne peut le tuer. |
  | `lib/shared/lib/rules_config.dart` | 21 | `@Default(50)` -> `@Default(-50)` (idem pour les autres `@Default`) | `@Default` n'est lu que par le générateur `freezed` : le code généré n'est pas régénéré dans la copie mutée, donc le comportement ne change pas. Les valeurs par défaut sont vérifiées par `rules_config_test.dart`. |
  | `lib/shared/persistence/app_database.dart` | 12 | `tables: [Students, …]` -> `tables: []` | La liste n'est lue que par le générateur `drift_dev` : le code généré n'est pas régénéré dans la copie mutée. Les tables sont vérifiées par la suite de contrat et par `migration_test.dart` (schéma = instantané). |

  Mutation ciblée de la persistance (2026-10-12, un lot de fichiers par
  exécution : un mutant coûte ~25-35 s avec la suite de contrat, une commande
  foreground est limitée à 10 min, donc ~15 mutants par lot) : 0 survivant hors
  la ligne ci-dessus.

  Les 13 autres mutants non détectés du rapport précédent sont tués par des
  tests : valeurs exactes de `AppSpacing`/`AppRadii` (`-32`, `-12`, `-16`), hauteurs
  de ligne de chaque style de `AppTypography`, formule du `hashCode` de
  `StatusColors` (permutations d'arguments), score parfait de `ScoreIndicator`
  (`score <= total`).
- **CI** (`.github/workflows/ci.yml`, job `mutation`) :
  - `pull_request` : `scripts/mutation.sh --changed origin/<base>` (mutation
    **ciblée**, fichiers modifiés vs la base) ;
  - `schedule` (dimanche 02:00 UTC) et `workflow_dispatch` : mutation **complète**
    (~30 min) ;
  - `push` sur `main` : pas de mutation (déjà exécutée sur la PR).
  Le rapport (`app/build/mutation-report`) est publié en artefact.
- **Lecture seule de `--fast`** : `app/test/tool/check_fast_read_only_test.dart`
  (tag `tooling`) copie le dépôt utile dans un dossier temporaire (`rsync`,
  comme `scripts/mutation.sh`), y dépose un fichier mal formaté, lance le
  `scripts/check.sh --fast` **de la copie**, exige l'échec du formatage et
  prouve que la copie (chemin, taille, date de modification de chaque fichier)
  est identique avant/après. Le vrai arbre n'est jamais écrit : une exécution
  concurrente (hook, IDE, autre agent) ne peut pas échouer à cause du test.
- **Tests des garde-fous** : `app/test/tool/` exerce chaque script avec des
  entrées limites (`validate_seances_test`, `check_coverage_test`,
  `check_l10n_test`, `check_widgetbook_test`, `architecture_rules_test`).

## Politique

- Pas de `skip`, `.only`, test factice, `// ignore` sans justification.
- Un garde-fou rouge se corrige à la source ; on ne baisse pas un seuil pour passer.
- Toute nouvelle règle de qualité s'ajoute dans `scripts/check.sh` (donc hooks + CI
  + agent d'un coup) et dans ce tableau.
